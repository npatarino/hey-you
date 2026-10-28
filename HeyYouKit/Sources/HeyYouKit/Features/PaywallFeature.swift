import ComposableArchitecture
import Foundation

/// "Hey You! Pro" sheet: one non-consumable, buy or restore.
@Reducer
public struct PaywallFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var source: PaywallSource
        public var products: [StoreProduct] = []
        public var isLoading = true
        public var isPurchasing = false
        public var isRestoring = false
        public var message: String?
        public var priceVariant = AppConfig.defaultPriceVariant

        public init(source: PaywallSource) {
            self.source = source
        }

        public var product: StoreProduct? {
            products.first { $0.id == AppConfig.proProductID } ?? products.first
        }

        public var isBusy: Bool {
            isPurchasing || isRestoring
        }
    }

    public enum Action: Sendable, Equatable {
        case task
        case loaded(Result<[StoreProduct], StoreError>, priceVariant: String)
        case purchaseTapped
        case purchaseResponse(Result<PurchaseResult, StoreError>)
        case restoreTapped
        case restoreResponse(Result<Entitlements, StoreError>)
        case closeTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Sendable, Equatable {
            case purchased(Entitlements)
            case restored(Entitlements)
        }
    }

    @Dependency(\.storeClient) var storeClient
    @Dependency(\.analyticsClient) var analytics
    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let source = state.source
                return .run { send in
                    let variant = await analytics.featureFlag("pro_price") ?? AppConfig.defaultPriceVariant
                    await analytics.track(.paywallViewed(source: source, priceVariant: variant))
                    let products: Result<[StoreProduct], StoreError>
                    do {
                        products = try await .success(storeClient.products())
                    } catch {
                        products = .failure(StoreError(error))
                    }
                    await send(.loaded(products, priceVariant: variant))
                }

            case let .loaded(result, variant):
                state.isLoading = false
                state.priceVariant = variant
                switch result {
                case let .success(products):
                    state.products = products
                    if products.isEmpty {
                        state.message = String(localized: "The App Store is not available right now.", bundle: .module)
                    }
                case .failure:
                    state.message = String(localized: "The App Store is not available right now.", bundle: .module)
                }
                return .none

            case .purchaseTapped:
                guard let product = state.product, !state.isBusy else { return .none }
                state.isPurchasing = true
                state.message = nil
                let variant = state.priceVariant
                return .run { send in
                    await analytics.track(.purchaseStarted(priceVariant: variant))
                    do {
                        try await send(.purchaseResponse(.success(storeClient.purchase(product.id))))
                    } catch {
                        await send(.purchaseResponse(.failure(StoreError(error))))
                    }
                }

            case let .purchaseResponse(.success(.success(entitlements))):
                state.isPurchasing = false
                let variant = state.priceVariant
                return .run { send in
                    await analytics.track(.purchaseCompleted(priceVariant: variant))
                    await send(.delegate(.purchased(entitlements)))
                    await dismiss()
                }

            case .purchaseResponse(.success(.pending)):
                state.isPurchasing = false
                state.message = String(localized: "Your purchase is waiting for approval.", bundle: .module)
                return .none

            case .purchaseResponse(.success(.cancelled)):
                state.isPurchasing = false
                let variant = state.priceVariant
                return .run { _ in
                    await analytics.track(.purchaseFailed(priceVariant: variant, errorType: .cancelled))
                }

            case .purchaseResponse(.failure):
                state.isPurchasing = false
                state.message = String(localized: "The purchase couldn't be completed. Try again.", bundle: .module)
                let variant = state.priceVariant
                return .run { _ in
                    await analytics.track(.purchaseFailed(priceVariant: variant, errorType: .store))
                }

            case .restoreTapped:
                guard !state.isBusy else { return .none }
                state.isRestoring = true
                state.message = nil
                return .run { send in
                    do {
                        try await send(.restoreResponse(.success(storeClient.restore())))
                    } catch {
                        await send(.restoreResponse(.failure(StoreError(error))))
                    }
                }

            case let .restoreResponse(.success(entitlements)) where entitlements.isPro:
                state.isRestoring = false
                let variant = state.priceVariant
                return .run { send in
                    await analytics.track(.purchaseRestored(priceVariant: variant))
                    await send(.delegate(.restored(entitlements)))
                    await dismiss()
                }

            case .restoreResponse:
                state.isRestoring = false
                state.message = String(localized: "No previous purchase found for this Apple ID.", bundle: .module)
                return .none

            case .closeTapped:
                return .run { _ in await dismiss() }

            case .delegate:
                return .none
            }
        }
    }
}
