import ComposableArchitecture
import DependenciesTestSupport
import Foundation
@testable import HeyYouKit
import Testing

@Suite(.dependencies)
struct PresentationTests {
    let posix = Locale(identifier: "en_GB")

    func alert(now: String, event: CalendarEvent = weeklySync, overlap: Int = 0, hook: ProHook? = nil) -> AlertFeature.State {
        AlertFeature.State(event: event, additionalCount: overlap, proHook: hook, now: date(now))
    }

    /// PRD B.1 / B.4 texts.
    @Test func alertTexts() {
        let counting = alert(now: "2026-11-03 10:59:00")
        #expect(counting.headline == "MEETING IN")
        #expect(counting.metaLine(locale: posix, timeZone: madrid) == "11:00 – 11:30 · Google Meet")
        #expect(counting.actionTitle == "Join meeting")
        #expect(counting.additionalText == nil)
        #expect(counting.hookText == nil)
        #expect(counting.countdownAccessibilityLabel == "Meeting in 60 seconds")

        #expect(alert(now: "2026-11-03 11:00:30").countdownAccessibilityLabel == "Meeting starting now")
        let started = alert(now: "2026-11-03 11:03:00")
        #expect(started.headline == "STARTED 3 MIN AGO")
        #expect(started.countdownAccessibilityLabel == "Meeting started 3 minutes ago")
    }

    @Test func alertWithoutLinkOverlapAndHooks() {
        let room = CalendarEvent.fixture(title: "Room", start: "2026-11-03 11:00", link: nil)
        let state = alert(now: "2026-11-03 10:59", event: room, overlap: 1, hook: .noLink)
        #expect(state.metaLine(locale: posix, timeZone: madrid) == "11:00 – 11:30")
        #expect(state.actionTitle == "Open in Calendar")
        #expect(state.additionalText == "+1 more")
        #expect(state.hookText == "No link · With Pro we wouldn't have alerted you")
        #expect(alert(now: "2026-11-03 10:59", hook: .declined).hookText == "Declined · With Pro we wouldn't have alerted you")
        #expect(alert(now: "2026-11-03 10:59", hook: .solo).hookText == "Just you · With Pro we wouldn't have alerted you")
    }

    @Test func soundNames() {
        #expect(AlertSound.allCases.map(\.displayName) == ["Default", "Chime", "Pulse", "Horn", "Bell", "None"])
    }

    @Test func buyTitle() {
        var paywall = PaywallFeature.State(source: .menu)
        #expect(paywall.buyTitle == "Buy")
        paywall.products = [StoreProduct(id: AppConfig.proProductID, displayName: "Pro", displayPrice: "5,99 €")]
        #expect(paywall.buyTitle == "Buy for 5,99 € · one time")
    }

    @Test func timeText() {
        #expect(TimeText.time(date("2026-11-03 09:05"), locale: posix, timeZone: madrid) == "9:05")
        let now = date("2026-11-03 10:18")
        #expect(TimeText.relative(date("2026-11-03 11:00"), now: now) == "42 min")
        #expect(TimeText.relative(date("2026-11-03 12:30"), now: now, locale: posix, timeZone: madrid) == "12:30")
        #expect(TimeText.relative(date("2026-11-03 10:00"), now: now) == "0 min")
    }

    @Test func workingHoursHelpers() {
        var monday = madridCalendar
        monday.firstWeekday = 2
        #expect(WorkingHours.orderedWeekdays(calendar: monday) == [2, 3, 4, 5, 6, 7, 1])
        var sunday = madridCalendar
        sunday.firstWeekday = 1
        #expect(WorkingHours.orderedWeekdays(calendar: sunday) == [1, 2, 3, 4, 5, 6, 7])
        var english = madridCalendar
        english.locale = Locale(identifier: "en_US")
        #expect(WorkingHours.symbol(for: 2, calendar: english) == "M")
        #expect(WorkingHours.symbol(for: 9, calendar: english).isEmpty)
        let picked = WorkingHours.date(forMinute: 9 * 60 + 30, on: date("2026-11-03 15:00"), calendar: madridCalendar)
        #expect(picked == date("2026-11-03 09:30"))
        #expect(WorkingHours.minute(of: picked, calendar: madridCalendar) == 570)
    }

    // MARK: - Menu bar

    func menu(_ configure: (inout AppFeature.State) -> Void, now: String = "2026-11-03 10:18") -> MenuBarFeature.State {
        var state = AppFeature.State()
        state.auth = .signedIn(GoogleAccount(email: "demo@example.com"))
        state.calendars = MockCalendar.calendars
        configure(&state)
        return MenuBarFeature.state(from: state, now: date(now), calendar: madridCalendar)
    }

    @Test func menuStatusTexts() {
        let watching = menu { $0.nextAlert = ScheduledAlert(event: weeklySync, fireAt: date("2026-11-03 10:59")) }
        #expect(watching.statusText() == "Watching 2 calendars · next in 42 min")
        #expect(watching.statusTone == .normal)
        #expect(menu { _ in }.statusText() == "Watching 2 calendars")

        let offline = menu { $0.offlineSince = date("2026-11-03 10:50") }
        #expect(offline.statusText(locale: posix, timeZone: madrid) == "Offline since 10:50")
        #expect(offline.statusTone == .warning)

        let expired = menu { $0.auth = .sessionExpired(email: "demo@example.com") }
        #expect(expired.statusText() == "Disconnected from Google")
        #expect(expired.statusTone == .error)
        #expect(expired.connectTitle == "Sign in again")

        let signedOut = menu { $0.auth = .signedOut }
        #expect(signedOut.statusText() == "Not connected to Google")
        #expect(signedOut.connectTitle == "Connect Google Calendar")
        #expect(menu { $0.auth = .unknown }.statusText() == "Connecting…")
    }

    @Test func menuPunctualityText() {
        #expect(menu { _ in }.punctualityText == nil)
        let pro = menu {
            $0.$entitlements.withLock { $0.isPro = true }
            $0.$stats.withLock { $0 = PunctualityStats(weekStart: date("2026-11-02 00:00"), alerts: 12, onTime: 11) }
        }
        #expect(pro.punctualityText == "On time 11 of 12 this week")
    }

    @Test func singularCalendar() {
        let one = menu { $0.calendars = [MockCalendar.calendars[0]] }
        #expect(one.statusText() == "Watching 1 calendar")
    }
}
