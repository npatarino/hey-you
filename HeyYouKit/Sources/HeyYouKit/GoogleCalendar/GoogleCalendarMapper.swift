import Foundation

/// Maps Google DTOs to domain models.
enum GoogleCalendarMapper {
    /// Event types that are not meetings and never alert.
    static let ignoredEventTypes: Set<String> = ["workingLocation", "outOfOffice", "birthday"]

    static func calendar(_ entry: GoogleCalendarDTO.CalendarListEntry) -> CalendarSummary {
        CalendarSummary(
            id: entry.id,
            name: entry.summaryOverride ?? entry.summary ?? entry.id,
            isPrimary: entry.primary ?? false,
            colorHex: entry.backgroundColor
        )
    }

    /// Returns nil for cancelled events, non-meeting event types and unparseable dates.
    static func event(_ dto: GoogleCalendarDTO.Event, calendarID: String, defaultTimeZone: TimeZone) -> CalendarEvent? {
        if dto.status == "cancelled" {
            return nil
        }
        if let type = dto.eventType, ignoredEventTypes.contains(type) {
            return nil
        }
        guard let startDTO = dto.start, let endDTO = dto.end else { return nil }
        let isAllDay = startDTO.dateTime == nil && startDTO.date != nil
        guard let start = date(startDTO, defaultTimeZone: defaultTimeZone),
              let end = date(endDTO, defaultTimeZone: defaultTimeZone)
        else { return nil }

        let attendees = dto.attendees ?? []
        let selfAttendee = attendees.first { $0.isSelf == true }
        let status: AttendeeStatus = if let selfAttendee {
            attendeeStatus(selfAttendee.responseStatus)
        } else if attendees.isEmpty {
            // No guest list: the user's own event.
            .accepted
        } else {
            .unknown
        }
        let hasOtherAttendees = attendees.contains { $0.isSelf != true && $0.resource != true }

        let videoURIs = (dto.conferenceData?.entryPoints ?? [])
            .filter { $0.entryPointType == "video" }
            .compactMap(\.uri)

        return CalendarEvent(
            id: dto.id,
            calendarID: calendarID,
            title: dto.summary ?? String(localized: "(No title)", bundle: .module),
            start: start,
            end: end,
            isAllDay: isAllDay,
            meetingLink: MeetingLinkParser.parse(
                hangoutLink: dto.hangoutLink,
                conferenceVideoURIs: videoURIs,
                location: dto.location,
                description: dto.description
            ),
            location: dto.location,
            organizer: dto.organizer?.displayName ?? dto.organizer?.email,
            attendeeStatus: status,
            hasOtherAttendees: hasOtherAttendees,
            htmlLink: dto.htmlLink.flatMap(URL.init(string:))
        )
    }

    static func attendeeStatus(_ value: String?) -> AttendeeStatus {
        switch value {
        case "accepted": .accepted
        case "tentative": .tentative
        case "declined": .declined
        case "needsAction": .needsAction
        default: .unknown
        }
    }

    static func date(_ dto: GoogleCalendarDTO.EventDate, defaultTimeZone: TimeZone) -> Date? {
        if let dateTime = dto.dateTime {
            return parseDateTime(dateTime)
        }
        if let day = dto.date {
            let zone = dto.timeZone.flatMap(TimeZone.init(identifier:)) ?? defaultTimeZone
            return parseDay(day, timeZone: zone)
        }
        return nil
    }

    static func parseDateTime(_ string: String) -> Date? {
        if let date = try? Date(string, strategy: .iso8601) {
            return date
        }
        let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        return try? fractional.parse(string)
    }

    static func parseDay(_ string: String, timeZone: TimeZone) -> Date? {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}
