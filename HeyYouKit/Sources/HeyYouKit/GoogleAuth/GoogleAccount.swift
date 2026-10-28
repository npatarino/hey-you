import Foundation

/// The signed-in Google account.
public struct GoogleAccount: Equatable, Sendable, Codable {
    public let email: String
    public let name: String?

    public init(email: String, name: String? = nil) {
        self.email = email
        self.name = name
    }
}

public enum AuthError: Error, Equatable, Sendable {
    /// `GIDClientID` is missing or still `REPLACE_ME`.
    case notConfigured
    /// The user did not grant calendar access on Google's consent screen.
    case missingCalendarScope
    case cancelled
    case notSignedIn
    case keychain
    case noWindow
    case failed(code: Int)

    public var analyticsType: AnalyticsErrorType {
        switch self {
        case .notConfigured: .notConfigured
        case .missingCalendarScope: .missingScope
        case .cancelled: .cancelled
        case .notSignedIn: .unauthorized
        case .keychain, .noWindow, .failed: .unknown
        }
    }
}
