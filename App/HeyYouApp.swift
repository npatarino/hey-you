import ComposableArchitecture
import HeyYouKit
import SwiftUI

/// Wiring only: the menu-bar item and the Settings window. Everything else lives in HeyYouKit.
@main
struct HeyYouApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(store: appDelegate.store)
        } label: {
            MenuBarLabel(store: appDelegate.store)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(store: appDelegate.store.scope(state: \.settingsScreen, action: \.settingsScreen))
        }
    }
}
