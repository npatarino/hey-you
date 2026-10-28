import AppKit
import ComposableArchitecture
import HeyYouKit
import SwiftUI

/// Owns the root store, the alert windows and the onboarding/paywall windows.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store: StoreOf<AppFeature> = AppDelegate.makeStore()
    private var alertWindows: AlertWindowController?
    private var onboardingWindow: PresentedWindowController?
    private var paywallWindow: PresentedWindowController?

    private static func makeStore() -> StoreOf<AppFeature> {
        #if DEBUG
            // `--mock-calendar`: fake Google account and calendar (a meeting 90 s after launch).
            if ProcessInfo.processInfo.arguments.contains("--mock-calendar") {
                return Store(initialState: AppFeature.State()) {
                    AppFeature()
                } withDependencies: {
                    $0.calendarClient = .mock()
                    $0.authClient = .mock
                }
            }
        #endif
        return Store(initialState: AppFeature.State()) { AppFeature() }
    }

    func applicationDidFinishLaunching(_: Notification) {
        let store = store
        alertWindows = AlertWindowController(store: store)
        onboardingWindow = PresentedWindowController(
            title: "Hey You!",
            size: CGSize(width: 480, height: 620),
            isPresented: { store.onboarding != nil },
            makeContent: {
                store.scope(state: \.onboarding, action: \.onboarding.presented).map { AnyView(OnboardingView(store: $0)) }
            },
            onClose: { store.send(.onboarding(.dismiss)) }
        )
        paywallWindow = PresentedWindowController(
            title: "Hey You! Pro",
            size: CGSize(width: 420, height: 560),
            isPresented: { store.paywall != nil },
            makeContent: {
                store.scope(state: \.paywall, action: \.paywall.presented).map { AnyView(PaywallView(store: $0)) }
            },
            onClose: { store.send(.paywall(.dismiss)) }
        )
        store.send(.task)
    }

    /// With an alert on screen, ⌘Q only dismisses it (PRD §5.4).
    func applicationShouldTerminate(_: NSApplication) -> NSApplication.TerminateReply {
        alertWindows?.interceptQuit() == true ? .terminateCancel : .terminateNow
    }

    func application(_: NSApplication, open urls: [URL]) {
        for url in urls {
            GoogleAuthURLHandler.handle(url)
        }
    }
}
