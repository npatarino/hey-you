import Foundation

/// Allowed alert lead times (PRD §5.1): 10…60 s in steps of 5. Never more than 60.
public enum LeadTime {
    public static let range = 10 ... 60
    public static let step = 5
    public static let free = 60

    /// Rounds to the nearest step and clamps into `range`.
    public static func clamp(_ seconds: Int) -> Int {
        let rounded = Int((Double(seconds) / Double(step)).rounded()) * step
        return min(max(rounded, range.lowerBound), range.upperBound)
    }

    public static var allValues: [Int] {
        Array(stride(from: range.lowerBound, through: range.upperBound, by: step))
    }
}

/// Sound played once when the alert appears.
public enum AlertSound: String, Codable, Sendable, CaseIterable, Equatable {
    case `default`
    case chime
    case pulse
    case horn
    case bell
    case none

    /// System sound name (`NSSound(named:)`), nil for silence.
    public var systemSoundName: String? {
        switch self {
        case .default: "Funk"
        case .chime: "Glass"
        case .pulse: "Ping"
        case .horn: "Sosumi"
        case .bell: "Submarine"
        case .none: nil
        }
    }
}

/// Working hours (Pro). Outside them there are no alerts.
public struct WorkingHours: Equatable, Codable, Sendable, Hashable {
    /// `Calendar` weekday numbers: 1 = Sunday … 7 = Saturday.
    public var weekdays: Set<Int>
    /// Minutes since midnight, inclusive.
    public var startMinute: Int
    /// Minutes since midnight, exclusive.
    public var endMinute: Int

    public init(weekdays: Set<Int>, startMinute: Int, endMinute: Int) {
        self.weekdays = weekdays
        self.startMinute = startMinute
        self.endMinute = endMinute
    }

    /// Monday to Friday, 09:00–18:00.
    public static let officeDefault = WorkingHours(weekdays: [2, 3, 4, 5, 6], startMinute: 9 * 60, endMinute: 18 * 60)

    /// Whether a meeting starting at `date` is inside working hours.
    public func contains(_ date: Date, calendar: Calendar) -> Bool {
        let components = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard let weekday = components.weekday, weekdays.contains(weekday) else { return false }
        let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        return minute >= startMinute && minute < endMinute
    }
}

/// User settings as stored. Never read directly by the scheduler: use `EffectiveSettings`.
public struct AppSettings: Equatable, Codable, Sendable {
    public var leadTimeSeconds: Int
    public var launchAtLogin: Bool
    // Pro
    public var ignoreDeclined: Bool
    public var ignoreWithoutOtherAttendees: Bool
    public var onlyEventsWithMeetingLink: Bool
    /// nil = all calendars.
    public var selectedCalendarIDs: Set<String>?
    public var sound: AlertSound
    /// nil = always.
    public var workingHours: WorkingHours?
    public var showCountdownInMenuBar: Bool

    public init(
        leadTimeSeconds: Int = LeadTime.free,
        launchAtLogin: Bool = false,
        ignoreDeclined: Bool = false,
        ignoreWithoutOtherAttendees: Bool = false,
        onlyEventsWithMeetingLink: Bool = false,
        selectedCalendarIDs: Set<String>? = nil,
        sound: AlertSound = .default,
        workingHours: WorkingHours? = nil,
        showCountdownInMenuBar: Bool = true
    ) {
        self.leadTimeSeconds = leadTimeSeconds
        self.launchAtLogin = launchAtLogin
        self.ignoreDeclined = ignoreDeclined
        self.ignoreWithoutOtherAttendees = ignoreWithoutOtherAttendees
        self.onlyEventsWithMeetingLink = onlyEventsWithMeetingLink
        self.selectedCalendarIDs = selectedCalendarIDs
        self.sound = sound
        self.workingHours = workingHours
        self.showCountdownInMenuBar = showCountdownInMenuBar
    }

    /// Tolerates missing keys so that adding a setting never wipes the stored ones.
    public init(from decoder: any Decoder) throws {
        let defaults = AppSettings()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        leadTimeSeconds = try container.decodeIfPresent(Int.self, forKey: .leadTimeSeconds) ?? defaults.leadTimeSeconds
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? defaults.launchAtLogin
        ignoreDeclined = try container.decodeIfPresent(Bool.self, forKey: .ignoreDeclined) ?? defaults.ignoreDeclined
        ignoreWithoutOtherAttendees = try container.decodeIfPresent(Bool.self, forKey: .ignoreWithoutOtherAttendees)
            ?? defaults.ignoreWithoutOtherAttendees
        onlyEventsWithMeetingLink = try container.decodeIfPresent(Bool.self, forKey: .onlyEventsWithMeetingLink)
            ?? defaults.onlyEventsWithMeetingLink
        selectedCalendarIDs = try container.decodeIfPresent(Set<String>.self, forKey: .selectedCalendarIDs)
        sound = try container.decodeIfPresent(AlertSound.self, forKey: .sound) ?? defaults.sound
        workingHours = try container.decodeIfPresent(WorkingHours.self, forKey: .workingHours)
        showCountdownInMenuBar = try container.decodeIfPresent(Bool.self, forKey: .showCountdownInMenuBar)
            ?? defaults.showCountdownInMenuBar
    }

    /// Defaults switched on the first time Pro is unlocked (PRD §5.2).
    public mutating func applyProDefaults() {
        ignoreDeclined = true
        ignoreWithoutOtherAttendees = true
    }
}

/// Analytics/contact consent (PRD §5.6.1).
public struct Consent: Equatable, Codable, Sendable {
    public var usageAnalytics: Bool
    public var emailContact: Bool

    public init(usageAnalytics: Bool = true, emailContact: Bool = false) {
        self.usageAnalytics = usageAnalytics
        self.emailContact = emailContact
    }
}

/// Pro purchase state, cached so the app starts as Pro without network.
public struct Entitlements: Equatable, Codable, Sendable {
    public var isPro: Bool
    public var purchasedAt: Date?
    /// Whether Pro defaults were already applied once (so turning a filter off later sticks).
    public var proDefaultsApplied: Bool

    public init(isPro: Bool = false, purchasedAt: Date? = nil, proDefaultsApplied: Bool = false) {
        self.isPro = isPro
        self.purchasedAt = purchasedAt
        self.proDefaultsApplied = proDefaultsApplied
    }
}

/// Settings with Pro gating applied. The only settings type the scheduler and reducers act on.
public struct EffectiveSettings: Equatable, Sendable {
    public let isPro: Bool
    public let leadTimeSeconds: Int
    public let ignoreDeclined: Bool
    public let ignoreWithoutOtherAttendees: Bool
    public let onlyEventsWithMeetingLink: Bool
    public let selectedCalendarIDs: Set<String>?
    public let sound: AlertSound
    public let workingHours: WorkingHours?
    public let showCountdownInMenuBar: Bool

    public init(_ settings: AppSettings, isPro: Bool) {
        self.isPro = isPro
        if isPro {
            leadTimeSeconds = LeadTime.clamp(settings.leadTimeSeconds)
            ignoreDeclined = settings.ignoreDeclined
            ignoreWithoutOtherAttendees = settings.ignoreWithoutOtherAttendees
            onlyEventsWithMeetingLink = settings.onlyEventsWithMeetingLink
            selectedCalendarIDs = settings.selectedCalendarIDs
            sound = settings.sound
            workingHours = settings.workingHours
            showCountdownInMenuBar = settings.showCountdownInMenuBar
        } else {
            leadTimeSeconds = LeadTime.free
            ignoreDeclined = false
            ignoreWithoutOtherAttendees = false
            onlyEventsWithMeetingLink = false
            selectedCalendarIDs = nil
            sound = .default
            workingHours = nil
            showCountdownInMenuBar = false
        }
    }
}
