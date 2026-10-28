import AppKit

/// What a key press does while the alert is visible.
public enum AlertInput: Equatable, Sendable {
    case join
    case dismiss(DismissReason)

    /// Return/Enter join; Esc dismisses as `escape`; ⌘Q, ⌘W and ⌘. as `quit_shortcut`; anything else as `key`.
    public static func forKey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, characters: String?) -> AlertInput {
        let returnKey: UInt16 = 36
        let keypadEnter: UInt16 = 76
        let escape: UInt16 = 53
        let flags = modifiers.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command), let key = characters?.lowercased(), ["q", "w", "."].contains(key) {
            return .dismiss(.quitShortcut)
        }
        switch keyCode {
        case returnKey, keypadEnter:
            return flags.isDisjoint(with: [.command, .option, .control]) ? .join : .dismiss(.key)
        case escape:
            return .dismiss(.escape)
        default:
            return .dismiss(.key)
        }
    }
}
