import Foundation
@testable import HeyYouKit
import Testing

struct AnalyticsTests {
    /// Every case produces the exact name and keys of PRD §6.1.
    @Test func taxonomy() {
        let cases: [(AnalyticsEvent, String, Set<String>)] = [
            (.appLaunched(launchAtLogin: true, daysSinceInstall: 3), "app_launched", ["launch_at_login", "days_since_install"]),
            (.onboardingViewed, "onboarding_viewed", []),
            (.signinStarted, "signin_started", []),
            (.signinCompleted, "signin_completed", []),
            (.signinFailed(errorType: .cancelled), "signin_failed", ["error_type"]),
            (.consentChanged(usage: true, email: false, source: .onboarding), "consent_changed", ["usage", "email", "source"]),
            (
                .calendarSynced(calendarsCount: 2, events24hCount: 5, eventsWithLinkCount: 4, durationMs: 120, errorType: nil),
                "calendar_synced",
                ["calendars_count", "events_24h_count", "events_with_link_count", "duration_ms"]
            ),
            (
                .calendarSynced(calendarsCount: 0, events24hCount: 0, eventsWithLinkCount: 0, durationMs: 9, errorType: .network),
                "calendar_synced",
                ["calendars_count", "events_24h_count", "events_with_link_count", "duration_ms", "error_type"]
            ),
            (.alertScheduled(secondsUntilFire: 30), "alert_scheduled", ["seconds_until_fire"]),
            (
                .alertShown(
                    leadTime: 60, provider: .googleMeet, screensCount: 2, isDeclined: false, hasOtherAttendees: true,
                    overlappingCount: 1, trigger: .scheduled, proHookShown: nil
                ),
                "alert_shown",
                [
                    "lead_time", "provider", "screens_count", "is_declined", "has_other_attendees",
                    "overlapping_count", "trigger", "pro_hook_shown",
                ]
            ),
            (
                .alertDismissed(reason: .join, secondsShown: 12, secondsToStart: 48, provider: nil),
                "alert_dismissed",
                ["reason", "seconds_shown", "seconds_to_start", "provider"]
            ),
            (.testAlertTriggered(source: .menu), "test_alert_triggered", ["source"]),
            (.settingChanged(.leadTime(20)), "setting_changed", ["key", "value"]),
            (.paywallViewed(source: .settingsLock, priceVariant: "5.99"), "paywall_viewed", ["source", "price_variant"]),
            (.purchaseStarted(priceVariant: "5.99"), "purchase_started", ["price_variant"]),
            (.purchaseCompleted(priceVariant: "5.99"), "purchase_completed", ["price_variant"]),
            (.purchaseFailed(priceVariant: "5.99", errorType: .store), "purchase_failed", ["price_variant", "error_type"]),
            (.purchaseRestored(priceVariant: "5.99"), "purchase_restored", ["price_variant"]),
            (.signout, "signout", []),
            (.appQuit(alertVisible: false), "app_quit", ["alert_visible"]),
            (.errorOccurred(type: .network, code: -1009), "error_occurred", ["type", "code"]),
        ]
        for (event, name, keys) in cases {
            #expect(event.name == name)
            #expect(Set(event.properties.keys) == keys, "\(name)")
        }
    }

    @Test func propertyValues() {
        let shown = AnalyticsEvent.alertShown(
            leadTime: 60, provider: .googleMeet, screensCount: 2, isDeclined: true, hasOtherAttendees: false,
            overlappingCount: 1, trigger: .test, proHookShown: .declined
        )
        #expect(shown.properties["provider"] == "meet")
        #expect(shown.properties["trigger"] == "test")
        #expect(shown.properties["pro_hook_shown"] == "declined")
        #expect(shown.properties["is_declined"] == true)
        #expect(shown.properties["lead_time"] == 60)

        let dismissed = AnalyticsEvent.alertDismissed(reason: .quitShortcut, secondsShown: 3, secondsToStart: -240, provider: nil)
        #expect(dismissed.properties["reason"] == "quit_shortcut")
        #expect(dismissed.properties["seconds_to_start"] == -240)
        #expect(dismissed.properties["provider"] == "none")
    }

    @Test(arguments: [
        (SettingChange.leadTime(20), "lead_time", AnalyticsValue.int(20)),
        (.ignoreDeclined(true), "ignore_declined", .bool(true)),
        (.ignoreWithoutOtherAttendees(false), "ignore_solo", .bool(false)),
        (.onlyEventsWithMeetingLink(true), "only_with_link", .bool(true)),
        (.selectedCalendarsCount(2), "calendars_count", .int(2)),
        (.selectedCalendarsCount(nil), "calendars_count", .string("all")),
        (.sound(.horn), "sound", .string("horn")),
        (.workingHours(enabled: true), "working_hours", .bool(true)),
        (.showCountdownInMenuBar(false), "menu_bar_countdown", .bool(false)),
        (.launchAtLogin(true), "launch_at_login", .bool(true)),
    ])
    func settingChanges(change: SettingChange, key: String, value: AnalyticsValue) {
        #expect(change.key == key)
        #expect(change.value == value)
    }

    /// PRD B.19: with usage analytics off, nothing reaches the backend.
    @Test func consentOffDropsEverything() async {
        let backend = RecordingAnalyticsBackend(flags: ["pro_price": "4.99"])
        let client = AnalyticsClient.recording(backend)
        await client.configure(Consent(usageAnalytics: false, emailContact: true))
        await client.track(.appLaunched(launchAtLogin: false, daysSinceInstall: 0))
        await client.identify("demo@example.com", ["is_pro": false])
        await client.setPersonProperties(["lead_time": 60])
        #expect(await client.featureFlag("pro_price") == nil)
        #expect(backend.events.isEmpty)
        #expect(backend.people.isEmpty)
        #expect(!backend.isEnabled)

        // Turning it on: consent_changed is the first event.
        await client.configure(Consent(usageAnalytics: true, emailContact: false))
        await client.track(.consentChanged(usage: true, email: false, source: .settings))
        #expect(backend.eventNames == ["consent_changed"])
        #expect(backend.isEnabled)
        #expect(await client.featureFlag("pro_price") == "4.99")
    }

    @Test func nothingBeforeConfigure() async {
        let backend = RecordingAnalyticsBackend()
        await AnalyticsClient.recording(backend).track(.signout)
        #expect(backend.events.isEmpty)
    }

    @Test func identifyHashesEmail() async {
        let backend = RecordingAnalyticsBackend()
        let client = AnalyticsClient.recording(backend)
        await client.configure(Consent(usageAnalytics: true, emailContact: false))
        await client.identify(" Demo@Example.com ", ["is_pro": false])
        let person = backend.people.last ?? [:]
        #expect(person["email_hash"] == .string(AnalyticsPipeline.sha256("demo@example.com")))
        #expect(person["email"] == nil)
        #expect(person["is_pro"] == false)

        await client.configure(Consent(usageAnalytics: true, emailContact: true))
        await client.identify("demo@example.com", [:])
        #expect(backend.people.last?["email"] == "demo@example.com")

        await client.reset()
        #expect(backend.events.isEmpty)
    }

    @Test func sha256() {
        #expect(AnalyticsPipeline.sha256("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    /// PRD B.19: events built from a real meeting never contain its title or link.
    @Test func noCalendarContentInEvents() {
        let event = CalendarEvent.fixture(title: "Weekly sync", start: "2026-11-03 11:00")
        let events: [AnalyticsEvent] = [
            .alertShown(
                leadTime: 60, provider: event.meetingLink?.provider, screensCount: 1,
                isDeclined: event.attendeeStatus == .declined, hasOtherAttendees: event.hasOtherAttendees,
                overlappingCount: 0, trigger: .scheduled, proHookShown: nil
            ),
            .alertDismissed(reason: .join, secondsShown: 5, secondsToStart: 30, provider: event.meetingLink?.provider),
        ]
        let serialized = events.map { "\($0.name) \($0.properties)" }.joined()
        #expect(!serialized.contains("Weekly sync"))
        #expect(!serialized.contains("meet.google.com"))
    }

    @Test func analyticsValueAny() {
        #expect(AnalyticsValue.string("a").anyValue as? String == "a")
        #expect(AnalyticsValue.int(1).anyValue as? Int == 1)
        #expect(AnalyticsValue.bool(true).anyValue as? Bool == true)
    }

    @Test func configValues() {
        #expect(!AppConfig.isRealValue("REPLACE_ME"))
        #expect(!AppConfig.isRealValue(" "))
        #expect(!AppConfig.isRealValue("$(GOOGLE_CLIENT_ID)"))
        #expect(AppConfig.isRealValue("123-abc.apps.googleusercontent.com"))
        #expect(Set(AppConfig.superProperties.keys) == ["app_version", "macos_version", "locale"])
    }

    @Test func postHogBackendWithoutKeyIsNoop() async {
        let backend = PostHogAnalyticsBackend(apiKey: "REPLACE_ME", superProperties: [:])
        backend.setEnabled(true)
        backend.capture("x", properties: [:])
        backend.identify(personProperties: ["is_pro": true])
        backend.reset()
        #expect(await backend.featureFlag("pro_price") == nil)
    }
}
