import Foundation

/// A property value sent to analytics. Only numbers, booleans and strings that come from closed enums.
public enum AnalyticsValue: Equatable, Sendable, Hashable {
    case string(String)
    case int(Int)
    case bool(Bool)

    public var anyValue: Any {
        switch self {
        case let .string(value): value
        case let .int(value): value
        case let .bool(value): value
        }
    }
}

extension AnalyticsValue: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByBooleanLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }

    public init(integerLiteral value: Int) {
        self = .int(value)
    }

    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

/// Where a consent change happened.
public enum ConsentSource: String, Sendable, Equatable {
    case onboarding
    case settings
}

/// What triggered an alert.
public enum AlertTrigger: String, Sendable, Equatable {
    case scheduled
    case wake
    case test
}

/// How the user dismissed an alert.
public enum DismissReason: String, Sendable, Equatable {
    case join
    case click
    case escape
    case quitShortcut = "quit_shortcut"
    case replaced
}

/// Where "Test alert" was pressed.
public enum TestAlertSource: String, Sendable, Equatable {
    case menu
    case onboarding
    case settings
}

/// Where the paywall was opened from.
public enum PaywallSource: String, Sendable, Equatable {
    case menu
    case settingsLock = "settings_lock"
    case alertHook = "alert_hook"
    case stats
}

/// Closed list of error categories. Never free text.
public enum AnalyticsErrorType: String, Sendable, Equatable {
    case network
    case unauthorized
    case notConfigured = "not_configured"
    case missingScope = "missing_scope"
    case cancelled
    case server
    case decoding
    case store
    case launchAtLogin = "launch_at_login"
    case unknown
}

/// A settings change. Only non-sensitive keys (PRD §6.1); calendars are reported as a count.
public enum SettingChange: Equatable, Sendable {
    case leadTime(Int)
    case ignoreDeclined(Bool)
    case ignoreWithoutOtherAttendees(Bool)
    case onlyEventsWithMeetingLink(Bool)
    case selectedCalendarsCount(Int?)
    case sound(AlertSound)
    case workingHours(enabled: Bool)
    case showCountdownInMenuBar(Bool)
    case launchAtLogin(Bool)

    public var key: String {
        switch self {
        case .leadTime: "lead_time"
        case .ignoreDeclined: "ignore_declined"
        case .ignoreWithoutOtherAttendees: "ignore_solo"
        case .onlyEventsWithMeetingLink: "only_with_link"
        case .selectedCalendarsCount: "calendars_count"
        case .sound: "sound"
        case .workingHours: "working_hours"
        case .showCountdownInMenuBar: "menu_bar_countdown"
        case .launchAtLogin: "launch_at_login"
        }
    }

    public var value: AnalyticsValue {
        switch self {
        case let .leadTime(seconds): .int(seconds)
        case let .ignoreDeclined(on), let .ignoreWithoutOtherAttendees(on), let .onlyEventsWithMeetingLink(on),
             let .showCountdownInMenuBar(on), let .launchAtLogin(on):
            .bool(on)
        case let .selectedCalendarsCount(count): count.map(AnalyticsValue.int) ?? .string("all")
        case let .sound(sound): .string(sound.rawValue)
        case let .workingHours(enabled): .bool(enabled)
        }
    }
}

/// The closed analytics taxonomy of PRD §6.1. There is deliberately no case that takes free text,
/// so meeting titles, links, attendees and calendar names can never be sent.
public enum AnalyticsEvent: Equatable, Sendable {
    case appLaunched(launchAtLogin: Bool, daysSinceInstall: Int)
    case onboardingViewed
    case signinStarted
    case signinCompleted
    case signinFailed(errorType: AnalyticsErrorType)
    case consentChanged(usage: Bool, email: Bool, source: ConsentSource)
    case calendarSynced(
        calendarsCount: Int,
        events24hCount: Int,
        eventsWithLinkCount: Int,
        durationMs: Int,
        errorType: AnalyticsErrorType?
    )
    case alertScheduled(secondsUntilFire: Int)
    case alertShown(
        leadTime: Int,
        provider: MeetingLink.Provider?,
        screensCount: Int,
        isDeclined: Bool,
        hasOtherAttendees: Bool,
        overlappingCount: Int,
        trigger: AlertTrigger,
        proHookShown: ProHook?
    )
    case alertDismissed(reason: DismissReason, secondsShown: Int, secondsToStart: Int, provider: MeetingLink.Provider?)
    case testAlertTriggered(source: TestAlertSource)
    case settingChanged(SettingChange)
    case paywallViewed(source: PaywallSource, priceVariant: String)
    case purchaseStarted(priceVariant: String)
    case purchaseCompleted(priceVariant: String)
    case purchaseFailed(priceVariant: String, errorType: AnalyticsErrorType)
    case purchaseRestored(priceVariant: String)
    case signout
    case appQuit(alertVisible: Bool)
    case errorOccurred(type: AnalyticsErrorType, code: Int)

    public var name: String {
        switch self {
        case .appLaunched: "app_launched"
        case .onboardingViewed: "onboarding_viewed"
        case .signinStarted: "signin_started"
        case .signinCompleted: "signin_completed"
        case .signinFailed: "signin_failed"
        case .consentChanged: "consent_changed"
        case .calendarSynced: "calendar_synced"
        case .alertScheduled: "alert_scheduled"
        case .alertShown: "alert_shown"
        case .alertDismissed: "alert_dismissed"
        case .testAlertTriggered: "test_alert_triggered"
        case .settingChanged: "setting_changed"
        case .paywallViewed: "paywall_viewed"
        case .purchaseStarted: "purchase_started"
        case .purchaseCompleted: "purchase_completed"
        case .purchaseFailed: "purchase_failed"
        case .purchaseRestored: "purchase_restored"
        case .signout: "signout"
        case .appQuit: "app_quit"
        case .errorOccurred: "error_occurred"
        }
    }

    public var properties: [String: AnalyticsValue] {
        switch self {
        case let .appLaunched(launchAtLogin, days):
            ["launch_at_login": .bool(launchAtLogin), "days_since_install": .int(days)]
        case .onboardingViewed, .signinStarted, .signinCompleted, .signout:
            [:]
        case let .signinFailed(errorType):
            ["error_type": .string(errorType.rawValue)]
        case let .consentChanged(usage, email, source):
            ["usage": .bool(usage), "email": .bool(email), "source": .string(source.rawValue)]
        case let .calendarSynced(calendars, events, withLink, duration, errorType):
            [
                "calendars_count": .int(calendars),
                "events_24h_count": .int(events),
                "events_with_link_count": .int(withLink),
                "duration_ms": .int(duration),
            ].merging(errorType.map { ["error_type": .string($0.rawValue)] } ?? [:]) { $1 }
        case let .alertScheduled(seconds):
            ["seconds_until_fire": .int(seconds)]
        case let .alertShown(leadTime, provider, screens, declined, others, overlapping, trigger, hook):
            [
                "lead_time": .int(leadTime),
                "provider": .string(provider.analyticsName),
                "screens_count": .int(screens),
                "is_declined": .bool(declined),
                "has_other_attendees": .bool(others),
                "overlapping_count": .int(overlapping),
                "trigger": .string(trigger.rawValue),
                "pro_hook_shown": .string(hook.analyticsName),
            ]
        case let .alertDismissed(reason, shown, toStart, provider):
            [
                "reason": .string(reason.rawValue),
                "seconds_shown": .int(shown),
                "seconds_to_start": .int(toStart),
                "provider": .string(provider.analyticsName),
            ]
        case let .testAlertTriggered(source):
            ["source": .string(source.rawValue)]
        case let .settingChanged(change):
            ["key": .string(change.key), "value": change.value]
        case let .paywallViewed(source, variant):
            ["source": .string(source.rawValue), "price_variant": .string(variant)]
        case let .purchaseStarted(variant), let .purchaseCompleted(variant), let .purchaseRestored(variant):
            ["price_variant": .string(variant)]
        case let .purchaseFailed(variant, errorType):
            ["price_variant": .string(variant), "error_type": .string(errorType.rawValue)]
        case let .appQuit(alertVisible):
            ["alert_visible": .bool(alertVisible)]
        case let .errorOccurred(type, code):
            ["type": .string(type.rawValue), "code": .int(code)]
        }
    }
}
