import Foundation

/// Subset of the Google Calendar API v3 responses we use. Field names match the API.
enum GoogleCalendarDTO {
    struct CalendarList: Decodable {
        let items: [CalendarListEntry]?
        let nextPageToken: String?
    }

    struct CalendarListEntry: Decodable {
        let id: String
        let summary: String?
        let summaryOverride: String?
        let primary: Bool?
        let selected: Bool?
        let hidden: Bool?
        let deleted: Bool?
        let backgroundColor: String?
    }

    struct Events: Decodable {
        let items: [Event]?
        let nextPageToken: String?
        let timeZone: String?
    }

    struct Event: Decodable {
        let id: String
        let status: String?
        let summary: String?
        let description: String?
        let location: String?
        let htmlLink: String?
        let hangoutLink: String?
        let eventType: String?
        let start: EventDate?
        let end: EventDate?
        let organizer: Person?
        let attendees: [Attendee]?
        let conferenceData: ConferenceData?
    }

    struct EventDate: Decodable {
        /// RFC 3339 with offset, for timed events.
        let dateTime: String?
        /// yyyy-MM-dd, for all-day events.
        let date: String?
        let timeZone: String?
    }

    struct Person: Decodable {
        let email: String?
        let displayName: String?
        let isSelf: Bool?

        enum CodingKeys: String, CodingKey {
            case email
            case displayName
            case isSelf = "self"
        }
    }

    struct Attendee: Decodable {
        let email: String?
        let isSelf: Bool?
        let resource: Bool?
        let responseStatus: String?

        enum CodingKeys: String, CodingKey {
            case email
            case isSelf = "self"
            case resource
            case responseStatus
        }
    }

    struct ConferenceData: Decodable {
        let entryPoints: [EntryPoint]?
    }

    struct EntryPoint: Decodable {
        let entryPointType: String?
        let uri: String?
    }

    struct ErrorResponse: Decodable {
        struct Body: Decodable {
            let code: Int?
            let message: String?
        }

        let error: Body?
    }
}
