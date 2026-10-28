import ComposableArchitecture
import Foundation

/// Root feature: auth, sync loop, scheduling, alert presentation, Pro state and analytics.
@Reducer
public struct AppFeature: Sendable {
    public enum AuthState: Equatable, Sendable {
        /// Restoring the previous sign-in.
        case unknown
        case signedOut
        case signedIn(GoogleAccount)
        /// Google rejected the token and refresh failed (PRD §5.10).
        case sessionExpired(email: String)

        public var account: GoogleAccount? {
            if case let .signedIn(account) = self {
                return account
            }
            return nil
        }

        public var isSessionExpired: Bool {
            if case .sessionExpired = self {
                return true
            }
            return false
        }
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        public var auth: AuthState = .unknown
        public var events: IdentifiedArrayOf<CalendarEvent> = []
        public var calendars: [CalendarSummary] = []
        public var nextAlert: ScheduledAlert?
        /// Dedupe key → event end. Entries are purged once the event is over.
        public var firedAlerts: [String: Date] = [:]
        public var lastSyncAt: Date?
        /// Set on the first failed refresh for lack of network (PRD §5.10, B.14).
        public var offlineSince: Date?
        /// When the last alert with a Pro hook was dismissed: a paywall opened soon after counts as `alert_hook`.
        public var lastProHookAt: Date?
        /// Wall-clock time for the menu bar (countdown, "next in"), refreshed every 15 s.
        public var now = Date.distantPast
        @Shared(.appSettings) public var settings
        @Shared(.consent) public var consent
        @Shared(.entitlements) public var entitlements
        @Shared(.punctuality) public var stats
        @Shared(.weeklyMeetings) public var weeklyMeetings
        @Shared(.installDate) public var installDate
        @Shared(.onboardingCompleted) public var onboardingCompleted
        @Presents public var alert: AlertFeature.State?
        @Presents public var paywall: PaywallFeature.State?
        @Presents public var onboarding: OnboardingFeature.State?
        public var settingsScreen = SettingsFeature.State()

        public init() {}

        public var effectiveSettings: EffectiveSettings {
            EffectiveSettings(settings, isPro: entitlements.isPro)
        }

        public var isAlertVisible: Bool {
            alert != nil
        }

        /// PostHog person properties derived from state (PRD §6.1). Sent when they change.
        public var personProperties: [String: AnalyticsValue] {
            let effective = effectiveSettings
            var properties: [String: AnalyticsValue] = [
                "is_pro": .bool(effective.isPro),
                "lead_time": .int(effective.leadTimeSeconds),
                "launch_at_login": .bool(settings.launchAtLogin),
                "weekly_meetings_bucket": .string(weeklyMeetings.bucket),
            ]
            let calendarsCount = effective.selectedCalendarIDs?.count ?? calendars.count
            if calendarsCount > 0 {
                properties["calendars_count"] = .int(calendarsCount)
            }
            return properties
        }
    }

    public enum Action: Sendable {
        case task
        case accountRestored(GoogleAccount?)
        case entitlementsUpdated(Entitlements)
        case refreshTick
        case refresh
        case eventsResponse(Result<[CalendarEvent], CalendarError>, startedAt: Date)
        case calendarsResponse([CalendarSummary])
        case alertDue(ScheduledAlert, AlertTrigger)
        case systemWoke
        case clockTick
        case menuBar(MenuBarFeature.Action)
        case alert(PresentationAction<AlertFeature.Action>)
        case paywall(PresentationAction<PaywallFeature.Action>)
        case onboarding(PresentationAction<OnboardingFeature.Action>)
        case settingsScreen(SettingsFeature.Action)
    }

    enum CancelID {
        case lifetime
        case alertTimer
        case refresh
        case testAlert
    }

    /// Events are fetched for the next 24 h.
    public static let syncWindow: TimeInterval = 24 * 3600
    /// "Test alert" appears after 5 s (PRD B.15).
    public static let testAlertDelay: Duration = .seconds(5)
    /// A paywall opened within this time after a Pro hook is attributed to the hook.
    public static let hookAttributionWindow: TimeInterval = 15 * 60

    @Dependency(\.authClient) var authClient
    @Dependency(\.calendarClient) var calendarClient
    @Dependency(\.storeClient) var storeClient
    @Dependency(\.analyticsClient) var analytics
    @Dependency(\.workspaceClient) var workspaceClient
    @Dependency(\.soundClient) var soundClient
    @Dependency(\.applicationClient) var applicationClient
    @Dependency(\.launchAtLoginClient) var launchAtLoginClient
    @Dependency(\.continuousClock) var clock
    @Dependency(\.menuBarClock) var menuBarClock
    @Dependency(\.date.now) var now
    @Dependency(\.calendar) var calendar

    public init() {}

    public var body: some ReducerOf<Self> {
        CombineReducers {
            Scope(state: \.settingsScreen, action: \.settingsScreen) {
                SettingsFeature()
            }
            core
        }
        // Any change to the effective settings (Settings window, purchase, refund) reschedules.
        .onChange(of: \.effectiveSettings) { old, state in
            let reschedule = scheduleNext(&state, includeInProgress: false)
            guard old.selectedCalendarIDs != state.effectiveSettings.selectedCalendarIDs else { return reschedule }
            return .merge(reschedule, .send(.refresh))
        }
        // Keep PostHog person properties current, sending only what changed.
        .onChange(of: \.personProperties) { old, state in
            let changed = state.personProperties.filter { old[$0.key] != $0.value }
            guard !changed.isEmpty, state.auth.account != nil else { return .none }
            return .run { _ in await analytics.setPersonProperties(changed) }
        }
    }

    private var core: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return start(&state)

            case let .accountRestored(account):
                guard let account else {
                    state.auth = .signedOut
                    if !state.onboardingCompleted {
                        state.onboarding = OnboardingFeature.State()
                    }
                    return .none
                }
                return signedIn(&state, account)

            case let .entitlementsUpdated(entitlements):
                return updateEntitlements(&state, entitlements)

            case .refreshTick:
                return .send(.refresh)

            case .refresh:
                guard state.auth.account != nil else { return .none }
                let now = now
                let ids = state.effectiveSettings.selectedCalendarIDs
                return .run { send in
                    do {
                        let events = try await calendarClient.upcomingEvents(now, now.addingTimeInterval(Self.syncWindow), ids)
                        await send(.eventsResponse(.success(events), startedAt: now))
                    } catch {
                        await send(.eventsResponse(.failure(CalendarError(error)), startedAt: now))
                    }
                }
                .cancellable(id: CancelID.refresh, cancelInFlight: true)

            case let .eventsResponse(.success(events), startedAt):
                return eventsLoaded(&state, events, startedAt: startedAt)

            case let .eventsResponse(.failure(error), startedAt):
                return syncFailed(&state, error, startedAt: startedAt)

            case let .calendarsResponse(calendars):
                state.calendars = calendars
                state.settingsScreen.calendars = calendars
                return .none

            case let .alertDue(scheduled, trigger):
                return presentAlert(&state, scheduled, trigger: trigger)

            case .clockTick:
                state.now = now
                return .none

            case .systemWoke:
                // Fire right away with what we have (network may not be back yet), then refresh.
                return .merge(scheduleNext(&state, includeInProgress: true), .send(.refresh))

            case let .menuBar(action):
                return menuBar(&state, action)

            case let .alert(.presented(.delegate(.finished(reason)))):
                return alertFinished(&state, reason)

            case .alert:
                return .none

            case let .paywall(.presented(.delegate(.purchased(entitlements)))),
                 let .paywall(.presented(.delegate(.restored(entitlements)))):
                return .send(.entitlementsUpdated(entitlements))

            case .paywall:
                return .none

            case let .onboarding(.presented(.delegate(delegate))):
                return onboardingDelegate(&state, delegate)

            case .onboarding:
                return .none

            case let .settingsScreen(.delegate(delegate)):
                return settingsDelegate(&state, delegate)

            case .settingsScreen:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert) { AlertFeature() }
        .ifLet(\.$paywall, action: \.paywall) { PaywallFeature() }
        .ifLet(\.$onboarding, action: \.onboarding) { OnboardingFeature() }
    }
}
