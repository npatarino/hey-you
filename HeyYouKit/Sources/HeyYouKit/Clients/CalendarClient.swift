import Dependencies
import DependenciesMacros
import Foundation

/// Reads calendars and events. Google today; the abstraction leaves room for EventKit later.
@DependencyClient
public struct CalendarClient: Sendable {
    public var calendars: @Sendable () async throws -> [CalendarSummary]
    /// - Parameter calendarIDs: nil = every visible calendar.
    public var upcomingEvents: @Sendable (_ from: Date, _ to: Date, _ calendarIDs: Set<String>?) async throws -> [CalendarEvent]
}

extension CalendarClient: DependencyKey {
    public static var liveValue: Self {
        @Dependency(\.authClient) var authClient
        let api = GoogleCalendarAPI(accessToken: { try await authClient.accessToken() })
        return Self(
            calendars: { try await api.calendars() },
            upcomingEvents: { try await api.events(from: $0, to: $1, calendarIDs: $2) }
        )
    }

    public static var previewValue: Self {
        .mock()
    }

    /// Fake calendar relative to `now`: a meeting in 90 s, one in 2 h, an all-day one and a declined one.
    public static func mock(now: (@Sendable () -> Date)? = nil) -> Self {
        Self(
            calendars: { MockCalendar.calendars },
            upcomingEvents: { from, to, calendarIDs in
                let reference = now?() ?? MockCalendar.anchor(for: from)
                return MockCalendar.events(relativeTo: reference)
                    .filter { $0.end > from && $0.start < to }
                    .filter { calendarIDs?.contains($0.calendarID) ?? true }
            }
        )
    }
}

public extension DependencyValues {
    var calendarClient: CalendarClient {
        get { self[CalendarClient.self] }
        set { self[CalendarClient.self] = newValue }
    }
}

/// Sample data for `--mock-calendar`, previews and tests.
public enum MockCalendar {
    public static let calendars = [
        CalendarSummary(id: "primary", name: "Work", isPrimary: true, colorHex: "#039BE5"),
        CalendarSummary(id: "personal", name: "Personal", colorHex: "#33B679"),
    ]

    /// The first call fixes the reference time, so the events don't drift on every refresh.
    private static let anchorStore = AnchorStore()

    static func anchor(for date: Date) -> Date {
        anchorStore.anchor(for: date)
    }

    public static func events(relativeTo now: Date) -> [CalendarEvent] {
        let meet = MeetingLink(
            provider: .googleMeet,
            url: URL(string: "https://meet.google.com/abc-defg-hij") ?? AppConfig.projectURL
        )
        let zoom = MeetingLink(
            provider: .zoom,
            url: URL(string: "https://zoom.us/j/91234567890?pwd=abc") ?? AppConfig.projectURL
        )
        let startOfDay = Calendar.current.startOfDay(for: now)
        return [
            CalendarEvent(
                id: "mock-weekly", title: "Weekly sync", start: now.addingTimeInterval(90),
                end: now.addingTimeInterval(90 + 30 * 60), meetingLink: meet, organizer: "Ana"
            ),
            CalendarEvent(
                id: "mock-demo", title: "Demo cliente", start: now.addingTimeInterval(2 * 3600),
                end: now.addingTimeInterval(2 * 3600 + 45 * 60), meetingLink: zoom
            ),
            CalendarEvent(
                id: "mock-allday", calendarID: "personal", title: "Cumpleaños de Marta", start: startOfDay,
                end: startOfDay.addingTimeInterval(86400), isAllDay: true, hasOtherAttendees: false
            ),
            CalendarEvent(
                id: "mock-retro", title: "Retro", start: now.addingTimeInterval(3 * 3600),
                end: now.addingTimeInterval(3 * 3600 + 3600), meetingLink: meet, attendeeStatus: .declined
            ),
        ]
    }
}

private final class AnchorStore: Sendable {
    private let value = LockIsolatedDate()

    func anchor(for date: Date) -> Date {
        value.anchor(date)
    }
}

private final class LockIsolatedDate: Sendable {
    private let lock = LockIsolated<Date?>(nil)

    func anchor(_ date: Date) -> Date {
        lock.withValue { stored in
            if let stored {
                return stored
            }
            stored = date
            return date
        }
    }
}
