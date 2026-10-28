import Foundation

/// Time formatting shared by the alert and the menu. Locale and time zone are parameters so tests are stable.
public enum TimeText {
    public static func time(_ date: Date, locale: Locale = .current, timeZone: TimeZone = .current) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: timeZone))
    }

    public static func range(_ start: Date, _ end: Date, locale: Locale = .current, timeZone: TimeZone = .current) -> String {
        "\(time(start, locale: locale, timeZone: timeZone)) – \(time(end, locale: locale, timeZone: timeZone))"
    }

    /// "42 min" under an hour, otherwise the clock time.
    public static func relative(_ date: Date, now: Date, locale: Locale = .current, timeZone: TimeZone = .current) -> String {
        let minutes = Int((date.timeIntervalSince(now) / 60).rounded(.up))
        if minutes < 60 {
            return String(localized: "\(max(minutes, 0)) min", bundle: .module)
        }
        return time(date, locale: locale, timeZone: timeZone)
    }
}
