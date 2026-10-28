import CryptoKit
import Foundation
import os

/// Where analytics events end up (PostHog in the app, memory in tests).
public protocol AnalyticsBackend: Sendable {
    func setEnabled(_ enabled: Bool)
    func capture(_ name: String, properties: [String: AnalyticsValue])
    func identify(personProperties: [String: AnalyticsValue])
    func featureFlag(_ key: String) async -> String?
    func reset()
}

/// Applies consent in one place: with usage analytics off nothing reaches the backend, not even queued.
public final class AnalyticsPipeline: Sendable {
    private struct State {
        var consent: Consent?
    }

    private let backend: any AnalyticsBackend
    private let state = OSAllocatedUnfairLock(initialState: State())

    public init(backend: any AnalyticsBackend) {
        self.backend = backend
    }

    private var isEnabled: Bool {
        state.withLock { $0.consent?.usageAnalytics ?? false }
    }

    public func configure(_ consent: Consent) {
        state.withLock { $0.consent = consent }
        backend.setEnabled(consent.usageAnalytics)
    }

    public func track(_ event: AnalyticsEvent) {
        guard isEnabled else { return }
        backend.capture(event.name, properties: event.properties)
    }

    /// Adds the SHA-256 of the email as a person property; the plain email only with contact consent.
    public func identify(email: String?, properties: [String: AnalyticsValue]) {
        let consent = state.withLock { $0.consent }
        guard let consent, consent.usageAnalytics else { return }
        var person = properties
        if let email {
            let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            person["email_hash"] = .string(Self.sha256(normalized))
            if consent.emailContact {
                person["email"] = .string(normalized)
            }
        }
        backend.identify(personProperties: person)
    }

    public func setPersonProperties(_ properties: [String: AnalyticsValue]) {
        guard isEnabled else { return }
        backend.identify(personProperties: properties)
    }

    public func featureFlag(_ key: String) async -> String? {
        guard isEnabled else { return nil }
        return await backend.featureFlag(key)
    }

    public func reset() {
        backend.reset()
    }

    static func sha256(_ string: String) -> String {
        SHA256.hash(data: Data(string.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// In-memory backend for tests and previews.
public final class RecordingAnalyticsBackend: AnalyticsBackend {
    public struct Captured: Equatable, Sendable {
        public let name: String
        public let properties: [String: AnalyticsValue]
    }

    private let storage = OSAllocatedUnfairLock(initialState: (
        events: [Captured](), people: [[String: AnalyticsValue]](), enabled: false
    ))
    private let flags: [String: String]

    public init(flags: [String: String] = [:]) {
        self.flags = flags
    }

    public var events: [Captured] {
        storage.withLock { $0.events }
    }

    public var eventNames: [String] {
        events.map(\.name)
    }

    public var people: [[String: AnalyticsValue]] {
        storage.withLock { $0.people }
    }

    public var isEnabled: Bool {
        storage.withLock { $0.enabled }
    }

    public func setEnabled(_ enabled: Bool) {
        storage.withLock { $0.enabled = enabled }
    }

    public func capture(_ name: String, properties: [String: AnalyticsValue]) {
        storage.withLock { $0.events.append(Captured(name: name, properties: properties)) }
    }

    public func identify(personProperties: [String: AnalyticsValue]) {
        storage.withLock { $0.people.append(personProperties) }
    }

    public func featureFlag(_ key: String) async -> String? {
        flags[key]
    }

    public func reset() {
        storage.withLock { $0.events.removeAll() }
    }
}
