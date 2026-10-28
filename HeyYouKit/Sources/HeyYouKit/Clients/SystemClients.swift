import AppKit
import Dependencies
import DependenciesMacros
import Foundation
import ServiceManagement

// MARK: - Launch at login

public enum LaunchAtLoginStatus: Equatable, Sendable {
    case enabled
    case disabled
    /// The user must allow it in System Settings → General → Login Items.
    case requiresApproval
}

/// `SMAppService.mainApp`, opt-in from Settings or onboarding.
@DependencyClient
public struct LaunchAtLoginClient: Sendable {
    public var status: @Sendable () -> LaunchAtLoginStatus = { .disabled }
    public var set: @Sendable (_ enabled: Bool) throws -> LaunchAtLoginStatus
    public var openSystemSettings: @Sendable () -> Void
}

extension LaunchAtLoginClient: DependencyKey {
    public static let liveValue = Self(
        status: { map(SMAppService.mainApp.status) },
        set: { enabled in
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return map(SMAppService.mainApp.status)
        },
        openSystemSettings: { SMAppService.openSystemSettingsLoginItems() }
    )

    public static let previewValue = Self.mock()

    public static func mock(initial: LaunchAtLoginStatus = .disabled) -> Self {
        let state = LockIsolated(initial)
        return Self(
            status: { state.value },
            set: { enabled in
                state.setValue(enabled ? .enabled : .disabled)
                return state.value
            },
            openSystemSettings: {}
        )
    }

    private static func map(_ status: SMAppService.Status) -> LaunchAtLoginStatus {
        switch status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        default: .disabled
        }
    }
}

// MARK: - Workspace

/// System sleep/wake.
@DependencyClient
public struct WorkspaceClient: Sendable {
    /// Emits when the Mac or its screens wake up.
    public var wakeNotifications: @Sendable () -> AsyncStream<Void> = { .finished }
}

extension WorkspaceClient: DependencyKey {
    public static let liveValue = Self(
        wakeNotifications: {
            AsyncStream { continuation in
                let task = Task {
                    let center = await MainActor.run { NSWorkspace.shared.notificationCenter }
                    await withTaskGroup(of: Void.self) { group in
                        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
                            group.addTask {
                                for await _ in center.notifications(named: name) {
                                    continuation.yield()
                                }
                            }
                        }
                    }
                    continuation.finish()
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
    )

    public static let previewValue = Self(wakeNotifications: { .finished })
}

// MARK: - Sound

/// Plays the alert sound once.
@DependencyClient
public struct SoundClient: Sendable {
    public var play: @Sendable (_ sound: AlertSound) async -> Void
}

extension SoundClient: DependencyKey {
    public static let liveValue = Self(
        play: { sound in
            guard let name = sound.systemSoundName else { return }
            await MainActor.run {
                _ = NSSound(named: NSSound.Name(name))?.play()
            }
        }
    )

    public static let previewValue = Self(play: { _ in })
}

// MARK: - Screens and app

/// Screen count and app lifecycle.
@DependencyClient
public struct ApplicationClient: Sendable {
    public var screensCount: @Sendable () async -> Int = { 1 }
    public var terminate: @Sendable () async -> Void
}

extension ApplicationClient: DependencyKey {
    public static let liveValue = Self(
        screensCount: { await MainActor.run { NSScreen.screens.count } },
        terminate: { await MainActor.run { NSApp.terminate(nil) } }
    )

    public static let previewValue = Self(screensCount: { 1 }, terminate: {})
}

public extension DependencyValues {
    var launchAtLoginClient: LaunchAtLoginClient {
        get { self[LaunchAtLoginClient.self] }
        set { self[LaunchAtLoginClient.self] = newValue }
    }

    var workspaceClient: WorkspaceClient {
        get { self[WorkspaceClient.self] }
        set { self[WorkspaceClient.self] = newValue }
    }

    var soundClient: SoundClient {
        get { self[SoundClient.self] }
        set { self[SoundClient.self] = newValue }
    }

    var applicationClient: ApplicationClient {
        get { self[ApplicationClient.self] }
        set { self[ApplicationClient.self] = newValue }
    }
}
