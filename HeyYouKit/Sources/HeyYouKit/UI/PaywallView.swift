import ComposableArchitecture
import SwiftUI

/// "Hey You! Pro" (420×560): benefits, localized price from StoreKit, buy, restore.
public struct PaywallView: View {
    let store: StoreOf<PaywallFeature>

    public init(store: StoreOf<PaywallFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(verbatim: "Hey You! Pro").font(.system(size: 28, weight: .bold, design: .rounded))
                Spacer()
                Button { store.send(.closeTapped) } label: {
                    Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel(Text("Close", bundle: .module))
            }
            Text("You decide when and for what we alert you.", bundle: .module)
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                benefit(String(localized: "Alert from 10 to 60 seconds before", bundle: .module))
                benefit(String(localized: "Skip meetings you declined", bundle: .module))
                benefit(String(localized: "Only meetings with a video link", bundle: .module))
                benefit(String(localized: "Skip focus blocks (just you)", bundle: .module))
                benefit(String(localized: "Choose calendars · working hours", bundle: .module))
                benefit(String(localized: "Sound · weekly punctuality stats", bundle: .module))
                benefit(String(localized: "Countdown in the menu bar", bundle: .module))
            }
            .padding(.vertical, 8)

            Spacer()

            if let message = store.message {
                Text(verbatim: message).font(.callout).foregroundStyle(.secondary)
            }

            Button { store.send(.purchaseTapped) } label: {
                HStack {
                    if store.isPurchasing {
                        ProgressView().controlSize(.small)
                    }
                    if let product = store.product {
                        Text("Buy for \(product.displayPrice) · one time", bundle: .module)
                    } else {
                        Text("Buy", bundle: .module)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 32)
            }
            .buttonStyle(.borderedProminent)
            .tint(.alertCrimson)
            .controlSize(.large)
            .disabled(store.product == nil || store.isBusy)

            HStack {
                Button { store.send(.restoreTapped) } label: { Text("Restore purchase", bundle: .module) }
                    .buttonStyle(.link)
                    .disabled(store.isBusy)
                Spacer()
                Link(destination: AppConfig.termsURL) { Text("Terms", bundle: .module) }
                Link(destination: AppConfig.privacyURL) { Text("Privacy", bundle: .module) }
            }
            .font(.callout)
        }
        .padding(28)
        .task { store.send(.task) }
    }

    private func benefit(_ text: String) -> some View {
        Label {
            Text(verbatim: text)
        } icon: {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.alertCrimson)
        }
        .font(.body)
    }
}

#Preview {
    PaywallView(store: Store(initialState: PaywallFeature.State(source: .menu)) { PaywallFeature() })
        .frame(width: 420, height: 560)
}
