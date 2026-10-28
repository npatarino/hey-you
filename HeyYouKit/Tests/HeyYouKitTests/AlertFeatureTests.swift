import ComposableArchitecture
import DependenciesTestSupport
import Foundation
@testable import HeyYouKit
import Testing

@MainActor
@Suite(.dependencies)
struct AlertFeatureTests {
    func state(now: String) -> AlertFeature.State {
        AlertFeature.State(event: weeklySync, now: date(now))
    }

    /// PRD B.1: 60 s at 10:59:00.
    @Test func countdownAtFire() {
        let alert = state(now: "2026-11-03 10:59:00")
        #expect(alert.secondsRemaining == 60)
        #expect(alert.phase == .countingDown(seconds: 60))
        #expect(alert.progress == 1)
        #expect(alert.hasMeetingLink)
        #expect(alert.joinURL == meetLink.url)
        #expect(alert.shownAt == date("2026-11-03 10:59:00"))
    }

    /// PRD B.4: NOW at 11:00:00 and 11:00:59, then STARTED 3 MIN AGO at 11:03:00.
    @Test func phasesWithoutInteraction() {
        var alert = state(now: "2026-11-03 10:59:00")
        alert.now = date("2026-11-03 10:59:30")
        #expect(alert.secondsRemaining == 30)
        #expect(alert.progress == 0.5)
        alert.now = date("2026-11-03 11:00:00")
        #expect(alert.phase == .startingNow)
        alert.now = date("2026-11-03 11:00:59")
        #expect(alert.phase == .startingNow)
        alert.now = date("2026-11-03 11:03:00")
        #expect(alert.phase == .started(minutesAgo: 3))
        #expect(alert.progress == 0)
    }

    @Test func fractionalSecondsRoundUp() {
        var alert = state(now: "2026-11-03 10:59:00")
        alert.now = date("2026-11-03 10:59:00").addingTimeInterval(0.4)
        #expect(alert.secondsRemaining == 60)
    }

    @Test func noLinkOpensCalendar() {
        let event = CalendarEvent.fixture(title: "Room", start: "2026-11-03 11:00", link: nil)
        let alert = AlertFeature.State(event: event, now: date("2026-11-03 10:59"))
        #expect(!alert.hasMeetingLink)
        #expect(alert.joinURL == event.htmlLink)
    }

    @Test func ticksFollowTheClock() async {
        let env = TestEnvironment(now: "2026-11-03 10:59:00")
        let store = TestStore(initialState: AlertFeature.State(event: weeklySync, now: env.now)) {
            AlertFeature()
        } withDependencies: { env.apply(&$0) }

        let task = await store.send(.task)
        await env.clock.advance(by: .seconds(1))
        await store.receive(\.tick) { $0.now = date("2026-11-03 10:59:01") }
        await env.clock.advance(by: .seconds(1))
        await store.receive(\.tick) { $0.now = date("2026-11-03 10:59:02") }
        #expect(store.state.secondsRemaining == 58)
        await task.cancel()
    }

    /// PRD B.2: Enter / Join opens the link and finishes.
    @Test func joinOpensLink() async {
        let env = TestEnvironment(now: "2026-11-03 10:59:12")
        let store = TestStore(initialState: AlertFeature.State(event: weeklySync, now: env.now)) {
            AlertFeature()
        } withDependencies: { env.apply(&$0) }

        await env.clock.advance(by: .seconds(1))
        await store.send(.joinTapped)
        await store.receive(\.delegate.finished)
        #expect(env.openedURLs.value == [meetLink.url])
    }

    @Test func joinWithoutAnyURLStillFinishes() async {
        let env = TestEnvironment(now: "2026-11-03 10:59:12")
        let event = CalendarEvent(id: "x", title: "x", start: date("2026-11-03 11:00"), end: date("2026-11-03 11:30"))
        let store = TestStore(initialState: AlertFeature.State(event: event, now: env.now)) {
            AlertFeature()
        } withDependencies: { env.apply(&$0) }
        await env.clock.advance(by: .seconds(1))
        await store.send(.joinTapped)
        await store.receive(\.delegate.finished)
        #expect(env.openedURLs.value.isEmpty)
    }

    /// PRD B.3: a click, Esc or ⌘Q / ⌘W / ⌘. dismiss without opening anything.
    @Test(arguments: [DismissReason.click, .escape, .quitShortcut])
    func deliberateInputDismisses(reason: DismissReason) async {
        let env = TestEnvironment(now: "2026-11-03 10:59:12")
        let store = TestStore(initialState: AlertFeature.State(event: weeklySync, now: env.now)) {
            AlertFeature()
        } withDependencies: { env.apply(&$0) }
        let task = await store.send(.task)
        await env.clock.advance(by: .seconds(1))
        await store.receive(\.tick) { $0.now = date("2026-11-03 10:59:13") }
        await store.send(.dismissed(reason))
        await store.receive(.delegate(.finished(reason)))
        await task.finish()
        #expect(env.openedURLs.value.isEmpty)
    }

    /// Input that arrives in the first second (typing or clicking already in progress) is ignored.
    @Test func gracePeriodIgnoresInput() async {
        let env = TestEnvironment(now: "2026-11-03 10:59:00")
        let store = TestStore(initialState: AlertFeature.State(event: weeklySync, now: env.now)) {
            AlertFeature()
        } withDependencies: { env.apply(&$0) }

        #expect(store.state.isInGracePeriod(at: date("2026-11-03 10:59:00")))
        #expect(!store.state.isInGracePeriod(at: date("2026-11-03 10:59:01")))
        await store.send(.dismissed(.click))
        await store.send(.dismissed(.escape))
        await store.send(.dismissed(.quitShortcut))
        await store.send(.joinTapped)
        await env.clock.advance(by: .milliseconds(999))
        await store.send(.dismissed(.click))
        #expect(env.openedURLs.value.isEmpty)

        await env.clock.advance(by: .milliseconds(1))
        await store.send(.dismissed(.escape))
        await store.receive(.delegate(.finished(.escape)))
    }
}
