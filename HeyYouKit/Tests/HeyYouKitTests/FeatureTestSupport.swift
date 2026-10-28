import Clocks
import ComposableArchitecture
import Foundation
@testable import HeyYouKit

/// Test clock plus a `date` that moves with it, and recorders for side effects.
final class TestEnvironment: Sendable {
    let clock = TestClock()
    let start: Date
    let analytics = RecordingAnalyticsBackend(flags: [:])
    let pipeline: AnalyticsPipeline
    let sounds = LockIsolated<[AlertSound]>([])
    let openedURLs = LockIsolated<[URL]>([])
    let signOuts = LockIsolated(0)
    let terminated = LockIsolated(false)
    let calendarResult: LockIsolated<Result<[CalendarEvent], CalendarError>>
    let account = GoogleAccount(email: "demo@example.com", name: "Demo")

    init(now: String, events: [CalendarEvent] = [], consent: Consent? = Consent()) {
        start = date(now)
        calendarResult = LockIsolated(.success(events))
        pipeline = AnalyticsPipeline(backend: analytics)
        if let consent {
            pipeline.configure(consent)
        }
    }

    var now: Date {
        start.addingTimeInterval(TestClock<Duration>.Instant().duration(to: clock.now).timeInterval)
    }

    var trackedNames: [String] {
        analytics.eventNames
    }

    func tracked(_ name: String) -> [RecordingAnalyticsBackend.Captured] {
        analytics.events.filter { $0.name == name }
    }

    func apply(_ values: inout DependencyValues, isPro: Bool = false) {
        values.continuousClock = clock
        values.date = DateGenerator { self.now }
        values.calendar = madridCalendar
        values.analyticsClient = .pipeline(pipeline)
        values.authClient = AuthClient(
            restorePreviousSignIn: { self.account },
            signIn: { self.account },
            signOut: { self.signOuts.withValue { $0 += 1 } },
            accessToken: { "token" }
        )
        values.calendarClient = CalendarClient(
            calendars: { MockCalendar.calendars },
            upcomingEvents: { _, _, _ in try self.calendarResult.value.get() }
        )
        values.storeClient = StoreClient(
            products: { [StoreProduct(id: AppConfig.proProductID, displayName: "Hey You! Pro", displayPrice: "5,99 €")] },
            purchase: { _ in .success(Entitlements(isPro: true, purchasedAt: self.start)) },
            restore: { Entitlements(isPro: true, purchasedAt: self.start) },
            currentEntitlements: { Entitlements(isPro: isPro) },
            updates: { .finished }
        )
        values.workspaceClient = WorkspaceClient(wakeNotifications: { .finished })
        values.soundClient = SoundClient(play: { sound in self.sounds.withValue { $0.append(sound) } })
        values.applicationClient = ApplicationClient(
            screensCount: { 2 },
            terminate: { self.terminated.setValue(true) }
        )
        values.launchAtLoginClient = .mock()
        values.openURL = OpenURLEffect { url in
            self.openedURLs.withValue { $0.append(url) }
            return true
        }
    }
}

let weeklySync = CalendarEvent.fixture(
    id: "weekly", title: "Weekly sync", start: "2026-11-03 11:00", end: "2026-11-03 11:30"
)
