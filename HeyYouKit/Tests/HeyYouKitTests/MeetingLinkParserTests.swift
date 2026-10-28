import Foundation
@testable import HeyYouKit
import Testing

struct MeetingLinkParserTests {
    @Test func hangoutLinkWins() {
        let link = MeetingLinkParser.parse(
            hangoutLink: "https://meet.google.com/abc-defg-hij",
            conferenceVideoURIs: ["https://zoom.us/j/1"],
            location: "https://zoom.us/j/2",
            description: "https://teams.microsoft.com/l/meetup-join/x"
        )
        #expect(link == meetLink)
    }

    @Test func conferenceDataBeforeFreeText() {
        let link = MeetingLinkParser.parse(
            hangoutLink: nil,
            conferenceVideoURIs: ["https://us02web.zoom.us/j/123456?pwd=x"],
            location: "https://meet.google.com/zzz",
            description: nil
        )
        #expect(link?.provider == .zoom)
        #expect(link?.url.absoluteString == "https://us02web.zoom.us/j/123456?pwd=x")
    }

    @Test func conferenceDataUnknownProviderIsOther() {
        let link = MeetingLinkParser.parse(
            hangoutLink: nil, conferenceVideoURIs: ["https://whereby.com/room"], location: nil, description: nil
        )
        #expect(link?.provider == .other)
    }

    @Test func invalidStructuredLinksAreSkipped() {
        let link = MeetingLinkParser.parse(
            hangoutLink: "not a url", conferenceVideoURIs: ["tel:+34600000000", ""], location: nil, description: nil
        )
        #expect(link == nil)
    }

    @Test func zoomInLocation() {
        let link = MeetingLinkParser.parse(
            hangoutLink: nil, location: "https://zoom.us/j/91234567890?pwd=abc", description: nil
        )
        #expect(link == zoomLink)
    }

    @Test func locationBeforeDescription() {
        let link = MeetingLinkParser.parse(
            hangoutLink: nil,
            location: "Room 4 / https://acme.webex.com/meet/ana",
            description: "Join https://meet.google.com/abc-defg-hij"
        )
        #expect(link?.provider == .webex)
    }

    @Test func teamsInHTMLDescription() {
        let html = """
        <p>Microsoft Teams meeting</p><a href="https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc%40thread.v2/0?context=%7b%7d&amp;x=1">Click here</a>
        """
        let link = MeetingLinkParser.parse(hangoutLink: nil, location: nil, description: html)
        #expect(link?.provider == .teams)
        #expect(link?.url.absoluteString == "https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc%40thread.v2/0?context=%7b%7d&x=1")
    }

    @Test func trailingPunctuationIsTrimmed() {
        let link = MeetingLinkParser.parse(
            hangoutLink: nil, location: nil, description: "Link: https://meet.google.com/abc-defg-hij."
        )
        #expect(link == meetLink)
    }

    @Test func unknownURLsInFreeTextAreIgnored() {
        let link = MeetingLinkParser.parse(
            hangoutLink: nil,
            location: "https://maps.google.com/?q=office",
            description: "Agenda: https://docs.google.com/doc and https://zoom.us/signin then https://acme.webex.com/join/x"
        )
        #expect(link?.provider == .webex)
    }

    @Test func noLink() {
        #expect(MeetingLinkParser.parse(hangoutLink: nil, location: "Room 4", description: "Bring snacks") == nil)
        #expect(MeetingLinkParser.parse(hangoutLink: nil, location: nil, description: nil) == nil)
    }

    @Test func providerDetection() {
        #expect(MeetingLinkParser.provider(of: url("https://meet.google.com/x")) == .googleMeet)
        #expect(MeetingLinkParser.provider(of: url("https://zoom.us/j/1")) == .zoom)
        #expect(MeetingLinkParser.provider(of: url("https://zoom.us/my/ana")) == nil)
        #expect(MeetingLinkParser.provider(of: url("https://teams.microsoft.com/l/meetup-join/1")) == .teams)
        #expect(MeetingLinkParser.provider(of: url("https://teams.microsoft.com/l/channel/1")) == nil)
        #expect(MeetingLinkParser.provider(of: url("https://webex.com/x")) == .webex)
        #expect(MeetingLinkParser.provider(of: url("https://example.com")) == nil)
        #expect(MeetingLinkParser.provider(of: url("mailto:a@b.c")) == nil)
    }

    @Test func analyticsNames() {
        #expect(MeetingLink.Provider.allCases.map(\.analyticsName) == ["meet", "zoom", "teams", "webex", "other"])
        let none: MeetingLink.Provider? = nil
        #expect(none.analyticsName == "none")
        #expect(MeetingLink.Provider.zoom.displayName == "Zoom")
        #expect(MeetingLink.Provider.allCases.allSatisfy { !$0.displayName.isEmpty })
    }
}
