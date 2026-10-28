import Foundation

/// A video-call link detected in an event.
public struct MeetingLink: Equatable, Sendable, Codable, Hashable {
    public enum Provider: String, Codable, Sendable, CaseIterable {
        case googleMeet
        case zoom
        case teams
        case webex
        case other

        /// Value used in analytics (`provider` property, PRD §6.1).
        public var analyticsName: String {
            switch self {
            case .googleMeet: "meet"
            case .zoom: "zoom"
            case .teams: "teams"
            case .webex: "webex"
            case .other: "other"
            }
        }

        public var displayName: String {
            switch self {
            case .googleMeet: "Google Meet"
            case .zoom: "Zoom"
            case .teams: "Microsoft Teams"
            case .webex: "Webex"
            case .other: String(localized: "Video call", bundle: .module)
            }
        }
    }

    public let provider: Provider
    public let url: URL

    public init(provider: Provider, url: URL) {
        self.provider = provider
        self.url = url
    }
}

public extension MeetingLink.Provider? {
    /// `none` when there is no link.
    var analyticsName: String {
        self?.analyticsName ?? "none"
    }
}
