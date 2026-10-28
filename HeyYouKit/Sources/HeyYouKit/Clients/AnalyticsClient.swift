import Dependencies
import DependenciesMacros
import Foundation

/// Product analytics (PostHog), gated by consent. Use only the typed `AnalyticsEvent`.
@DependencyClient
public struct AnalyticsClient: Sendable {
    public var configure: @Sendable (_ consent: Consent) async -> Void
    public var track: @Sendable (_ event: AnalyticsEvent) async -> Void
    /// Identifies the person with the email hash (plain email only with contact consent) and properties.
    public var identify: @Sendable (_ email: String?, _ properties: [String: AnalyticsValue]) async -> Void
    public var setPersonProperties: @Sendable (_ properties: [String: AnalyticsValue]) async -> Void
    public var featureFlag: @Sendable (_ key: String) async -> String?
    public var reset: @Sendable () async -> Void
}

public extension AnalyticsClient {
    static func pipeline(_ pipeline: AnalyticsPipeline) -> Self {
        Self(
            configure: { pipeline.configure($0) },
            track: { pipeline.track($0) },
            identify: { pipeline.identify(email: $0, properties: $1) },
            setPersonProperties: { pipeline.setPersonProperties($0) },
            featureFlag: { await pipeline.featureFlag($0) },
            reset: { pipeline.reset() }
        )
    }

    /// Records into memory through the real consent pipeline (tests, PRD B.19).
    static func recording(_ backend: RecordingAnalyticsBackend) -> Self {
        .pipeline(AnalyticsPipeline(backend: backend))
    }

    static let noop = Self(
        configure: { _ in }, track: { _ in }, identify: { _, _ in }, setPersonProperties: { _ in },
        featureFlag: { _ in nil }, reset: {}
    )
}

extension AnalyticsClient: DependencyKey {
    public static let liveValue: Self = .pipeline(AnalyticsPipeline(
        backend: PostHogAnalyticsBackend(apiKey: AppConfig.postHogAPIKey, superProperties: AppConfig.superProperties)
    ))
    public static let previewValue: Self = .noop
}

public extension DependencyValues {
    var analyticsClient: AnalyticsClient {
        get { self[AnalyticsClient.self] }
        set { self[AnalyticsClient.self] = newValue }
    }
}
