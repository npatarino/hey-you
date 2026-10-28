import Dependencies
import DependenciesMacros
import Foundation

/// Google sign-in. The SDK stores and refreshes tokens in the Keychain.
@DependencyClient
public struct AuthClient: Sendable {
    public var restorePreviousSignIn: @Sendable () async -> GoogleAccount?
    /// Interactive sign-in. Needs a visible app window (onboarding or settings) to anchor the web session.
    public var signIn: @Sendable () async throws -> GoogleAccount
    public var signOut: @Sendable () async -> Void
    public var accessToken: @Sendable () async throws -> String
}

extension AuthClient: DependencyKey {
    public static let liveValue = Self(
        restorePreviousSignIn: { await GoogleSignInService.restore() },
        signIn: { try await GoogleSignInService.interactiveSignIn() },
        signOut: { await GoogleSignInService.signOut() },
        accessToken: { try await GoogleSignInService.accessToken() }
    )

    public static let previewValue = Self.mock

    /// Signs in immediately as demo@example.com.
    public static let mock = Self(
        restorePreviousSignIn: { GoogleAccount(email: "demo@example.com", name: "Demo") },
        signIn: { GoogleAccount(email: "demo@example.com", name: "Demo") },
        signOut: {},
        accessToken: { "mock-token" }
    )
}

public extension DependencyValues {
    var authClient: AuthClient {
        get { self[AuthClient.self] }
        set { self[AuthClient.self] = newValue }
    }
}
