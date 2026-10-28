import Dependencies
import DependenciesMacros
import Foundation
import StoreKit

/// A product as shown in the paywall.
public struct StoreProduct: Equatable, Identifiable, Sendable {
    public let id: String
    public let displayName: String
    public let displayPrice: String

    public init(id: String, displayName: String, displayPrice: String) {
        self.id = id
        self.displayName = displayName
        self.displayPrice = displayPrice
    }
}

public enum PurchaseResult: Equatable, Sendable {
    case success(Entitlements)
    case pending
    case cancelled
}

public enum StoreError: Error, Equatable, Sendable {
    case productNotFound
    case unverified
    case failed
}

/// StoreKit 2. Pro is derived only from `Transaction.currentEntitlements`.
@DependencyClient
public struct StoreClient: Sendable {
    public var products: @Sendable () async throws -> [StoreProduct]
    public var purchase: @Sendable (_ productID: String) async throws -> PurchaseResult
    /// `AppStore.sync()` and then the current entitlements.
    public var restore: @Sendable () async throws -> Entitlements
    public var currentEntitlements: @Sendable () async -> Entitlements = { Entitlements() }
    public var updates: @Sendable () -> AsyncStream<Entitlements> = { .finished }
}

extension StoreClient: DependencyKey {
    public static let liveValue = Self(
        products: {
            try await Product.products(for: [AppConfig.proProductID]).map {
                StoreProduct(id: $0.id, displayName: $0.displayName, displayPrice: $0.displayPrice)
            }
        },
        purchase: { productID in
            guard let product = try await Product.products(for: [productID]).first else {
                throw StoreError.productNotFound
            }
            switch try await product.purchase() {
            case let .success(verification):
                let transaction = try verified(verification)
                await transaction.finish()
                // Use the verified transaction itself: `currentEntitlements` can lag right after a purchase.
                return .success(LiveStore.entitlements(from: transaction))
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .cancelled
            }
        },
        restore: {
            try await AppStore.sync()
            return await LiveStore.currentEntitlements()
        },
        currentEntitlements: { await LiveStore.currentEntitlements() },
        updates: {
            AsyncStream { continuation in
                let task = Task {
                    for await update in Transaction.updates {
                        if let transaction = try? verified(update), transaction.productID == AppConfig.proProductID {
                            await transaction.finish()
                            continuation.yield(LiveStore.entitlements(from: transaction))
                        } else {
                            await continuation.yield(LiveStore.currentEntitlements())
                        }
                    }
                    continuation.finish()
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
    )

    public static let previewValue = Self.mock(isPro: false)

    /// Purchases succeed after 0.5 s.
    public static func mock(isPro: Bool) -> Self {
        let state = LockIsolated(Entitlements(isPro: isPro))
        return Self(
            products: { [StoreProduct(id: AppConfig.proProductID, displayName: "Hey You! Pro", displayPrice: "5,99 €")] },
            purchase: { _ in
                try await Task.sleep(for: .milliseconds(500))
                state.setValue(Entitlements(isPro: true, purchasedAt: Date()))
                return .success(state.value)
            },
            restore: { state.value },
            currentEntitlements: { state.value },
            updates: { .finished }
        )
    }

    private static func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case let .verified(value): value
        case .unverified: throw StoreError.unverified
        }
    }
}

enum LiveStore {
    /// Pro from `Transaction.currentEntitlements`, falling back to the latest Pro transaction
    /// (the entitlement list can lag right after a purchase or restore).
    static func currentEntitlements() async -> Entitlements {
        for await result in Transaction.currentEntitlements {
            if case let .verified(transaction) = result, transaction.productID == AppConfig.proProductID {
                return entitlements(from: transaction)
            }
        }
        if case let .verified(transaction)? = await Transaction.latest(for: AppConfig.proProductID) {
            return entitlements(from: transaction)
        }
        return Entitlements(isPro: false)
    }

    /// Pro unless the transaction was refunded or revoked.
    static func entitlements(from transaction: Transaction) -> Entitlements {
        guard transaction.revocationDate == nil else { return Entitlements(isPro: false) }
        return Entitlements(isPro: true, purchasedAt: transaction.purchaseDate)
    }
}

public extension DependencyValues {
    var storeClient: StoreClient {
        get { self[StoreClient.self] }
        set { self[StoreClient.self] = newValue }
    }
}
