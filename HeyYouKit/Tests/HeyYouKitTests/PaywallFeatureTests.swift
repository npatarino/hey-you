import ComposableArchitecture
import DependenciesTestSupport
import Foundation
@testable import HeyYouKit
import Testing

@MainActor
@Suite(.dependencies)
struct PaywallFeatureTests {
    let product = StoreProduct(id: AppConfig.proProductID, displayName: "Hey You! Pro", displayPrice: "5,99 €")

    @Test func loadsAndTracksView() async {
        let env = TestEnvironment(now: "2026-11-03 10:00")
        let store = TestStore(initialState: PaywallFeature.State(source: .settingsLock)) {
            PaywallFeature()
        } withDependencies: {
            env.apply(&$0)
            $0.dismiss = DismissEffect {}
        }

        await store.send(.task)
        await store.receive(\.loaded) {
            $0.isLoading = false
            $0.products = [product]
        }
        #expect(store.state.product == product)
        let viewed = env.tracked("paywall_viewed").first
        #expect(viewed?.properties["source"] == "settings_lock")
        #expect(viewed?.properties["price_variant"] == "5.99")
    }

    @Test func priceVariantFromFlag() async {
        let env = TestEnvironment(now: "2026-11-03 10:00")
        let backend = RecordingAnalyticsBackend(flags: ["pro_price": "7.99"])
        let client = AnalyticsClient.recording(backend)
        await client.configure(Consent())
        let store = TestStore(initialState: PaywallFeature.State(source: .menu)) {
            PaywallFeature()
        } withDependencies: {
            env.apply(&$0)
            $0.analyticsClient = client
        }
        await store.send(.task)
        await store.receive(\.loaded) {
            $0.isLoading = false
            $0.products = [product]
            $0.priceVariant = "7.99"
        }
    }

    @Test func storeUnavailable() async {
        let env = TestEnvironment(now: "2026-11-03 10:00")
        let store = TestStore(initialState: PaywallFeature.State(source: .menu)) {
            PaywallFeature()
        } withDependencies: {
            env.apply(&$0)
            $0.storeClient.products = { throw StoreError.failed }
        }
        await store.send(.task)
        await store.receive(\.loaded) {
            $0.isLoading = false
            $0.message = "The App Store is not available right now."
        }
        await store.send(.purchaseTapped)
        await store.send(.loaded(.success([]), priceVariant: "5.99"))
    }

    /// PRD B.17 (paywall side).
    @Test func purchase() async {
        let env = TestEnvironment(now: "2026-11-03 10:00")
        var state = PaywallFeature.State(source: .menu)
        state.products = [product]
        state.isLoading = false
        let store = TestStore(initialState: state) {
            PaywallFeature()
        } withDependencies: {
            env.apply(&$0)
            $0.dismiss = DismissEffect {}
        }

        await store.send(.purchaseTapped) { $0.isPurchasing = true }
        await store.receive(\.purchaseResponse.success) { $0.isPurchasing = false }
        await store.receive(\.delegate.purchased)
        #expect(env.trackedNames == ["purchase_started", "purchase_completed"])
    }

    @Test func purchaseOutcomes() async {
        let env = TestEnvironment(now: "2026-11-03 10:00")
        let result = LockIsolated<Result<PurchaseResult, StoreError>>(.success(.cancelled))
        var state = PaywallFeature.State(source: .menu)
        state.products = [product]
        state.isLoading = false
        let store = TestStore(initialState: state) {
            PaywallFeature()
        } withDependencies: {
            env.apply(&$0)
            $0.storeClient.purchase = { _ in try result.value.get() }
        }

        await store.send(.purchaseTapped) { $0.isPurchasing = true }
        await store.receive(\.purchaseResponse.success) { $0.isPurchasing = false }

        result.setValue(.success(.pending))
        await store.send(.purchaseTapped) { $0.isPurchasing = true }
        await store.receive(\.purchaseResponse.success) {
            $0.isPurchasing = false
            $0.message = "Your purchase is waiting for approval."
        }

        result.setValue(.failure(.failed))
        await store.send(.purchaseTapped) {
            $0.isPurchasing = true
            $0.message = nil
        }
        await store.receive(\.purchaseResponse.failure) {
            $0.isPurchasing = false
            $0.message = "The purchase couldn't be completed. Try again."
        }
        let failures = env.tracked("purchase_failed").map { $0.properties["error_type"] }
        #expect(failures == ["cancelled", "store"])
    }

    /// PRD B.18 (paywall side).
    @Test func restore() async {
        let env = TestEnvironment(now: "2026-11-03 10:00")
        let store = TestStore(initialState: PaywallFeature.State(source: .menu)) {
            PaywallFeature()
        } withDependencies: {
            env.apply(&$0)
            $0.dismiss = DismissEffect {}
        }
        await store.send(.restoreTapped) { $0.isRestoring = true }
        await store.receive(\.restoreResponse.success) { $0.isRestoring = false }
        await store.receive(\.delegate.restored)
        #expect(env.trackedNames == ["purchase_restored"])
    }

    @Test func restoreWithoutPurchase() async {
        let env = TestEnvironment(now: "2026-11-03 10:00")
        let store = TestStore(initialState: PaywallFeature.State(source: .menu)) {
            PaywallFeature()
        } withDependencies: {
            env.apply(&$0)
            $0.storeClient.restore = { Entitlements(isPro: false) }
        }
        await store.send(.restoreTapped) { $0.isRestoring = true }
        await store.receive(\.restoreResponse.success) {
            $0.isRestoring = false
            $0.message = "No previous purchase found for this Apple ID."
        }
    }

    @Test func close() async {
        let env = TestEnvironment(now: "2026-11-03 10:00")
        let dismissed = LockIsolated(false)
        let store = TestStore(initialState: PaywallFeature.State(source: .menu)) {
            PaywallFeature()
        } withDependencies: {
            env.apply(&$0)
            $0.dismiss = DismissEffect { dismissed.setValue(true) }
        }
        await store.send(.closeTapped)
        #expect(dismissed.value)
    }
}
