import ComposableArchitecture
import DependenciesTestSupport
import Foundation
@testable import HeyYouKit
import Testing

@MainActor
@Suite(.dependencies)
struct OnboardingFeatureTests {
    @Test func signInFlow() async {
        let env = TestEnvironment(now: "2026-11-03 10:00")
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        } withDependencies: { env.apply(&$0) }

        await store.send(.task)
        await store.send(.signInTapped) { $0.isSigningIn = true }
        await store.receive(\.signInResponse.success) {
            $0.isSigningIn = false
            $0.step = .connected(env.account)
        }
        await store.receive(\.delegate.signedIn)
        #expect(env.trackedNames == ["onboarding_viewed", "signin_started", "signin_completed"])

        await store.send(.setLaunchAtLogin(true)) { $0.launchAtLogin = .enabled }
        await store.receive(.delegate(.launchAtLoginChanged(true)))
        await store.send(.testAlertTapped)
        await store.receive(.delegate(.testAlert))
        await store.send(.doneTapped)
        await store.receive(.delegate(.finished))
    }

    @Test func signInErrors() async {
        let env = TestEnvironment(now: "2026-11-03 10:00")
        let error = LockIsolated(AuthError.notConfigured)
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        } withDependencies: {
            env.apply(&$0)
            $0.authClient.signIn = { throw error.value }
        }
        await store.send(.signInTapped) { $0.isSigningIn = true }
        await store.receive(\.signInResponse.failure) {
            $0.isSigningIn = false
            $0.errorMessage = AuthError.notConfigured.message
        }
        error.setValue(.cancelled)
        await store.send(.signInTapped) {
            $0.isSigningIn = true
            $0.errorMessage = nil
        }
        await store.receive(\.signInResponse.failure) { $0.isSigningIn = false }
        let failures = env.tracked("signin_failed").map { $0.properties["error_type"] }
        #expect(failures == ["not_configured", "cancelled"])
        #expect(AuthError.missingCalendarScope.message != nil)
        #expect(AuthError.noWindow.message != nil)
        #expect(AuthError.failed(code: 1).message != nil)
        #expect(AuthError(URLError(.timedOut)) == .failed(code: URLError.timedOut.rawValue))
    }

    /// PRD B.19: switching usage analytics off in onboarding sends nothing.
    @Test func consentToggles() async {
        let env = TestEnvironment(now: "2026-11-03 10:00")
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        } withDependencies: { env.apply(&$0) }

        await store.send(.setUsageConsent(false)) { $0.$consent.withLock { $0.usageAnalytics = false } }
        await store.send(.setEmailConsent(true)) { $0.$consent.withLock { $0.emailContact = true } }
        #expect(env.analytics.events.isEmpty)
        await store.send(.setUsageConsent(true)) { $0.$consent.withLock { $0.usageAnalytics = true } }
        #expect(env.trackedNames == ["consent_changed"])
        #expect(env.analytics.events.first?.properties["source"] == "onboarding")
        #expect(env.analytics.events.first?.properties["email"] == true)
    }
}
