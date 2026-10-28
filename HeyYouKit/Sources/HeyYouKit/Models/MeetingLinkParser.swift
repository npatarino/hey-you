import Foundation

/// Finds the video-call link of an event.
///
/// Priority: `hangoutLink` → `conferenceData` video entry point → known provider URL in `location`
/// → known provider URL in `description`. The first match wins.
public enum MeetingLinkParser {
    public static func parse(
        hangoutLink: String?,
        conferenceVideoURIs: [String] = [],
        location: String?,
        description: String?
    ) -> MeetingLink? {
        if let hangoutLink, let link = link(fromTrusted: hangoutLink) {
            return link
        }
        for uri in conferenceVideoURIs {
            if let link = link(fromTrusted: uri) {
                return link
            }
        }
        if let location, let link = firstKnownLink(in: location) {
            return link
        }
        if let description, let link = firstKnownLink(in: description) {
            return link
        }
        return nil
    }

    /// Detects the provider of a URL, or nil if it is not one of the known providers.
    public static func provider(of url: URL) -> MeetingLink.Provider? {
        guard let host = url.host()?.lowercased() else { return nil }
        let path = url.path().lowercased()
        if host == "meet.google.com" {
            return .googleMeet
        }
        if host == "zoom.us" || host.hasSuffix(".zoom.us") {
            return path.hasPrefix("/j/") ? .zoom : nil
        }
        if host == "teams.microsoft.com" {
            return path.hasPrefix("/l/meetup-join") ? .teams : nil
        }
        if host == "webex.com" || host.hasSuffix(".webex.com") {
            return .webex
        }
        return nil
    }

    // MARK: - Private

    /// URLs from structured fields (hangoutLink, conferenceData) are trusted: any http(s) URL counts.
    private static func link(fromTrusted string: String) -> MeetingLink? {
        guard let url = httpURL(string.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        return MeetingLink(provider: provider(of: url) ?? .other, url: url)
    }

    /// Free text: only URLs from known providers count.
    private static func firstKnownLink(in text: String) -> MeetingLink? {
        for candidate in urls(in: text) {
            if let url = httpURL(candidate), let provider = provider(of: url) {
                return MeetingLink(provider: provider, url: url)
            }
        }
        return nil
    }

    private static func httpURL(_ string: String) -> URL? {
        guard let url = URL(string: string),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              url.host() != nil
        else { return nil }
        return url
    }

    /// Extracts `http(s)://…` substrings, stopping at whitespace, quotes and HTML delimiters
    /// (Google sends descriptions as HTML) and trimming trailing punctuation.
    private static func urls(in text: String) -> [String] {
        let decoded = text.replacingOccurrences(of: "&amp;", with: "&")
        let terminators = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'<>()[]{}|\\^`"))
        let trailing = CharacterSet(charactersIn: ".,;:!?")
        var results: [String] = []
        var searchRange = decoded.startIndex ..< decoded.endIndex
        while let match = decoded.range(of: "https?://", options: [.regularExpression, .caseInsensitive], range: searchRange) {
            var end = match.upperBound
            while end < decoded.endIndex,
                  let scalar = decoded[end].unicodeScalars.first,
                  !terminators.contains(scalar) {
                end = decoded.index(after: end)
            }
            var candidate = String(decoded[match.lowerBound ..< end])
            while let last = candidate.unicodeScalars.last, trailing.contains(last) {
                candidate.removeLast()
            }
            results.append(candidate)
            searchRange = end ..< decoded.endIndex
        }
        return results
    }
}
