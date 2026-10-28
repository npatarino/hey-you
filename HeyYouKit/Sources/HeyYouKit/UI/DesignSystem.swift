import AppKit
import SwiftUI

/// Colors of the alert. Fixed red theme, independent of light/dark mode.
public extension Color {
    /// #E0263A, gradient center.
    static let alertRed = Color(red: 224 / 255, green: 38 / 255, blue: 58 / 255)
    /// #B5121F, reference for contrast (white on it is 6.5:1).
    static let alertCrimson = Color(red: 181 / 255, green: 18 / 255, blue: 31 / 255)
    /// #8E0F1E, gradient edges.
    static let alertDeep = Color(red: 142 / 255, green: 15 / 255, blue: 30 / 255)
}

/// White pill used for "Join meeting".
public struct PillButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundStyle(Color.alertCrimson)
            .padding(.horizontal, 36)
            .frame(height: 56)
            .background(Capsule().fill(.white.opacity(configuration.isPressed ? 0.85 : 1)))
            .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

/// "Sign in with Google" following Google's branding guidelines: white, #747775 1 pt border,
/// 4 pt radius, 40 pt tall, the official multicolor "G" at 20×20 and #1F1F1F label in 14 pt medium.
public struct GoogleSignInButton: View {
    let isLoading: Bool
    let action: () -> Void
    @State private var isHovering = false

    public init(isLoading: Bool = false, action: @escaping () -> Void) {
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView().controlSize(.small).frame(width: 20, height: 20)
                } else {
                    GoogleLogo().frame(width: 20, height: 20)
                }
                Text("Sign in with Google", bundle: .module)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(red: 31 / 255, green: 31 / 255, blue: 31 / 255))
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
        }
        .buttonStyle(GoogleButtonStyle(isHovering: isHovering))
        .onHover { isHovering = $0 }
        .disabled(isLoading)
        .accessibilityLabel(Text("Sign in with Google", bundle: .module))
    }
}

private struct GoogleButtonStyle: ButtonStyle {
    let isHovering: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(red: 48 / 255, green: 48 / 255, blue: 48 / 255)
                                .opacity(configuration.isPressed ? 0.12 : isHovering ? 0.08 : 0))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color(red: 116 / 255, green: 119 / 255, blue: 117 / 255), lineWidth: 1)
            )
    }
}

/// The official Google "G" shipped with the GoogleSignIn SDK.
struct GoogleLogo: View {
    var body: some View {
        if let image = Bundle.module.image(forResource: "google_g") {
            Image(nsImage: image).resizable().interpolation(.high).accessibilityHidden(true)
        } else {
            Text(verbatim: "G").font(.system(size: 16, weight: .bold))
        }
    }
}

/// Wraps a Pro control: free users see it disabled with a lock; the lock opens the paywall.
public struct ProGated: ViewModifier {
    let isPro: Bool
    let onLockTap: () -> Void

    public func body(content: Content) -> some View {
        if isPro {
            content
        } else {
            HStack {
                content.disabled(true)
                Button(action: onLockTap) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(Text("Unlock with Hey You! Pro", bundle: .module))
                }
                .buttonStyle(.borderless)
                .help(Text("Unlock with Hey You! Pro", bundle: .module))
            }
        }
    }
}

public extension View {
    func proGated(isPro: Bool, onLockTap: @escaping () -> Void) -> some View {
        modifier(ProGated(isPro: isPro, onLockTap: onLockTap))
    }
}

/// Time formatting shared by the alert and the menu.
enum TimeText {
    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func range(_ start: Date, _ end: Date) -> String {
        "\(time(start)) – \(time(end))"
    }
}
