# Store content

Texts and images for the Mac App Store listing and the Product Hunt launch.

| What | Where |
|---|---|
| App Store texts, English | [metadata/en-US](metadata/en-US) |
| App Store texts, Spanish | [metadata/es-ES](metadata/es-ES) |
| App Store screenshots (2880×1800, no alpha) | [screenshots/en](screenshots/en), [screenshots/es](screenshots/es) |
| Product Hunt texts | [PRODUCT_HUNT.md](PRODUCT_HUNT.md) |
| Product Hunt gallery (1270×760) | [product-hunt](product-hunt) |

## Positioning

Hey You! is the meeting reminder you can't ignore. Every text leads with the same story (you knew about the meeting, looked at 10:55, and then it was 11:07) and the same promise: 20 seconds before every meeting, your whole screen turns red.

The four things a reader should remember, in this order:

1. It can't be missed: every display, above full-screen apps, and it stays until you react.
2. It never traps you: Enter joins, a click or Esc dismisses.
3. Your calendar stays on your Mac: read-only Google sign-in, no servers.
4. The free version does the whole job. Pro is a one-time purchase for fine control.

## App Store Connect fields

One file per field, in the layout `fastlane deliver` uses, so they can be pasted by hand or uploaded later.

| File | Field | Limit |
|---|---|---|
| `name.txt` | App name | 30 |
| `subtitle.txt` | Subtitle | 30 |
| `keywords.txt` | Keywords | 100 |
| `promotional_text.txt` | Promotional text (editable without a new build) | 170 |
| `description.txt` | Description | 4000 |
| `release_notes.txt` | What's New | 4000 |
| `iap_name.txt`, `iap_description.txt` | Display name and description of the Hey You! Pro purchase | 35 / 55 |

`python3 scripts/check-store-metadata.py` checks every field against its limit.

Keywords don't repeat words from the name or subtitle, because the App Store already indexes those. The Spanish (Mexico) localization is also indexed in the US store: copying the Spanish texts there and filling its keyword field with extra English terms (`reminder,agenda,schedule,late,punctual,time,blindness,slack,huddle,standup`) doubles the English keywords.

## Screenshots

`./scripts/make-store-screenshots.sh` renders everything from the real SwiftUI views (`StoreScreenshotTests`), in both languages, so the images follow the app when the UI or a string changes. Headlines live in that test.

| # | File | Headline (en) | Headline (es) |
|---|---|---|---|
| 1 | `01-alert` | 20 seconds before every meeting, your whole screen turns red. | 20 segundos antes de cada reunión, toda tu pantalla se pone roja. |
| 2 | `02-every-screen` | On every display. Even over full-screen apps. | En todas tus pantallas. También sobre apps a pantalla completa. |
| 3 | `03-join-or-dismiss` | Enter joins the call. Esc makes it go away. | Enter te une a la llamada. Esc la quita. |
| 4 | `04-started` | Stepped away? It waits for you. | ¿Te habías levantado? Te espera. |
| 5 | `05-menu-bar` | Quiet until it matters. | Callada hasta que hace falta. |
| 6 | `06-privacy` | Your calendar never leaves your Mac. | Tu calendario no sale de tu Mac. |
| 7 | `07-pro` | Pro: you decide when, and for what. | Pro: tú decides cuándo y de qué. |

The first three show in search results without opening the page, so they carry the promise, the reach and the way out. `07-pro` is also the review screenshot for the in-app purchase.

Every frame follows one grid (`StoreGrid` in the test): 96 pt side margins, 72 pt top and bottom, a header with a two-line headline and a one-line subline, a 64 pt gap and a 520 pt stage for the app. Nothing is cropped by the canvas edge, and sublines stay under about 66 characters so they fit on one line.

The display bezels, the desktop behind the menu and the window title bars are drawn by the test. The alert, menu, onboarding, settings and paywall inside them are the app's own views.
