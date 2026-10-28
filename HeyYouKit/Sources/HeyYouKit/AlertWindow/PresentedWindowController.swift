import AppKit
import ComposableArchitecture
import SwiftUI

/// Opens a regular window while a piece of presentation state is non-nil (onboarding, paywall)
/// and dismisses that state when the user closes the window.
@MainActor
public final class PresentedWindowController: NSObject, NSWindowDelegate {
    private let isPresented: @MainActor () -> Bool
    private let makeContent: @MainActor () -> AnyView?
    private let onClose: @MainActor () -> Void
    private let title: String
    private let size: CGSize
    private var window: NSWindow?
    private var tokens: [ObserveToken] = []

    public init(
        title: String,
        size: CGSize,
        isPresented: @escaping @MainActor () -> Bool,
        makeContent: @escaping @MainActor () -> AnyView?,
        onClose: @escaping @MainActor () -> Void
    ) {
        self.title = title
        self.size = size
        self.isPresented = isPresented
        self.makeContent = makeContent
        self.onClose = onClose
        super.init()
        tokens.append(observe { [weak self] in
            guard let self else { return }
            if self.isPresented() {
                present()
            } else {
                close()
            }
        })
    }

    private func present() {
        guard window == nil, let content = makeContent() else { return }
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: content.frame(width: size.width, height: size.height))
        window.center()
        window.delegate = self
        window.level = .floating
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func close() {
        guard let window else { return }
        self.window = nil
        window.delegate = nil
        window.close()
    }

    public func windowWillClose(_: Notification) {
        window = nil
        if isPresented() {
            onClose()
        }
    }

    /// The window that anchors Google's sign-in sheet.
    public var nsWindow: NSWindow? {
        window
    }
}
