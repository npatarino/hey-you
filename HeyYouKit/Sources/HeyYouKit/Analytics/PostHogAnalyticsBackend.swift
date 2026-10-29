import Foundation
import os
import PostHog

/// PostHog Cloud EU. Autocapture, screen views and session replay are off: only the typed events are sent.
public final class PostHogAnalyticsBackend: AnalyticsBackend {
    private static let logger = Logger(subsystem: "pro.chimi.heyyou", category: "analytics")
    private let isConfigured: Bool

    /// - Parameter apiKey: nil or a placeholder makes this backend a no-op.
    public init(apiKey: String?, superProperties: [String: AnalyticsValue]) {
        guard let apiKey, AppConfig.isRealValue(apiKey) else {
            Self.logger.warning("POSTHOG_API_KEY not set: analytics disabled")
            isConfigured = false
            return
        }
        let config = PostHogConfig(projectToken: apiKey, host: "https://eu.i.posthog.com")
        config.captureApplicationLifecycleEvents = false
        config.captureScreenViews = false
        config.enableSwizzling = false
        config.personProfiles = .identifiedOnly
        // Start opted out; `setEnabled` opts in only with consent.
        config.optOut = true
        PostHogSDK.shared.setup(config)
        PostHogSDK.shared.register(superProperties.mapValues(\.anyValue))
        isConfigured = true
    }

    public func setEnabled(_ enabled: Bool) {
        guard isConfigured else { return }
        if enabled {
            PostHogSDK.shared.optIn()
        } else {
            PostHogSDK.shared.optOut()
        }
    }

    public func capture(_ name: String, properties: [String: AnalyticsValue]) {
        guard isConfigured else { return }
        PostHogSDK.shared.capture(name, properties: properties.mapValues(\.anyValue))
    }

    public func identify(personProperties: [String: AnalyticsValue]) {
        guard isConfigured else { return }
        if let isPro = personProperties["is_pro"] {
            PostHogSDK.shared.register(["is_pro": isPro.anyValue])
        }
        let sdk = PostHogSDK.shared
        sdk.identify(sdk.getDistinctId(), userProperties: personProperties.mapValues(\.anyValue))
    }

    public func featureFlag(_ key: String) async -> String? {
        guard isConfigured else { return nil }
        let value = PostHogSDK.shared.getFeatureFlag(key)
        return (value as? String) ?? (value as? Bool).map { $0 ? "true" : "false" }
    }

    public func reset() {
        guard isConfigured else { return }
        PostHogSDK.shared.reset()
    }
}
