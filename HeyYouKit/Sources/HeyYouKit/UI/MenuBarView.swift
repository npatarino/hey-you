import ComposableArchitecture
import SwiftUI

/// Label of the status item: bell (or bell.slash) plus "Xm" for Pro.
public struct MenuBarLabel: View {
    let store: StoreOf<AppFeature>

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        // No TimelineView here: inside a MenuBarExtra label it makes SwiftUI re-render in a loop.
        // `store.now` is refreshed every 15 s by AppFeature instead.
        let menu = MenuBarFeature.state(from: store.state, now: store.now, calendar: .current)
        HStack(spacing: 3) {
            Image(systemName: menu.iconName)
            if let countdown = menu.countdown {
                Text(verbatim: countdown).monospacedDigit()
            }
        }
        .accessibilityLabel(Text(verbatim: "Hey You!"))
    }
}

/// Content of the menu-bar window: status, today's next meetings and actions.
public struct MenuBarView: View {
    let store: StoreOf<AppFeature>
    @Environment(\.openSettings) private var openSettings

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        let menu = MenuBarFeature.state(from: store.state, now: store.now, calendar: .current)
        VStack(alignment: .leading, spacing: 0) {
            header(menu)
            Divider().padding(.vertical, 6)
            if menu.rows.isEmpty {
                Text("No more meetings today", bundle: .module)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            } else {
                ForEach(menu.rows) { row in
                    EventRow(row: row)
                }
            }
            Divider().padding(.vertical, 6)
            punctuality(menu)
            actions(menu)
        }
        .padding(.vertical, 8)
        .frame(width: 320)
    }

    private func header(_ menu: MenuBarFeature.State) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: "Hey You!").font(.headline)
            Text(verbatim: menu.statusText())
                .font(.callout)
                .foregroundStyle(color(menu.statusTone))
            if menu.canConnect {
                Button {
                    store.send(.menuBar(.connectGoogle))
                } label: {
                    Text(verbatim: menu.connectTitle)
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private func punctuality(_ menu: MenuBarFeature.State) -> some View {
        if let punctuality = menu.punctualityText {
            Text(verbatim: punctuality)
                .font(.callout)
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
        } else if !menu.isPro {
            MenuButton(title: String(localized: "Punctuality stats · Pro", bundle: .module), systemImage: "chart.bar") {
                store.send(.menuBar(.statsTapped))
            }
        }
    }

    @ViewBuilder
    private func actions(_ menu: MenuBarFeature.State) -> some View {
        MenuButton(title: String(localized: "Test alert", bundle: .module), systemImage: "bell.badge") {
            store.send(.menuBar(.testAlert))
        }
        MenuButton(title: String(localized: "Refresh now", bundle: .module), systemImage: "arrow.clockwise") {
            store.send(.menuBar(.refreshNow))
        }
        if menu.showsProEntry {
            MenuButton(title: String(localized: "Hey You! Pro…", bundle: .module), systemImage: "star") {
                store.send(.menuBar(.openPaywall))
            }
        }
        MenuButton(title: String(localized: "Settings…", bundle: .module), systemImage: "gearshape") {
            openSettings()
            NSApp.activate()
        }
        Divider().padding(.vertical, 6)
        MenuButton(title: String(localized: "Quit Hey You!", bundle: .module), systemImage: "power") {
            store.send(.menuBar(.quit))
        }
    }

    private func color(_ tone: MenuBarFeature.State.Tone) -> Color {
        switch tone {
        case .normal: .secondary
        case .warning: .orange
        case .error: .red
        }
    }
}

private struct EventRow: View {
    let row: MenuBarFeature.Row

    var body: some View {
        HStack(spacing: 8) {
            Text(verbatim: TimeText.time(row.event.start))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
            Text(verbatim: row.event.title)
                .lineLimit(1)
                .strikethrough(row.event.attendeeStatus == .declined)
            Spacer(minLength: 4)
            if row.isOutsideWorkingHours {
                Label {
                    Text("Outside hours", bundle: .module)
                } icon: {
                    Image(systemName: "moon.fill")
                }
                .labelStyle(.iconOnly)
                .help(Text("Outside working hours: no alert", bundle: .module))
            }
            providerBadge
        }
        .font(.callout)
        .opacity(row.isFiltered || row.isOutsideWorkingHours ? 0.45 : 1)
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
    }

    @ViewBuilder private var providerBadge: some View {
        if let provider = row.event.meetingLink?.provider {
            Text(verbatim: provider.displayName)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(.quaternary))
        } else {
            Text("No link", bundle: .module)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct MenuButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 4).fill(isHovering ? Color.accentColor.opacity(0.15) : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .onHover { isHovering = $0 }
    }
}

#Preview {
    MenuBarView(store: Store(initialState: {
        var state = AppFeature.State()
        state.auth = .signedIn(GoogleAccount(email: "demo@example.com"))
        state.events = IdentifiedArray(uniqueElements: MockCalendar.events(relativeTo: .now))
        state.calendars = MockCalendar.calendars
        return state
    }()) {
        AppFeature()
    })
}
