import Foundation

/// Ready-to-display texts of the alert (PLAN §6), so `AlertView` only lays them out.
public extension AlertFeature.State {
    /// "MEETING IN" / "STARTED 3 MIN AGO".
    var headline: String {
        switch phase {
        case .countingDown, .startingNow:
            String(localized: "MEETING IN", bundle: .module)
        case let .started(minutes):
            String(localized: "STARTED \(minutes) MIN AGO", bundle: .module)
        }
    }

    /// "10:00 – 10:30 · Google Meet" (just the time range without a link).
    func metaLine(locale: Locale = .current, timeZone: TimeZone = .current) -> String {
        let range = TimeText.range(event.start, event.end, locale: locale, timeZone: timeZone)
        guard let provider = event.meetingLink?.provider else { return range }
        return "\(range) · \(provider.displayName)"
    }

    /// "Join meeting", or "Open in Calendar" when there is no video link.
    var actionTitle: String {
        hasMeetingLink
            ? String(localized: "Join meeting", bundle: .module)
            : String(localized: "Open in Calendar", bundle: .module)
    }

    /// "+1 more" for overlapping meetings.
    var additionalText: String? {
        additionalCount > 0 ? String(localized: "+\(additionalCount) more", bundle: .module) : nil
    }

    /// The Pro hint line (text only, never a button).
    var hookText: String? {
        switch proHook {
        case .declined: String(localized: "Declined · With Pro we wouldn't have alerted you", bundle: .module)
        case .noLink: String(localized: "No link · With Pro we wouldn't have alerted you", bundle: .module)
        case .solo: String(localized: "Just you · With Pro we wouldn't have alerted you", bundle: .module)
        case nil: nil
        }
    }

    /// VoiceOver label for the countdown.
    var countdownAccessibilityLabel: String {
        switch phase {
        case let .countingDown(seconds): String(localized: "Meeting in \(seconds) seconds", bundle: .module)
        case .startingNow: String(localized: "Meeting starting now", bundle: .module)
        case let .started(minutes): String(localized: "Meeting started \(minutes) minutes ago", bundle: .module)
        }
    }
}

public extension AlertSound {
    var displayName: String {
        switch self {
        case .default: String(localized: "Default", bundle: .module)
        case .chime: String(localized: "Chime", bundle: .module)
        case .pulse: String(localized: "Pulse", bundle: .module)
        case .horn: String(localized: "Horn", bundle: .module)
        case .bell: String(localized: "Bell", bundle: .module)
        case .none: String(localized: "None", bundle: .module)
        }
    }
}

public extension PaywallFeature.State {
    /// "Buy for 5,99 € · one time" with the App Store's localized price.
    var buyTitle: String {
        guard let product else { return String(localized: "Buy", bundle: .module) }
        return String(localized: "Buy for \(product.displayPrice) · one time", bundle: .module)
    }
}

public extension WorkingHours {
    /// Weekday numbers (1 = Sunday) starting on the calendar's first weekday.
    static func orderedWeekdays(calendar: Calendar) -> [Int] {
        (0 ..< 7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
    }

    /// Very short weekday symbol ("M", "L"…) for a weekday number.
    static func symbol(for weekday: Int, calendar: Calendar) -> String {
        let symbols = calendar.veryShortWeekdaySymbols
        return symbols.indices.contains(weekday - 1) ? symbols[weekday - 1] : ""
    }

    /// A date on `day` at `minute` minutes after midnight (for time pickers).
    static func date(forMinute minute: Int, on day: Date, calendar: Calendar) -> Date {
        calendar.startOfDay(for: day).addingTimeInterval(TimeInterval(minute * 60))
    }

    /// Minutes after midnight of a picked time.
    static func minute(of date: Date, calendar: Calendar) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}
