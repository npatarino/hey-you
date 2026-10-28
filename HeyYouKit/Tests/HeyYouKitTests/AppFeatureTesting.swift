import ComposableArchitecture
import ConcurrencyExtras
import Foundation
@testable import HeyYouKit

@MainActor
protocol AppFeatureTesting {}

extension AppFeatureTesting {
    func makeStore(_ env: TestEnvironment, state: AppFeature.State, isPro: Bool = false) -> TestStoreOf<AppFeature> {
        TestStore(initialState: state) { AppFeature() } withDependencies: { env.apply(&$0, isPro: isPro) }
    }

    func signedIn(_ env: TestEnvironment, events: [CalendarEvent] = [], isPro: Bool = false) -> AppFeature.State {
        var state = AppFeature.State()
        state.auth = .signedIn(env.account)
        state.settingsScreen.account = env.account
        state.$onboardingCompleted.withLock { $0 = true }
        state.$installDate.withLock { $0 = env.start }
        if isPro {
            state.$entitlements.withLock { $0 = Entitlements(isPro: true, proDefaultsApplied: true) }
            state.$settings.withLock { $0.applyProDefaults() }
        }
        state.events = IdentifiedArray(uniqueElements: events)
        return state
    }

    func settle() async {
        await Task.megaYield()
    }
}
