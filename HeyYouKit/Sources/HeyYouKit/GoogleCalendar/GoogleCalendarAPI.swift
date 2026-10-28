import Foundation

public enum CalendarError: Error, Equatable, Sendable {
    /// 401 after one retry with a fresh token: the session is gone.
    case unauthorized
    /// No network.
    case offline
    case server(status: Int)
    case decoding

    public var analyticsType: AnalyticsErrorType {
        switch self {
        case .unauthorized: .unauthorized
        case .offline: .network
        case .server: .server
        case .decoding: .decoding
        }
    }

    public var code: Int {
        switch self {
        case .unauthorized: 401
        case .offline: -1009
        case let .server(status): status
        case .decoding: -1
        }
    }
}

/// Google Calendar REST API v3 over an injectable transport (URLSession in the app, closures in tests).
public struct GoogleCalendarAPI: Sendable {
    public typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    let baseURL: URL
    let transport: Transport
    let accessToken: @Sendable () async throws -> String
    let timeZone: TimeZone

    public init(
        baseURL: URL = URL(string: "https://www.googleapis.com/calendar/v3") ?? URL(fileURLWithPath: "/"),
        transport: @escaping Transport = { try await URLSession.shared.data(for: $0) },
        timeZone: TimeZone = .current,
        accessToken: @escaping @Sendable () async throws -> String
    ) {
        self.baseURL = baseURL
        self.transport = transport
        self.timeZone = timeZone
        self.accessToken = accessToken
    }

    /// Calendars visible in the user's Google Calendar (selected and not hidden).
    public func calendars() async throws -> [CalendarSummary] {
        try await calendarEntries()
            .filter { $0.deleted != true && $0.hidden != true && ($0.selected ?? $0.primary ?? false) }
            .map(GoogleCalendarMapper.calendar)
    }

    /// Events between `from` and `to`. `calendarIDs == nil` means every visible calendar.
    /// Recurring events are expanded by Google (`singleEvents=true`). Duplicates across calendars are removed.
    public func events(from: Date, to: Date, calendarIDs: Set<String>?) async throws -> [CalendarEvent] {
        let ids: [String] = if let calendarIDs {
            calendarIDs.sorted()
        } else {
            try await calendars().map(\.id)
        }
        let perCalendar = try await withThrowingTaskGroup(of: (Int, [CalendarEvent]).self) { group in
            for (index, id) in ids.enumerated() {
                group.addTask { try await (index, events(calendarID: id, from: from, to: to)) }
            }
            var results: [(Int, [CalendarEvent])] = []
            for try await result in group {
                results.append(result)
            }
            return results.sorted { $0.0 < $1.0 }.flatMap(\.1)
        }
        var seen: Set<String> = []
        return perCalendar
            .filter { seen.insert($0.dedupeKey).inserted }
            .sorted { $0.start < $1.start }
    }

    func events(calendarID: String, from: Date, to: Date) async throws -> [CalendarEvent] {
        let fields = "items(id,status,summary,description,location,htmlLink,hangoutLink,eventType,"
            + "start,end,organizer(email,displayName),attendees(email,self,resource,responseStatus),"
            + "conferenceData(entryPoints(entryPointType,uri))),nextPageToken,timeZone"
        var events: [CalendarEvent] = []
        var pageToken: String?
        repeat {
            var query = [
                URLQueryItem(name: "singleEvents", value: "true"),
                URLQueryItem(name: "orderBy", value: "startTime"),
                URLQueryItem(name: "timeMin", value: from.ISO8601Format()),
                URLQueryItem(name: "timeMax", value: to.ISO8601Format()),
                URLQueryItem(name: "maxResults", value: "250"),
                URLQueryItem(name: "fields", value: fields),
            ]
            if let pageToken {
                query.append(URLQueryItem(name: "pageToken", value: pageToken))
            }
            let page: GoogleCalendarDTO.Events = try await get(["calendars", calendarID, "events"], query: query)
            let zone = page.timeZone.flatMap(TimeZone.init(identifier:)) ?? timeZone
            events += (page.items ?? []).compactMap {
                GoogleCalendarMapper.event($0, calendarID: calendarID, defaultTimeZone: zone)
            }
            pageToken = page.nextPageToken
        } while pageToken != nil
        return events
    }

    private func calendarEntries() async throws -> [GoogleCalendarDTO.CalendarListEntry] {
        var entries: [GoogleCalendarDTO.CalendarListEntry] = []
        var pageToken: String?
        repeat {
            var query = [
                URLQueryItem(name: "minAccessRole", value: "reader"),
                URLQueryItem(
                    name: "fields",
                    value: "items(id,summary,summaryOverride,primary,selected,hidden,deleted,backgroundColor),nextPageToken"
                ),
            ]
            if let pageToken {
                query.append(URLQueryItem(name: "pageToken", value: pageToken))
            }
            let page: GoogleCalendarDTO.CalendarList = try await get(["users", "me", "calendarList"], query: query)
            entries += page.items ?? []
            pageToken = page.nextPageToken
        } while pageToken != nil
        return entries
    }

    /// GET with bearer token; on 401 retries once with a freshly requested token.
    private func get<T: Decodable>(_ path: [String], query: [URLQueryItem]) async throws -> T {
        var url = baseURL
        for component in path {
            url.append(path: component)
        }
        url.append(queryItems: query)
        var lastStatus = 0
        for _ in 0 ..< 2 {
            let token: String
            do {
                token = try await accessToken()
            } catch {
                throw CalendarError.unauthorized
            }
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 20
            let (data, response) = try await send(request)
            lastStatus = (response as? HTTPURLResponse)?.statusCode ?? 0
            switch lastStatus {
            case 200 ..< 300:
                do {
                    return try JSONDecoder().decode(T.self, from: data)
                } catch {
                    throw CalendarError.decoding
                }
            case 401:
                continue
            default:
                throw CalendarError.server(status: lastStatus)
            }
        }
        throw CalendarError.unauthorized
    }

    private func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await transport(request)
        } catch let error as URLError {
            throw error.code == .cancelled ? error : CalendarError.offline
        }
    }
}
