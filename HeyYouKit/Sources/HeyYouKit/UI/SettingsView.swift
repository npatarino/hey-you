import ComposableArchitecture
import SwiftUI

/// Native settings window. Pro controls are wrapped in `proGated`.
public struct SettingsView: View {
    let store: StoreOf<SettingsFeature>

    public init(store: StoreOf<SettingsFeature>) {
        self.store = store
    }

    public var body: some View {
        Form {
            accountSection
            generalSection
            alertSection
            filtersSection
            calendarsSection
            privacySection
            proSection
            Section {
                LabeledContent {
                    Text(verbatim: AppConfig.appVersion)
                } label: {
                    Text("Version", bundle: .module)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 680)
        .task { store.send(.task) }
    }

    private var isPro: Bool {
        store.isPro
    }

    private func lock() {
        store.send(.lockTapped)
    }

    // MARK: - Sections

    private var accountSection: some View {
        Section {
            if let account = store.account {
                LabeledContent {
                    Button(role: .destructive) { store.send(.signOutTapped) } label: {
                        Text("Disconnect", bundle: .module)
                    }
                } label: {
                    Text(verbatim: account.email)
                }
            } else {
                LabeledContent {
                    Button { store.send(.connectTapped) } label: { Text("Connect Google Calendar", bundle: .module) }
                } label: {
                    Text("Not connected", bundle: .module)
                }
            }
        } header: {
            Text("Account", bundle: .module)
        }
    }

    private var generalSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { store.launchAtLogin == .enabled },
                set: { store.send(.setLaunchAtLogin($0)) }
            )) {
                Text("Open at login", bundle: .module)
                Text("Hey You! can only alert you while it's running.", bundle: .module)
            }
            if store.launchAtLogin == .requiresApproval {
                LabeledContent {
                    Button { store.send(.openLoginItemsTapped) } label: { Text("Open Login Items", bundle: .module) }
                } label: {
                    Text("Allow Hey You! in System Settings → General → Login Items.", bundle: .module)
                        .foregroundStyle(.secondary)
                }
            }
            LabeledContent {
                Button { store.send(.testAlertTapped) } label: { Text("Test alert", bundle: .module) }
            } label: {
                Text("See what the alert looks like (in 5 seconds).", bundle: .module)
            }
        } header: {
            Text("General", bundle: .module)
        }
    }

    private var alertSection: some View {
        Section {
            VStack(alignment: .leading) {
                LabeledContent {
                    Text(verbatim: "\(store.effective.leadTimeSeconds) s").monospacedDigit()
                } label: {
                    Text("Alert before the meeting", bundle: .module)
                }
                Slider(
                    value: Binding(
                        get: { Double(store.effective.leadTimeSeconds) },
                        set: { store.send(.setLeadTime(Int($0))) }
                    ),
                    in: Double(LeadTime.range.lowerBound) ... Double(LeadTime.range.upperBound),
                    step: Double(LeadTime.step)
                ) {
                    Text("Alert before the meeting", bundle: .module)
                } minimumValueLabel: {
                    Text(verbatim: "10 s")
                } maximumValueLabel: {
                    Text(verbatim: "60 s")
                }
                .labelsHidden()
            }
            .proGated(isPro: isPro, onLockTap: lock)

            Picker(selection: Binding(get: { store.effective.sound }, set: { store.send(.setSound($0)) })) {
                ForEach(AlertSound.allCases, id: \.self) { sound in
                    Text(verbatim: sound.displayName).tag(sound)
                }
            } label: {
                Text("Sound", bundle: .module)
            }
            .proGated(isPro: isPro, onLockTap: lock)

            Toggle(isOn: Binding(
                get: { store.effective.showCountdownInMenuBar },
                set: { store.send(.setShowCountdown($0)) }
            )) {
                Text("Countdown in the menu bar", bundle: .module)
                Text("Shows “8m” next to the bell when a meeting is less than 10 minutes away.", bundle: .module)
            }
            .proGated(isPro: isPro, onLockTap: lock)
        } header: {
            proHeader(Text("Alert", bundle: .module))
        }
    }

    private var filtersSection: some View {
        Section {
            Toggle(isOn: Binding(get: { store.effective.ignoreDeclined }, set: { store.send(.setIgnoreDeclined($0)) })) {
                Text("Ignore meetings I declined", bundle: .module)
            }
            .proGated(isPro: isPro, onLockTap: lock)
            Toggle(isOn: Binding(
                get: { store.effective.ignoreWithoutOtherAttendees },
                set: { store.send(.setIgnoreWithoutOtherAttendees($0)) }
            )) {
                Text("Ignore events with no other attendees", bundle: .module)
                Text("Focus blocks and reminders you created for yourself.", bundle: .module)
            }
            .proGated(isPro: isPro, onLockTap: lock)
            Toggle(isOn: Binding(get: { store.effective.onlyEventsWithMeetingLink }, set: { store.send(.setOnlyWithLink($0)) })) {
                Text("Only meetings with a video link", bundle: .module)
            }
            .proGated(isPro: isPro, onLockTap: lock)
            Toggle(isOn: Binding(get: { store.effective.workingHours != nil }, set: { store.send(.setWorkingHoursEnabled($0)) })) {
                Text("Only during working hours", bundle: .module)
            }
            .proGated(isPro: isPro, onLockTap: lock)
            if let hours = store.effective.workingHours {
                WorkingHoursEditor(hours: hours, send: { store.send($0) })
            }
        } header: {
            proHeader(Text("Filters", bundle: .module))
        }
    }

    private var calendarsSection: some View {
        Section {
            if store.calendars.isEmpty {
                Text("Calendars appear here once you're connected.", bundle: .module).foregroundStyle(.secondary)
            }
            ForEach(store.calendars) { calendar in
                Toggle(isOn: Binding(
                    get: { !isPro || store.state.isCalendarSelected(calendar.id) },
                    set: { _ in store.send(.toggleCalendar(calendar.id)) }
                )) {
                    Text(verbatim: calendar.name)
                }
                .proGated(isPro: isPro, onLockTap: lock)
            }
        } header: {
            proHeader(Text("Calendars", bundle: .module))
        }
    }

    private var privacySection: some View {
        Section {
            Toggle(isOn: Binding(get: { store.consent.usageAnalytics }, set: { store.send(.setUsageConsent($0)) })) {
                Text("Share anonymous usage statistics", bundle: .module)
                Text("Never your meeting titles, links, attendees or calendar names.", bundle: .module)
            }
            Toggle(isOn: Binding(get: { store.consent.emailContact }, set: { store.send(.setEmailConsent($0)) })) {
                Text("Email me about new features", bundle: .module)
            }
            Link(destination: AppConfig.privacyURL) {
                Text("Privacy policy", bundle: .module)
            }
        } header: {
            Text("Privacy", bundle: .module)
        }
    }

    private var proSection: some View {
        Section {
            if isPro {
                Label {
                    Text("Hey You! Pro is active. Thank you!", bundle: .module)
                } icon: {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                }
            } else {
                LabeledContent {
                    Button { store.send(.unlockProTapped) } label: { Text("Unlock Pro…", bundle: .module) }
                        .buttonStyle(.borderedProminent)
                } label: {
                    Text("Free version", bundle: .module)
                }
            }
            LabeledContent {
                Button { store.send(.restoreTapped) } label: { Text("Restore purchase", bundle: .module) }
                    .disabled(store.isRestoring)
            } label: {
                if let message = store.message {
                    Text(verbatim: message).foregroundStyle(.secondary)
                } else {
                    Text(verbatim: "")
                }
            }
        } header: {
            Text(verbatim: "Hey You! Pro")
        }
    }

    private func proHeader(_ title: Text) -> some View {
        HStack {
            title
            if !isPro {
                Text(verbatim: "PRO")
                    .font(.caption2.bold())
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.alertCrimson))
                    .foregroundStyle(.white)
            }
        }
    }
}

private struct WorkingHoursEditor: View {
    let hours: WorkingHours
    let send: (SettingsFeature.Action) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                ForEach(WorkingHours.orderedWeekdays(calendar: .current), id: \.self) { weekday in
                    Toggle(isOn: Binding(get: { hours.weekdays.contains(weekday) }, set: { _ in send(.toggleWorkday(weekday)) })) {
                        Text(verbatim: WorkingHours.symbol(for: weekday, calendar: .current))
                    }
                    .toggleStyle(.button)
                }
            }
            HStack {
                DatePicker(
                    selection: binding(hours.startMinute) { send(.setWorkingHoursStart(minute: $0)) },
                    displayedComponents: .hourAndMinute
                ) {
                    Text("From", bundle: .module)
                }
                DatePicker(
                    selection: binding(hours.endMinute) { send(.setWorkingHoursEnd(minute: $0)) },
                    displayedComponents: .hourAndMinute
                ) {
                    Text("To", bundle: .module)
                }
            }
        }
    }

    private func binding(_ minute: Int, set: @escaping (Int) -> Void) -> Binding<Date> {
        Binding(
            get: { WorkingHours.date(forMinute: minute, on: .now, calendar: .current) },
            set: { set(WorkingHours.minute(of: $0, calendar: .current)) }
        )
    }
}

#Preview("Free") {
    SettingsView(store: Store(initialState: SettingsFeature.State(account: GoogleAccount(email: "demo@example.com"))) {
        SettingsFeature()
    })
}
