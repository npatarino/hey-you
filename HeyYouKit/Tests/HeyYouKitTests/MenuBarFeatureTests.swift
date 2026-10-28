import ComposableArchitecture
import DependenciesTestSupport
import Foundation
@testable import HeyYouKit
import Testing

@Suite(.dependencies)
struct MenuBarFeatureTests {
    func appState(
        events: [CalendarEvent], isPro: Bool = false, configure: (inout AppSettings) -> Void = { _ in }
    ) -> AppFeature.State {
        var state = AppFeature.State()
        state.auth = .signedIn(GoogleAccount(email: "demo@example.com"))
        state.calendars = MockCalendar.calendars
        state.events = IdentifiedArray(uniqueElements: events)
        state.$entitlements.withLock { $0.isPro = isPro }
        state.$settings.withLock(configure)
        return state
    }

    @Test func rowsAreTodaysUpcomingTimedEvents() {
        let events = (0 ..< 7).map { index in
            CalendarEvent.fixture(id: "e\(index)", title: "E\(index)", start: "2026-11-03 \(12 + index):00")
        } + [
            .fixture(id: "past", title: "Past", start: "2026-11-03 08:00"),
            .fixture(id: "allday", title: "Holiday", start: "2026-11-03 00:00", end: "2026-11-04 00:00", isAllDay: true),
            .fixture(id: "tomorrow", title: "Tomorrow", start: "2026-11-04 09:00"),
        ]
        let menu = MenuBarFeature.state(from: appState(events: events), now: date("2026-11-03 11:00"), calendar: madridCalendar)
        #expect(menu.rows.map(\.event.id) == ["e0", "e1", "e2", "e3", "e4"])
        #expect(menu.iconName == "bell")
        #expect(menu.status == .watching(calendars: 2, nextStart: nil))
        #expect(menu.countdown == nil)
        #expect(menu.punctuality == nil)
        #expect(menu.showsProEntry)
        #expect(!menu.canConnect)
    }

    @Test func filteredAndOutsideHours() {
        let declined = CalendarEvent.fixture(id: "d", title: "Declined", start: "2026-11-07 10:00", status: .declined)
        let saturday = CalendarEvent.fixture(id: "s", title: "Saturday", start: "2026-11-07 11:00")
        let state = appState(events: [declined, saturday], isPro: true) {
            $0.applyProDefaults()
            $0.workingHours = .officeDefault
        }
        let menu = MenuBarFeature.state(from: state, now: date("2026-11-07 09:00"), calendar: madridCalendar)
        #expect(menu.rows.map(\.isFiltered) == [true, false])
        #expect(menu.rows.map(\.isOutsideWorkingHours) == [true, true])
        #expect(menu.rows.first?.id == declined.dedupeKey)
    }

    @Test func countdownOnlyForProUnderTenMinutes() {
        var state = appState(events: [weeklySync], isPro: true)
        state.nextAlert = ScheduledAlert(event: weeklySync, fireAt: date("2026-11-03 10:59"))
        #expect(MenuBarFeature.state(from: state, now: date("2026-11-03 10:50:30"), calendar: madridCalendar).countdown == "10m")
        #expect(MenuBarFeature.state(from: state, now: date("2026-11-03 10:50:00"), calendar: madridCalendar).countdown == nil)
        #expect(MenuBarFeature.state(from: state, now: date("2026-11-03 10:59:30"), calendar: madridCalendar).countdown == "1m")
        #expect(MenuBarFeature.state(from: state, now: date("2026-11-03 11:00:00"), calendar: madridCalendar).countdown == nil)
        state.$settings.withLock { $0.showCountdownInMenuBar = false }
        #expect(MenuBarFeature.state(from: state, now: date("2026-11-03 10:55"), calendar: madridCalendar).countdown == nil)
        state.$settings.withLock { $0.showCountdownInMenuBar = true }
        state.$entitlements.withLock { $0.isPro = false }
        #expect(MenuBarFeature.state(from: state, now: date("2026-11-03 10:55"), calendar: madridCalendar).countdown == nil)
    }

    @Test func statuses() {
        var state = appState(events: [])
        state.auth = .unknown
        #expect(MenuBarFeature.state(from: state, now: .now, calendar: madridCalendar).status == .loading)
        state.auth = .signedOut
        let signedOut = MenuBarFeature.state(from: state, now: .now, calendar: madridCalendar)
        #expect(signedOut.status == .signedOut)
        #expect(signedOut.iconName == "bell.slash")
        #expect(signedOut.canConnect)
        state.auth = .sessionExpired(email: "demo@example.com")
        #expect(MenuBarFeature.state(from: state, now: .now, calendar: madridCalendar).status == .sessionExpired)
        #expect(state.auth.account == nil)
        state.auth = .signedIn(GoogleAccount(email: "demo@example.com"))
        state.offlineSince = date("2026-11-03 10:50")
        #expect(MenuBarFeature.state(from: state, now: .now, calendar: madridCalendar).status == .offline(since: date("2026-11-03 10:50")))
        state.offlineSince = nil
        state.$entitlements.withLock { $0.isPro = true }
        state.$settings.withLock { $0.selectedCalendarIDs = ["primary"] }
        #expect(MenuBarFeature.state(from: state, now: .now, calendar: madridCalendar).status == .watching(calendars: 1, nextStart: nil))
    }
}
