import AppKit
import GoogleSignIn

/// Thin MainActor wrapper over `GIDSignIn.sharedInstance`. Credentials live in the Keychain (SDK-managed).
/// Callbacks only hand Sendable values (account, token, error) back across the continuation.
@MainActor
enum GoogleSignInService {
    private static var signIn: GIDSignIn {
        GIDSignIn.sharedInstance
    }

    private static func configure() throws {
        guard let clientID = AppConfig.googleClientID else { throw AuthError.notConfigured }
        if signIn.configuration?.clientID != clientID {
            signIn.configuration = GIDConfiguration(clientID: clientID)
        }
    }

    static func restore() async -> GoogleAccount? {
        guard (try? configure()) != nil, signIn.hasPreviousSignIn() else { return nil }
        return await withCheckedContinuation { continuation in
            signIn.restorePreviousSignIn { user, _ in
                continuation.resume(returning: user.flatMap(account(from:)))
            }
        }
    }

    static func interactiveSignIn() async throws -> GoogleAccount {
        try configure()
        let window = try presentingWindow()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            signIn.signIn(withPresenting: window, hint: nil, additionalScopes: [AppConfig.calendarScope]) { result, error in
                if result != nil {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: mapError(error))
                }
            }
        }
        guard let user = signIn.currentUser else { throw AuthError.failed(code: 0) }
        if !(user.grantedScopes ?? []).contains(AppConfig.calendarScope) {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                user.addScopes([AppConfig.calendarScope], presenting: window) { result, error in
                    if result != nil {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: mapError(error))
                    }
                }
            }
        }
        guard let current = signIn.currentUser,
              (current.grantedScopes ?? []).contains(AppConfig.calendarScope)
        else {
            throw AuthError.missingCalendarScope
        }
        guard let account = account(from: current) else { throw AuthError.failed(code: 0) }
        return account
    }

    static func signOut() {
        signIn.signOut()
    }

    /// A fresh access token, refreshing it if it expires soon.
    static func accessToken() async throws -> String {
        guard let user = signIn.currentUser else { throw AuthError.notSignedIn }
        return try await withCheckedThrowingContinuation { continuation in
            user.refreshTokensIfNeeded { user, error in
                if let token = user?.accessToken.tokenString {
                    continuation.resume(returning: token)
                } else {
                    continuation.resume(throwing: mapError(error))
                }
            }
        }
    }

    @discardableResult
    static func handle(_ url: URL) -> Bool {
        signIn.handle(url)
    }

    // MARK: - Private

    private nonisolated static func account(from user: GIDGoogleUser) -> GoogleAccount? {
        guard let profile = user.profile else { return nil }
        return GoogleAccount(email: profile.email, name: profile.name)
    }

    /// The onboarding/settings window anchors `ASWebAuthenticationSession`.
    private static func presentingWindow() throws -> NSWindow {
        if let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible && $0.canBecomeKey }) {
            return window
        }
        throw AuthError.noWindow
    }

    nonisolated static func mapError(_ error: (any Error)?) -> AuthError {
        guard let error = error as NSError? else { return .failed(code: 0) }
        guard error.domain == kGIDSignInErrorDomain else { return .failed(code: error.code) }
        switch GIDSignInError.Code(rawValue: error.code) {
        case .canceled: return .cancelled
        case .hasNoAuthInKeychain: return .notSignedIn
        case .keychain: return .keychain
        default: return .failed(code: error.code)
        }
    }
}

/// Entry point for the app delegate's URL handler.
public enum GoogleAuthURLHandler {
    @MainActor
    @discardableResult
    public static func handle(_ url: URL) -> Bool {
        GoogleSignInService.handle(url)
    }
}
