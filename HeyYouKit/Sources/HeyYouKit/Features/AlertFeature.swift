import ComposableArchitecture
import Foundation

/// The full-screen red alert. It never closes by itself; any interaction dismisses it.
@Reducer
public struct AlertFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var event: CalendarEvent
        public var additionalCount: Int
        public var proHook: ProHook?
        public var leadTimeSeconds: Int
        public var trigger: AlertTrigger
        public var shownAt: Date
        public var now: Date

        public init(
            event: CalendarEvent,
            additionalCount: Int = 0,
            proHook: ProHook? = nil,
            leadTimeSeconds: Int = LeadTime.free,
            trigger: AlertTrigger = .scheduled,
            now: Date
        ) {
            self.event = event
            self.additionalCount = additionalCount
            self.proHook = proHook
            self.leadTimeSeconds = leadTimeSeconds
            self.trigger = trigger
            shownAt = now
            self.now = now
        }

        /// Whole seconds until the start (rounded up, so the first second shows the full lead time).
        /// Negative once the meeting has started.
        public var secondsRemaining: Int {
            Int(event.start.timeIntervalSince(now).rounded(.up))
        }

        public var phase: AlertPhase {
            AlertPhase(secondsRemaining: secondsRemaining)
        }

        /// Fraction of the progress ring (1 at the lead time, 0 at the start).
        public var progress: Double {
            min(max(Double(secondsRemaining) / Double(max(leadTimeSeconds, 1)), 0), 1)
        }

        /// The meeting link, or the event in Google Calendar when there is none.
        public var joinURL: URL? {
            event.meetingLink?.url ?? event.htmlLink
        }

        public var hasMeetingLink: Bool {
            event.meetingLink != nil
        }
    }

    public enum Action: Sendable, Equatable {
        case task
        case tick
        case joinTapped
        case dismissed(DismissReason)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Sendable, Equatable {
            case finished(DismissReason)
        }
    }

    private enum CancelID {
        case timer
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.date.now) var now
    @Dependency(\.openURL) var openURL

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return .run { send in
                    for await _ in clock.timer(interval: .seconds(1)) {
                        await send(.tick)
                    }
                }
                .cancellable(id: CancelID.timer, cancelInFlight: true)

            case .tick:
                state.now = now
                return .none

            case .joinTapped:
                guard let url = state.joinURL else {
                    return .send(.delegate(.finished(.join)))
                }
                return .run { send in
                    await openURL(url)
                    await send(.delegate(.finished(.join)))
                }

            case let .dismissed(reason):
                return .merge(.cancel(id: CancelID.timer), .send(.delegate(.finished(reason))))

            case .delegate:
                return .none
            }
        }
    }
}
