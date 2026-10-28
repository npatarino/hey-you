import ComposableArchitecture
import ConcurrencyExtras
import DependenciesTestSupport
import Foundation
@testable import HeyYouKit
import Testing

/// Error, Pro, consent, sign-out and quit flows of `AppFeature`.
@MainActor
@Suite(.dependencies)
struct AppFeatureProTests: AppFeatureTesting {
    // MARK: - B.13 / B.14 errors

    @Test func sessionExpiredKeepsAlerting() async {
        let env = TestEnvironment(now: "2026-11-03 10:50", events: [weeklySync])
        var state = signedIn(env, events: [weeklySync])
        state.nextAlert = ScheduledAlert(event: weeklySync, fireAt: date("2026-11-03 10:59"))
        let store = makeStore(env, state: state)
        env.calendarResult.setValue(.failure(.unauthorized))
        await store.send(.refresh)
        await store.receive(\.eventsResponse) {
            $0.auth = .sessionExpired(email: "demo@example.com")
            $0.settingsScreen.account = nil
        }
        await store.finish()
        #expect(env.signOuts.value == 1)
        let menu = MenuBarFeature.state(from: store.state, now: env.now, calendar: madridCalendar)
        #expect(menu.iconName == "bell.slash")
        #expect(menu.status == .sessionExpired)
        #expect(menu.canConnect)
        // Refresh is a no-op until the user signs in again.
        await store.send(.refresh)
        await store.send(.menuBar(.connectGoogle)) { $0.onboarding = OnboardingFeature.State() }
        #expect(env.tracked("calendar_synced").first?.properties["error_type"] == "unauthorized")
    }

    @Test func offlineKeepsAlerting() async {
        let env = TestEnvironment(now: "2026-11-03 10:50", events: [weeklySync])
        let store = makeStore(env, state: signedIn(env))
        await store.send(.refresh)
        await store.receive(\.eventsResponse) {
            $0.events = [weeklySync]
            $0.lastSyncAt = date("2026-11-03 10:50")
            $0.nextAlert = ScheduledAlert(event: weeklySync, fireAt: date("2026-11-03 10:59"))
        }
        env.calendarResult.setValue(.failure(.offline))
        await store.send(.refresh)
        await store.receive(\.eventsResponse) { $0.offlineSince = date("2026-11-03 10:50") }
        await env.clock.advance(by: .seconds(60))
        await store.send(.refresh)
        await store.receive(\.eventsResponse)
        let menu = MenuBarFeature.state(from: store.state, now: env.now, calendar: madridCalendar)
        #expect(menu.status == .offline(since: date("2026-11-03 10:50")))
        await env.clock.advance(by: .seconds(8 * 60))
        await store.receive(\.alertDue) {
            $0.$weeklyMeetings.withLock { $0 = WeeklyMeetings(weekStart: date("2026-11-02 00:00"), count: 1) }
            $0.firedAlerts = [weeklySync.dedupeKey: weeklySync.end]
            $0.alert = AlertFeature.State(event: weeklySync, now: date("2026-11-03 10:59"))
            $0.nextAlert = nil
        }
        // Back online clears the offline state.
        env.calendarResult.setValue(.success([weeklySync]))
        await store.send(.refresh)
        await store.receive(\.eventsResponse) {
            $0.lastSyncAt = date("2026-11-03 10:59")
            $0.offlineSince = nil
        }
        await store.finish()
    }

    @Test func serverErrorIsReported() async {
        let env = TestEnvironment(now: "2026-11-03 10:50")
        env.calendarResult.setValue(.failure(.server(status: 503)))
        let store = makeStore(env, state: signedIn(env))
        await store.send(.refresh)
        await store.receive(\.eventsResponse)
        await store.finish()
        #expect(env.tracked("error_occurred").first?.properties["code"] == 503)
        #expect(CalendarError(URLError(.timedOut)) == .offline)
        #expect(CalendarError(AuthError.notSignedIn) == .unauthorized)
        #expect(CalendarError(StoreError.failed) == .server(status: 0))
    }

    // MARK: - B.16 / B.17 / B.18 Pro

    @Test func lockedLeadTimeOpensPaywall() async {
        let env = TestEnvironment(now: "2026-11-03 10:00")
        let store = makeStore(env, state: signedIn(env))
        await store.send(.settingsScreen(.setLeadTime(20)))
        await store.receive(\.settingsScreen.delegate.openPaywall) { $0.paywall = PaywallFeature.State(source: .settingsLock) }
        await store.send(.paywall(.presented(.task)))
        await store.receive(\.paywall.presented.loaded) {
            $0.paywall?.isLoading = false
            $0.paywall?.products = [StoreProduct(id: AppConfig.proProductID, displayName: "Hey You! Pro", displayPrice: "5,99 €")]
        }
        #expect(store.state.settings.leadTimeSeconds == 60)
        #expect(env.tracked("paywall_viewed").first?.properties["source"] == "settings_lock")
    }

    @Test func purchaseUnlocksPro() async {
        let env = TestEnvironment(now: "2026-11-03 10:52")
        let store = makeStore(env, state: signedIn(env, events: [weeklySync]))
        #expect(MenuBarFeature.state(from: store.state, now: env.now, calendar: madridCalendar).showsProEntry)

        await store.send(.menuBar(.openPaywall)) { $0.paywall = PaywallFeature.State(source: .menu) }
        await store.send(.paywall(.presented(.task)))
        await store.receive(\.paywall.presented.loaded) {
            $0.paywall?.isLoading = false
            $0.paywall?.products = [StoreProduct(id: AppConfig.proProductID, displayName: "Hey You! Pro", displayPrice: "5,99 €")]
        }
        await store.send(.paywall(.presented(.purchaseTapped))) { $0.paywall?.isPurchasing = true }
        await store.receive(\.paywall.presented.purchaseResponse.success) {
            $0.paywall?.isPurchasing = false
            $0.$entitlements.withLock {
                $0 = Entitlements(isPro: true, purchasedAt: date("2026-11-03 10:52"), proDefaultsApplied: true)
            }
            $0.$settings.withLock { $0.applyProDefaults() }
        }
        await store.receive(\.paywall.presented.delegate.purchased)
        await store.receive(\.entitlementsUpdated) {
            $0.nextAlert = ScheduledAlert(event: weeklySync, fireAt: date("2026-11-03 10:59"))
        }
        await store.receive(\.paywall.dismiss) { $0.paywall = nil }
        await store.skipInFlightEffects(strict: false)

        #expect(store.state.settings.ignoreDeclined)
        #expect(store.state.settings.ignoreWithoutOtherAttendees)
        let menu = MenuBarFeature.state(from: store.state, now: env.now, calendar: madridCalendar)
        #expect(!menu.showsProEntry)
        #expect(menu.countdown == "8m")
        #expect(menu.punctuality == PunctualityStats(weekStart: date("2026-11-02 00:00")))
        await settle()
        #expect(env.trackedNames.contains("purchase_completed"))
        #expect(env.analytics.people.contains { $0["is_pro"] == true })
        #expect(env.analytics.people.contains { $0["pro_purchased_at"] != nil })
    }

    /// Pro defaults are applied once; a later restore doesn't turn filters back on.
    @Test func proDefaultsOnlyOnce() async {
        let env = TestEnvironment(now: "2026-11-03 10:00")
        let state = signedIn(env, isPro: true)
        state.$settings.withLock { $0.ignoreDeclined = false }
        let store = makeStore(env, state: state, isPro: true)
        await store.send(.entitlementsUpdated(Entitlements(isPro: true)))
        #expect(!store.state.settings.ignoreDeclined)
        // Losing Pro (refund) goes back to free behaviour without touching stored settings.
        await store.send(.entitlementsUpdated(Entitlements(isPro: false))) {
            $0.$entitlements.withLock { $0.isPro = false }
        }
        #expect(store.state.effectiveSettings == EffectiveSettings(AppSettings(), isPro: false))
        await store.finish()
    }

    @Test func restoreFromSettings() async {
        let env = TestEnvironment(now: "2026-11-03 10:00")
        let store = makeStore(env, state: signedIn(env))
        await store.send(.settingsScreen(.restoreTapped)) { $0.settingsScreen.isRestoring = true }
        await store.receive(\.settingsScreen.restoreResponse.success) {
            $0.settingsScreen.isRestoring = false
            $0.settingsScreen.message = "Purchase restored. Thanks for supporting Hey You!"
            $0.$entitlements.withLock {
                $0 = Entitlements(isPro: true, purchasedAt: date("2026-11-03 10:00"), proDefaultsApplied: true)
            }
            $0.$settings.withLock { $0.applyProDefaults() }
        }
        await store.receive(\.settingsScreen.delegate.entitlementsUpdated)
        await store.receive(\.entitlementsUpdated)
        await store.finish()
        #expect(env.trackedNames.contains("purchase_restored"))
    }

    @Test func storeUpdatesStreamUnlocksPro() async {
        let env = TestEnvironment(now: "2026-11-03 10:00")
        var state = signedIn(env)
        state.auth = .signedOut
        let store = TestStore(initialState: state) { AppFeature() } withDependencies: {
            env.apply(&$0)
            $0.authClient.restorePreviousSignIn = { nil }
            $0.storeClient.updates = { AsyncStream { $0.yield(Entitlements(isPro: true)); $0.finish() } }
        }
        let task = await store.send(.task) { $0.now = date("2026-11-03 10:00") }
        await store.receive(\.entitlementsUpdated) {
            $0.$entitlements.withLock { $0 = Entitlements(isPro: true, proDefaultsApplied: true) }
            $0.$settings.withLock { $0.applyProDefaults() }
        }
        await store.receive(\.entitlementsUpdated)
        await store.receive(\.accountRestored)
        await task.cancel()
    }

    @Test func punctualityForPro() async {
        let env = TestEnvironment(now: "2026-11-03 11:00:20")
        var state = signedIn(env, isPro: true)
        state.alert = AlertFeature.State(event: weeklySync, now: date("2026-11-03 10:59"))
        let store = makeStore(env, state: state, isPro: true)
        await store.send(.alert(.presented(.dismissed(.click)))) {
            $0.$stats.withLock { $0 = PunctualityStats(weekStart: date("2026-11-02 00:00"), alerts: 1, onTime: 1) }
        }
        await store.receive(\.alert.presented.delegate.finished) { $0.alert = nil }
        await store.finish()
    }

    @Test func proHookAttributesPaywall() async {
        let env = TestEnvironment(now: "2026-11-03 08:59:10")
        var state = signedIn(env)
        state.alert = AlertFeature.State(event: AppFeatureTests.b8Events[1], proHook: .declined, now: date("2026-11-03 08:59"))
        let store = makeStore(env, state: state)
        await store.send(.alert(.presented(.dismissed(.key))))
        await store.receive(\.alert.presented.delegate.finished) {
            $0.alert = nil
            $0.lastProHookAt = date("2026-11-03 08:59:10")
        }
        await store.send(.menuBar(.openPaywall)) { $0.paywall = PaywallFeature.State(source: .alertHook) }
        await store.send(.paywall(.dismiss)) { $0.paywall = nil }
        await store.send(.menuBar(.statsTapped)) { $0.paywall = PaywallFeature.State(source: .stats) }
        await store.finish()
    }

    // MARK: - B.19 consent

    @Test func consentOffSendsNothing() async {
        let env = TestEnvironment(now: "2026-11-03 10:58:30", events: [weeklySync], consent: Consent(usageAnalytics: false))
        let state = signedIn(env)
        state.$consent.withLock { $0.usageAnalytics = false }
        let store = makeStore(env, state: state)

        await store.send(.refresh)
        await store.receive(\.eventsResponse) {
            $0.events = [weeklySync]
            $0.lastSyncAt = date("2026-11-03 10:58:30")
            $0.nextAlert = ScheduledAlert(event: weeklySync, fireAt: date("2026-11-03 10:59"))
        }
        await env.clock.advance(by: .seconds(30))
        await store.receive(\.alertDue) {
            $0.$weeklyMeetings.withLock { $0 = WeeklyMeetings(weekStart: date("2026-11-02 00:00"), count: 1) }
            $0.firedAlerts = [weeklySync.dedupeKey: weeklySync.end]
            $0.alert = AlertFeature.State(event: weeklySync, now: date("2026-11-03 10:59"))
            $0.nextAlert = nil
        }
        await store.send(.alert(.presented(.joinTapped)))
        await store.receive(\.alert.presented.delegate.finished) { $0.alert = nil }
        await store.finish()
        #expect(env.analytics.events.isEmpty)

        await store.send(.settingsScreen(.setUsageConsent(true))) {
            $0.$consent.withLock { $0.usageAnalytics = true }
        }
        await store.finish()
        #expect(env.trackedNames == ["consent_changed"])
    }

    // MARK: - Sign out / quit

    @Test func signOutFromSettings() async {
        let env = TestEnvironment(now: "2026-11-03 10:00")
        var state = signedIn(env, events: [weeklySync])
        state.calendars = MockCalendar.calendars
        state.nextAlert = ScheduledAlert(event: weeklySync, fireAt: date("2026-11-03 10:59"))
        let store = makeStore(env, state: state)
        await store.send(.settingsScreen(.signOutTapped))
        await store.receive(\.settingsScreen.delegate.signOut) {
            $0.auth = .signedOut
            $0.settingsScreen.account = nil
            $0.events = []
            $0.calendars = []
            $0.nextAlert = nil
        }
        await store.finish()
        #expect(env.signOuts.value == 1)
        #expect(env.trackedNames == ["signout"])
        await store.send(.settingsScreen(.connectTapped))
        await store.receive(\.settingsScreen.delegate.connect) { $0.onboarding = OnboardingFeature.State() }
    }

    @Test func quitFromMenu() async {
        let env = TestEnvironment(now: "2026-11-03 10:00")
        let store = makeStore(env, state: signedIn(env))
        await store.send(.menuBar(.quit))
        await store.finish()
        #expect(env.terminated.value)
        #expect(env.tracked("app_quit").first?.properties["alert_visible"] == false)
    }

    @Test func refreshNowFromMenu() async {
        let env = TestEnvironment(now: "2026-11-03 10:00")
        let store = makeStore(env, state: signedIn(env))
        await store.send(.menuBar(.refreshNow))
        await store.receive(\.refresh)
        await store.receive(\.eventsResponse) { $0.lastSyncAt = date("2026-11-03 10:00") }
    }

    @Test func launchAtLoginIsSyncedFromSystem() async {
        let env = TestEnvironment(now: "2026-11-03 10:00")
        let state = signedIn(env)
        state.$settings.withLock { $0.launchAtLogin = true }
        let store = TestStore(initialState: state) { AppFeature() } withDependencies: {
            env.apply(&$0)
            $0.authClient.restorePreviousSignIn = { nil }
        }
        let task = await store.send(.task) {
            $0.now = date("2026-11-03 10:00")
            $0.$settings.withLock { $0.launchAtLogin = false }
        }
        await store.receive(\.entitlementsUpdated)
        await store.receive(\.accountRestored) { $0.auth = .signedOut }
        await task.cancel()
    }
}
