# QA — Milestone 7

Date: 2026-10-29 · Machine: macOS 26.6.2, Apple Silicon, one built-in display (1728×1117 pt) · Xcode 27.1 · Debug build with `--mock-calendar`.

Legend: ✅ verified · 🧪 verified by automated test only · ⏳ not verified yet (needs a person at the keyboard or credentials) · ⚠️ verified with a limitation.

## How it was checked

The agent that built the app has no Screen Recording or Accessibility permission on this Mac, so it could not take real screenshots or send key presses / clicks to the app. What it could do:

- Run the real app and read the **window server** (`CGWindowListCopyWindowInfo`): which windows the app owns, their level and bounds.
- Sample the process (`sample HeyYou`) to see what the main thread is doing.
- Render every screen off-screen with `ImageRenderer` (`docs/screenshots/*.png`, regenerate with
  `cd HeyYouKit && HEYYOU_SNAPSHOTS=$PWD/../docs/screenshots swift test --filter SnapshotRenderTests`).
  Native AppKit controls (checkboxes, link buttons) show as yellow placeholders in those renders; that is a renderer limitation, not the app.
- Everything in reducers is covered by `TestStore` tests (B.1–B.9, B.13–B.19, see `HeyYouKit/Tests`).

## Bugs found and fixed while doing this

1. **App froze on launch** (main thread at 100 %, no alert ever fired). A `TimelineView` inside the `MenuBarExtra` label makes SwiftUI re-render the status item in an endless loop on macOS 26. Fixed: the store now carries a `now` value refreshed every 15 s and the label reads it.
2. **Alert at the wrong window level.** Setting `NSPanel.isFloatingPanel` after `level` reset the level to *floating* (3) instead of *screen saver* (1000), so it would not have covered full-screen apps. Fixed and covered by `AlertPanelTests`.
3. The "s" after the countdown touched the progress ring. Number shrunk from 180 to 150 pt.

## Results

| Case | Result | Notes |
|---|---|---|
| App starts as menu-bar app (no Dock icon) | ✅ | `LSUIElement = YES`; process runs with no regular window. |
| Mock meeting at +90 s fires the alert at +30 s | ✅ | Launched 00:02:00, alert window appeared 00:02:32. |
| Alert covers the whole screen, above everything | ✅ | Window level 1000 (screen saver), bounds = full screen. Only one display available, so multi-display not checked. |
| B.1 alert content ("MEETING IN", "60s", title, time · provider, Join) | 🧪 + render | `alert-countdown.png`; `AppFeatureTests.launchToAlert`. |
| B.2 Enter / Join opens the link and closes | 🧪 | Key mapping (`AlertInputTests`) and reducer tested. ⏳ real key press. |
| B.3 click, Esc, ⌘Q, ⌘W, right-click dismiss; `j`/space ignored; first second ignored; app keeps running | 🧪 | ⏳ Real input not sent (no Accessibility permission). |
| B.4 no auto-close; NOW; STARTED 3 MIN AGO | 🧪 + render | `alert-started-hook.png`. |
| B.5–B.9, B.16–B.19 | 🧪 | All in `AppFeatureTests` / `AppFeatureProTests`. |
| B.10 above full-screen Safari, two monitors | ⏳ | Level and collection behaviour are correct (`.screenSaver`, `.fullScreenAuxiliary`, `.canJoinAllSpaces`); needs a person with two monitors. |
| B.11 Zoom screen sharing | ⏳ | Expected to show (documented behaviour). |
| B.12 Keynote presenting | ⏳ | If it doesn't show, document as known limitation. |
| B.13 Google session lost → `bell.slash`, "Disconnected" | 🧪 | `sessionExpiredKeepsAlerting`. ⏳ with a real revoked token. |
| B.14 offline → alert still fires, "Offline since" | 🧪 | `offlineKeepsAlerting`. |
| B.15 Test alert in 5 s | 🧪 | `testAlertFromMenu`. ⏳ clicking the real menu. |
| B.20 working hours | 🧪 | Scheduler and menu-row tests. |
| Sound plays | ⏳ | `NSSound(named: "Funk")` call is tested via the mock; audio not heard. |
| Status item countdown "Xm" | 🧪 | `MenuBarFeatureTests`. |
| Onboarding "Sign in with Google" branding | ✅ render | `onboarding.png`: white, grey border, official G from the SDK. |
| Real Google OAuth | ⏳ | Needs `Config/Secrets.xcconfig` (client ID) and a signed build (Team ID). Without a client ID the onboarding shows a clear "not set up" message. |
| Launch at login | ⏳ | `SMAppService` needs a signed app in /Applications to be meaningful. |
| StoreKit purchase / restore with `HeyYou.storekit` | 🧪 | Reducer flows tested with the mock store. ⏳ in Xcode with the StoreKit configuration (Run from Xcode; the scheme already points at it). |
| PostHog traffic has no titles/links (B.19) | 🧪 | Typed taxonomy makes it impossible to send free text; consent-off sends nothing. ⏳ traffic inspection needs a PostHog key. |

## Manual checklist for you (≈10 minutes)

1. `open HeyYou.xcodeproj`, click **Trust & Enable** for the package macros if asked, edit the scheme → Run → Arguments → tick `--mock-calendar`, Run.
2. Wait ~30 s: red alert on every screen. Type a letter or Space: nothing happens. Then try Esc, a click, right-click, ⌘Q, ⌘W (each time use **Test alert** from the menu): the alert closes and the bell stays in the menu bar. Input in the first second after it appears is ignored.
3. **Test alert** again and press Enter: the project page opens.
4. Leave one alert alone for 5 minutes: it should say "STARTED 4 MIN AGO" and stay.
5. Put Safari in full screen, then **Test alert**: the alert must appear over it.
6. Menu → **Hey You! Pro…** → Buy (StoreKit test purchase) → padlocks disappear in Settings.
7. With `Config/Secrets.xcconfig` filled in: quit, relaunch without `--mock-calendar`, sign in with Google.

## Milestone 8 quality pass

- SwiftLint `--strict`: 0 violations. SwiftFormat applied. No compiler warnings in `App/` or `HeyYouKit/Sources` (Swift 6, strict concurrency complete).
- No hard-coded UI strings: every visible string goes through the `en`/`es` catalog (106 keys); data (titles, emails) uses `Text(verbatim:)`.
- Contrast: white on the gradient centre `#E0263A` is 4.66:1 and on `#B5121F` 6.84:1, but white at 75–85 % opacity on the centre was only 3.2–3.4:1, so all alert text is now fully opaque white. The Join button text (`#B5121F` on white) is 6.84:1.
- Reduce Motion disables the pulse, the "NOW" scaling, the ring animation and the entrance animation. Buttons have accessibility labels; the countdown reads as "Meeting in 47 seconds".
- Pro gating: the scheduler only accepts `EffectiveSettings`; raw `AppSettings` is read only for launch at login (free) and inside the Settings editor after the Pro guard.
- Size: a plain Release build is 42 MB (with symbols), but the **archived app is 13 MB** (universal, stripped), within the PRD's 15 MB.

## Review pass (2026-10-29)

- Presentation logic moved out of the views into `Presentation/` and unit-tested (alert texts, menu status lines, time formatting, working-hours pickers).
- New tests: AppKit window controllers (panels per screen, Return joins, only deliberate keys dismiss, first-second grace, ⌘Q only dismisses while visible, onboarding window follows state), live clients (wake notifications, Google sign-in without a client ID, error mapping, mocks), StoreKit 2 against `App/HeyYou.storekit` in an app-hosted test target.
- **Bug fixed:** after a successful purchase the live store client re-read `Transaction.currentEntitlements`, which can lag, so the app could stay "free" until relaunch. It now uses the verified transaction. Same for `Transaction.updates`.
- **Not verifiable here:** under StoreKitTest on macOS 26, `currentEntitlements`, `Transaction.latest` and `SKTestSession.buyProduct` don't see test purchases, so "Pro survives a relaunch" and "Restore purchase" still need the manual check (run from Xcode with the StoreKit configuration).
- Person properties from PRD §6.1 now complete: `calendars_count`, `weekly_meetings_bucket` (new weekly counter), and `lead_time` / `launch_at_login` / `is_pro` are re-sent when they change.
- Tests: 160 package tests + 2 app-hosted, all green (`./scripts/test.sh --xcode`).

## Change 2026-10-29: deliberate dismissal

In the first real run the alert appeared while the user was typing and a keystroke already in flight dismissed it unseen. Now only Esc, ⌘Q, ⌘W, ⌘. and clicks dismiss; other keys are swallowed; and all input is ignored for 1 s after the alert appears (`AlertFeature.inputGracePeriod`). PRD §5.4 and B.3 updated. Tests: key mapping table, `gracePeriodIgnoresInput`, `onlyDeliberateKeysDismiss`.
