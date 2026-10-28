import AppKit
import ComposableArchitecture
import DependenciesTestSupport
@testable import HeyYouKit
import SwiftUI
import Testing

/// Waits for main-queue observation callbacks (swift-navigation's `observe` hops to the main queue).
@MainActor
func eventually(_ condition: () -> Bool, timeout: Duration = .seconds(3)) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while !condition() {
        if clock.now > deadline {
            return false
        }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return true
}

@MainActor
@Suite(.dependencies, .serialized)
struct WindowControllerTests {
    init() {
        _ = NSApplication.shared
    }

    func makeStore(_ env: TestEnvironment) -> StoreOf<AppFeature> {
        var state = AppFeature.State()
        state.auth = .signedIn(env.account)
        state.$onboardingCompleted.withLock { $0 = true }
        return Store(initialState: state) { AppFeature() } withDependencies: { env.apply(&$0) }
    }

    func showAlert(_ store: StoreOf<AppFeature>, env: TestEnvironment) {
        store.send(.alertDue(ScheduledAlert(event: weeklySync, fireAt: env.now), .test))
    }

    @Test func alertPanelsFollowState() async {
        let env = TestEnvironment(now: "2026-11-03 10:59")
        let store = makeStore(env)
        let controller = AlertWindowController(store: store)
        #expect(!controller.isShowing)

        showAlert(store, env: env)
        #expect(await eventually { controller.isShowing })
        #expect(controller.visiblePanels.count == NSScreen.screens.count)
        #expect(controller.visiblePanels.allSatisfy { $0.level == .screenSaver && $0.contentView != nil })

        // Return joins: the link opens and the alert goes away.
        controller.handle(.join)
        #expect(await eventually { store.alert == nil && !controller.isShowing })
        #expect(env.openedURLs.value == [meetLink.url])
        #expect(controller.visiblePanels.isEmpty)
    }

    @Test func anyKeyDismisses() async {
        let env = TestEnvironment(now: "2026-11-03 10:59")
        let store = makeStore(env)
        let controller = AlertWindowController(store: store)
        showAlert(store, env: env)
        #expect(await eventually { controller.isShowing })
        controller.handle(.dismiss(.key))
        #expect(await eventually { store.alert == nil && !controller.isShowing })
        #expect(env.openedURLs.value.isEmpty)
    }

    /// PRD §5.4: ⌘Q with an alert only dismisses it; without one the app may quit.
    @Test func quitIsInterceptedOnlyWhileVisible() async {
        let env = TestEnvironment(now: "2026-11-03 10:59")
        let store = makeStore(env)
        let controller = AlertWindowController(store: store)
        #expect(!controller.interceptQuit())

        showAlert(store, env: env)
        #expect(await eventually { controller.isShowing })
        #expect(controller.interceptQuit())
        #expect(await eventually { store.alert == nil })
        #expect(!controller.interceptQuit())
    }

    @Test func presentedWindowOpensAndClosesWithState() async throws {
        let env = TestEnvironment(now: "2026-11-03 10:00")
        let store = makeStore(env)
        let controller = PresentedWindowController(
            title: "Hey You!",
            size: CGSize(width: 480, height: 620),
            isPresented: { store.onboarding != nil },
            makeContent: { AnyView(Text(verbatim: "Onboarding")) },
            onClose: { store.send(.onboarding(.dismiss)) }
        )
        #expect(controller.nsWindow == nil)

        store.send(.menuBar(.connectGoogle))
        #expect(await eventually { controller.nsWindow != nil })
        let window = try #require(controller.nsWindow)
        #expect(window.title == "Hey You!")
        #expect(window.frame.size.width == 480)

        // Closing the window dismisses the state.
        window.performClose(nil)
        #expect(await eventually { store.onboarding == nil })
        #expect(controller.nsWindow == nil)

        // Dismissing the state closes the window.
        store.send(.menuBar(.connectGoogle))
        #expect(await eventually { controller.nsWindow != nil })
        store.send(.onboarding(.dismiss))
        #expect(await eventually { controller.nsWindow == nil })
    }
}
