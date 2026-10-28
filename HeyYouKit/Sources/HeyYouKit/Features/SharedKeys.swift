import ComposableArchitecture
import Foundation

public extension SharedKey where Self == AppStorageKey<AppSettings>.Default {
    static var appSettings: Self {
        Self[.appStorage("settings"), default: AppSettings()]
    }
}

public extension SharedKey where Self == AppStorageKey<Consent>.Default {
    static var consent: Self {
        Self[.appStorage("consent"), default: Consent()]
    }
}

public extension SharedKey where Self == AppStorageKey<Entitlements>.Default {
    static var entitlements: Self {
        Self[.appStorage("entitlements"), default: Entitlements()]
    }
}

public extension SharedKey where Self == AppStorageKey<PunctualityStats>.Default {
    static var punctuality: Self {
        Self[.appStorage("punctuality"), default: PunctualityStats()]
    }
}

public extension SharedKey where Self == AppStorageKey<Bool>.Default {
    static var onboardingCompleted: Self {
        Self[.appStorage("onboardingCompleted"), default: false]
    }
}

public extension SharedKey where Self == AppStorageKey<Date?> {
    static var installDate: Self {
        .appStorage("installDate")
    }
}

/// Converts any thrown error into the closed error enums used in actions.
extension CalendarError {
    init(_ error: any Error) {
        if let error = error as? CalendarError {
            self = error
        } else if error is URLError {
            self = .offline
        } else if let error = error as? AuthError, error == .notSignedIn {
            self = .unauthorized
        } else {
            self = .server(status: 0)
        }
    }
}

extension AuthError {
    init(_ error: any Error) {
        self = (error as? AuthError) ?? .failed(code: (error as NSError).code)
    }

    /// User-facing message (nil for a cancelled sign-in, which needs no message).
    public var message: String? {
        switch self {
        case .cancelled:
            nil
        case .notConfigured:
            String(
                localized: "Google sign-in isn't set up in this build. Add your OAuth client ID to Config/Secrets.xcconfig.",
                bundle: .module
            )
        case .missingCalendarScope:
            String(localized: "Hey You! needs read access to your calendar. Please allow it on Google's screen.", bundle: .module)
        case .noWindow:
            String(localized: "Couldn't open the Google sign-in window. Try again.", bundle: .module)
        case .notSignedIn, .keychain, .failed:
            String(localized: "Couldn't sign in with Google. Try again.", bundle: .module)
        }
    }
}

extension StoreError {
    init(_ error: any Error) {
        self = (error as? StoreError) ?? .failed
    }
}

extension Duration {
    var timeInterval: TimeInterval {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
