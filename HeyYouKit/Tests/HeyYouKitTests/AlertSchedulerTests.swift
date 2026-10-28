import Foundation
@testable import HeyYouKit
import Testing

struct AlertSchedulerTests {
    let weekly = CalendarEvent.fixture(title: "Weekly sync", start: "2026-11-03 11:00", end: "2026-11-03 11:30")

    /// PRD B.1
    @Test func basicFire() {
        let alert = AlertScheduler.next(events: [weekly], now: date("2026-11-03 10:58:30"), settings: free, fired: [])
        #expect(alert?.event == weekly)
        #expect(alert?.fireAt == date("2026-11-03 10:59:00"))
        #expect(alert?.additionalCount == 0)
        #expect(alert?.proHook == nil)
    }

    /// PRD B.5: once fired, a refresh with the same event schedules the next one.
    @Test func dedupe() {
        let next = CalendarEvent.fixture(title: "1:1 con Ana", start: "2026-11-03 12:30")
        let alert = AlertScheduler.next(
            events: [weekly, next], now: date("2026-11-03 10:59:30"), settings: free, fired: [weekly.dedupeKey]
        )
        #expect(alert?.event == next)
        #expect(alert?.fireAt == date("2026-11-03 12:29:00"))
    }

    /// Fire time already passed but the event has not started: fire now (fireAt in the past).
    @Test func lateFireStillReturned() {
        let ana = CalendarEvent.fixture(title: "1:1 con Ana", start: "2026-11-03 12:30", end: "2026-11-03 13:00")
        let alert = AlertScheduler.next(events: [ana], now: date("2026-11-03 12:29:40"), settings: free, fired: [])
        #expect(alert?.event == ana)
        #expect(alert?.fireAt == date("2026-11-03 12:29:00"))
    }

    /// PRD B.7: after wake an event in progress still alerts; a finished one does not.
    @Test func inProgressOnlyOnWake() {
        let ana = CalendarEvent.fixture(title: "1:1 con Ana", start: "2026-11-03 12:30", end: "2026-11-03 13:00")
        let now = date("2026-11-03 12:34:10")
        #expect(AlertScheduler.next(events: [ana], now: now, settings: free, fired: []) == nil)
        #expect(AlertScheduler.next(events: [ana], now: now, settings: free, fired: [], includeInProgress: true)?.event == ana)
        #expect(
            AlertScheduler.next(
                events: [ana], now: date("2026-11-03 13:05"), settings: free, fired: [], includeInProgress: true
            ) == nil
        )
        #expect(
            AlertScheduler.next(
                events: [ana], now: now, settings: free, fired: [ana.dedupeKey], includeInProgress: true
            ) == nil
        )
    }

    /// PRD B.8 fixtures.
    var b8Events: [CalendarEvent] {
        [
            .fixture(
                title: "Cumpleaños de Marta", start: "2026-11-03 00:00", end: "2026-11-04 00:00",
                isAllDay: true, link: nil, others: false
            ),
            .fixture(title: "Retro", start: "2026-11-03 09:00", link: meetLink, status: .declined),
            .fixture(title: "Foco", start: "2026-11-03 09:30", end: "2026-11-03 11:00", link: nil, others: false),
            .fixture(title: "Demo cliente", start: "2026-11-03 10:00", link: zoomLink, others: true),
        ]
    }

    @Test func b8Free() {
        var now = date("2026-11-03 08:00")
        var fired: Set<String> = []
        var sequence: [(String, Date, ProHook?)] = []
        while let alert = AlertScheduler.next(events: b8Events, now: now, settings: free, fired: fired) {
            sequence.append((alert.event.title, alert.fireAt, alert.proHook))
            fired.formUnion(alert.dedupeKeys)
            now = alert.fireAt
        }
        #expect(sequence.map(\.0) == ["Retro", "Foco", "Demo cliente"])
        #expect(sequence.map(\.1) == [date("2026-11-03 08:59"), date("2026-11-03 09:29"), date("2026-11-03 09:59")])
        #expect(sequence.map(\.2) == [.declined, .solo, nil])
    }

    @Test func b8Pro() {
        let now = date("2026-11-03 08:00")
        let alert = AlertScheduler.next(events: b8Events, now: now, settings: pro(), fired: [])
        #expect(alert?.event.title == "Demo cliente")
        #expect(alert?.fireAt == date("2026-11-03 09:59"))
        #expect(alert?.event.meetingLink?.provider == .zoom)
        #expect(alert?.proHook == nil)

        let onlyLink = AlertScheduler.next(
            events: b8Events, now: now, settings: pro { $0.onlyEventsWithMeetingLink = true }, fired: []
        )
        #expect(onlyLink?.event.title == "Demo cliente")

        let short = AlertScheduler.next(events: b8Events, now: now, settings: pro { $0.leadTimeSeconds = 20 }, fired: [])
        #expect(short?.fireAt == date("2026-11-03 09:59:40"))
    }

    /// PRD B.9: same start → one alert, alphabetical first, "+1 more", both fired.
    @Test func overlap() {
        let roadmap = CalendarEvent.fixture(title: "Alinear roadmap", start: "2026-11-03 11:00")
        let alert = AlertScheduler.next(events: [weekly, roadmap], now: date("2026-11-03 10:00"), settings: free, fired: [])
        #expect(alert?.event == roadmap)
        #expect(alert?.overlapping == [weekly])
        #expect(alert?.additionalCount == 1)
        #expect(alert?.dedupeKeys == [roadmap.dedupeKey, weekly.dedupeKey])
        #expect(alert?.fireAt == date("2026-11-03 10:59"))
    }

    @Test func overlapSameTitleOrdersByID() {
        let first = CalendarEvent.fixture(id: "a", title: "Sync", start: "2026-11-03 11:00")
        let second = CalendarEvent.fixture(id: "b", title: "Sync", start: "2026-11-03 11:00")
        let alert = AlertScheduler.next(events: [second, first], now: date("2026-11-03 10:00"), settings: free, fired: [])
        #expect(alert?.event.id == "a")
    }

    @Test func earliestWinsRegardlessOfOrder() {
        let later = CalendarEvent.fixture(title: "A later", start: "2026-11-03 15:00")
        let alert = AlertScheduler.next(events: [later, weekly], now: date("2026-11-03 10:00"), settings: free, fired: [])
        #expect(alert?.event == weekly)
    }

    @Test func allDayNeverFires() {
        let allDay = CalendarEvent.fixture(title: "Holiday", start: "2026-11-04 00:00", end: "2026-11-05 00:00", isAllDay: true)
        #expect(AlertScheduler.next(events: [allDay], now: date("2026-11-03 10:00"), settings: free, fired: []) == nil)
    }

    @Test func emptyEvents() {
        #expect(AlertScheduler.next(events: [], now: date("2026-11-03 10:00"), settings: free, fired: []) == nil)
    }

    @Test func leadTimeChangeMovesFire() {
        let now = date("2026-11-03 10:00")
        let at60 = AlertScheduler.next(events: [weekly], now: now, settings: pro { $0.leadTimeSeconds = 60 }, fired: [])
        let at10 = AlertScheduler.next(events: [weekly], now: now, settings: pro { $0.leadTimeSeconds = 10 }, fired: [])
        let at65 = AlertScheduler.next(events: [weekly], now: now, settings: pro { $0.leadTimeSeconds = 65 }, fired: [])
        #expect(at60?.fireAt == date("2026-11-03 10:59:00"))
        #expect(at10?.fireAt == date("2026-11-03 10:59:50"))
        #expect(at65?.fireAt == date("2026-11-03 10:59:00"))
    }

    @Test func calendarSelection() {
        let personal = CalendarEvent.fixture(title: "Dentist", start: "2026-11-03 10:30", calendarID: "personal")
        let now = date("2026-11-03 10:00")
        let all = AlertScheduler.next(events: [personal, weekly], now: now, settings: pro(), fired: [])
        #expect(all?.event == personal)
        let workOnly = AlertScheduler.next(
            events: [personal, weekly], now: now, settings: pro { $0.selectedCalendarIDs = ["primary"] }, fired: []
        )
        #expect(workOnly?.event == weekly)
        // Free users always watch every calendar.
        let freeAlert = AlertScheduler.next(events: [personal, weekly], now: now, settings: free, fired: [])
        #expect(freeAlert?.event == personal)
    }

    @Test func onlyWithLinkFilter() {
        let noLink = CalendarEvent.fixture(title: "Room only", start: "2026-11-03 10:30", link: nil)
        let now = date("2026-11-03 10:00")
        #expect(AlertScheduler.next(events: [noLink, weekly], now: now, settings: pro(), fired: [])?.event == noLink)
        let settings = pro { $0.onlyEventsWithMeetingLink = true }
        #expect(AlertScheduler.next(events: [noLink, weekly], now: now, settings: settings, fired: [])?.event == weekly)
    }

    /// PRD B.20
    @Test func workingHoursFilter() {
        let settings = pro { $0.workingHours = .officeDefault }
        let saturday = CalendarEvent.fixture(title: "Sat", start: "2026-11-07 10:00")
        let early = CalendarEvent.fixture(title: "Early", start: "2026-11-09 08:30")
        let late = CalendarEvent.fixture(title: "Late", start: "2026-11-09 17:59")
        let alert = AlertScheduler.next(
            events: [saturday, early, late], now: date("2026-11-06 20:00"), settings: settings, fired: [],
            calendar: madridCalendar
        )
        #expect(alert?.event == late)
    }

    @Test func proHooksOnlyForFree() {
        let solo = CalendarEvent.fixture(title: "Solo", start: "2026-11-03 11:00", link: meetLink, others: false)
        let noLink = CalendarEvent.fixture(title: "No link", start: "2026-11-03 11:00", link: nil, others: true)
        let declinedSolo = CalendarEvent.fixture(title: "Both", start: "2026-11-03 11:00", link: nil, status: .declined, others: false)
        #expect(AlertScheduler.proHook(for: solo, settings: free) == .solo)
        #expect(AlertScheduler.proHook(for: noLink, settings: free) == .noLink)
        #expect(AlertScheduler.proHook(for: declinedSolo, settings: free) == .declined)
        #expect(AlertScheduler.proHook(for: weekly, settings: free) == nil)
        #expect(AlertScheduler.proHook(for: declinedSolo, settings: pro { $0.ignoreDeclined = false }) == nil)
        let none: ProHook? = nil
        #expect(none.analyticsName == "none")
        #expect(ProHook.noLink.rawValue == "no_link")
    }

    @Test func proIgnoresSoloAndDeclined() {
        let solo = CalendarEvent.fixture(title: "Solo", start: "2026-11-03 10:30", others: false)
        let declined = CalendarEvent.fixture(title: "Declined", start: "2026-11-03 10:40", status: .declined)
        let now = date("2026-11-03 10:00")
        #expect(AlertScheduler.next(events: [solo, declined, weekly], now: now, settings: pro(), fired: [])?.event == weekly)
        let soloAllowed = pro { $0.ignoreWithoutOtherAttendees = false }
        #expect(AlertScheduler.next(events: [solo, declined, weekly], now: now, settings: soloAllowed, fired: [])?.event == solo)
    }

    /// PRD B.4 and B.7
    @Test(arguments: [
        (60, AlertPhase.countingDown(seconds: 60)),
        (1, .countingDown(seconds: 1)),
        (0, .startingNow),
        (-59, .startingNow),
        (-60, .started(minutesAgo: 1)),
        (-180, .started(minutesAgo: 3)),
        (-250, .started(minutesAgo: 4)),
    ])
    func alertPhase(seconds: Int, expected: AlertPhase) {
        #expect(AlertPhase(secondsRemaining: seconds) == expected)
    }
}
