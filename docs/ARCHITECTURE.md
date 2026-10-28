# Architecture

How the code is organised, and where it differs from PLAN.md (the plan allows adapting the implementation as long as the architecture and acceptance criteria hold).

## Layers

```
App/                      wiring only: @main, AppDelegate (store, window controllers, ⌘Q), Info.plist
HeyYouKit/
  Models/                 domain types, MeetingLinkParser, settings + EffectiveSettings (Pro gating)
  Scheduling/             AlertScheduler — pure: events + now + settings + fired → next alert
  GoogleCalendar/         REST API v3 over an injectable transport, DTOs, mapper
  GoogleAuth/             thin MainActor wrapper over GIDSignIn
  Analytics/              closed AnalyticsEvent taxonomy, consent-gated pipeline, PostHog backend
  Clients/                TCA dependencies (auth, calendar, store, analytics, launch at login, workspace, sound, app)
  Features/               TCA reducers: App, Alert, Settings, Onboarding, Paywall; MenuBar is derived state
  Presentation/           ready-to-display texts and conversions (headlines, status lines, time formatting)
  UI/                     SwiftUI views: lay out state, send actions, nothing else
  AlertWindow/            AppKit: one panel per screen for the alert, regular windows for onboarding/paywall
AppTests/                 tests that need a real app process (StoreKit 2 against App/HeyYou.storekit)
```

Rules that hold everywhere:

- **Pro gating lives in one place.** Reducers and the scheduler read `EffectiveSettings(settings, isPro:)`; raw `AppSettings` is only read for launch at login and inside the Settings editor after the Pro guard.
- **No clocks or dates in reducers.** `continuousClock` for alert/refresh timers, a separate `menuBarClock` for the 15 s menu-bar tick, `date.now` for wall time.
- **No logic in views.** Texts, time formatting and picker conversions come from `Presentation/` and are unit-tested.
- **Analytics can't carry content.** `AnalyticsEvent` has no free-text case; consent is applied in `AnalyticsPipeline` before anything reaches PostHog. Person properties are derived from state (`AppFeature.State.personProperties`) and only changes are sent.

## Deviations from PLAN.md

| PLAN | Implementation | Why |
|---|---|---|
| `AlertPresenterClient.show(store)` called from the reducer | `AlertWindowController` observes `state.alert` and shows/hides the panels | A reducer can't hold a store; presentation driven by state is the TCA way and is testable (`WindowControllerTests`). |
| Paywall as a `.sheet` | Its own 420×560 window (`PresentedWindowController`) | It can be opened from the menu bar, where there is no window to attach a sheet to. |
| `AuthClient.signIn(presenting: NSWindow)` | `signIn()` finds the visible onboarding/settings window itself | `NSWindow` isn't `Sendable` and can't travel through actions. |
| `AuthClient.accountStream()` | Not implemented | Auth state lives in `AppFeature.State.auth`; nothing needed a stream. |
| `firedAlerts: Set<String>` | `[dedupeKey: eventEnd]` | Lets keys be purged exactly when the event is over. |
| `MenuBarFeature` reducer | Pure `MenuBarFeature.state(from:now:calendar:)`; its actions are handled by `AppFeature` | Everything it shows is derived; a separate reducer would only forward. |
| `TimelineView` for the countdown | `AppFeature.State.now`, ticked every 15 s | `TimelineView` inside a `MenuBarExtra` label re-renders forever on macOS 26 (found in QA). |
| "All calendars" | Calendars visible in the user's Google Calendar (`selected`, not hidden) | Subscribed colleague calendars would otherwise fire alerts for other people's meetings. |
| Turning analytics off sends `consent_changed` | It sends nothing | Privacy first. The PRD guardrail "users who turn analytics off > 15 %" can only be estimated (users who stop sending events). |
| A meeting already in progress at launch | Not alerted; only after wake (PRD B.7) | Avoids an alert for a meeting you're already in every time the app starts. |
