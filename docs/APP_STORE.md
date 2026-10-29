# App Store checklist — Hey You!

Everything here needs your Apple Developer account. Items marked **(you)** can't be done by the agent.

## 1. Accounts and identifiers (you)

- [ ] Apple Developer Program membership (paid).
- [ ] App ID `pro.chimi.heyyou` (Certificates, Identifiers & Profiles → Identifiers). If you use another bundle ID, change `BUNDLE_ID` in `project.yml` (the only place) and the product ID below.
- [ ] Put your Team ID in `Config/Secrets.xcconfig`: `TEAM_ID = ABCDE12345` and `HEYYOU_SIGN_IDENTITY = Apple Development`. Xcode automatic signing then creates the *Apple Development* / *Apple Distribution* certificates and the Mac App Store provisioning profile.
- [ ] Google OAuth client (type iOS) for the same bundle ID, values in `Config/Secrets.xcconfig` (see README).
- [ ] **Google OAuth verification** for the sensitive `calendar.readonly` scope: home page, published privacy policy (PRIVACY.md at a public URL), demo video of the sign-in and of the scope in use. Until approved only 100 test users can sign in. Start this as soon as there is a TestFlight build.
- [ ] PostHog EU project; API key in `POSTHOG_API_KEY`.

## 2. App Store Connect (you)

- [ ] New macOS app: name **Hey You!**, primary language English, bundle ID `pro.chimi.heyyou`, SKU `heyyou-mac`.
- [ ] In-app purchase: **Non-Consumable**, product ID `pro.chimi.heyyou.pro`, reference name "Hey You! Pro", price 5.99 € tier, **Family Sharing on**, display name and description in en/es (texts below), review screenshot of the paywall. Submit it **together with the first build**.
- [ ] Pricing: Free. Availability: all territories.
- [ ] Category: Productivity (secondary: Business).
- [ ] Age rating: 4+.

## 3. Build and upload

```bash
./scripts/bootstrap.sh
source scripts/env.sh
xcodebuild -project HeyYou.xcodeproj -scheme HeyYou -configuration Release \
  -skipMacroValidation -skipPackagePluginValidation \
  archive -archivePath build/HeyYou.xcarchive
xcodebuild -exportArchive -archivePath build/HeyYou.xcarchive \
  -exportOptionsPlist Config/ExportOptions.plist -exportPath build/export
```

Then upload `build/export/HeyYou.pkg` with Transporter, or use Xcode → Organizer → Distribute App → App Store Connect. Bump `CURRENT_PROJECT_VERSION` in `Config/Base.xcconfig` for every upload, `MARKETING_VERSION` for every release.

Size: the archived app (universal Intel + Apple Silicon, symbols stripped) is 13 MB, within the PRD's 15 MB.

## 4. Metadata

**Subtitle** (30 chars): Never be late to a meeting again · ES: Que no llegues tarde nunca más

**Keywords** (100 chars): meeting,reminder,calendar,google calendar,alert,zoom,meet,teams,focus,punctual,notification,menu bar

**Promotional text**: One minute before every meeting, your whole screen turns red. One click and it's gone — but you can't miss it.

**Description (en)**

> Hey You! lives in your menu bar and watches your Google Calendar. One minute before each meeting it turns every screen red with the meeting name, a countdown and a Join button. It never closes by itself, and it never locks you out: a click or Esc dismisses it, Enter joins the call.
>
> • Works over full-screen apps and on every display
> • Detects Google Meet, Zoom, Microsoft Teams and Webex links
> • Read-only Google sign-in. Your calendar never leaves your Mac
> • Shows "Started 3 min ago" if you were away
> • Test alert from the menu
>
> Hey You! Pro — one-time purchase:
> • Alert 10 to 60 seconds before
> • Skip meetings you declined, focus blocks with just you, or meetings without a video link
> • Choose calendars and working hours
> • Pick the sound, show a countdown in the menu bar
> • Weekly punctuality stats

**Descripción (es)**

> Hey You! vive en tu barra de menús y vigila tu Google Calendar. Un minuto antes de cada reunión pinta todas tus pantallas de rojo con el nombre de la reunión, una cuenta atrás y un botón para unirte. No se cierra sola y nunca te bloquea: un clic o Esc la quitan y Enter te une a la llamada.
>
> • Funciona sobre apps a pantalla completa y en todas las pantallas
> • Detecta enlaces de Google Meet, Zoom, Microsoft Teams y Webex
> • Inicio de sesión de Google en solo lectura. Tu calendario no sale de tu Mac
> • Muestra "Empezó hace 3 min" si no estabas
> • Prueba la alerta desde el menú
>
> Hey You! Pro, compra única: aviso de 10 a 60 segundos, sin reuniones rechazadas, sin bloques de foco, solo reuniones con enlace, elige calendarios y horario laboral, sonido, cuenta atrás en la barra y estadística semanal de puntualidad.

**IAP display name / description**: Hey You! Pro — "Lead time 10–60 s, filters, calendars, working hours, sound and punctuality stats." / "Aviso de 10 a 60 s, filtros, calendarios, horario, sonido y puntualidad."

**Screenshots** (1280×800 or 2560×1600): the alert (`docs/screenshots/alert-countdown.png` is 2880×1800, resize or retake on a 1440×900 display), the alert with the Pro hook, the menu, Settings with padlocks, **the paywall**. Real screenshots from a running build are better than the off-screen renders in `docs/screenshots`.

**URLs**: Support URL (GitHub repo or a page), Privacy Policy URL (PRIVACY.md published, e.g. GitHub Pages).

## 5. App Privacy ("nutrition labels")

Data collected only when the user opts in to usage statistics:

| Data type | Linked to user | Used for tracking | Purposes |
|---|---|---|---|
| Identifiers → User ID (random ID, email hash) | Yes | No | Analytics, App Functionality |
| Usage Data → Product Interaction | Yes | No | Analytics |
| Contact Info → Email Address (only with the "email me" opt-in) | Yes | No | Developer's Advertising or Marketing |

Calendar content is processed on device only and is **not collected**. No tracking across apps or websites. No third-party advertising.

## 6. Notes for the reviewer

> Hey You! is a menu-bar app (LSUIElement); look for the bell icon in the menu bar. To see the core feature without a Google account, click the bell → **Test alert**: a full-screen red alert appears after 5 seconds. A click, Esc or ⌘Q/⌘W dismisses it (after the first second); Enter opens the meeting link.
>
> Test Google account: <email> / <password> (a test user added to our OAuth consent screen, with sample meetings).
>
> • ⌘Q while the alert is on screen only dismisses the alert (the user's "get rid of this" reflex); ⌘Q at any other time and "Quit Hey You!" in the menu quit normally.
> • Open at login is opt-in (Settings → General) and uses SMAppService.
> • Sign in with Google: per guideline 4.8, the exception applies — the app is a client for the user's Google Calendar and the user must sign in to Google to access that content. We do not have our own accounts.
> • The Pro line inside the alert ("Declined · With Pro we wouldn't have alerted you") is informational text, not a button; the paywall is opened only from the menu or Settings, and has Restore Purchase.
> • The in-app purchase can be tested in the sandbox.

## 7. Before submitting

- [ ] Run the manual checklist in `docs/QA.md` on a signed Release build.
- [ ] Real OAuth sign-in with a test user works; sign-out and re-sign-in work.
- [ ] Sandbox purchase and restore work.
- [ ] PostHog shows events with the properties of PRD §6.1 and none contain a meeting title or link.
- [ ] TestFlight with 5–10 people for a week (PRD §9 phase 2).
