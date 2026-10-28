# Hey You! — Plan de implementación

App de macOS (menu bar, siempre en background) que se conecta a Google Calendar y, cuando falta **1 minuto** para una reunión, toma **toda la pantalla** (todas las pantallas) con una alerta roja, bonita e imposible de ignorar, con botón para unirse a la reunión. Se publicará en la **Mac App Store**.

El *qué* y el *porqué* del producto están en [docs/PRD.md](docs/PRD.md) (nota de prensa, FAQ, decisiones, métricas, casos de prueba del anexo B). Léelo antes que esto. Este documento es el plan completo para que un agente lo ejecute **de forma autónoma y en orden**. Cada hito termina con criterios de aceptación verificables y un commit. No saltes hitos. Si algo del plan no compila con las versiones reales de las librerías, adapta la implementación pero mantén la arquitectura y los criterios de aceptación.

---

## 0. Estado del entorno y prerrequisitos (verificar antes de empezar)

Estado comprobado el 2026-10-28 en esta máquina:

| Elemento | Estado |
|---|---|
| macOS | 26.6.2 (arm64) |
| Swift toolchain | 6.3.3 (Command Line Tools) |
| Xcode.app | **NO instalado** (solo `/Library/Developer/CommandLineTools`) |
| XCTest / Swift Testing en CLT | **No disponibles** (`swift test` fallará sin Xcode) |
| xcodegen, swiftlint, swiftformat | No instalados; `brew` sí está en `/opt/homebrew/bin/brew` |
| Repo | vacío, remoto `https://github.com/npatarino/hey-you`, rama `main` |

### 0.1 Acciones del agente al arrancar
1. Ejecuta `xcode-select -p` y `ls /Applications | grep Xcode`.
   - Si Xcode **no** está instalado: haz todo lo que se pueda sin él (hitos 1–6 se pueden escribir y compilar con `swift build` del paquete), y **avisa claramente al usuario** de que para los hitos 7–9 (bundle .app, firma, App Store) necesita instalar Xcode desde la App Store y ejecutar `sudo xcode-select -s /Applications/Xcode.app` y `sudo xcodebuild -runFirstLaunch`. No te quedes bloqueado: sigue con lo que se pueda.
   - Si Xcode está instalado: todo el plan es ejecutable.
2. Instala herramientas: `brew install xcodegen swiftlint swiftformat`.
3. Confirma que `swift build` funciona en un paquete vacío con `import SwiftUI` (el SDK de CLT incluye SwiftUI, AppKit, AuthenticationServices, ServiceManagement, EventKit).

### 0.2 Prerrequisitos que solo puede hacer el usuario (no bloquean el desarrollo)
El agente desarrolla con un `GoogleOAuthConfig` de placeholder y con un `CalendarClient` mock; cuando el usuario tenga estos datos, los mete en `Config/Secrets.xcconfig` (gitignored) y todo funciona de verdad.

1. **Google Cloud Console** → crear proyecto → habilitar *Google Calendar API* → *OAuth consent screen* (tipo External, scope `https://www.googleapis.com/auth/calendar.readonly`, añadir su email como test user mientras esté en modo Testing) → *Credentials → Create OAuth client ID → tipo **iOS*** (sí, iOS: es el tipo que Google usa para apps nativas de macOS; permite redirect por custom URL scheme y PKCE sin client secret). Bundle ID = el de la app. Esto da un `CLIENT_ID` de la forma `1234-abc.apps.googleusercontent.com`; el URL scheme de redirect es el client ID invertido: `com.googleusercontent.apps.1234-abc`.
2. **Apple Developer Program** (de pago) para firmar y subir a App Store Connect. Crear el App ID con el bundle ID y la app en App Store Connect.
3. Para publicar a terceros con scope `calendar.readonly` (scope *sensitive*), Google exige **verificación de la app OAuth** (home page, privacy policy publicada, vídeo demo). Hasta entonces la app funciona solo para test users. Esto no afecta al código.

---

## 1. Decisiones de arquitectura (cerradas, no reabrir)

| Tema | Decisión | Por qué |
|---|---|---|
| Lenguaje / UI | Swift 6 (strict concurrency), SwiftUI + AppKit donde haga falta (ventanas, status item) | Requisito |
| Arquitectura | **TCA** (`swift-composable-architecture` 1.x, última estable) + `swift-dependencies` + `swift-sharing` para `@Shared(.appStorage)` | Requisito |
| macOS mínimo | **14.0 (Sonoma)** | `@Observable`, `MenuBarExtra` maduro, `SMAppService` |
| Estructura | Un **Swift Package local** `HeyYouKit` con toda la lógica + un target de app fino generado con **XcodeGen** (`project.yml` versionado, `.xcodeproj` **no** versionado) | Lógica compilable/testeable sin abrir Xcode; proyecto reproducible |
| Autenticación | **SDK oficial `GoogleSignIn-iOS`** (soporta macOS vía SPM; usa `ASWebAuthenticationSession` por debajo) + botón **"Sign in with Google"** con la marca oficial de Google (logo "G", guías de branding). Scope adicional `calendar.readonly` | El usuario quiere la experiencia típica de login con Google; el SDK gestiona tokens, refresh y Keychain |
| Calendario | **Google Calendar REST API v3** con `URLSession` y el access token del SDK. Sin librería cliente de Google APIs | Pocas llamadas; evitar dependencias pesadas |
| Abstracción | `CalendarClient` como dependencia TCA. Implementaciones: `.google` (real), `.mock` (DEBUG/tests). Dejar la puerta abierta a EventKit en el futuro, **no implementarlo ahora** | Extensible |
| Tokens | Gestionados por el SDK de Google (Keychain). Sin `KeychainClient` propio | Menos código, seguridad |
| Background | App de **menu bar** (`LSUIElement = YES`, sin Dock). Launch at login con `SMAppService.mainApp` (opt-in en Settings) | "Siempre corriendo" compatible con App Store |
| Alerta | Una `NSWindow` **por pantalla** (`NSScreen.screens`), `level = .screenSaver`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`, `NSApp.activate(ignoringOtherApps: true)`, contenido SwiftUI | Cubre apps en pantalla completa y todos los Spaces |
| Salida de la alerta | **Cualquier interacción la descarta**: clic en cualquier punto, cualquier tecla (Esc, Espacio, Enter…), Cmd+Q, Cmd+W, Cmd+. (mientras la alerta está visible, Cmd+Q **no** cierra la app: solo descarta la alerta). Botón **Unirse** (abre el enlace y descarta). **Sin auto-cierre**: permanece hasta que el usuario la descarte; cuando la reunión ya ha empezado muestra "Empezó hace X min" | No bloquear al usuario, pero que no pueda ignorar la notificación |
| Tiempo de aviso | Por defecto **60 s** antes del evento, configurable (30 s / 1 / 2 / 5 min) | Requisito + flexibilidad |
| Scheduling | Efecto de larga duración en `AppFeature`: refresco de eventos cada 60 s (ventana próximas 24 h), cálculo del siguiente disparo, `clock.sleep` hasta `start - leadTime`, dedupe por `eventID+start`. Recalcular en `NSWorkspace.didWakeNotification` y al cambiar settings | Preciso y barato |
| Persistencia | `@Shared(.appStorage)` para settings; nada más | Simple |
| Idiomas | **Inglés (base) + Español**, String Catalog `Localizable.xcstrings` | App Store global, usuario hispanohablante |
| Tests | **Swift Testing** (`import Testing`) + `TestStore` de TCA. Cobertura: scheduler, parsing de eventos/enlaces, refresh de tokens, reducers | Buenas prácticas |
| Lint/format | SwiftLint + SwiftFormat con configs versionadas; `swiftformat .` antes de cada commit | Buenas prácticas |
| Bundle ID | `com.patarino.heyyou` (placeholder; único sitio: `project.yml` → `BUNDLE_ID`) | Cambiar si el usuario indica otro |
| Nombre | Producto **"Hey You!"**, módulo `HeyYou`, paquete `HeyYouKit` | Nombre del repo |

---

## 2. Estructura del repositorio objetivo

```
hey-you/
├── PLAN.md                      # este fichero
├── CLAUDE.md                    # reglas para el agente
├── README.md
├── .gitignore
├── .swiftlint.yml
├── .swiftformat
├── project.yml                  # XcodeGen
├── Config/
│   ├── Base.xcconfig            # MACOSX_DEPLOYMENT_TARGET, SWIFT_VERSION, BUNDLE_ID, MARKETING_VERSION
│   ├── Secrets.example.xcconfig # GOOGLE_CLIENT_ID = REPLACE_ME
│   └── Secrets.xcconfig         # gitignored (copiado del example)
├── App/                         # target Xcode "HeyYou" (fino)
│   ├── HeyYouApp.swift          # @main, crea Store raíz, MenuBarExtra
│   ├── AppDelegate.swift        # NSApplicationDelegate: wake notifications, URL handling
│   ├── Info.plist               # LSUIElement, CFBundleURLTypes (scheme OAuth), NSHumanReadableCopyright…
│   ├── HeyYou.entitlements      # app-sandbox, network.client
│   └── Assets.xcassets          # AppIcon, AccentColor, colores de la alerta
├── HeyYouKit/                   # Swift Package local
│   ├── Package.swift
│   ├── Sources/
│   │   ├── Models/              # CalendarEvent, MeetingLink, AppSettings, LeadTime
│   │   ├── GoogleAuth/          # Wrapper de GoogleSignIn (GIDSignIn), GoogleAccount
│   │   ├── GoogleCalendar/      # GoogleCalendarAPI (URLSession), DTOs, mapeo a CalendarEvent
│   │   ├── Clients/             # Dependencias TCA: CalendarClient, AuthClient,
│   │   │                        #   LaunchAtLoginClient, AlertPresenterClient, WorkspaceClient, SoundClient
│   │   ├── Scheduling/          # AlertScheduler (función pura: eventos + now + leadTime + fired → próximo disparo)
│   │   ├── Features/            # Reducers TCA: AppFeature, MenuBarFeature, SettingsFeature,
│   │   │                        #   OnboardingFeature, AlertFeature
│   │   ├── UI/                  # Vistas SwiftUI: MenuBarView, SettingsView, OnboardingView, AlertView,
│   │   │                        #   DesignSystem (colores, tipografías, componentes)
│   │   └── AlertWindow/         # AppKit: AlertWindowController (ventanas por pantalla)
│   ├── Resources/Localizable.xcstrings
│   └── Tests/HeyYouKitTests/
└── scripts/
    ├── bootstrap.sh             # brew install xcodegen swiftlint swiftformat; xcodegen generate
    ├── build.sh                 # xcodebuild build (Debug)
    └── test.sh                  # swift test / xcodebuild test
```

`Package.swift`: un único target de librería `HeyYouKit` (con sub-carpetas como organización; si el agente prefiere, targets separados `Models`, `Scheduling` para tests puros sin AppKit). Dependencias: `pointfreeco/swift-composable-architecture` (from: última 1.x; ya trae `swift-dependencies`, `swift-sharing`, `swift-clocks`, `swift-identified-collections`) y `google/GoogleSignIn-iOS` (producto `GoogleSignIn`).

Nota para el usuario: un "Swift Package local" es simplemente una carpeta con `Package.swift` dentro del repo que contiene todo el código como librería; el proyecto Xcode de la app la importa. Ventaja: se compila y testea desde terminal sin abrir Xcode y queda bien separada la lógica de la app.

---

## 3. Modelo de dominio

```swift
struct CalendarEvent: Equatable, Identifiable, Sendable, Codable {
    let id: String                 // Google event id
    let calendarID: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let meetingLink: MeetingLink?  // Meet/Zoom/Teams/Webex/otro
    let location: String?
    let organizer: String?
    let attendeeStatus: AttendeeStatus // accepted / tentative / declined / needsAction / unknown
    let htmlLink: URL?
}

struct MeetingLink: Equatable, Sendable, Codable {
    enum Provider: String, Codable { case googleMeet, zoom, teams, webex, other }
    let provider: Provider
    let url: URL
}

struct AppSettings: Equatable, Codable, Sendable {
    var leadTime: LeadTime = .oneMinute      // enum: 30s, 1m, 2m, 5m
    var launchAtLogin = false
    var playSound = true
    var ignoreDeclined = true
    var ignoreAllDay = true
    var onlyEventsWithMeetingLink = false
    var selectedCalendarIDs: Set<String>? = nil   // nil = todos
}

struct ScheduledAlert: Equatable, Sendable { let event: CalendarEvent; let fireAt: Date }
```

**Extracción de `MeetingLink`** (`MeetingLinkParser`): orden de prioridad: `hangoutLink` → `conferenceData.entryPoints[type == "video"].uri` → URLs en `location` → URLs en `description`. Regex de dominios: `meet.google.com`, `*.zoom.us/j/`, `teams.microsoft.com/l/meetup-join`, `*.webex.com`. Primera coincidencia gana. Tests con fixtures.

---

## 4. Features TCA

### `AppFeature` (raíz)
- State: `auth: AuthState` (`.signedOut | .signedIn(email)`), `events: IdentifiedArrayOf<CalendarEvent>`, `nextAlert: ScheduledAlert?`, `@Shared(.appStorage("settings")) settings`, `firedAlerts: Set<String>` (en memoria), `@Presents alert: AlertFeature.State?`, `menuBar: MenuBarFeature.State`, `settingsWindow: SettingsFeature.State?`, `onboarding: OnboardingFeature.State?`, `lastSyncError: String?`.
- Actions: `task` (arranque), `authChanged`, `refreshTick`, `eventsResponse(Result)`, `scheduleNext`, `alertDue(CalendarEvent)`, `systemWoke`, `settingsChanged`, hijos.
- Efectos:
  - `.task`: `authClient.restorePreviousSignIn()`; si signed in → `refreshEvents`; suscribirse a `workspaceClient.wakeNotifications()`; loop `for await _ in clock.timer(interval: .seconds(60)) { send(.refreshTick) }`.
  - `refreshEvents`: `calendarClient.upcomingEvents(window: 24h)` → filtra según settings → `scheduleNext`.
  - `scheduleNext`: `AlertScheduler.next(events:, now:, leadTime:, fired:)` → cancela efecto anterior (`cancellable(id: CancelID.alertTimer)`) → `clock.sleep(until fireAt)` → `send(.alertDue(event))`. Tolerancia: si `fireAt` ya pasó pero `event.start > now`, dispara inmediatamente.
  - `alertDue`: marca `firedAlerts`, `soundClient.play()` si procede, `alert = AlertFeature.State(event:, startsAt:)`, `alertPresenterClient.show()`, luego `scheduleNext`.
  - Dedupe: clave `"\(event.id)|\(event.start.timeIntervalSince1970)"`. Purgar claves de eventos ya terminados en cada refresh.

### `AlertFeature`
- State: `event`, `secondsRemaining: Int` (puede ser negativo), `phase: .countingDown | .startingNow (0…59 s tras el inicio) | .started(minutesAgo)`, `reduceMotion`.
- Actions: `task` (timer 1 s con `clock`), `tick`, `joinTapped`, `dismissed(DismissReason)` (`.click | .key | .quitShortcut | .button`), `delegate(.joined | .dismissed)`.
- `joinTapped`: `openURL(meetingLink.url)` (si no hay link, abre `htmlLink`), luego dismiss.
- **Sin auto-cierre.** La alerta permanece hasta que el usuario interactúa. La captura de clics y teclas la hace `AlertWindowController` (AppKit) y la traduce en `.dismissed(reason)` al store.
- Si durante una alerta visible llega otro `alertDue` (dos reuniones seguidas), se reemplaza el evento mostrado.

### `MenuBarFeature`
- State derivado: próximos 5 eventos del día, estado de conexión, countdown al próximo.
- Actions: `openSettings`, `connectGoogle`, `refreshNow`, `previewAlert` (dispara en 5 s una alerta con el evento ficticio "Hey You! test" enlazando a la web del proyecto; disponible también en Release, PRD caso B.15), `quit`.
- Icono del status item: SF Symbol `bell` con el texto "Xm" cuando quedan <10 min; `bell.slash` cuando la sesión de Google se ha perdido. Menú muestra "Sin conexión desde hh:mm" si el último refresco falló por red (PRD §5.10; casos B.13, B.14).

### `SettingsFeature`
- Form SwiftUI con: cuenta (email, Disconnect), lead time (Picker), calendarios (lista con toggles, cargada de `calendarClient.calendars()`), Launch at login (Toggle → `launchAtLoginClient.set(_:)`; reflejar `SMAppService.status`), sonido, filtros (declined, all-day, solo con enlace), botón "Test alert" (dispara `previewAlert` también en Release: es una feature de usuario legítima), versión, enlaces privacidad.

### `OnboardingFeature`
- Pantalla única de bienvenida (ventana normal 480×560): explica qué hace la app, botón "Connect Google Calendar" → `authClient.signIn()` → al éxito cierra y arranca sync. Muestra errores.
- La ventana de onboarding/Settings sirve de `ASPresentationAnchor` para `ASWebAuthenticationSession`.

---

## 5. Clientes (dependencias TCA)

Cada cliente: `struct XClient { var op: @Sendable (...) async throws -> ... }`, `extension XClient: DependencyKey { static let liveValue; static let testValue (unimplemented); static let previewValue (mock) }`, `extension DependencyValues { var xClient }`.

- **`AuthClient`**: `signIn(presenting: NSWindow) async throws -> GoogleAccount`, `signOut()`, `restorePreviousSignIn() async -> GoogleAccount?`, `accessToken() async throws -> String`, `accountStream() -> AsyncStream<GoogleAccount?>`.
  - Live: envuelve `GIDSignIn.sharedInstance` (paquete SPM `https://github.com/google/GoogleSignIn-iOS`, producto `GoogleSignIn`, versión 7.x o superior; soporta macOS 10.15+). `signIn(withPresenting: window, hint: nil, additionalScopes: ["https://www.googleapis.com/auth/calendar.readonly"])`; comprobar que `grantedScopes` incluye el scope y si no, `addScopes`. `accessToken()` usa `user.refreshTokensIfNeeded()` y devuelve `user.accessToken.tokenString`. El SDK guarda las credenciales en Keychain por sí mismo (no hace falta `KeychainClient` propio; eliminarlo del plan si no se usa).
  - Configuración: `GIDClientID` en `Info.plist` (desde `Secrets.xcconfig`) y `CFBundleURLTypes` con el client ID invertido. En `AppDelegate`, `application(_:open:)` → `GIDSignIn.sharedInstance.handle(url)`.
  - Si `GIDClientID` es `REPLACE_ME` → `AuthError.notConfigured` con mensaje claro en la UI.
  - Mock: `GoogleAccount(email: "demo@example.com")` inmediato.
- **Botón "Sign in with Google"** (`GoogleSignInButton` en `UI/DesignSystem`): SwiftUI, siguiendo las guías de branding de Google (fondo blanco, borde `#747775` 1 pt, radio 4 pt, alto 40 pt, logo "G" multicolor oficial a la izquierda a 20×20, texto "Sign in with Google" en Roboto Medium 14 pt o, si no se embebe Roboto, SF Pro Medium 14 pt, `#1F1F1F`; estado hover y pressed). El logo se guarda en `Assets.xcassets/google_g` como PDF/SVG descargado de los recursos de branding de Google (https://developers.google.com/identity/branding-guidelines). No alterar colores ni proporciones del logo.
- **`CalendarClient`**: `calendars() async throws -> [CalendarSummary]`, `upcomingEvents(from: Date, to: Date, calendarIDs: Set<String>?) async throws -> [CalendarEvent]`.
  - Google: `GET /calendar/v3/users/me/calendarList` y `GET /calendar/v3/calendars/{id}/events?singleEvents=true&orderBy=startTime&timeMin=&timeMax=&maxResults=250` por cada calendario seleccionado (en paralelo con `withThrowingTaskGroup`). Mapear `attendees[self==true].responseStatus`. Errores 401 → intentar refresh una vez → si falla, `authChient.signOut()` y estado `.signedOut` con aviso en menú.
  - Mock: eventos generados relativos a `now` (uno en 90 s, otro en 2 h, uno all-day, uno declinado).
- **`AlertPresenterClient`**: `show(store: StoreOf<AlertFeature>)`, `dismiss()`, `isShowing() -> Bool`. Live: `AlertWindowController` (MainActor) que crea una `NSWindow` (subclase `AlertWindow` con `canBecomeKey = true`) por `NSScreen` con `NSHostingView(rootView: AlertView(store:))`, estilo `.borderless`, `isOpaque`, `backgroundColor = .clear`, `level = .screenSaver`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`, `hidesOnDeactivate = false`, `makeKeyAndOrderFront`, `NSApp.activate(ignoringOtherApps: true)`. Escucha `NSApplication.didChangeScreenParametersNotification` para rehacer ventanas si cambian pantallas. `dismiss()` cierra todas con fade-out (0.25 s).
  - **Descartar con cualquier interacción**: `AlertWindow` sobreescribe `mouseDown`/`rightMouseDown` (clic en cualquier punto que no sea el botón Unirse → `.dismissed(.click)`), `keyDown` (cualquier tecla → `.dismissed(.key)`; Enter → `joinTapped`), `cancelOperation` (Esc). Para Cmd+Q / Cmd+W / Cmd+.: un `NSEvent.addLocalMonitorForEvents(matching: .keyDown)` activo solo mientras la alerta está visible intercepta `q`, `w`, `.` con `.command` y envía `.dismissed(.quitShortcut)` devolviendo `nil` (consume el evento). Además `AppDelegate.applicationShouldTerminate` devuelve `.terminateCancel` y descarta la alerta si `isShowing()`; cuando no hay alerta, Cmd+Q desde el menú sale normalmente.
  - Si el usuario cambia de app con Cmd+Tab o clic en otra pantalla, la alerta sigue encima (nivel screenSaver); no se descarta por perder el foco, pero cualquier clic sobre ella sí.
- **`LaunchAtLoginClient`**: `status() -> Bool`, `set(Bool) throws` sobre `SMAppService.mainApp`.
- **`WorkspaceClient`**: `wakeNotifications() -> AsyncStream<Void>` (`NSWorkspace.shared.notificationCenter`, `didWakeNotification` y `screensDidWakeNotification`).
- **`SoundClient`**: `play()` → `NSSound(named: .init("Funk"))` o un `.caf` propio en Assets. Respeta `settings.playSound`.
- **`OpenURLClient`**: `NSWorkspace.shared.open`.
- Usar `@Dependency(\.continuousClock)`, `@Dependency(\.date)`, `@Dependency(\.uuid)` siempre; nunca `Date()` directo en reducers.

---

## 6. Diseño visual de la alerta (`AlertView`)

Objetivo: bonita, premium, imposible de no ver. Tema único (siempre rojo), independiente del modo claro/oscuro.

- **Fondo**: gradiente radial de `#E0263A` (centro) a `#8E0F1E` (bordes), con un overlay de "pulso" (círculo concéntrico que se expande y desvanece cada 1.2 s, `opacity` 0.25→0). Desactivar animaciones si `accessibilityReduceMotion`.
- **Layout (centrado, vertical, max width 720)**:
  1. Etiqueta superior en caps, tracking 4, 14 pt, blanco 80 %: `"MEETING IN"` / `"REUNIÓN EN"`.
  2. **Countdown**: número gigante `secondsRemaining` (SF Pro Rounded, black, 180 pt, monospaced digits) con sufijo `s`. Al llegar a 0: `"NOW"` / `"AHORA"` con escala 1.0→1.08 en loop suave durante el primer minuto; después, la etiqueta superior cambia a `"STARTED 3 MIN AGO"` / `"EMPEZÓ HACE 3 MIN"` y el número muestra los minutos transcurridos.
  3. **Anillo de progreso** alrededor del número (stroke 10 pt, blanco 90 %, `trim` de `secondsRemaining / leadTimeSeconds`, cap redondeado).
  4. **Título del evento**: 44 pt, bold, blanco, 2 líneas máx, centrado.
  5. Línea de meta: `"10:00 – 10:30 · Google Meet"` 20 pt blanco 85 %, icono del proveedor (SF Symbols: `video.fill`).
  6. **Botón** primario **"Join meeting"** pill blanca 56 pt alto, texto rojo bold 20 pt, icono `arrow.right`, `keyboardShortcut(.defaultAction)`. Si no hay enlace: pasa a ser "Open in Calendar". No hay botón "Dismiss": lo sustituye el pie.
  7. Pie: `"Click anywhere or press any key to dismiss"` / `"Haz clic o pulsa cualquier tecla para descartar"` 16 pt blanco 60 %.
- **Entrada**: la ventana aparece con fade 0.2 s y el contenido escala 0.96→1.0 (spring). **Salida**: fade 0.25 s.
- Multi-monitor: misma vista en cada pantalla; los botones funcionan en todas.
- Todo texto localizado (en/es). Tipografías: `.system(.., design: .rounded)`.

El menú bar y Settings usan estilo nativo macOS (sin tema rojo).

---

## 7. Hitos (ejecutar en orden, commit al final de cada uno)

Formato de commit: `feat(scope): …` / `chore: …` / `test: …`. Antes de cada commit: `swiftformat .`, `swiftlint`, y build verde.

### Hito 1 — Bootstrap del repo
- `.gitignore` (Xcode, SPM `.build`, `*.xcodeproj`, `Config/Secrets.xcconfig`, `DerivedData`, `.DS_Store`).
- `README.md` (qué es, cómo construir, cómo configurar Google OAuth, paso a paso para el usuario).
- `.swiftlint.yml`, `.swiftformat` (reglas razonables; `--swiftversion 6`).
- `scripts/bootstrap.sh`, `scripts/build.sh`, `scripts/test.sh`.
- `HeyYouKit/Package.swift` con TCA; `swift build` compila un `Models` vacío.
- **Aceptación**: `swift build` en `HeyYouKit` OK. Commit `chore: bootstrap project`.

### Hito 2 — Modelos, parser de enlaces y scheduler (lógica pura, 100 % testeada)
- `CalendarEvent`, `MeetingLink`, `MeetingLinkParser`, `AppSettings`, `LeadTime`, `ScheduledAlert`.
- `AlertScheduler.next(events:now:leadTime:fired:settings:) -> ScheduledAlert?` (pura): aplica filtros (all-day, declined, sin link si procede, calendarios), descarta eventos ya empezados hace >0 s, elige el de `fireAt` mínimo no disparado. Dos eventos a la misma hora → una sola alerta con el primero por orden alfabético, subtítulo "+1 more" (`ScheduledAlert.additionalCount`), y ambos se marcan como fired al disparar (PRD §5.3, caso B.9).
- Tests (Swift Testing): parser (Meet/Zoom/Teams/Webex/sin link/location vs description), scheduler (lead time, dedupe, filtros, evento pasado, orden, cambio de leadTime).
- **Aceptación**: `swift test` verde (si Xcode está instalado; si no, deja los tests escritos y compila con `swift build`). Commit.

### Hito 3 — Clientes de Google (auth + calendar)
- Añadir `GoogleSignIn-iOS` a `Package.swift` (producto `GoogleSignIn`). Verificar que compila para macOS con `swift build`.
- `AuthClient.live` sobre `GIDSignIn` (ver §5); `AuthClient.mock`. `GIDClientID` leído de `Info.plist` (inyectado desde `Secrets.xcconfig`); si es `REPLACE_ME`, `AuthError.notConfigured`.
- `GoogleCalendarAPI` con `URLSession` inyectable (`URLProtocol` stub en tests), DTOs `Decodable`, mapeo a `CalendarEvent` (parsear `dateTime` con offset y `date` all-day). Token obtenido vía `authClient.accessToken()` en cada petición.
- Tests: decodificación de fixtures JSON reales de la API (incluir fixtures en `Tests/Fixtures`), 401 → signOut, mapeo de `responseStatus`.
- **Aceptación**: tests verdes, `swift build` OK. Commit.

### Hito 4 — Features TCA (reducers) con tests
- `AppFeature`, `AlertFeature`, `MenuBarFeature`, `SettingsFeature`, `OnboardingFeature` según §4, con `Reducer` macros, `@ObservableState`, `@Dependency`.
- Tests `TestStore` con `TestClock` que cubran los casos B.1–B.9 del PRD (anexo B) con sus fechas exactas, además de: arranque → refresh → scheduleNext → avanzar reloj → `alertDue` → alert presentada; dedupe tras segundo refresh; wake recalcula; cambiar leadTime reprograma; alert join/dismiss cierra; token caducado → signedOut.
- **Aceptación**: tests verdes. Commit.

### Hito 5 — UI SwiftUI + ventana de alerta AppKit
- `DesignSystem` (colores en Assets + `Color` extensions, estilos de botón), `AlertView` según §6, `MenuBarView` (`MenuBarExtra` con `.window` style: lista de próximos eventos, countdown, botones), `SettingsView`, `OnboardingView`.
- `AlertWindowController` (`AlertPresenterClient.live`).
- Previews de SwiftUI con `previewValue`s.
- **Aceptación**: compila; previews declaradas. Commit.

### Hito 6 — Target de app, Info.plist, entitlements, XcodeGen
- `project.yml`: target `HeyYou` (macOS app, deployment 14.0, `SWIFT_STRICT_CONCURRENCY = complete`, `ENABLE_HARDENED_RUNTIME = YES`, `CODE_SIGN_ENTITLEMENTS`, xcconfigs), dependencia del paquete local, schemes `HeyYou` (build/run/test) con test target `HeyYouKitTests`.
- `Info.plist`: `LSUIElement = YES`, `CFBundleURLTypes` con scheme `$(GOOGLE_REVERSED_CLIENT_ID)`, `GoogleClientID = $(GOOGLE_CLIENT_ID)`, `NSHumanReadableCopyright`, `LSApplicationCategoryType = public.app-category.productivity`, `ITSAppUsesNonExemptEncryption = NO`.
- `HeyYou.entitlements`: `com.apple.security.app-sandbox = YES`, `com.apple.security.network.client = YES`.
- `HeyYouApp.swift`: `@main struct HeyYouApp: App` con `@NSApplicationDelegateAdaptor`, `let store = Store(initialState: AppFeature.State()) { AppFeature() }`, `MenuBarExtra`, `Settings { SettingsView }`, `Window("Onboarding")`. En `DEBUG`, si `ProcessInfo.processInfo.arguments.contains("--mock-calendar")`, usar `withDependencies { $0.calendarClient = .mock; $0.authClient = .mock }`.
- AppIcon: generar un icono simple (campana blanca sobre fondo rojo) como PNGs 16…1024 con un script (`swift` o `sips`/CoreGraphics) en `scripts/make-icon.swift`.
- **Aceptación**: `xcodegen generate && xcodebuild -scheme HeyYou -configuration Debug build` OK (requiere Xcode). Si no hay Xcode: dejar todo preparado y `swift build` del paquete verde. Commit.

### Hito 7 — Verificación manual end-to-end (requiere Xcode)
- Ejecutar a mano los casos B.10–B.15 del PRD y anotar el resultado en `docs/QA.md`.
- Lanzar la app con `--mock-calendar`: aparece en menu bar, el evento mock en 90 s dispara la alerta a los 30 s (leadTime 60 s) en **todas** las pantallas, sobre apps full-screen; Enter abre el link; Esc, cualquier tecla, clic en cualquier punto, Cmd+Q y Cmd+W descartan la alerta **sin cerrar la app**; sin interacción la alerta sigue visible pasados 5 min y muestra "Empezó hace 5 min"; sonido suena; el status item muestra el countdown. Cmd+Q sin alerta visible cierra la app.
- Onboarding: el botón "Sign in with Google" sigue el branding de Google y al pulsarlo (con `Secrets.xcconfig` configurado) abre la ventana de consentimiento de Google.
- Probar Settings → Launch at login (ver estado en System Settings → General → Login Items).
- Probar el flujo real de OAuth si el usuario ya ha rellenado `Secrets.xcconfig`; si no, documentar en README exactamente cómo hacerlo.
- Hacer capturas de pantalla (`screencapture`) de la alerta y del menú y guardarlas en `docs/screenshots/`.
- Corregir lo que falle. Commit `fix:`/`polish:`.

### Hito 8 — Calidad final
- SwiftLint 0 warnings, SwiftFormat aplicado, Swift 6 strict concurrency sin warnings.
- Localización completa es/en (revisar que no haya strings hardcodeados: `swiftlint` regla `nslocalizedstring`? → usar `String(localized:)`).
- Accesibilidad: labels en botones, `reduceMotion`, contraste AA (blanco sobre `#B5121F` ≥ 4.5:1).
- README final con GIF/capturas, FAQ (¿por qué pide Google? ¿qué datos guarda? solo lectura, tokens en Keychain, nada sale del Mac salvo a Google).
- `PRIVACY.md` (política de privacidad en en/es, necesaria para App Store y para la verificación OAuth de Google).
- Commit.

### Hito 9 — Preparación App Store (documentar; ejecutar lo que no requiera credenciales)
- `docs/APP_STORE.md` con checklist: cuenta Apple Developer, App ID = bundle id, certificado *Apple Distribution* + *Mac App Store* provisioning (Xcode automatic signing con el Team), Archive → Distribute → App Store Connect, metadatos (nombre "Hey You!", subtítulo "Never be late to a meeting again", categoría Productivity, keywords, descripción en/es, capturas 1280×800/2560×1600, privacy nutrition labels: datos no recogidos; solo acceso a calendario vía Google con consentimiento), URL privacidad, notas para el revisor (cómo probar: usar botón "Test alert" en Settings, explicar que `LSUIElement` y launch-at-login son opt-in).
- `project.yml` ya con `DEVELOPMENT_TEAM = $(TEAM_ID)` desde `Secrets.xcconfig`.
- Comando documentado: `xcodebuild -scheme HeyYou -configuration Release archive -archivePath build/HeyYou.xcarchive` y `xcodebuild -exportArchive -exportOptionsPlist Config/ExportOptions.plist` (method `app-store-connect`).
- **Aceptación**: documentación completa; archive verde si hay Team configurado. Commit final y `git push origin main`.

---

## 8. Reglas de implementación para el agente

1. **No preguntes** salvo bloqueo real; toma la decisión de este plan. Si falta Xcode, Team ID o Client ID: sigue con placeholders/mocks y deja instrucciones en README.
2. Swift 6, `strict concurrency = complete`, sin `@unchecked Sendable` salvo justificación en comentario; sin force unwraps ni `try!` fuera de tests; `MainActor` explícito en AppKit.
3. Toda lógica en `HeyYouKit`; `App/` solo wiring. Nada de lógica en vistas: las vistas leen `store.state` y envían acciones.
4. Dependencias siempre vía `@Dependency`; `testValue` = `unimplemented` (TCA lo hace por defecto con `@DependencyClient`). Usa la macro `@DependencyClient`.
5. Cada feature tiene tests `TestStore` exhaustivos (`exhaustivity = .on`).
6. Strings de UI con `String(localized:)` y claves en `Localizable.xcstrings` (en/es).
7. Comprueba la API real de TCA de la versión resuelta (`Package.resolved`) antes de escribir código: `@Reducer`, `@ObservableState`, `@Presents`, `@Shared`, `Store`/`Scope`, `.ifLet`, `Effect.run`, `clock.sleep(until:)` (vía `swift-clocks`). Si una API no existe, lee el código fuente en `.build/checkouts/swift-composable-architecture`.
8. Compila (`swift build` o `xcodebuild`) tras cada feature, no solo al final. Un hito no está hecho si no compila.
9. Un commit por hito como mínimo; mensajes en inglés; nunca `--force`.
10. Si el hito 7 no se puede hacer (sin Xcode), dilo explícitamente en el resumen final; no lo des por verificado.

---

## 9. Riesgos conocidos y mitigación

| Riesgo | Mitigación |
|---|---|
| Sin Xcode no hay tests ni bundle .app | Toda la lógica compila con `swift build`; avisar al usuario pronto |
| `GIDSignIn.signIn(withPresenting:)` necesita una `NSWindow` en una app sin ventanas | Usar la ventana de Onboarding/Settings; abrirla antes de `signIn()` |
| `GoogleSignIn-iOS` trae dependencias (AppAuth, GTMAppAuth, GTMSessionFetcher) y podría no compilar en macOS con `swift build` | Es soportado oficialmente en macOS; si falla, fijar versión 7.1+ y compilar vía `xcodebuild`. Último recurso: OAuth PKCE propio con `ASWebAuthenticationSession` manteniendo el mismo botón y `AuthClient` |
| Cmd+Q interceptado mientras hay alerta podría parecer que la app "bloquea" | Solo se intercepta con alerta visible y la acción es descartar la alerta (lo que el usuario quería); documentar en notas al revisor de App Store |
| Ventana no aparece sobre apps full-screen | `collectionBehavior` incluye `.fullScreenAuxiliary` + `.canJoinAllSpaces`; `level = .screenSaver`; probar en hito 7 |
| Reloj dormido: el `clock.sleep` no dispara al despertar | Recalcular en `didWakeNotification`; si `fireAt` quedó atrás pero el evento no ha empezado, disparar al instante |
| Rate limits de Google | Refresco cada 60 s de pocos calendarios está muy por debajo de los límites; usar `fields=` para reducir payload |
| Revisión App Store: app sin UI visible | Onboarding al primer arranque + Settings accesibles desde menu bar; explicar en notas al revisor |
| Launch at login en sandbox | `SMAppService.mainApp` está soportado; si `status == .requiresApproval`, mostrar texto que lleve a System Settings |
