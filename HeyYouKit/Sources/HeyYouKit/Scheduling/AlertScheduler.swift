import Foundation

/// Pure function that decides the next alert. No clocks, no I/O.
public enum AlertScheduler {
    /// - Parameters:
    ///   - events: events in the sync window, in any order.
    ///   - now: current time.
    ///   - settings: settings with Pro gating applied.
    ///   - fired: dedupe keys of alerts already shown.
    ///   - includeInProgress: also return events that already started and have not ended
    ///     (used after the Mac wakes up, PRD B.7). Otherwise started events are skipped.
    ///   - calendar: used for working hours.
    /// - Returns: the alert with the earliest start; ties are grouped (first by title, "+N more").
    ///   `fireAt` may be in the past, meaning "fire now".
    public static func next(
        events: [CalendarEvent],
        now: Date,
        settings: EffectiveSettings,
        fired: Set<String>,
        includeInProgress: Bool = false,
        calendar: Calendar = .current
    ) -> ScheduledAlert? {
        let candidates = events.filter { event in
            !fired.contains(event.dedupeKey)
                && isEligible(event, now: now, settings: settings, includeInProgress: includeInProgress, calendar: calendar)
        }
        let sorted = candidates.sorted { lhs, rhs in
            lhs.start == rhs.start ? titleOrder(lhs, rhs) : lhs.start < rhs.start
        }
        guard let first = sorted.first else { return nil }
        return ScheduledAlert(
            event: first,
            overlapping: sorted.dropFirst().filter { $0.start == first.start },
            fireAt: first.start.addingTimeInterval(-TimeInterval(settings.leadTimeSeconds)),
            proHook: proHook(for: first, settings: settings)
        )
    }

    /// Whether an event passes the base rules and the (Pro) filters.
    public static func isEligible(
        _ event: CalendarEvent,
        now: Date,
        settings: EffectiveSettings,
        includeInProgress: Bool = false,
        calendar: Calendar = .current
    ) -> Bool {
        if event.isAllDay || event.end <= now {
            return false
        }
        if event.start <= now, !includeInProgress {
            return false
        }
        if let selected = settings.selectedCalendarIDs, !selected.contains(event.calendarID) {
            return false
        }
        if settings.ignoreDeclined, event.attendeeStatus == .declined {
            return false
        }
        if settings.ignoreWithoutOtherAttendees, !event.hasOtherAttendees {
            return false
        }
        if settings.onlyEventsWithMeetingLink, event.meetingLink == nil {
            return false
        }
        if let hours = settings.workingHours, !hours.contains(event.start, calendar: calendar) {
            return false
        }
        return true
    }

    /// The Pro hint for a free user: what a Pro filter would have done with this event.
    public static func proHook(for event: CalendarEvent, settings: EffectiveSettings) -> ProHook? {
        guard !settings.isPro else { return nil }
        if event.attendeeStatus == .declined {
            return .declined
        }
        if !event.hasOtherAttendees {
            return .solo
        }
        if event.meetingLink == nil {
            return .noLink
        }
        return nil
    }

    private static func titleOrder(_ lhs: CalendarEvent, _ rhs: CalendarEvent) -> Bool {
        let order = lhs.title.localizedStandardCompare(rhs.title)
        return order == .orderedSame ? lhs.id < rhs.id : order == .orderedAscending
    }
}

/// What the alert shows depending on the seconds left until the start.
public enum AlertPhase: Equatable, Sendable {
    /// Before the start: "MEETING IN 47s".
    case countingDown(seconds: Int)
    /// First minute after the start: "NOW".
    case startingNow
    /// Later: "STARTED 3 MIN AGO".
    case started(minutesAgo: Int)

    public init(secondsRemaining: Int) {
        if secondsRemaining > 0 {
            self = .countingDown(seconds: secondsRemaining)
        } else if secondsRemaining > -60 {
            self = .startingNow
        } else {
            self = .started(minutesAgo: -secondsRemaining / 60)
        }
    }
}
