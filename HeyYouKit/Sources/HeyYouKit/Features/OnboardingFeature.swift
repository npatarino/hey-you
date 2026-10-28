import ComposableArchitecture
import Foundation

/// One welcome window: what the app does, Sign in with Google, consent toggles.
/// After sign-in: launch at login and "Test the alert". Never mentions Pro.
@Reducer
public struct OnboardingFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public enum Step: Equatable, Sendable {
            case welcome
            case connected(GoogleAccount)
        }

        public var step: Step = .welcome
        public var isSigningIn = false
        public var errorMessage: String?
        public var launchAtLogin: LaunchAtLoginStatus = .disabled
        @Shared(.consent) public var consent

        public init(step: Step = .welcome) {
            self.step = step
        }
    }

    public enum Action: Sendable, Equatable {
        case task
        case signInTapped
        case signInResponse(Result<GoogleAccount, AuthError>)
        case setUsageConsent(Bool)
        case setEmailConsent(Bool)
        case setLaunchAtLogin(Bool)
        case testAlertTapped
        case doneTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Sendable, Equatable {
            case signedIn(GoogleAccount)
            case launchAtLoginChanged(Bool)
            case testAlert
            case finished
        }
    }

    @Dependency(\.authClient) var authClient
    @Dependency(\.analyticsClient) var analytics
    @Dependency(\.launchAtLoginClient) var launchAtLoginClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                state.launchAtLogin = launchAtLoginClient.status()
                return .run { _ in await analytics.track(.onboardingViewed) }

            case .signInTapped:
                guard !state.isSigningIn else { return .none }
                state.isSigningIn = true
                state.errorMessage = nil
                return .run { send in
                    await analytics.track(.signinStarted)
                    do {
                        try await send(.signInResponse(.success(authClient.signIn())))
                    } catch {
                        await send(.signInResponse(.failure(AuthError(error))))
                    }
                }

            case let .signInResponse(.success(account)):
                state.isSigningIn = false
                state.step = .connected(account)
                return .merge(
                    .run { _ in await analytics.track(.signinCompleted) },
                    .send(.delegate(.signedIn(account)))
                )

            case let .signInResponse(.failure(error)):
                state.isSigningIn = false
                state.errorMessage = error.message
                return .run { _ in await analytics.track(.signinFailed(errorType: error.analyticsType)) }

            case let .setUsageConsent(enabled):
                state.$consent.withLock { $0.usageAnalytics = enabled }
                return Self.consentChanged(state.consent, analytics: analytics)

            case let .setEmailConsent(enabled):
                state.$consent.withLock { $0.emailContact = enabled }
                return Self.consentChanged(state.consent, analytics: analytics)

            case let .setLaunchAtLogin(enabled):
                state.launchAtLogin = (try? launchAtLoginClient.set(enabled)) ?? launchAtLoginClient.status()
                return .send(.delegate(.launchAtLoginChanged(state.launchAtLogin == .enabled)))

            case .testAlertTapped:
                return .send(.delegate(.testAlert))

            case .doneTapped:
                return .send(.delegate(.finished))

            case .delegate:
                return .none
            }
        }
    }

    /// Applies consent first, so turning analytics off sends nothing and turning it on sends `consent_changed` first.
    static func consentChanged(_ consent: Consent, analytics: AnalyticsClient) -> Effect<Action> {
        .run { _ in
            await analytics.configure(consent)
            await analytics.track(.consentChanged(usage: consent.usageAnalytics, email: consent.emailContact, source: .onboarding))
        }
    }
}
