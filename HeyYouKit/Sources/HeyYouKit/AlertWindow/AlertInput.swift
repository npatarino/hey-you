import AppKit

/// What a key press does while the alert is visible.
public enum AlertInput: Equatable, Sendable {
    case join
    case dismiss(DismissReason)
    /// Not a deliberate "close this" key (letters, space, arrows, other shortcuts): swallowed, alert stays.
    case ignore

    /// Only deliberate keys act: Return/Enter join, Esc dismisses, ⌘Q / ⌘W / ⌘. dismiss as `quit_shortcut`.
    /// Everything else is ignored, so typing that was already in progress can't make the alert vanish unseen.
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
            return flags.isDisjoint(with: [.command, .option, .control]) ? .join : .ignore
        case escape:
            return .dismiss(.escape)
        default:
            return .ignore
        }
    }
}
