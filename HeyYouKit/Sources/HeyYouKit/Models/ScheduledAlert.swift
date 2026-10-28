import Foundation

/// Why a free user sees a Pro hint under the alert title (PRD §5.6.2). Text only, never a button.
public enum ProHook: String, Equatable, Sendable, Codable {
    case declined
    case noLink = "no_link"
    case solo
}

public extension ProHook? {
    /// `pro_hook_shown` analytics value.
    var analyticsName: String {
        self?.rawValue ?? "none"
    }
}

/// The next alert to fire.
public struct ScheduledAlert: Equatable, Sendable {
    /// Event shown in the alert (first alphabetically when several start together).
    public let event: CalendarEvent
    /// Other events starting at the same time ("+1 more"); they are marked fired together.
    public let overlapping: [CalendarEvent]
    public let fireAt: Date
    public let proHook: ProHook?

    public init(event: CalendarEvent, overlapping: [CalendarEvent] = [], fireAt: Date, proHook: ProHook? = nil) {
        self.event = event
        self.overlapping = overlapping
        self.fireAt = fireAt
        self.proHook = proHook
    }

    public var additionalCount: Int {
        overlapping.count
    }

    /// Dedupe keys of every event covered by this alert.
    public var dedupeKeys: Set<String> {
        Set([event.dedupeKey] + overlapping.map(\.dedupeKey))
    }
}

/// Weekly punctuality (Pro): alerts that ended in Join or a dismissal ≤ 30 s after start.
public struct PunctualityStats: Equatable, Codable, Sendable {
    public var weekStart: Date
    public var alerts: Int
    public var onTime: Int

    public init(weekStart: Date = .distantPast, alerts: Int = 0, onTime: Int = 0) {
        self.weekStart = weekStart
        self.alerts = alerts
        self.onTime = onTime
    }

    /// Counts one alert, starting a new week when `date` is in a later week.
    public func recording(onTime isOnTime: Bool, at date: Date, calendar: Calendar) -> PunctualityStats {
        let currentWeek = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        var stats = currentWeek == weekStart ? self : PunctualityStats(weekStart: currentWeek)
        stats.alerts += 1
        if isOnTime {
            stats.onTime += 1
        }
        return stats
    }

    /// Stats for the week containing `date` (zero if the stored week is old).
    public func current(at date: Date, calendar: Calendar) -> PunctualityStats {
        let currentWeek = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        return currentWeek == weekStart ? self : PunctualityStats(weekStart: currentWeek)
    }

    /// A dismissal counts as on time if it was Join or happened at most 30 s after start.
    public static func isOnTime(joined: Bool, secondsToStart: Int) -> Bool {
        joined || secondsToStart >= -30
    }
}
