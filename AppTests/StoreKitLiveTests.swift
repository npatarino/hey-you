import Foundation
import HeyYouKit
import StoreKitTest
import Testing

/// Runs inside the app (hosted test bundle): StoreKitTest needs a real app process.
/// The real StoreKit 2 client against the local `App/HeyYou.storekit` configuration.
@Suite(.serialized)
struct StoreClientLiveTests {
    static var configurationURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("App/HeyYou.storekit")
    }

    func session() throws -> SKTestSession {
        let session = try SKTestSession(contentsOf: Self.configurationURL)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        return session
    }

    @Test func productsPurchaseAndEntitlements() async throws {
        _ = try session()
        let client = StoreClient.liveValue

        let products = try await client.products()
        #expect(products.map(\.id) == [AppConfig.proProductID])
        #expect(products.first?.displayName == "Hey You! Pro")
        #expect(await client.currentEntitlements().isPro == false)

        let result = try await client.purchase(AppConfig.proProductID)
        guard case let .success(entitlements) = result else {
            Issue.record("purchase did not succeed: \(result)")
            return
        }
        #expect(entitlements.isPro)
        #expect(entitlements.purchasedAt != nil)
        // Not asserted: re-reading `currentEntitlements` and `AppStore.sync()` right after a purchase.
        // Under StoreKitTest on macOS 26 neither sees the new transaction (see docs/QA.md); check them by hand.
    }

    @Test func unknownProduct() async throws {
        _ = try session()
        await #expect(throws: StoreError.productNotFound) {
            try await StoreClient.liveValue.purchase("com.example.nope")
        }
    }
}
