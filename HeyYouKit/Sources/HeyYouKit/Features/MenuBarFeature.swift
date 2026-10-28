import Foundation

/// The menu-bar item: upcoming meetings, status and shortcuts. State is derived from `AppFeature.State`.
public enum MenuBarFeature {
    public enum Action: Sendable, Equatable {
        case openPaywall
        case statsTapped
        case connectGoogle
        case refreshNow
        case testAlert
        case quit
    }

    public enum Status: Equatable, Sendable {
        case loading
        case signedOut
        case sessionExpired
        case offline(since: Date)
        case watching(calendars: Int, nextStart: Date?)
    }

    public struct Row: Equatable, Sendable, Identifiable {
        public let event: CalendarEvent
        /// Hidden by a Pro filter (declined, solo, no link, calendar).
        public let isFiltered: Bool
        /// Outside working hours (Pro), shown with a moon (PRD B.20).
        public let isOutsideWorkingHours: Bool

        public var id: String {
            event.dedupeKey
        }
    }

    public struct State: Equatable, Sendable {
        public var now: Date
        public var status: Status
        public var rows: [Row]
        /// "Xm" next to the bell (Pro, < 10 min).
        public var countdown: String?
        public var iconName: String
        public var isPro: Bool
        /// Punctuality this week (Pro only).
        public var punctuality: PunctualityStats?
        public var canConnect: Bool

        public var showsProEntry: Bool {
            !isPro
        }

        public enum Tone: Equatable, Sendable {
            case normal
            case warning
            case error
        }

        /// Status line under the title.
        public func statusText(locale: Locale = .current, timeZone: TimeZone = .current) -> String {
            switch status {
            case .loading:
                return String(localized: "Connecting…", bundle: .module)
            case .signedOut:
                return String(localized: "Not connected to Google", bundle: .module)
            case .sessionExpired:
                return String(localized: "Disconnected from Google", bundle: .module)
            case let .offline(since):
                return String(localized: "Offline since \(TimeText.time(since, locale: locale, timeZone: timeZone))", bundle: .module)
            case let .watching(calendars, nextStart):
                guard let nextStart, nextStart > now else {
                    return String(localized: "Watching \(calendars) calendars", bundle: .module)
                }
                let next = TimeText.relative(nextStart, now: now, locale: locale, timeZone: timeZone)
                return String(localized: "Watching \(calendars) calendars · next in \(next)", bundle: .module)
            }
        }

        public var statusTone: Tone {
            switch status {
            case .sessionExpired: .error
            case .offline: .warning
            default: .normal
            }
        }

        /// "Sign in again" after losing the session, otherwise "Connect Google Calendar".
        public var connectTitle: String {
            status == .sessionExpired
                ? String(localized: "Sign in again", bundle: .module)
                : String(localized: "Connect Google Calendar", bundle: .module)
        }

        /// "On time 11 of 12 this week" (Pro only).
        public var punctualityText: String? {
            punctuality.map { String(localized: "On time \($0.onTime) of \($0.alerts) this week", bundle: .module) }
        }
    }

    public static let maxRows = 5

    public static func state(from app: AppFeature.State, now: Date, calendar: Calendar) -> State {
        let effective = app.effectiveSettings
        let endOfDay = calendar.dateInterval(of: .day, for: now)?.end ?? now.addingTimeInterval(86400)
        let rows = app.events
            .filter { !$0.isAllDay && $0.end > now && $0.start < endOfDay }
            .sorted { $0.start < $1.start }
            .prefix(maxRows)
            .map { event in
                var withoutHours = app.settings
                withoutHours.workingHours = nil
                let passesFilters = AlertScheduler.isEligible(
                    event, now: now, settings: EffectiveSettings(withoutHours, isPro: effective.isPro),
                    includeInProgress: true, calendar: calendar
                )
                let outside = effective.workingHours.map { !$0.contains(event.start, calendar: calendar) } ?? false
                return Row(event: event, isFiltered: !passesFilters, isOutsideWorkingHours: outside)
            }

        let status: Status = switch app.auth {
        case .unknown: .loading
        case .signedOut: .signedOut
        case .sessionExpired: .sessionExpired
        case .signedIn:
            if let since = app.offlineSince {
                .offline(since: since)
            } else {
                .watching(
                    calendars: effective.selectedCalendarIDs?.count ?? max(app.calendars.count, 1),
                    nextStart: app.nextAlert?.event.start
                )
            }
        }

        var countdown: String?
        if effective.showCountdownInMenuBar, let start = app.nextAlert?.event.start {
            let seconds = start.timeIntervalSince(now)
            if seconds > 0, seconds < 10 * 60 {
                countdown = "\(Int((seconds / 60).rounded(.up)))m"
            }
        }

        let iconName = switch app.auth {
        case .sessionExpired, .signedOut: "bell.slash"
        default: "bell"
        }

        return State(
            now: now,
            status: status,
            rows: Array(rows),
            countdown: countdown,
            iconName: iconName,
            isPro: effective.isPro,
            punctuality: effective.isPro ? app.stats.current(at: now, calendar: calendar) : nil,
            canConnect: app.auth == .signedOut || app.auth.isSessionExpired
        )
    }
}
