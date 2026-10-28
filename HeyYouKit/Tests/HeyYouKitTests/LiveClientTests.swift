import AppKit
import Foundation
import GoogleSignIn
@testable import HeyYouKit
import Testing

struct OtherClientTests {
    @Test func mocks() async throws {
        let store = StoreClient.mock(isPro: false)
        #expect(await store.currentEntitlements().isPro == false)
        #expect(try await store.products().first?.id == AppConfig.proProductID)
        guard case let .success(entitlements) = try await store.purchase(AppConfig.proProductID) else {
            Issue.record("mock purchase failed")
            return
        }
        #expect(entitlements.isPro)
        #expect(try await store.restore().isPro)

        let auth = AuthClient.mock
        #expect(await auth.restorePreviousSignIn()?.email == "demo@example.com")
        #expect(try await auth.signIn().email == "demo@example.com")
        #expect(try await auth.accessToken() == "mock-token")

        let launch = LaunchAtLoginClient.mock()
        #expect(launch.status() == .disabled)
        #expect(try launch.set(true) == .enabled)
        #expect(launch.status() == .enabled)
    }

    /// The live workspace client turns system wake notifications into events.
    @MainActor
    @Test func wakeNotifications() async {
        let stream = WorkspaceClient.liveValue.wakeNotifications()
        let received = Task {
            var iterator = stream.makeAsyncIterator()
            return await iterator.next() != nil
        }
        // Give the observer time to subscribe, then post.
        let center = NSWorkspace.shared.notificationCenter
        for _ in 0 ..< 50 {
            try? await Task.sleep(for: .milliseconds(20))
            center.post(name: NSWorkspace.didWakeNotification, object: nil)
        }
        #expect(await received.value)
    }
}

/// Google sign-in wrapper paths that don't need a browser.
@MainActor
struct GoogleSignInServiceTests {
    @Test func withoutClientIDNothingHappens() async {
        // The test bundle has no GIDClientID: sign-in must fail clearly, restore must be a no-op.
        #expect(AppConfig.googleClientID == nil)
        #expect(await GoogleSignInService.restore() == nil)
        await #expect(throws: AuthError.notConfigured) {
            try await GoogleSignInService.interactiveSignIn()
        }
        await #expect(throws: AuthError.notSignedIn) {
            try await GoogleSignInService.accessToken()
        }
        #expect(!GoogleAuthURLHandler.handle(AppConfig.projectURL))
    }

    @Test func errorMapping() {
        func error(_ code: GIDSignInError.Code) -> NSError {
            NSError(domain: kGIDSignInErrorDomain, code: code.rawValue)
        }
        #expect(GoogleSignInService.mapError(error(.canceled)) == .cancelled)
        #expect(GoogleSignInService.mapError(error(.hasNoAuthInKeychain)) == .notSignedIn)
        #expect(GoogleSignInService.mapError(error(.keychain)) == .keychain)
        #expect(GoogleSignInService.mapError(error(.EMM)) == .failed(code: GIDSignInError.Code.EMM.rawValue))
        #expect(GoogleSignInService.mapError(NSError(domain: "other", code: 7)) == .failed(code: 7))
        #expect(GoogleSignInService.mapError(nil) == .failed(code: 0))
    }
}
