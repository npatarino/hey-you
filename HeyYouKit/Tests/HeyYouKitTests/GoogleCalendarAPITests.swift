import Foundation
@testable import HeyYouKit
import Testing

/// Records requests and returns canned responses keyed by path.
final class StubTransport: Sendable {
    struct Response {
        let status: Int
        let body: Data
    }

    private let state = LockIsolatedBox<(requests: [URLRequest], responses: [String: [Response]])>(
        (requests: [], responses: [:])
    )

    func respond(path: String, status: Int = 200, fixture: String) throws {
        let body = try Fixture.data(fixture)
        state.mutate { $0.responses[path, default: []].append(Response(status: status, body: body)) }
    }

    func respond(path: String, status: Int, body: String) {
        state.mutate { $0.responses[path, default: []].append(Response(status: status, body: Data(body.utf8))) }
    }

    var requests: [URLRequest] {
        state.read { $0.requests }
    }

    var transport: GoogleCalendarAPI.Transport {
        { request in
            let path = request.url?.path() ?? ""
            let response: Response? = self.state.mutate { state in
                state.requests.append(request)
                guard var queue = state.responses[path], !queue.isEmpty else { return nil }
                let first = queue.removeFirst()
                // Keep the last response for repeated calls.
                state.responses[path] = queue.isEmpty ? [first] : queue
                return first
            }
            guard let response, let url = request.url,
                  let http = HTTPURLResponse(url: url, statusCode: response.status, httpVersion: nil, headerFields: nil)
            else { throw URLError(.badServerResponse) }
            return (response.body, http)
        }
    }
}

final class LockIsolatedBox<Value>: @unchecked Sendable {
    // @unchecked: every access goes through `lock`.
    private var value: Value
    private let lock = NSLock()

    init(_ value: Value) {
        self.value = value
    }

    func mutate<T>(_ body: (inout Value) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }

    func read<T>(_ body: (Value) -> T) -> T {
        mutate { body($0) }
    }
}

enum Fixture {
    static func data(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try Data(contentsOf: url)
    }
}

struct GoogleCalendarAPITests {
    let primaryEvents = "/calendar/v3/calendars/demo@example.com/events"
    let teamEvents = "/calendar/v3/calendars/team123@group.calendar.google.com/events"
    let calendarList = "/calendar/v3/users/me/calendarList"

    func api(_ stub: StubTransport, tokens: TokenCounter = TokenCounter()) -> GoogleCalendarAPI {
        GoogleCalendarAPI(transport: stub.transport, timeZone: madrid, accessToken: { tokens.next() })
    }

    @Test func calendarListFiltersHiddenAndUnselected() async throws {
        let stub = StubTransport()
        try stub.respond(path: calendarList, fixture: "calendarList")
        let calendars = try await api(stub).calendars()
        #expect(calendars == [
            CalendarSummary(id: "demo@example.com", name: "demo@example.com", isPrimary: true, colorHex: "#9fe1e7"),
            CalendarSummary(id: "team123@group.calendar.google.com", name: "Equipo", colorHex: "#7bd148"),
        ])
        let request = try #require(stub.requests.first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token-1")
    }

    @Test func eventsMapping() async throws {
        let stub = StubTransport()
        try stub.respond(path: primaryEvents, fixture: "events")
        let events = try await api(stub).events(
            from: date("2026-11-03 00:00"), to: date("2026-11-04 00:00"), calendarIDs: ["demo@example.com"]
        )
        #expect(events.map(\.id) == ["birthday1", "retro1", "focus1", "demo1", "weekly_20261103T100000Z", "teams1", "noTitle"])

        let weekly = try #require(events.first { $0.id == "weekly_20261103T100000Z" })
        #expect(weekly.title == "Weekly sync")
        #expect(weekly.start == date("2026-11-03 11:00"))
        #expect(weekly.end == date("2026-11-03 11:30"))
        #expect(weekly.meetingLink == meetLink)
        #expect(weekly.attendeeStatus == .accepted)
        #expect(weekly.hasOtherAttendees)
        #expect(weekly.organizer == "Ana")
        #expect(weekly.calendarID == "demo@example.com")
        #expect(weekly.htmlLink?.absoluteString == "https://www.google.com/calendar/event?eid=d2Vla2x5")
        #expect(!weekly.isAllDay)

        let retro = try #require(events.first { $0.id == "retro1" })
        #expect(retro.start == date("2026-11-03 09:00"))
        #expect(retro.attendeeStatus == .declined)
        #expect(retro.meetingLink?.provider == .zoom)

        let focus = try #require(events.first { $0.id == "focus1" })
        #expect(focus.start == date("2026-11-03 09:30"))
        #expect(focus.attendeeStatus == .accepted)
        #expect(!focus.hasOtherAttendees)
        #expect(focus.meetingLink == nil)

        let demo = try #require(events.first { $0.id == "demo1" })
        #expect(demo.meetingLink == zoomLink)
        #expect(demo.attendeeStatus == .tentative)
        #expect(demo.hasOtherAttendees)

        let teams = try #require(events.first { $0.id == "teams1" })
        #expect(teams.meetingLink?.provider == .teams)
        #expect(teams.attendeeStatus == .needsAction)

        let birthday = try #require(events.first { $0.id == "birthday1" })
        #expect(birthday.isAllDay)
        #expect(birthday.start == date("2026-11-03 00:00"))
        #expect(birthday.end == date("2026-11-04 00:00"))

        let untitled = try #require(events.first { $0.id == "noTitle" })
        #expect(untitled.title == "(No title)")
        #expect(untitled.attendeeStatus == .unknown)
        #expect(untitled.hasOtherAttendees)
    }

    @Test func eventsRequestParameters() async throws {
        let stub = StubTransport()
        try stub.respond(path: primaryEvents, fixture: "events")
        _ = try await api(stub).events(
            from: date("2026-11-03 10:00"), to: date("2026-11-04 10:00"), calendarIDs: ["demo@example.com"]
        )
        let url = try #require(stub.requests.first?.url)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let query = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        #expect(query["singleEvents"] == "true")
        #expect(query["orderBy"] == "startTime")
        #expect(query["timeMin"] == "2026-11-03T09:00:00Z")
        #expect(query["timeMax"] == "2026-11-04T09:00:00Z")
        #expect(query["maxResults"] == "250")
        #expect(query["fields"]?.contains("hangoutLink") == true)
    }

    @Test func allVisibleCalendarsAreFetchedAndDeduplicated() async throws {
        let stub = StubTransport()
        try stub.respond(path: calendarList, fixture: "calendarList")
        try stub.respond(path: primaryEvents, fixture: "events")
        try stub.respond(path: teamEvents, fixture: "events")
        let events = try await api(stub).events(from: date("2026-11-03 00:00"), to: date("2026-11-04 00:00"), calendarIDs: nil)
        #expect(events.count == 7)
        #expect(Set(events.map(\.calendarID)) == ["demo@example.com"])
        let paths = Set(stub.requests.compactMap { $0.url?.path() })
        #expect(paths == [calendarList, primaryEvents, teamEvents])
    }

    @Test func pagination() async throws {
        let stub = StubTransport()
        let first = #"{"items":[{"id":"a","summary":"A","start":{"dateTime":"2026-11-03T10:00:00Z"},"#
            + #""end":{"dateTime":"2026-11-03T11:00:00Z"}}],"nextPageToken":"p2"}"#
        let second = #"{"items":[{"id":"b","summary":"B","start":{"dateTime":"2026-11-03T12:00:00Z"},"#
            + #""end":{"dateTime":"2026-11-03T13:00:00Z"}}]}"#
        stub.respond(path: primaryEvents, status: 200, body: first)
        stub.respond(path: primaryEvents, status: 200, body: second)
        let events = try await api(stub).events(
            from: date("2026-11-03 00:00"), to: date("2026-11-04 00:00"), calendarIDs: ["demo@example.com"]
        )
        #expect(events.map(\.id) == ["a", "b"])
        #expect(stub.requests.last?.url?.query()?.contains("pageToken=p2") == true)
    }

    /// 401 → one retry with a fresh token → still 401 → unauthorized (the app then signs out).
    @Test func unauthorizedAfterRetry() async throws {
        let stub = StubTransport()
        stub.respond(path: calendarList, status: 401, body: #"{"error":{"code":401,"message":"Invalid Credentials"}}"#)
        let tokens = TokenCounter()
        await #expect(throws: CalendarError.unauthorized) {
            try await api(stub, tokens: tokens).calendars()
        }
        #expect(stub.requests.count == 2)
        #expect(stub.requests.map { $0.value(forHTTPHeaderField: "Authorization") } == ["Bearer token-1", "Bearer token-2"])
    }

    @Test func unauthorizedThenRefreshedSucceeds() async throws {
        let stub = StubTransport()
        stub.respond(path: calendarList, status: 401, body: "{}")
        try stub.respond(path: calendarList, fixture: "calendarList")
        let calendars = try await api(stub).calendars()
        #expect(calendars.count == 2)
    }

    @Test func tokenFailureIsUnauthorized() async {
        let api = GoogleCalendarAPI(transport: StubTransport().transport, accessToken: { throw AuthError.notSignedIn })
        await #expect(throws: CalendarError.unauthorized) {
            try await api.calendars()
        }
    }

    @Test func serverAndDecodingErrors() async {
        let stub = StubTransport()
        stub.respond(path: calendarList, status: 503, body: "")
        await #expect(throws: CalendarError.server(status: 503)) { try await api(stub).calendars() }

        let garbage = StubTransport()
        garbage.respond(path: calendarList, status: 200, body: "<html>")
        await #expect(throws: CalendarError.decoding) { try await api(garbage).calendars() }
    }

    @Test func offline() async {
        let api = GoogleCalendarAPI(transport: { _ in throw URLError(.notConnectedToInternet) }, accessToken: { "t" })
        await #expect(throws: CalendarError.offline) { try await api.calendars() }
    }

    @Test func errorMetadata() {
        #expect(CalendarError.unauthorized.analyticsType == .unauthorized)
        #expect(CalendarError.offline.analyticsType == .network)
        #expect(CalendarError.server(status: 500).analyticsType == .server)
        #expect(CalendarError.decoding.analyticsType == .decoding)
        #expect([CalendarError.unauthorized, .offline, .server(status: 503), .decoding].map(\.code) == [401, -1009, 503, -1])
        #expect(AuthError.notConfigured.analyticsType == .notConfigured)
        #expect(AuthError.missingCalendarScope.analyticsType == .missingScope)
        #expect(AuthError.cancelled.analyticsType == .cancelled)
        #expect(AuthError.notSignedIn.analyticsType == .unauthorized)
        #expect(AuthError.failed(code: 3).analyticsType == .unknown)
    }

    @Test func attendeeStatusMapping() {
        #expect(GoogleCalendarMapper.attendeeStatus("accepted") == .accepted)
        #expect(GoogleCalendarMapper.attendeeStatus("tentative") == .tentative)
        #expect(GoogleCalendarMapper.attendeeStatus("declined") == .declined)
        #expect(GoogleCalendarMapper.attendeeStatus("needsAction") == .needsAction)
        #expect(GoogleCalendarMapper.attendeeStatus("weird") == .unknown)
        #expect(GoogleCalendarMapper.attendeeStatus(nil) == .unknown)
        #expect(GoogleCalendarMapper.parseDay("2026-11", timeZone: madrid) == nil)
    }

    @Test func mockCalendar() async throws {
        let now = date("2026-11-03 10:00")
        let client = CalendarClient.mock(now: { now })
        let events = try await client.upcomingEvents(now, now.addingTimeInterval(86400), nil)
        #expect(events.map(\.title) == ["Weekly sync", "Demo cliente", "Cumpleaños de Marta", "Retro"])
        #expect(events.first?.start == now.addingTimeInterval(90))
        let personal = try await client.upcomingEvents(now, now.addingTimeInterval(86400), ["personal"])
        #expect(personal.map(\.title) == ["Cumpleaños de Marta"])
        #expect(try await client.calendars().count == 2)
    }
}

final class TokenCounter: Sendable {
    private let count = LockIsolatedBox(0)

    func next() -> String {
        count.mutate { value in
            value += 1
            return "token-\(value)"
        }
    }
}
