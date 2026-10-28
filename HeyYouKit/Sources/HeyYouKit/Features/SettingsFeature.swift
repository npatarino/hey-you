import ComposableArchitecture
import Foundation

/// Settings window. Pro controls are locked for free users; touching one opens the paywall (`settings_lock`).
@Reducer
public struct SettingsFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        @Shared(.appSettings) public var settings
        @Shared(.entitlements) public var entitlements
        @Shared(.consent) public var consent
        public var account: GoogleAccount?
        public var calendars: [CalendarSummary] = []
        public var launchAtLogin: LaunchAtLoginStatus = .disabled
        public var isRestoring = false
        public var message: String?

        public init(account: GoogleAccount? = nil) {
            self.account = account
        }

        public var isPro: Bool {
            entitlements.isPro
        }

        public var effective: EffectiveSettings {
            EffectiveSettings(settings, isPro: isPro)
        }

        public func isCalendarSelected(_ id: String) -> Bool {
            settings.selectedCalendarIDs?.contains(id) ?? true
        }
    }

    public enum Action: Sendable, Equatable {
        case task
        case calendarsResponse([CalendarSummary])
        case setLaunchAtLogin(Bool)
        case openLoginItemsTapped
        case testAlertTapped
        case setLeadTime(Int)
        case setSound(AlertSound)
        case setShowCountdown(Bool)
        case setIgnoreDeclined(Bool)
        case setIgnoreWithoutOtherAttendees(Bool)
        case setOnlyWithLink(Bool)
        case setWorkingHoursEnabled(Bool)
        case toggleWorkday(Int)
        case setWorkingHoursStart(minute: Int)
        case setWorkingHoursEnd(minute: Int)
        case toggleCalendar(String)
        case setUsageConsent(Bool)
        case setEmailConsent(Bool)
        case lockTapped
        case unlockProTapped
        case restoreTapped
        case restoreResponse(Result<Entitlements, StoreError>)
        case signOutTapped
        case connectTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Sendable, Equatable {
            case openPaywall(PaywallSource)
            case signOut
            case connect
            case testAlert
            case entitlementsUpdated(Entitlements)
        }
    }

    @Dependency(\.calendarClient) var calendarClient
    @Dependency(\.launchAtLoginClient) var launchAtLoginClient
    @Dependency(\.analyticsClient) var analytics
    @Dependency(\.storeClient) var storeClient
    @Dependency(\.soundClient) var soundClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                state.launchAtLogin = launchAtLoginClient.status()
                guard state.account != nil else { return .none }
                return .run { send in
                    if let calendars = try? await calendarClient.calendars() {
                        await send(.calendarsResponse(calendars))
                    }
                }

            case let .calendarsResponse(calendars):
                state.calendars = calendars
                return .none

            case let .setLaunchAtLogin(enabled):
                let status = (try? launchAtLoginClient.set(enabled)) ?? launchAtLoginClient.status()
                state.launchAtLogin = status
                state.$settings.withLock { $0.launchAtLogin = status == .enabled }
                return track(.launchAtLogin(status == .enabled))

            case .openLoginItemsTapped:
                return .run { _ in launchAtLoginClient.openSystemSettings() }

            case .testAlertTapped:
                return .send(.delegate(.testAlert))

            case .lockTapped, .unlockProTapped:
                return .send(.delegate(.openPaywall(.settingsLock)))

            case .setLeadTime, .setSound, .setShowCountdown, .setIgnoreDeclined, .setIgnoreWithoutOtherAttendees,
                 .setOnlyWithLink, .setWorkingHoursEnabled, .toggleWorkday, .setWorkingHoursStart, .setWorkingHoursEnd,
                 .toggleCalendar:
                // Pro gate: a free user touching a Pro control gets the paywall, never the change.
                guard state.isPro else { return .send(.delegate(.openPaywall(.settingsLock))) }
                return reduceProSetting(&state, action)

            case let .setUsageConsent(enabled):
                state.$consent.withLock { $0.usageAnalytics = enabled }
                return consentChanged(state.consent)

            case let .setEmailConsent(enabled):
                state.$consent.withLock { $0.emailContact = enabled }
                let email = state.account?.email
                return .merge(
                    consentChanged(state.consent),
                    .run { _ in
                        if enabled {
                            await analytics.identify(email, [:])
                        } else {
                            await analytics.setPersonProperties(["email": ""])
                        }
                    }
                )

            case .restoreTapped:
                guard !state.isRestoring else { return .none }
                state.isRestoring = true
                state.message = nil
                return .run { send in
                    do {
                        try await send(.restoreResponse(.success(storeClient.restore())))
                    } catch {
                        await send(.restoreResponse(.failure(StoreError(error))))
                    }
                }

            case let .restoreResponse(.success(entitlements)):
                state.isRestoring = false
                guard entitlements.isPro else {
                    state.message = String(localized: "No previous purchase found for this Apple ID.", bundle: .module)
                    return .none
                }
                state.message = String(localized: "Purchase restored. Thanks for supporting Hey You!", bundle: .module)
                return .merge(
                    .run { _ in await analytics.track(.purchaseRestored(priceVariant: AppConfig.defaultPriceVariant)) },
                    .send(.delegate(.entitlementsUpdated(entitlements)))
                )

            case .restoreResponse(.failure):
                state.isRestoring = false
                state.message = String(localized: "Couldn't reach the App Store. Try again.", bundle: .module)
                return .none

            case .signOutTapped:
                return .send(.delegate(.signOut))

            case .connectTapped:
                return .send(.delegate(.connect))

            case .delegate:
                return .none
            }
        }
    }

    private func reduceProSetting(_ state: inout State, _ action: Action) -> Effect<Action> {
        switch action {
        case let .setLeadTime(seconds):
            let value = LeadTime.clamp(seconds)
            guard value != state.settings.leadTimeSeconds else { return .none }
            state.$settings.withLock { $0.leadTimeSeconds = value }
            return track(.leadTime(value))
        case let .setSound(sound):
            state.$settings.withLock { $0.sound = sound }
            return .merge(track(.sound(sound)), .run { _ in await soundClient.play(sound) })
        case let .setShowCountdown(on):
            state.$settings.withLock { $0.showCountdownInMenuBar = on }
            return track(.showCountdownInMenuBar(on))
        case let .setIgnoreDeclined(on):
            state.$settings.withLock { $0.ignoreDeclined = on }
            return track(.ignoreDeclined(on))
        case let .setIgnoreWithoutOtherAttendees(on):
            state.$settings.withLock { $0.ignoreWithoutOtherAttendees = on }
            return track(.ignoreWithoutOtherAttendees(on))
        case let .setOnlyWithLink(on):
            state.$settings.withLock { $0.onlyEventsWithMeetingLink = on }
            return track(.onlyEventsWithMeetingLink(on))
        case let .setWorkingHoursEnabled(on):
            state.$settings.withLock { $0.workingHours = on ? ($0.workingHours ?? .officeDefault) : nil }
            return track(.workingHours(enabled: on))
        case .toggleWorkday, .setWorkingHoursStart, .setWorkingHoursEnd:
            state.$settings.withLock { Self.editWorkingHours(&$0, action) }
            return .none
        case let .toggleCalendar(id):
            let all = Set(state.calendars.map(\.id))
            var selected = state.settings.selectedCalendarIDs ?? all
            if selected.contains(id) {
                // Always keep at least one calendar.
                guard selected.count > 1 else { return .none }
                selected.remove(id)
            } else {
                selected.insert(id)
            }
            let newValue: Set<String>? = selected == all ? nil : selected
            state.$settings.withLock { $0.selectedCalendarIDs = newValue }
            return track(.selectedCalendarsCount(newValue?.count))
        default:
            return .none
        }
    }

    static func editWorkingHours(_ settings: inout AppSettings, _ action: Action) {
        var hours = settings.workingHours ?? .officeDefault
        switch action {
        case let .toggleWorkday(weekday) where (1 ... 7).contains(weekday):
            if hours.weekdays.contains(weekday) {
                hours.weekdays.remove(weekday)
            } else {
                hours.weekdays.insert(weekday)
            }
        case let .setWorkingHoursStart(minute):
            hours.startMinute = min(max(minute, 0), hours.endMinute - 15)
        case let .setWorkingHoursEnd(minute):
            hours.endMinute = max(min(minute, 24 * 60), hours.startMinute + 15)
        default:
            return
        }
        settings.workingHours = hours
    }

    private func track(_ change: SettingChange) -> Effect<Action> {
        .run { _ in await analytics.track(.settingChanged(change)) }
    }

    private func consentChanged(_ consent: Consent) -> Effect<Action> {
        .run { _ in
            await analytics.configure(consent)
            await analytics.track(.consentChanged(usage: consent.usageAnalytics, email: consent.emailContact, source: .settings))
        }
    }
}
