import Foundation
@testable import HeyYouKit
import Testing

struct SettingsTests {
    @Test(arguments: [(5, 10), (0, 10), (10, 10), (12, 10), (13, 15), (20, 20), (58, 60), (60, 60), (65, 60), (600, 60)])
    func leadTimeClamp(input: Int, expected: Int) {
        #expect(LeadTime.clamp(input) == expected)
    }

    /// PRD B.16: possible values are 10, 15 … 60.
    @Test func leadTimeValues() {
        #expect(LeadTime.allValues == [10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60])
    }

    @Test func freeIgnoresProSettings() {
        let stored = AppSettings(
            leadTimeSeconds: 20, ignoreDeclined: true, ignoreWithoutOtherAttendees: true,
            onlyEventsWithMeetingLink: true, selectedCalendarIDs: ["work"], sound: .horn,
            workingHours: .officeDefault, showCountdownInMenuBar: true
        )
        let effective = EffectiveSettings(stored, isPro: false)
        #expect(effective == EffectiveSettings(AppSettings(), isPro: false))
        #expect(effective.leadTimeSeconds == 60)
        #expect(effective.sound == .default)
        #expect(!effective.showCountdownInMenuBar)
    }

    @Test func proAppliesSettings() {
        let stored = AppSettings(
            leadTimeSeconds: 22, ignoreDeclined: true, selectedCalendarIDs: ["work"], sound: .none, workingHours: .officeDefault
        )
        let effective = EffectiveSettings(stored, isPro: true)
        #expect(effective.isPro)
        #expect(effective.leadTimeSeconds == 20)
        #expect(effective.ignoreDeclined)
        #expect(!effective.ignoreWithoutOtherAttendees)
        #expect(effective.selectedCalendarIDs == ["work"])
        #expect(effective.sound == .none)
        #expect(effective.workingHours == .officeDefault)
        #expect(effective.showCountdownInMenuBar)
    }

    @Test func proDefaults() {
        var settings = AppSettings()
        settings.applyProDefaults()
        #expect(settings.ignoreDeclined)
        #expect(settings.ignoreWithoutOtherAttendees)
        #expect(!settings.onlyEventsWithMeetingLink)
        #expect(settings.selectedCalendarIDs == nil)
        #expect(settings.workingHours == nil)
    }

    @Test func decodingToleratesMissingKeys() throws {
        let decoded = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"leadTimeSeconds": 30}"#.utf8))
        #expect(decoded == AppSettings(leadTimeSeconds: 30))
        let full = AppSettings(leadTimeSeconds: 15, selectedCalendarIDs: ["a"], sound: .bell, workingHours: .officeDefault)
        let roundTrip = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(full))
        #expect(roundTrip == full)
    }

    @Test func soundNames() {
        #expect(AlertSound.allCases.compactMap(\.systemSoundName) == ["Funk", "Glass", "Ping", "Sosumi", "Submarine"])
        #expect(AlertSound.none.systemSoundName == nil)
    }

    /// PRD B.20: Mon–Fri 09:00–18:00.
    @Test func workingHours() {
        let hours = WorkingHours.officeDefault
        #expect(!hours.contains(date("2026-11-07 10:00"), calendar: madridCalendar)) // Saturday
        #expect(!hours.contains(date("2026-11-09 08:30"), calendar: madridCalendar)) // Monday, too early
        #expect(hours.contains(date("2026-11-09 09:00"), calendar: madridCalendar))
        #expect(hours.contains(date("2026-11-09 17:59"), calendar: madridCalendar))
        #expect(!hours.contains(date("2026-11-09 18:00"), calendar: madridCalendar))
    }

    @Test func punctualityWeeks() {
        let calendar = madridCalendar
        var stats = PunctualityStats()
        stats = stats.recording(onTime: true, at: date("2026-11-03 10:00"), calendar: calendar)
        stats = stats.recording(onTime: false, at: date("2026-11-05 10:00"), calendar: calendar)
        #expect(stats.alerts == 2)
        #expect(stats.onTime == 1)
        #expect(stats.weekStart == date("2026-11-02 00:00"))
        #expect(stats.current(at: date("2026-11-08 23:00"), calendar: calendar) == stats)
        let nextWeek = stats.recording(onTime: true, at: date("2026-11-09 10:00"), calendar: calendar)
        #expect(nextWeek == PunctualityStats(weekStart: date("2026-11-09 00:00"), alerts: 1, onTime: 1))
        #expect(stats.current(at: date("2026-11-10 10:00"), calendar: calendar).alerts == 0)
    }

    @Test func onTimeRule() {
        #expect(PunctualityStats.isOnTime(joined: true, secondsToStart: -300))
        #expect(PunctualityStats.isOnTime(joined: false, secondsToStart: 40))
        #expect(PunctualityStats.isOnTime(joined: false, secondsToStart: -30))
        #expect(!PunctualityStats.isOnTime(joined: false, secondsToStart: -31))
    }

    @Test func dedupeKeyIncludesStart() {
        let event = CalendarEvent.fixture(id: "e1", title: "A", start: "2026-11-03 11:00")
        let moved = CalendarEvent.fixture(id: "e1", title: "A", start: "2026-11-03 11:30")
        #expect(event.dedupeKey != moved.dedupeKey)
        #expect(event.dedupeKey.hasPrefix("e1|"))
    }

    @Test func simpleModels() {
        #expect(Consent() == Consent(usageAnalytics: true, emailContact: false))
        #expect(Entitlements() == Entitlements(isPro: false, purchasedAt: nil, proDefaultsApplied: false))
        let summary = CalendarSummary(id: "work", name: "Work")
        #expect(!summary.isPrimary)
        #expect(summary.colorHex == nil)
    }
}
