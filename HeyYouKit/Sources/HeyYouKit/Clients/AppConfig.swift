import AppKit
import Foundation

/// Values injected into Info.plist from `Config/Secrets.xcconfig`.
public enum AppConfig {
    public static let proProductID = "com.patarino.heyyou.pro"
    public static let calendarScope = "https://www.googleapis.com/auth/calendar.readonly"
    public static let projectURL = URL(string: "https://github.com/npatarino/hey-you") ?? URL(fileURLWithPath: "/")
    public static let privacyURL = URL(string: "https://github.com/npatarino/hey-you/blob/main/PRIVACY.md")
        ?? URL(fileURLWithPath: "/")
    public static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
        ?? URL(fileURLWithPath: "/")
    public static let defaultPriceVariant = "5.99"

    public static var googleClientID: String? {
        infoValue("GIDClientID")
    }

    public static var postHogAPIKey: String? {
        infoValue("PostHogAPIKey")
    }

    public static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// False for empty values, `REPLACE_ME` and unexpanded `$(VARIABLES)`.
    public static func isRealValue(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != "REPLACE_ME" && !trimmed.hasPrefix("$(")
    }

    /// Properties attached to every analytics event (PRD §6.1).
    public static var superProperties: [String: AnalyticsValue] {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        return [
            "app_version": .string(appVersion),
            "macos_version": .string("\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"),
            "locale": .string(Locale.current.identifier),
        ]
    }

    private static func infoValue(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String, isRealValue(value) else {
            return nil
        }
        return value
    }
}
