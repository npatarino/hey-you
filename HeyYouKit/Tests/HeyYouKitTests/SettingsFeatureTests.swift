import ComposableArchitecture
import DependenciesTestSupport
import Foundation
@testable import HeyYouKit
import Testing

@MainActor
@Suite(.dependencies)
struct SettingsFeatureTests {
    func store(env: TestEnvironment, isPro: Bool, consent: Consent = Consent()) -> TestStoreOf<SettingsFeature> {
        let state = SettingsFeature.State(account: env.account)
        state.$entitlements.withLock { $0.isPro = isPro }
        state.$consent.withLock { $0 = consent }
        return TestStore(initialState: state) { SettingsFeature() } withDependencies: { env.apply(&$0) }
    }

    @Test func taskLoadsCalendarsAndLaunchStatus() async {
        let env = TestEnvironment(now: "2026-11-03 10:00")
        let store = store(env: env, isPro: true)
        await store.send(.task)
        await store.receive(\.calendarsResponse) { $0.calendars = MockCalendar.calendars }
        #expect(store.state.isCalendarSelected("personal"))
    }

    /// PRD B.16: free users get the paywall from any Pro control, and nothing changes.
    @Test func freeUserHitsTheLock() async {
        let env = TestEnvironment(now: "2026-11-03 10:00")
        let store = store(env: env, isPro: false)
        let proActions: [SettingsFeature.Action] = [
            .setLeadTime(20), .setSound(.horn), .setShowCountdown(false), .setIgnoreDeclined(true),
            .setIgnoreWithoutOtherAttendees(true), .setOnlyWithLink(true), .setWorkingHoursEnabled(true),
            .toggleWorkday(1), .setWorkingHoursStart(minute: 600), .setWorkingHoursEnd(minute: 700), .toggleCalendar("primary"),
        ]
        for action in proActions {
            await store.send(action)
            await store.receive(.delegate(.openPaywall(.settingsLock)))
        }
        await store.send(.lockTapped)
        await store.receive(.delegate(.openPaywall(.settingsLock)))
        await store.send(.unlockProTapped)
        await store.receive(.delegate(.openPaywall(.settingsLock)))
        #expect(store.state.settings == AppSettings())
        #expect(store.state.effective.leadTimeSeconds == 60)
    }

    /// PRD B.16: values are 10…60 in steps of 5.
    @Test func proLeadTime() async {
        let env = TestEnvironment(now: "2026-11-03 10:00")
        let store = store(env: env, isPro: true)
        await store.send(.setLeadTime(22)) { $0.$settings.withLock { $0.leadTimeSeconds = 20 } }
        await store.send(.setLeadTime(5)) { $0.$settings.withLock { $0.leadTimeSeconds = 10 } }
        await store.send(.setLeadTime(65)) { $0.$settings.withLock { $0.leadTimeSeconds = 60 } }
        await store.send(.setLeadTime(61))
        let values = env.tracked("setting_changed").map { $0.properties["value"] }
        #expect(values == [20, 10, 60])
    }

    @Test func proToggles() async {
        let env = TestEnvironment(now: "2026-11-03 10:00")
        let store = store(env: env, isPro: true)
        await store.send(.setSound(.bell)) { $0.$settings.withLock { $0.sound = .bell } }
        await store.send(.setShowCountdown(false)) { $0.$settings.withLock { $0.showCountdownInMenuBar = false } }
        await store.send(.setIgnoreDeclined(true)) { $0.$settings.withLock { $0.ignoreDeclined = true } }
        await store.send(.setIgnoreWithoutOtherAttendees(true)) { $0.$settings.withLock { $0.ignoreWithoutOtherAttendees = true } }
        await store.send(.setOnlyWithLink(true)) { $0.$settings.withLock { $0.onlyEventsWithMeetingLink = true } }
        #expect(env.sounds.value == [.bell])
        let keys = env.tracked("setting_changed").map { $0.properties["key"] }
        #expect(keys == ["sound", "menu_bar_countdown", "ignore_declined", "ignore_solo", "only_with_link"])
    }

    @Test func workingHours() async {
        let env = TestEnvironment(now: "2026-11-03 10:00")
        let store = store(env: env, isPro: true)
        await store.send(.setWorkingHoursEnabled(true)) { $0.$settings.withLock { $0.workingHours = .officeDefault } }
        await store.send(.toggleWorkday(2)) { $0.$settings.withLock { _ = $0.workingHours?.weekdays.remove(2) } }
        await store.send(.toggleWorkday(2)) { $0.$settings.withLock { _ = $0.workingHours?.weekdays.insert(2) } }
        await store.send(.toggleWorkday(9))
        await store.send(.setWorkingHoursStart(minute: 8 * 60)) { $0.$settings.withLock { $0.workingHours?.startMinute = 480 } }
        await store.send(.setWorkingHoursEnd(minute: 19 * 60)) { $0.$settings.withLock { $0.workingHours?.endMinute = 1140 } }
        // Start can't pass the end and vice versa.
        await store.send(.setWorkingHoursStart(minute: 1200)) { $0.$settings.withLock { $0.workingHours?.startMinute = 1125 } }
        await store.send(.setWorkingHoursEnd(minute: 0)) { $0.$settings.withLock { $0.workingHours?.endMinute = 1140 } }
        await store.send(.setWorkingHoursEnabled(false)) { $0.$settings.withLock { $0.workingHours = nil } }
    }

    @Test func calendarSelection() async {
        let env = TestEnvironment(now: "2026-11-03 10:00")
        let store = store(env: env, isPro: true)
        await store.send(.calendarsResponse(MockCalendar.calendars)) { $0.calendars = MockCalendar.calendars }
        await store.send(.toggleCalendar("personal")) { $0.$settings.withLock { $0.selectedCalendarIDs = ["primary"] } }
        #expect(!store.state.isCalendarSelected("personal"))
        // The last calendar can't be removed.
        await store.send(.toggleCalendar("primary"))
        await store.send(.toggleCalendar("personal")) { $0.$settings.withLock { $0.selectedCalendarIDs = nil } }
        let values = env.tracked("setting_changed").map { $0.properties["value"] }
        #expect(values == [1, "all"])
    }

    @Test func launchAtLogin() async {
        let env = TestEnvironment(now: "2026-11-03 10:00")
        let store = store(env: env, isPro: false)
        await store.send(.setLaunchAtLogin(true)) {
            $0.launchAtLogin = .enabled
            $0.$settings.withLock { $0.launchAtLogin = true }
        }
        await store.send(.setLaunchAtLogin(false)) {
            $0.launchAtLogin = .disabled
            $0.$settings.withLock { $0.launchAtLogin = false }
        }
        await store.send(.openLoginItemsTapped)
        #expect(env.tracked("setting_changed").map { $0.properties["key"] } == ["launch_at_login", "launch_at_login"])
    }

    /// PRD B.19: re-enabling analytics in Settings sends consent_changed first.
    @Test func consent() async {
        let env = TestEnvironment(now: "2026-11-03 10:00", consent: Consent(usageAnalytics: false))
        let store = store(env: env, isPro: false, consent: Consent(usageAnalytics: false))
        await store.send(.setEmailConsent(true)) { $0.$consent.withLock { $0.emailContact = true } }
        #expect(env.analytics.events.isEmpty)
        await store.send(.setUsageConsent(true)) { $0.$consent.withLock { $0.usageAnalytics = true } }
        #expect(env.trackedNames == ["consent_changed"])
        await store.send(.setEmailConsent(false)) { $0.$consent.withLock { $0.emailContact = false } }
        #expect(env.analytics.people.last?["email"] == "")
        await store.send(.setUsageConsent(false)) { $0.$consent.withLock { $0.usageAnalytics = false } }
        #expect(env.trackedNames == ["consent_changed", "consent_changed"])
    }

    /// PRD B.18
    @Test func restorePurchase() async {
        let env = TestEnvironment(now: "2026-11-03 10:00")
        let store = store(env: env, isPro: false)
        await store.send(.restoreTapped) { $0.isRestoring = true }
        await store.receive(\.restoreResponse.success) {
            $0.isRestoring = false
            $0.message = "Purchase restored. Thanks for supporting Hey You!"
        }
        await store.receive(\.delegate.entitlementsUpdated)
        #expect(env.trackedNames == ["purchase_restored"])
    }

    @Test func restoreFailures() async {
        let env = TestEnvironment(now: "2026-11-03 10:00")
        let result = LockIsolated<Result<Entitlements, StoreError>>(.success(Entitlements()))
        let state = SettingsFeature.State()
        state.$entitlements.withLock { $0.isPro = false }
        let store = TestStore(initialState: state) { SettingsFeature() } withDependencies: {
            env.apply(&$0)
            $0.storeClient.restore = { try result.value.get() }
        }
        await store.send(.task)
        await store.send(.restoreTapped) { $0.isRestoring = true }
        await store.receive(\.restoreResponse.success) {
            $0.isRestoring = false
            $0.message = "No previous purchase found for this Apple ID."
        }
        result.setValue(.failure(.failed))
        await store.send(.restoreTapped) {
            $0.isRestoring = true
            $0.message = nil
        }
        await store.receive(\.restoreResponse.failure) {
            $0.isRestoring = false
            $0.message = "Couldn't reach the App Store. Try again."
        }
    }

    @Test func delegates() async {
        let env = TestEnvironment(now: "2026-11-03 10:00")
        let store = store(env: env, isPro: false)
        await store.send(.signOutTapped)
        await store.receive(.delegate(.signOut))
        await store.send(.connectTapped)
        await store.receive(.delegate(.connect))
        await store.send(.testAlertTapped)
        await store.receive(.delegate(.testAlert))
    }
}
