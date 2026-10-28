import Foundation

/// The user's response to a meeting invitation.
public enum AttendeeStatus: String, Codable, Sendable, Equatable {
    case accepted
    case tentative
    case declined
    case needsAction
    case unknown
}

/// A timed (or all-day) calendar event, already mapped from the provider's format.
public struct CalendarEvent: Equatable, Identifiable, Sendable, Codable, Hashable {
    public let id: String
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
    public var dedupeKey: String {
        "\(id)|\(Int(start.timeIntervalSince1970))"
    }
}

/// A calendar the user can choose to watch (Pro).
public struct CalendarSummary: Equatable, Identifiable, Sendable, Codable, Hashable {
    public let id: String
    public let name: String
    public let isPrimary: Bool
    public let colorHex: String?

    public init(id: String, name: String, isPrimary: Bool = false, colorHex: String? = nil) {
        self.id = id
        self.name = name
        self.isPrimary = isPrimary
        self.colorHex = colorHex
    }
}
