import AppKit
import ComposableArchitecture
import SwiftUI

/// Shows `AlertView` on every screen while `AppFeature.State.alert` is set.
///
/// Each screen gets a borderless, non-activating panel at screen-saver level that joins all Spaces and
/// sits above full-screen apps. Non-activating panels can take keyboard focus without activating the app,
/// so keys reach the alert even when another app is frontmost. While visible, a local event monitor
/// turns every key and secondary click into a dismissal (Return joins) and swallows ⌘Q / ⌘W / ⌘.
@MainActor
public final class AlertWindowController: NSObject {
    private let store: StoreOf<AppFeature>
    private var panels: [AlertPanel] = []
    private var monitor: Any?
    private var tokens: [ObserveToken] = []
    private var screenObserver: (any NSObjectProtocol)?

    public private(set) var isShowing = false

    public init(store: StoreOf<AppFeature>) {
        self.store = store
        super.init()
        tokens.append(observe { [weak self] in
            guard let self else { return }
            let wantsAlert = self.store.alert != nil
            if wantsAlert, !isShowing {
                show(animated: true)
            } else if !wantsAlert, isShowing {
                hide()
            }
        })
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.screensChanged() }
        }
    }

    private func show(animated: Bool) {
        guard let alertStore = store.scope(state: \.alert, action: \.alert.presented) else { return }
        closePanels()
        isShowing = true
        let mouseScreen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }
        for screen in NSScreen.screens {
            let panel = AlertPanel(screen: screen)
            panel.contentView = FirstMouseHostingView(rootView: AlertView(store: alertStore))
            panel.alphaValue = animated ? 0 : 1
            panels.append(panel)
            if screen == (mouseScreen ?? NSScreen.main) {
                panel.makeKeyAndOrderFront(nil)
            } else {
                panel.orderFrontRegardless()
            }
        }
        NSApplication.shared.activate()
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                for panel in panels {
                    panel.animator().alphaValue = 1
                }
            }
        }
        installMonitor()
    }

    private func hide() {
        isShowing = false
        removeMonitor()
        let closing = panels
        panels = []
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            for panel in closing {
                panel.animator().alphaValue = 0
            }
        } completionHandler: {
            MainActor.assumeIsolated {
                for panel in closing {
                    panel.orderOut(nil)
                    panel.contentView = nil
                }
            }
        }
    }

    private func closePanels() {
        for panel in panels {
            panel.orderOut(nil)
            panel.contentView = nil
        }
        panels = []
    }

    private func screensChanged() {
        guard isShowing else { return }
        removeMonitor()
        show(animated: false)
    }

    // MARK: - Input

    private func installMonitor() {
        removeMonitor()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            let input: AlertInput = event.type == .keyDown
                ? AlertInput.forKey(keyCode: event.keyCode, modifiers: event.modifierFlags, characters: event.charactersIgnoringModifiers)
                : .dismiss(.click)
            let consumed = MainActor.assumeIsolated { self?.consume(input) ?? false }
            return consumed ? nil : event
        }
    }

    /// Panels currently on screen (one per display).
    var visiblePanels: [NSPanel] {
        panels
    }

    private func consume(_ input: AlertInput) -> Bool {
        guard isShowing else { return false }
        handle(input)
        return true
    }

    private func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    func handle(_ input: AlertInput) {
        switch input {
        case .join:
            store.send(.alert(.presented(.joinTapped)))
        case let .dismiss(reason):
            store.send(.alert(.presented(.dismissed(reason))))
        }
    }

    /// Called by the app delegate for ⌘Q / "Quit": with an alert visible, quitting only dismisses it.
    public func interceptQuit() -> Bool {
        guard store.alert != nil else { return false }
        store.send(.alert(.presented(.dismissed(.quitShortcut))))
        return true
    }
}

/// Borderless panel covering one screen.
final class AlertPanel: NSPanel {
    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        setFrame(screen.frame, display: false)
        // Must come before `level`: setting isFloatingPanel resets the level to .floating.
        isFloatingPanel = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isMovable = false
        isReleasedWhenClosed = false
        becomesKeyOnlyIfNeeded = false
        animationBehavior = .none
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }
}

/// Lets the first click on a non-key screen reach SwiftUI (Join button, background tap).
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
