import ComposableArchitecture
import Foundation

extension AppFeature {
    // MARK: - Lifecycle

    func start(_ state: inout State) -> Effect<Action> {
        let now = now
        state.now = now
        if state.installDate == nil {
            state.$installDate.withLock { $0 = now }
        }
        let launchAtLogin = launchAtLoginClient.status() == .enabled
        if state.settings.launchAtLogin != launchAtLogin {
            state.$settings.withLock { $0.launchAtLogin = launchAtLogin }
        }
        let consent = state.consent
        let days = calendar.dateComponents([.day], from: state.installDate ?? now, to: now).day ?? 0
        return .merge(
            .run { send in
                await analytics.configure(consent)
                await analytics.track(.appLaunched(launchAtLogin: launchAtLogin, daysSinceInstall: max(days, 0)))
                await send(.entitlementsUpdated(storeClient.currentEntitlements()))
                await send(.accountRestored(authClient.restorePreviousSignIn()))
            },
            .run { send in
                for await entitlements in storeClient.updates() {
                    await send(.entitlementsUpdated(entitlements))
                }
            },
            .run { send in
                for await _ in workspaceClient.wakeNotifications() {
                    await send(.systemWoke)
                }
            },
            .run { send in
                for await _ in clock.timer(interval: .seconds(60)) {
                    await send(.refreshTick)
                }
            },
            .run { send in
                for await _ in menuBarClock.timer(interval: .seconds(15)) {
                    await send(.clockTick)
                }
            }
        )
        .cancellable(id: CancelID.lifetime, cancelInFlight: true)
    }

    func signedIn(_ state: inout State, _ account: GoogleAccount) -> Effect<Action> {
        state.auth = .signedIn(account)
        state.settingsScreen.account = account
        let properties = personProperties(state)
        // Calendars first, so the sync event knows how many there are.
        return .run { send in
            await analytics.identify(account.email, properties)
            if let calendars = try? await calendarClient.calendars() {
                await send(.calendarsResponse(calendars))
            }
            await send(.refresh)
        }
    }

    func signOut(_ state: inout State) -> Effect<Action> {
        state.auth = .signedOut
        state.settingsScreen.account = nil
        state.events = []
        state.calendars = []
        state.nextAlert = nil
        state.offlineSince = nil
        return .merge(
            .cancel(id: CancelID.alertTimer),
            .cancel(id: CancelID.refresh),
            .run { _ in
                await authClient.signOut()
                await analytics.track(.signout)
            }
        )
    }

    func personProperties(_ state: State) -> [String: AnalyticsValue] {
        var properties = state.personProperties
        properties["locale"] = .string(Locale.current.identifier)
        if let installDate = state.installDate {
            properties["install_date"] = .string(installDate.formatted(.iso8601.year().month().day()))
        }
        return properties
    }

    func updateEntitlements(_ state: inout State, _ entitlements: Entitlements) -> Effect<Action> {
        let wasPro = state.entitlements.isPro
        state.$entitlements.withLock {
            $0.isPro = entitlements.isPro
            $0.purchasedAt = entitlements.purchasedAt ?? $0.purchasedAt
        }
        if entitlements.isPro, !state.entitlements.proDefaultsApplied {
            state.$settings.withLock { $0.applyProDefaults() }
            state.$entitlements.withLock { $0.proDefaultsApplied = true }
        }
        // `is_pro` itself is sent by the person-properties onChange.
        guard !wasPro, entitlements.isPro, let purchasedAt = state.entitlements.purchasedAt else { return .none }
        let properties: [String: AnalyticsValue] = ["pro_purchased_at": .string(purchasedAt.formatted(.iso8601))]
        return .run { _ in await analytics.setPersonProperties(properties) }
    }

    // MARK: - Sync

    func eventsLoaded(_ state: inout State, _ events: [CalendarEvent], startedAt: Date) -> Effect<Action> {
        let now = now
        state.events = IdentifiedArray(events, uniquingIDsWith: { first, _ in first })
        state.lastSyncAt = now
        state.offlineSince = nil
        state.firedAlerts = state.firedAlerts.filter { $0.value > now }
        let calendarsCount = state.effectiveSettings.selectedCalendarIDs?.count ?? state.calendars.count
        let synced = AnalyticsEvent.calendarSynced(
            calendarsCount: calendarsCount,
            events24hCount: events.count { !$0.isAllDay },
            eventsWithLinkCount: events.count { $0.meetingLink != nil },
            durationMs: max(Int((now.timeIntervalSince(startedAt) * 1000).rounded()), 0),
            errorType: nil
        )
        return .merge(
            .run { _ in await analytics.track(synced) },
            scheduleNext(&state, includeInProgress: false)
        )
    }

    func syncFailed(_ state: inout State, _ error: CalendarError, startedAt: Date) -> Effect<Action> {
        let now = now
        var effects: [Effect<Action>] = [
            .run { _ in
                await analytics.track(.calendarSynced(
                    calendarsCount: 0, events24hCount: 0, eventsWithLinkCount: 0,
                    durationMs: max(Int((now.timeIntervalSince(startedAt) * 1000).rounded()), 0),
                    errorType: error.analyticsType
                ))
            },
        ]
        switch error {
        case .unauthorized:
            // Keep the cached events and keep alerting with them; show the disconnected state.
            if let account = state.auth.account {
                state.auth = .sessionExpired(email: account.email)
            }
            state.settingsScreen.account = nil
            effects.append(.run { _ in await authClient.signOut() })
        case .offline:
            state.offlineSince = state.offlineSince ?? now
        case .server, .decoding:
            effects.append(.run { _ in await analytics.track(.errorOccurred(type: error.analyticsType, code: error.code)) })
        }
        return .merge(effects)
    }

    // MARK: - Scheduling

    func scheduleNext(_ state: inout State, includeInProgress: Bool) -> Effect<Action> {
        let now = now
        guard let next = AlertScheduler.next(
            events: Array(state.events),
            now: now,
            settings: state.effectiveSettings,
            fired: Set(state.firedAlerts.keys),
            includeInProgress: includeInProgress,
            calendar: calendar
        ) else {
            state.nextAlert = nil
            return .cancel(id: CancelID.alertTimer)
        }
        let changed = state.nextAlert != next
        state.nextAlert = next
        let delay = next.fireAt.timeIntervalSince(now)
        guard delay > 0 else {
            // Late (after wake or a just-created event): fire now.
            return .merge(.cancel(id: CancelID.alertTimer), .send(.alertDue(next, includeInProgress ? .wake : .scheduled)))
        }
        let timer: Effect<Action> = .run { send in
            try await clock.sleep(for: .seconds(delay))
            await send(.alertDue(next, .scheduled))
        }
        .cancellable(id: CancelID.alertTimer, cancelInFlight: true)
        guard changed else { return timer }
        return .merge(timer, .run { _ in await analytics.track(.alertScheduled(secondsUntilFire: Int(delay.rounded()))) })
    }

    func presentAlert(_ state: inout State, _ scheduled: ScheduledAlert, trigger: AlertTrigger) -> Effect<Action> {
        let now = now
        let effective = state.effectiveSettings
        var effects: [Effect<Action>] = []
        if trigger != .test {
            for event in [scheduled.event] + scheduled.overlapping {
                state.firedAlerts[event.dedupeKey] = event.end
            }
            let meetings = 1 + scheduled.additionalCount
            state.$weeklyMeetings.withLock { $0 = $0.adding(meetings, at: now, calendar: calendar) }
        }
        if let current = state.alert {
            let replaced = AnalyticsEvent.alertDismissed(
                reason: .replaced,
                secondsShown: Int(now.timeIntervalSince(current.shownAt).rounded()),
                secondsToStart: Int(current.event.start.timeIntervalSince(now).rounded()),
                provider: current.event.meetingLink?.provider
            )
            effects.append(.run { _ in await analytics.track(replaced) })
        }
        state.alert = AlertFeature.State(
            event: scheduled.event,
            additionalCount: scheduled.additionalCount,
            proHook: scheduled.proHook,
            leadTimeSeconds: effective.leadTimeSeconds,
            trigger: trigger,
            now: now
        )
        let event = scheduled.event
        effects.append(.run { _ in
            await soundClient.play(effective.sound)
            let screens = await applicationClient.screensCount()
            await analytics.track(.alertShown(
                leadTime: effective.leadTimeSeconds,
                provider: event.meetingLink?.provider,
                screensCount: screens,
                isDeclined: event.attendeeStatus == .declined,
                hasOtherAttendees: event.hasOtherAttendees,
                overlappingCount: scheduled.additionalCount,
                trigger: trigger,
                proHookShown: scheduled.proHook
            ))
        })
        if trigger != .test {
            effects.append(scheduleNext(&state, includeInProgress: false))
        }
        return .merge(effects)
    }

    func alertFinished(_ state: inout State, _ reason: DismissReason) -> Effect<Action> {
        guard let alert = state.alert else { return .none }
        let now = now
        let secondsToStart = Int(alert.event.start.timeIntervalSince(now).rounded())
        let dismissed = AnalyticsEvent.alertDismissed(
            reason: reason,
            secondsShown: Int(now.timeIntervalSince(alert.shownAt).rounded()),
            secondsToStart: secondsToStart,
            provider: alert.event.meetingLink?.provider
        )
        if state.entitlements.isPro, alert.trigger != .test {
            let onTime = PunctualityStats.isOnTime(joined: reason == .join, secondsToStart: secondsToStart)
            state.$stats.withLock { $0 = $0.recording(onTime: onTime, at: now, calendar: calendar) }
        }
        if alert.proHook != nil {
            state.lastProHookAt = now
        }
        state.alert = nil
        return .run { _ in await analytics.track(dismissed) }
    }

    func testAlert(_ state: inout State, source: TestAlertSource) -> Effect<Action> {
        let now = now
        let lead = state.effectiveSettings.leadTimeSeconds
        let fireAt = now.addingTimeInterval(Self.testAlertDelay.timeInterval)
        let start = fireAt.addingTimeInterval(TimeInterval(lead))
        let event = CalendarEvent(
            id: "hey-you-test",
            calendarID: "hey-you",
            title: String(localized: "Hey You! test", bundle: .module),
            start: start,
            end: start.addingTimeInterval(30 * 60),
            meetingLink: MeetingLink(provider: .other, url: AppConfig.projectURL),
            hasOtherAttendees: true,
            htmlLink: AppConfig.projectURL
        )
        let scheduled = ScheduledAlert(event: event, fireAt: fireAt)
        return .run { send in
            await analytics.track(.testAlertTriggered(source: source))
            try await clock.sleep(for: Self.testAlertDelay)
            await send(.alertDue(scheduled, .test))
        }
        .cancellable(id: CancelID.testAlert, cancelInFlight: true)
    }

    // MARK: - Children

    func menuBar(_ state: inout State, _ action: MenuBarFeature.Action) -> Effect<Action> {
        switch action {
        case .openPaywall:
            let fromHook = state.lastProHookAt.map { now.timeIntervalSince($0) < Self.hookAttributionWindow } ?? false
            state.paywall = PaywallFeature.State(source: fromHook ? .alertHook : .menu)
            return .none
        case .statsTapped:
            guard !state.entitlements.isPro else { return .none }
            state.paywall = PaywallFeature.State(source: .stats)
            return .none
        case .connectGoogle:
            state.onboarding = OnboardingFeature.State()
            return .none
        case .refreshNow:
            return .send(.refresh)
        case .testAlert:
            return testAlert(&state, source: .menu)
        case .quit:
            let alertVisible = state.alert != nil
            return .run { _ in
                await analytics.track(.appQuit(alertVisible: alertVisible))
                await applicationClient.terminate()
            }
        }
    }

    func onboardingDelegate(_ state: inout State, _ delegate: OnboardingFeature.Action.Delegate) -> Effect<Action> {
        switch delegate {
        case let .signedIn(account):
            state.$onboardingCompleted.withLock { $0 = true }
            return signedIn(&state, account)
        case let .launchAtLoginChanged(enabled):
            state.$settings.withLock { $0.launchAtLogin = enabled }
            return .run { _ in await analytics.track(.settingChanged(.launchAtLogin(enabled))) }
        case .testAlert:
            state.onboarding = nil
            return testAlert(&state, source: .onboarding)
        case .finished:
            state.onboarding = nil
            return .none
        }
    }

    func settingsDelegate(_ state: inout State, _ delegate: SettingsFeature.Action.Delegate) -> Effect<Action> {
        switch delegate {
        case let .openPaywall(source):
            state.paywall = PaywallFeature.State(source: source)
            return .none
        case .signOut:
            return signOut(&state)
        case .connect:
            state.onboarding = OnboardingFeature.State()
            return .none
        case .testAlert:
            return testAlert(&state, source: .settings)
        case let .entitlementsUpdated(entitlements):
            return .send(.entitlementsUpdated(entitlements))
        }
    }
}
