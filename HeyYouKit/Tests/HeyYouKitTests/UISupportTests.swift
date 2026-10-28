import AppKit
@testable import HeyYouKit
import Testing

struct AlertInputTests {
    /// PRD B.2 / B.3 key handling.
    static let command = NSEvent.ModifierFlags.command.rawValue
    static let shift = NSEvent.ModifierFlags.shift.rawValue

    /// PRD B.2 / B.3 key handling.
    @Test(arguments: [
        (UInt16(36), UInt(0), "\r", AlertInput.join),
        (76, 0, "\u{3}", .join),
        (53, 0, "\u{1b}", .dismiss(.escape)),
        (38, 0, "j", .dismiss(.key)),
        (49, 0, " ", .dismiss(.key)),
        (12, command, "q", .dismiss(.quitShortcut)),
        (12, command | shift, "Q", .dismiss(.quitShortcut)),
        (13, command, "w", .dismiss(.quitShortcut)),
        (47, command, ".", .dismiss(.quitShortcut)),
        (8, command, "c", .dismiss(.key)),
        (36, command, "\r", .dismiss(.key)),
        (36, shift, "\r", .join),
    ])
    func mapping(keyCode: UInt16, modifiers: UInt, characters: String, expected: AlertInput) {
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        #expect(AlertInput.forKey(keyCode: keyCode, modifiers: flags, characters: characters) == expected)
    }

    @Test func missingCharacters() {
        #expect(AlertInput.forKey(keyCode: 12, modifiers: [.command], characters: nil) == .dismiss(.key))
    }
}

struct LocalizationTests {
    var kitBundle: Bundle {
        // Bundle.module of the test target is not the library's; find the library resource bundle.
        let candidates = [Bundle.main.resourceURL, Bundle(for: BundleToken.self).resourceURL]
            .compactMap { $0 }
            .flatMap { [$0, $0.deletingLastPathComponent()] }
        for url in candidates {
            if let bundle = Bundle(url: url.appendingPathComponent("HeyYouKit_HeyYouKit.bundle")) {
                return bundle
            }
        }
        return Bundle.main
    }

    func localized(_ key: String, language: String) -> String {
        guard let path = kitBundle.path(forResource: language, ofType: "lproj"), let bundle = Bundle(path: path) else {
            return "<no \(language).lproj>"
        }
        return bundle.localizedString(forKey: key, value: "<missing>", table: nil)
    }

    @Test(arguments: [
        ("MEETING IN", "REUNIÓN EN"),
        ("NOW", "AHORA"),
        ("Click anywhere or press any key to dismiss", "Haz clic o pulsa cualquier tecla para descartar"),
        ("Join meeting", "Unirse a la reunión"),
        ("Declined · With Pro we wouldn't have alerted you", "Rechazada · Con Pro no te habríamos avisado"),
    ])
    func spanishStrings(key: String, expected: String) {
        #expect(localized(key, language: "es") == expected)
    }

    @Test func spanishFormat() {
        let format = localized("STARTED %lld MIN AGO", language: "es")
        #expect(String(format: format, 3) == "EMPEZÓ HACE 3 MIN")
    }
}

private final class BundleToken {}

@MainActor
struct AlertPanelTests {
    /// Regression: `isFloatingPanel` used to reset the level to floating (3) after it was set.
    @Test func panelSitsAboveEverything() throws {
        let screen = try #require(NSScreen.screens.first)
        let panel = AlertPanel(screen: screen)
        #expect(panel.level == .screenSaver)
        #expect(panel.collectionBehavior.contains(.canJoinAllSpaces))
        #expect(panel.collectionBehavior.contains(.fullScreenAuxiliary))
        #expect(panel.collectionBehavior.contains(.stationary))
        #expect(panel.styleMask.contains(.nonactivatingPanel))
        #expect(panel.canBecomeKey)
        #expect(!panel.hidesOnDeactivate)
        #expect(panel.frame == screen.frame)
    }
}
