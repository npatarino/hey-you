import ComposableArchitecture
import ConcurrencyExtras
import DependenciesTestSupport
import Foundation
@testable import HeyYouKit
import Testing

@MainActor
@Suite(.dependencies)
struct AppFeatureTests: AppFeatureTesting {
    // MARK: - B.1 launch → sync → schedule → alert

    @Test func launchToAlert() async {
        let env = TestEnvironment(now: "2026-11-03 10:58:30", events: [weeklySync])
        let state = AppFeature.State()
        state.$onboardingCompleted.withLock { $0 = true }
        let store = makeStore(env, state: state)

        let task = await store.send(.task) {
            $0.$installDate.withLock { $0 = date("2026-11-03 10:58:30") }
        }
        await store.receive(\.entitlementsUpdated)
        await store.receive(\.accountRestored) {
            $0.auth = .signedIn(env.account)
            $0.settingsScreen.account = env.account
        }
        await store.receive(\.calendarsResponse) {
            $0.calendars = MockCalendar.calendars
            $0.settingsScreen.calendars = MockCalendar.calendars
        }
        await store.receive(\.refresh)
        await store.receive(\.eventsResponse) {
            $0.events = [weeklySync]
            $0.lastSyncAt = date("2026-11-03 10:58:30")
            $0.nextAlert = ScheduledAlert(event: weeklySync, fireAt: date("2026-11-03 10:59:00"))
        }
        await env.clock.advance(by: .seconds(29))
        #expect(store.state.alert == nil)
        await env.clock.advance(by: .seconds(1))
        await store.receive(\.alertDue) {
            $0.firedAlerts = [weeklySync.dedupeKey: weeklySync.end]
            $0.alert = AlertFeature.State(event: weeklySync, now: date("2026-11-03 10:59:00"))
            $0.nextAlert = nil
        }
        #expect(store.state.alert?.secondsRemaining == 60)
        #expect(store.state.isAlertVisible)

        // The 60 s refresh loop keeps running.
        await env.clock.advance(by: .seconds(30))
        await store.receive(\.refreshTick)
        await store.receive(\.refresh)
        await store.receive(\.eventsResponse) { $0.lastSyncAt = date("2026-11-03 10:59:30") }

        await task.cancel()
        await store.finish()
        #expect(env.sounds.value == [.default])
        #expect(env.trackedNames == [
            "app_launched", "calendar_synced", "alert_scheduled", "alert_shown", "calendar_synced",
        ])
        let shown = env.tracked("alert_shown").first?.properties
        #expect(shown?["provider"] == "meet")
        #expect(shown?["screens_count"] == 2)
        #expect(shown?["trigger"] == "scheduled")
        #expect(shown?["lead_time"] == 60)
        #expect(env.tracked("calendar_synced").first?.properties["calendars_count"] == 2)
        #expect(env.analytics.people.first?["email_hash"] != nil)
    }

    /// First launch without a session opens onboarding; signing in there starts syncing.
    @Test func firstLaunchOnboarding() async {
        let env = TestEnvironment(now: "2026-11-03 10:00", events: [])
        let store = TestStore(initialState: AppFeature.State()) { AppFeature() } withDependencies: {
            env.apply(&$0)
            $0.authClient.restorePreviousSignIn = { nil }
        }
        let task = await store.send(.task) { $0.$installDate.withLock { $0 = date("2026-11-03 10:00") } }
        await store.receive(\.entitlementsUpdated)
        await store.receive(\.accountRestored) {
            $0.auth = .signedOut
            $0.onboarding = OnboardingFeature.State()
        }
        await store.send(.onboarding(.presented(.signInTapped))) { $0.onboarding?.isSigningIn = true }
        await store.receive(\.onboarding.presented.signInResponse.success) {
            $0.onboarding?.isSigningIn = false
            $0.onboarding?.step = .connected(env.account)
            $0.$onboardingCompleted.withLock { $0 = true }
        }
        await store.receive(\.onboarding.presented.delegate.signedIn) {
            $0.auth = .signedIn(env.account)
            $0.settingsScreen.account = env.account
        }
        await store.receive(\.calendarsResponse) {
            $0.calendars = MockCalendar.calendars
            $0.settingsScreen.calendars = MockCalendar.calendars
        }
        await store.receive(\.refresh)
        await store.receive(\.eventsResponse) { $0.lastSyncAt = date("2026-11-03 10:00") }

        await store.send(.onboarding(.presented(.setLaunchAtLogin(true)))) {
            $0.onboarding?.launchAtLogin = .enabled
            $0.$settings.withLock { $0.launchAtLogin = true }
        }
        await store.receive(\.onboarding.presented.delegate.launchAtLoginChanged)
        await store.send(.onboarding(.presented(.testAlertTapped)))
        await store.receive(\.onboarding.presented.delegate.testAlert) { $0.onboarding = nil }
        await env.clock.advance(by: .seconds(5))
        await store.receive(\.alertDue) {
            $0.alert = AlertFeature.State(
                event: Self.testEvent(firedAt: date("2026-11-03 10:00:05")), trigger: .test, now: date("2026-11-03 10:00:05")
            )
        }
        await task.cancel()
        await store.finish()
        #expect(env.tracked("test_alert_triggered").first?.properties["source"] == "onboarding")
    }

    @Test func onboardingDone() async {
        let env = TestEnvironment(now: "2026-11-03 10:00")
        var state = signedIn(env)
        state.onboarding = OnboardingFeature.State(step: .connected(env.account))
        let store = makeStore(env, state: state)
        await store.send(.onboarding(.presented(.doneTapped)))
        await store.receive(\.onboarding.presented.delegate.finished) { $0.onboarding = nil }
    }

    // MARK: - B.2 / B.3

    @Test func joinOpensLinkAndCloses() async {
        let env = TestEnvironment(now: "2026-11-03 10:59:12", events: [weeklySync])
        var state = signedIn(env, events: [weeklySync])
        state.alert = AlertFeature.State(event: weeklySync, now: date("2026-11-03 10:59:00"))
        state.firedAlerts = [weeklySync.dedupeKey: weeklySync.end]
        let store = makeStore(env, state: state)

        await store.send(.alert(.presented(.joinTapped)))
        await store.receive(\.alert.presented.delegate.finished) { $0.alert = nil }
        await store.finish()
        #expect(env.openedURLs.value == [url("https://meet.google.com/abc-defg-hij")])
        let dismissed = env.tracked("alert_dismissed").first?.properties
        #expect(dismissed?["reason"] == "join")
        #expect(dismissed?["seconds_shown"] == 12)
        #expect(dismissed?["seconds_to_start"] == 48)
        #expect(dismissed?["provider"] == "meet")
        #expect(store.state.firedAlerts.keys.contains(weeklySync.dedupeKey))
    }

    @Test(arguments: [DismissReason.click, .key, .escape, .quitShortcut])
    func anyInteractionDismissesAndAppKeepsRunning(reason: DismissReason) async {
        let env = TestEnvironment(now: "2026-11-03 10:59:12")
        var state = signedIn(env)
        state.alert = AlertFeature.State(event: weeklySync, now: date("2026-11-03 10:59:00"))
        let store = makeStore(env, state: state)
        await store.send(.alert(.presented(.dismissed(reason))))
        await store.receive(\.alert.presented.delegate.finished) { $0.alert = nil }
        await store.finish()
        #expect(env.openedURLs.value.isEmpty)
        #expect(!env.terminated.value)
        #expect(store.state.auth == .signedIn(env.account))
    }

    // MARK: - B.5 dedupe

    @Test func dedupeAfterRefresh() async {
        let ana = CalendarEvent.fixture(id: "ana", title: "1:1 con Ana", start: "2026-11-03 12:30", end: "2026-11-03 13:00")
        let env = TestEnvironment(now: "2026-11-03 10:59:30", events: [weeklySync, ana])
        var state = signedIn(env, events: [weeklySync, ana])
        state.firedAlerts = [weeklySync.dedupeKey: weeklySync.end]
        let store = makeStore(env, state: state)

        await store.send(.refresh)
        await store.receive(\.eventsResponse) {
            $0.lastSyncAt = date("2026-11-03 10:59:30")
            $0.nextAlert = ScheduledAlert(event: ana, fireAt: date("2026-11-03 12:29:00"))
        }
        #expect(store.state.alert == nil)
        await store.skipInFlightEffects(strict: false)
    }

    @Test func firedKeysArePurgedAfterTheEventEnds() async {
        let env = TestEnvironment(now: "2026-11-03 11:31", events: [])
        var state = signedIn(env)
        state.firedAlerts = [weeklySync.dedupeKey: weeklySync.end]
        let store = makeStore(env, state: state)
        await store.send(.eventsResponse(.success([]), startedAt: env.now)) {
            $0.lastSyncAt = date("2026-11-03 11:31")
            $0.firedAlerts = [:]
        }
        await store.finish()
    }

    // MARK: - B.6 / B.7 wake

    static let ana = CalendarEvent.fixture(id: "ana", title: "1:1 con Ana", start: "2026-11-03 12:30", end: "2026-11-03 13:00")

    @Test func wakeWithLateFire() async {
        let env = TestEnvironment(now: "2026-11-03 12:29:40", events: [Self.ana])
        let store = makeStore(env, state: signedIn(env, events: [Self.ana]))

        await store.send(.systemWoke) {
            $0.nextAlert = ScheduledAlert(event: Self.ana, fireAt: date("2026-11-03 12:29:00"))
        }
        await store.receive(\.alertDue) {
            $0.firedAlerts = [Self.ana.dedupeKey: Self.ana.end]
            $0.alert = AlertFeature.State(event: Self.ana, trigger: .wake, now: date("2026-11-03 12:29:40"))
            $0.nextAlert = nil
        }
        #expect(store.state.alert?.secondsRemaining == 20)
        await store.receive(\.refresh)
        await store.receive(\.eventsResponse) { $0.lastSyncAt = date("2026-11-03 12:29:40") }
        await store.finish()
        #expect(env.tracked("alert_shown").first?.properties["trigger"] == "wake")
    }

    @Test func wakeAfterStart() async {
        let env = TestEnvironment(now: "2026-11-03 12:34:10", events: [Self.ana])
        let store = makeStore(env, state: signedIn(env, events: [Self.ana]))
        await store.send(.systemWoke) {
            $0.nextAlert = ScheduledAlert(event: Self.ana, fireAt: date("2026-11-03 12:29:00"))
        }
        await store.receive(\.alertDue) {
            $0.firedAlerts = [Self.ana.dedupeKey: Self.ana.end]
            $0.alert = AlertFeature.State(event: Self.ana, trigger: .wake, now: date("2026-11-03 12:34:10"))
            $0.nextAlert = nil
        }
        #expect(store.state.alert?.phase == .started(minutesAgo: 4))
        await store.receive(\.refresh)
        await store.receive(\.eventsResponse) { $0.lastSyncAt = date("2026-11-03 12:34:10") }
        await store.finish()
    }

    @Test func wakeAfterEnd() async {
        let env = TestEnvironment(now: "2026-11-03 13:05", events: [])
        let store = makeStore(env, state: signedIn(env, events: [Self.ana]))
        await store.send(.systemWoke)
        await store.receive(\.refresh)
        await store.receive(\.eventsResponse) {
            $0.events = []
            $0.lastSyncAt = date("2026-11-03 13:05")
        }
        #expect(store.state.alert == nil)
        await store.finish()
    }

    // MARK: - B.8 filters

    static let b8Events: [CalendarEvent] = [
        .fixture(id: "bday", title: "Cumpleaños de Marta", start: "2026-11-03 00:00", end: "2026-11-04 00:00", isAllDay: true, link: nil),
        .fixture(id: "retro", title: "Retro", start: "2026-11-03 09:00", status: .declined),
        .fixture(id: "foco", title: "Foco", start: "2026-11-03 09:30", end: "2026-11-03 11:00", link: nil, others: false),
        .fixture(id: "demo", title: "Demo cliente", start: "2026-11-03 10:00", link: zoomLink),
    ]

    @Test func filtersFree() async {
        let env = TestEnvironment(now: "2026-11-03 08:00")
        let store = makeStore(env, state: signedIn(env))
        await store.send(.eventsResponse(.success(Self.b8Events), startedAt: env.now)) {
            $0.events = IdentifiedArray(uniqueElements: Self.b8Events)
            $0.lastSyncAt = date("2026-11-03 08:00")
            $0.nextAlert = ScheduledAlert(event: Self.b8Events[1], fireAt: date("2026-11-03 08:59"), proHook: .declined)
        }
        await env.clock.advance(by: .seconds(59 * 60))
        await store.receive(\.alertDue) {
            $0.firedAlerts = [Self.b8Events[1].dedupeKey: Self.b8Events[1].end]
            $0.alert = AlertFeature.State(event: Self.b8Events[1], proHook: .declined, now: date("2026-11-03 08:59"))
            $0.nextAlert = ScheduledAlert(event: Self.b8Events[2], fireAt: date("2026-11-03 09:29"), proHook: .solo)
        }
        await store.skipInFlightEffects(strict: false)
        #expect(env.tracked("alert_shown").first?.properties["pro_hook_shown"] == "declined")
        #expect(env.tracked("alert_shown").first?.properties["is_declined"] == true)
    }

    @Test func filtersProAndLeadTime() async {
        let env = TestEnvironment(now: "2026-11-03 08:00")
        let store = makeStore(env, state: signedIn(env, isPro: true), isPro: true)
        let demo = Self.b8Events[3]
        await store.send(.eventsResponse(.success(Self.b8Events), startedAt: env.now)) {
            $0.events = IdentifiedArray(uniqueElements: Self.b8Events)
            $0.lastSyncAt = date("2026-11-03 08:00")
            $0.nextAlert = ScheduledAlert(event: demo, fireAt: date("2026-11-03 09:59"))
        }
        // Changing the lead time reschedules.
        await store.send(.settingsScreen(.setLeadTime(20))) {
            $0.$settings.withLock { $0.leadTimeSeconds = 20 }
            $0.nextAlert = ScheduledAlert(event: demo, fireAt: date("2026-11-03 09:59:40"))
        }
        await store.send(.settingsScreen(.setOnlyWithLink(true))) {
            $0.$settings.withLock { $0.onlyEventsWithMeetingLink = true }
        }
        // Turning the declined filter off brings Retro back.
        await store.send(.settingsScreen(.setIgnoreDeclined(false))) {
            $0.$settings.withLock { $0.ignoreDeclined = false }
            $0.nextAlert = ScheduledAlert(event: Self.b8Events[1], fireAt: date("2026-11-03 08:59:40"))
        }
        await env.clock.advance(by: .seconds(59 * 60 + 40))
        await store.receive(\.alertDue) {
            $0.firedAlerts = [Self.b8Events[1].dedupeKey: Self.b8Events[1].end]
            $0.alert = AlertFeature.State(event: Self.b8Events[1], leadTimeSeconds: 20, now: date("2026-11-03 08:59:40"))
            $0.nextAlert = ScheduledAlert(event: demo, fireAt: date("2026-11-03 09:59:40"))
        }
        await store.skipInFlightEffects(strict: false)
    }

    @Test func calendarSelectionTriggersRefresh() async {
        let env = TestEnvironment(now: "2026-11-03 08:00")
        var state = signedIn(env, isPro: true)
        state.settingsScreen.calendars = MockCalendar.calendars
        let store = makeStore(env, state: state, isPro: true)
        await store.send(.settingsScreen(.toggleCalendar("personal"))) {
            $0.$settings.withLock { $0.selectedCalendarIDs = ["primary"] }
        }
        await store.receive(\.refresh)
        await store.receive(\.eventsResponse) { $0.lastSyncAt = date("2026-11-03 08:00") }
        await store.finish()
    }

    // MARK: - B.9 overlap

    @Test func overlapShowsOneAlertAndFiresBoth() async {
        let roadmap = CalendarEvent.fixture(id: "roadmap", title: "Alinear roadmap", start: "2026-11-03 11:00")
        let env = TestEnvironment(now: "2026-11-03 10:58:30")
        let store = makeStore(env, state: signedIn(env))
        await store.send(.eventsResponse(.success([weeklySync, roadmap]), startedAt: env.now)) {
            $0.events = [weeklySync, roadmap]
            $0.lastSyncAt = date("2026-11-03 10:58:30")
            $0.nextAlert = ScheduledAlert(event: roadmap, overlapping: [weeklySync], fireAt: date("2026-11-03 10:59"))
        }
        await env.clock.advance(by: .seconds(30))
        await store.receive(\.alertDue) {
            $0.firedAlerts = [roadmap.dedupeKey: roadmap.end, weeklySync.dedupeKey: weeklySync.end]
            $0.alert = AlertFeature.State(event: roadmap, additionalCount: 1, now: date("2026-11-03 10:59"))
            $0.nextAlert = nil
        }
        await store.finish()
        #expect(env.tracked("alert_shown").first?.properties["overlapping_count"] == 1)
    }

    @Test func newAlertReplacesVisibleOne() async {
        let next = CalendarEvent.fixture(id: "next", title: "Next", start: "2026-11-03 11:01")
        let env = TestEnvironment(now: "2026-11-03 11:00:00")
        var state = signedIn(env, events: [weeklySync, next])
        state.alert = AlertFeature.State(event: weeklySync, now: date("2026-11-03 10:59"))
        let store = makeStore(env, state: state)
        await store.send(.alertDue(ScheduledAlert(event: next, fireAt: env.now), .scheduled)) {
            $0.firedAlerts = [next.dedupeKey: next.end]
            $0.alert = AlertFeature.State(event: next, now: date("2026-11-03 11:00"))
        }
        await store.finish()
        let replaced = env.tracked("alert_dismissed").first?.properties
        #expect(replaced?["reason"] == "replaced")
        #expect(replaced?["seconds_shown"] == 60)
        #expect(replaced?["seconds_to_start"] == 0)
    }

    // MARK: - B.15 test alert

    static func testEvent(firedAt: Date) -> CalendarEvent {
        CalendarEvent(
            id: "hey-you-test", calendarID: "hey-you", title: "Hey You! test",
            start: firedAt.addingTimeInterval(60), end: firedAt.addingTimeInterval(60 + 30 * 60),
            meetingLink: MeetingLink(provider: .other, url: AppConfig.projectURL), hasOtherAttendees: true,
            htmlLink: AppConfig.projectURL
        )
    }

    @Test func alertFromMenu() async {
        let env = TestEnvironment(now: "2026-11-03 10:00")
        let store = makeStore(env, state: signedIn(env))
        await store.send(.menuBar(.testAlert))
        await env.clock.advance(by: .seconds(4))
        #expect(store.state.alert == nil)
        await env.clock.advance(by: .seconds(1))
        let event = Self.testEvent(firedAt: date("2026-11-03 10:00:05"))
        await store.receive(\.alertDue) {
            $0.alert = AlertFeature.State(event: event, trigger: .test, now: date("2026-11-03 10:00:05"))
        }
        #expect(store.state.alert?.secondsRemaining == 60)
        await store.send(.alert(.presented(.joinTapped)))
        await store.receive(\.alert.presented.delegate.finished) { $0.alert = nil }
        await store.finish()
        #expect(env.openedURLs.value == [AppConfig.projectURL])
        #expect(env.trackedNames == ["test_alert_triggered", "alert_shown", "alert_dismissed"])
        #expect(env.tracked("alert_shown").first?.properties["trigger"] == "test")
        #expect(store.state.firedAlerts.isEmpty)
    }

    @Test func alertFromSettings() async {
        let env = TestEnvironment(now: "2026-11-03 10:00")
        let store = makeStore(env, state: signedIn(env))
        await store.send(.settingsScreen(.testAlertTapped))
        await store.receive(\.settingsScreen.delegate.testAlert)
        await env.clock.advance(by: .seconds(5))
        await store.receive(\.alertDue) {
            $0.alert = AlertFeature.State(
                event: Self.testEvent(firedAt: date("2026-11-03 10:00:05")), trigger: .test, now: date("2026-11-03 10:00:05")
            )
        }
        await store.finish()
        #expect(env.tracked("test_alert_triggered").first?.properties["source"] == "settings")
    }
}
