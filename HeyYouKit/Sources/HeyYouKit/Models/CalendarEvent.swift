import Foundation

/// The user's response to a meeting invitation.
public enum AttendeeStatus: String, Codable, Sendable, Equatable {
    case accepted
    case tentative
    case declined
    case needsAction
    case unknown
}

/// Where calendars and events are read from. Both can be on at the same time.
public enum CalendarSource: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    /// Google Calendar, through Sign in with Google.
    case google
    /// The calendars set up on the Mac (EventKit): iCloud, Exchange, Google, CalDAV…
    case mac
}

/// A timed (or all-day) calendar event, already mapped from the provider's format.
public struct CalendarEvent: Equatable, Identifiable, Sendable, Codable, Hashable {
    public let id: String
    public let source: CalendarSource
    /// The iCalendar UID, shared by every copy of the same event (Google `iCalUID`, EventKit external identifier).
    public let externalID: String?
    public let calendarID: String
    public let title: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
    public let meetingLink: MeetingLink?
    public let location: String?
    public let organizer: String?
    public let attendeeStatus: AttendeeStatus
    /// True when the event has at least one attendee other than the user (not a focus block).
    public let hasOtherAttendees: Bool
    public let htmlLink: URL?

    public init(
        id: String,
        source: CalendarSource = .google,
        externalID: String? = nil,
        calendarID: String = "primary",
        title: String,
        start: Date,
        end: Date,
        isAllDay: Bool = false,
        meetingLink: MeetingLink? = nil,
        location: String? = nil,
        organizer: String? = nil,
        attendeeStatus: AttendeeStatus = .accepted,
        hasOtherAttendees: Bool = true,
        htmlLink: URL? = nil
    ) {
        self.id = id
        self.source = source
        self.externalID = externalID
        self.calendarID = calendarID
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.meetingLink = meetingLink
        self.location = location
        self.organizer = organizer
        self.attendeeStatus = attendeeStatus
        self.hasOtherAttendees = hasOtherAttendees
        self.htmlLink = htmlLink
    }

    /// Key used to avoid firing the same occurrence twice. A moved event (new start) fires again.
    /// It uses the iCalendar UID when there is one, so the same meeting read from Google and from the
    /// Mac's calendar has the same key.
    public var dedupeKey: String {
        "\(externalID ?? id)|\(Int(start.timeIntervalSince1970))"
    }
}

/// A calendar the user can choose to watch (Pro).
public struct CalendarSummary: Equatable, Identifiable, Sendable, Codable, Hashable {
    public let id: String
    public let source: CalendarSource
    public let name: String
    /// The account the calendar belongs to on the Mac ("iCloud", "Work Exchange"); nil for Google.
    public let account: String?
    public let isPrimary: Bool
    public let colorHex: String?

    public init(
        id: String,
        source: CalendarSource = .google,
        name: String,
        account: String? = nil,
        isPrimary: Bool = false,
        colorHex: String? = nil
    ) {
        self.id = id
        self.source = source
        self.name = name
        self.account = account
        self.isPrimary = isPrimary
        self.colorHex = colorHex
    }
}
