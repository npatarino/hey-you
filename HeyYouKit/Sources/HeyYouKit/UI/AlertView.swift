import ComposableArchitecture
import SwiftUI

/// The red full-screen alert (PLAN §6). Shown on every screen by `AlertWindowController`.
public struct AlertView: View {
    let store: StoreOf<AlertFeature>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared: Bool

    public init(store: StoreOf<AlertFeature>) {
        self.init(store: store, animateEntrance: true)
    }

    /// `animateEntrance: false` renders the final state directly (snapshots).
    init(store: StoreOf<AlertFeature>, animateEntrance: Bool) {
        self.store = store
        _appeared = State(initialValue: !animateEntrance)
    }

    public var body: some View {
        ZStack {
            background
                .contentShape(Rectangle())
                .onTapGesture { store.send(.dismissed(.click)) }
            content
                .frame(maxWidth: 720)
                .padding(48)
                .scaleEffect(appeared || reduceMotion ? 1 : 0.96)
                .opacity(appeared || reduceMotion ? 1 : 0)
        }
        .ignoresSafeArea()
        .task { await store.send(.task).finish() }
        .onAppear {
            withAnimation(.spring(duration: 0.35)) { appeared = true }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private var background: some View {
        GeometryReader { proxy in
            let radius = max(proxy.size.width, proxy.size.height) * 0.75
            ZStack {
                RadialGradient(colors: [.alertRed, .alertDeep], center: .center, startRadius: 0, endRadius: radius)
                if !reduceMotion {
                    PulseRing(diameter: min(proxy.size.width, proxy.size.height) * 0.9)
                }
            }
        }
    }

    private var content: some View {
        VStack(spacing: 24) {
            Text(verbatim: store.state.headline)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .tracking(4)
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)

            CountdownRing(
                phase: store.phase, progress: store.progress,
                accessibilityText: store.state.countdownAccessibilityLabel, reduceMotion: reduceMotion
            )
            .frame(width: 300, height: 300)

            VStack(spacing: 10) {
                Text(store.event.title)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                if let additional = store.state.additionalText {
                    Text(verbatim: additional)
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                }
                if let hook = store.state.hookText {
                    Label(hook, systemImage: "lock.fill")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                }
            }

            Label(store.state.metaLine(), systemImage: "video.fill")
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundStyle(.white)

            Button {
                store.send(.joinTapped)
            } label: {
                Label {
                    Text(verbatim: store.state.actionTitle)
                } icon: {
                    Image(systemName: "arrow.right")
                }
                .labelStyle(TrailingIconLabelStyle())
            }
            .buttonStyle(PillButtonStyle())
            .keyboardShortcut(.defaultAction)
            .padding(.top, 8)

            Text("Click anywhere or press any key to dismiss", bundle: .module)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, 12)
        }
    }
}

/// Big number with a progress ring; "NOW" pulses gently during the first minute.
struct CountdownRing: View {
    let phase: AlertPhase
    let progress: Double
    let accessibilityText: String
    let reduceMotion: Bool
    @State private var pulsing = false

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.2), lineWidth: 10)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .linear(duration: 1), value: progress)
            number
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: accessibilityText))
    }

    @ViewBuilder private var number: some View {
        switch phase {
        case let .countingDown(seconds):
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(verbatim: "\(seconds)")
                    .font(.system(size: 150, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                Text(verbatim: "s").font(.system(size: 48, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(.white)
            .minimumScaleFactor(0.4)
            .lineLimit(1)
            .padding(.horizontal, 36)
        case .startingNow:
            Text("NOW", bundle: .module)
                .font(.system(size: 120, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.4)
                .scaleEffect(pulsing ? 1.08 : 1)
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { pulsing = true }
                }
        case let .started(minutes):
            Text(verbatim: "\(minutes)")
                .font(.system(size: 180, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .minimumScaleFactor(0.4)
        }
    }
}

/// Concentric circle that grows and fades every 1.2 s.
struct PulseRing: View {
    let diameter: CGFloat
    @State private var expanded = false

    var body: some View {
        Circle()
            .stroke(.white, lineWidth: 2)
            .frame(width: diameter * 0.35, height: diameter * 0.35)
            .scaleEffect(expanded ? 2.6 : 1)
            .opacity(expanded ? 0 : 0.25)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) { expanded = true }
            }
            .accessibilityHidden(true)
    }
}

struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            configuration.title
            configuration.icon
        }
    }
}

#Preview("Counting down") {
    AlertView(store: Store(initialState: AlertFeature.State(
        event: MockCalendar.events(relativeTo: .now)[0], now: .now.addingTimeInterval(43)
    )) {
        AlertFeature()
    })
    .frame(width: 1280, height: 800)
}

#Preview("Started, with hook") {
    AlertView(store: Store(initialState: AlertFeature.State(
        event: MockCalendar.events(relativeTo: .now)[3], additionalCount: 1, proHook: .declined,
        now: .now.addingTimeInterval(3 * 3600 + 200)
    )) {
        AlertFeature()
    })
    .frame(width: 1280, height: 800)
}
