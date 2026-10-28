import ComposableArchitecture
import DependenciesTestSupport
import Foundation
@testable import HeyYouKit
import Testing

@MainActor
@Suite(.dependencies)
struct PersonPropertiesTests: AppFeatureTesting {
    @Test(arguments: [(0, "0-2"), (2, "0-2"), (3, "3-10"), (10, "3-10"), (11, "11-25"), (25, "11-25"), (26, "25+")])
    func buckets(count: Int, bucket: String) {
        #expect(WeeklyMeetings(count: count).bucket == bucket)
    }

    @Test func weeklyRollover() {
        let week = WeeklyMeetings().adding(2, at: date("2026-11-03 10:00"), calendar: madridCalendar)
        #expect(week == WeeklyMeetings(weekStart: date("2026-11-02 00:00"), count: 2))
        #expect(week.adding(1, at: date("2026-11-08 23:00"), calendar: madridCalendar).count == 3)
        #expect(week.adding(1, at: date("2026-11-09 08:00"), calendar: madridCalendar)
            == WeeklyMeetings(weekStart: date("2026-11-09 00:00"), count: 1))
    }

    @Test func derivedProperties() {
        let env = TestEnvironment(now: "2026-11-03 10:00")
        var state = signedIn(env, isPro: true)
        state.calendars = MockCalendar.calendars
        state.$settings.withLock { $0.leadTimeSeconds = 20 }
        #expect(state.personProperties == [
            "is_pro": true, "lead_time": 20, "launch_at_login": false,
            "weekly_meetings_bucket": "0-2", "calendars_count": 2,
        ])
        state.$settings.withLock { $0.selectedCalendarIDs = ["primary"] }
        #expect(state.personProperties["calendars_count"] == 1)
        state.$entitlements.withLock { $0.isPro = false }
        #expect(state.personProperties["lead_time"] == 60)
        #expect(state.personProperties["calendars_count"] == 2)
    }

    /// Only changed properties are sent, and only while signed in.
    @Test func onlyChangesAreSent() async {
        let env = TestEnvironment(now: "2026-11-03 10:00")
        let store = makeStore(env, state: signedIn(env, isPro: true), isPro: true)
        await store.send(.calendarsResponse(MockCalendar.calendars)) {
            $0.calendars = MockCalendar.calendars
            $0.settingsScreen.calendars = MockCalendar.calendars
        }
        await store.send(.settingsScreen(.setLeadTime(30))) { $0.$settings.withLock { $0.leadTimeSeconds = 30 } }
        await store.finish()
        #expect(env.analytics.people == [["calendars_count": 2], ["lead_time": 30]])

        await store.send(.settingsScreen(.signOutTapped))
        await store.receive(\.settingsScreen.delegate.signOut) {
            $0.auth = .signedOut
            $0.settingsScreen.account = nil
            $0.calendars = []
        }
        await store.finish()
        #expect(env.analytics.people.count == 2)
    }
}
