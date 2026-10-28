import ComposableArchitecture
import SwiftUI

/// Single welcome window (480×620). Never mentions Pro.
public struct OnboardingView: View {
    let store: StoreOf<OnboardingFeature>

    public init(store: StoreOf<OnboardingFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 12)
            ZStack {
                Circle().fill(LinearGradient(colors: [.alertRed, .alertDeep], startPoint: .top, endPoint: .bottom))
                Image(systemName: "bell.fill").font(.system(size: 40, weight: .bold)).foregroundStyle(.white)
            }
            .frame(width: 88, height: 88)
            .accessibilityHidden(true)

            Text(verbatim: "Hey You!").font(.system(size: 34, weight: .bold, design: .rounded))

            VStack(spacing: 6) {
                Text("One minute before every meeting, your whole screen turns red.", bundle: .module)
                Text("It doesn't lock you out. It just can't be ignored.", bundle: .module)
                    .foregroundStyle(.secondary)
            }
            .font(.title3)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            switch store.step {
            case .welcome:
                welcome
            case let .connected(account):
                connected(account)
            }
            Spacer(minLength: 12)
        }
        .padding(32)
        .task { store.send(.task) }
    }

    private var welcome: some View {
        VStack(spacing: 14) {
            GoogleSignInButton(isLoading: store.isSigningIn) { store.send(.signInTapped) }
            Text("Read-only · your calendar never leaves your Mac", bundle: .module)
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let error = store.errorMessage {
                Text(verbatim: error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            consentToggles.padding(.top, 8)
        }
    }

    private func connected(_ account: GoogleAccount) -> some View {
        VStack(spacing: 14) {
            Label {
                Text("Connected as \(account.email)", bundle: .module)
            } icon: {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
            Toggle(isOn: Binding(get: { store.launchAtLogin == .enabled }, set: { store.send(.setLaunchAtLogin($0)) })) {
                Text("Open at login (recommended)", bundle: .module)
            }
            .toggleStyle(.switch)
            HStack {
                Button { store.send(.testAlertTapped) } label: { Text("Test the alert", bundle: .module) }
                    .buttonStyle(.borderedProminent)
                    .tint(.alertCrimson)
                Button { store.send(.doneTapped) } label: { Text("Done", bundle: .module) }
                    .keyboardShortcut(.defaultAction)
            }
            consentToggles.padding(.top, 8)
        }
    }

    private var consentToggles: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(get: { store.consent.usageAnalytics }, set: { store.send(.setUsageConsent($0)) })) {
                VStack(alignment: .leading) {
                    Text("Share anonymous usage statistics", bundle: .module)
                    Text("Never the content of your calendar.", bundle: .module).font(.caption).foregroundStyle(.secondary)
                }
            }
            Toggle(isOn: Binding(get: { store.consent.emailContact }, set: { store.send(.setEmailConsent($0)) })) {
                Text("Email me about new features", bundle: .module)
            }
        }
        .toggleStyle(.checkbox)
        .frame(maxWidth: 360, alignment: .leading)
    }
}

#Preview {
    OnboardingView(store: Store(initialState: OnboardingFeature.State()) { OnboardingFeature() })
        .frame(width: 480, height: 620)
}
