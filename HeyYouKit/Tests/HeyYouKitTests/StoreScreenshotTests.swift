import AppKit
import ComposableArchitecture
@testable import HeyYouKit
import SwiftUI
import Testing

/// Mac App Store screenshots (2880×1800, no alpha): the real views inside marketing frames with a headline,
/// laid out on `StoreGrid`.
/// Opt-in, one language per run: `./scripts/make-store-screenshots.sh` renders English and Spanish into `docs/store/screenshots`.
@MainActor
@Suite(.enabled(if: ProcessInfo.processInfo.environment["HEYYOU_STORE_SHOTS"] != nil), .serialized)
struct StoreScreenshotTests {
    static let canvas = CGSize(width: 1440, height: 900)

    let language = StoreLanguage.code
    var isSpanish: Bool {
        language == "es"
    }

    var folder: URL {
        URL(fileURLWithPath: ProcessInfo.processInfo.environment["HEYYOU_STORE_SHOTS"] ?? ".")
    }

    /// Picks the copy for the language of this run.
    func copy(_ english: String, _ spanish: String) -> String {
        isSpanish ? spanish : english
    }

    // MARK: - Fixtures

    /// A Tuesday at 11:00 local time.
    static let meetingStart: Date = Calendar.current.date(
        from: DateComponents(year: 2026, month: 11, day: 17, hour: 11)
    ) ?? Date(timeIntervalSince1970: 1_793_700_000)

    func event(
        _ id: String, _ title: String, hour: Int, minute: Int = 0, minutes: Int = 30,
        provider: MeetingLink.Provider? = .googleMeet, status: AttendeeStatus = .accepted
    ) -> CalendarEvent {
        let start = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Self.meetingStart) ?? Self.meetingStart
        return CalendarEvent(
            id: id, title: title, start: start, end: start.addingTimeInterval(TimeInterval(minutes * 60)),
            meetingLink: provider.map { MeetingLink(provider: $0, url: AppConfig.projectURL) }, attendeeStatus: status
        )
    }

    var weekly: CalendarEvent {
        event("weekly", copy("Weekly sync", "Sync semanal"), hour: 11)
    }

    func alert(_ event: CalendarEvent, secondsFromStart: TimeInterval) -> some View {
        AlertView(
            store: Store(initialState: AlertFeature.State(event: event, now: event.start.addingTimeInterval(secondsFromStart))) {
                EmptyReducer()
            },
            animateEntrance: false
        )
    }

    func setPro(_ isPro: Bool) {
        @Shared(.entitlements) var entitlements
        $entitlements.withLock { $0 = Entitlements(isPro: isPro, proDefaultsApplied: isPro) }
    }

    // MARK: - Frames

    @Test func frame1Hero() throws {
        try write(
            StoreFrame(
                headline: copy(
                    "20 seconds before every meeting,\nyour whole screen turns red.",
                    "20 segundos antes de cada reunión,\ntoda tu pantalla se pone roja."
                ),
                subline: copy("The meeting reminder you can't miss.", "El aviso de reunión que no puedes pasar por alto.")
            ) {
                DisplayMock(screenSize: Self.canvas, width: StoreGrid.displayWidth) { alert(weekly, secondsFromStart: -17) }
            },
            name: "01-alert"
        )
    }

    @Test func frame2EveryScreen() throws {
        try write(
            StoreFrame(
                headline: copy(
                    "On every display.\nEven over full-screen apps.",
                    "En todas tus pantallas.\nTambién sobre apps a pantalla completa."
                ),
                subline: copy("Wherever you're looking, that's where it shows up.", "Mires donde mires, ahí aparece.")
            ) {
                // 740 + 40 + 468 = 1248, the full width between the side margins.
                HStack(alignment: .bottom, spacing: 40) {
                    DisplayMock(screenSize: Self.canvas, width: 720) { alert(weekly, secondsFromStart: -17) }
                    DisplayMock(screenSize: CGSize(width: 1280, height: 800), width: 448) { alert(weekly, secondsFromStart: -17) }
                }
                .frame(height: StoreGrid.stageHeight, alignment: .bottom)
            },
            name: "02-every-screen"
        )
    }

    @Test func frame3JoinOrDismiss() throws {
        let demo = event("demo", copy("Client demo", "Demo con cliente"), hour: 11, minutes: 45, provider: .zoom)
        try write(
            StoreFrame(
                headline: copy("Enter joins the call.\nEsc makes it go away.", "Enter te une a la llamada.\nEsc la quita."),
                subline: copy(
                    "Meet, Zoom, Teams and Webex links. It never locks your Mac.",
                    "Enlaces de Meet, Zoom, Teams y Webex. Nunca bloquea tu Mac."
                )
            ) {
                ZStack(alignment: .topTrailing) {
                    DisplayMock(screenSize: CGSize(width: 1200, height: 750), width: StoreGrid.displayWidth) {
                        alert(demo, secondsFromStart: -12)
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        Keycap(key: "⏎", label: copy("Join", "Unirse"))
                        Keycap(key: "esc", label: copy("Dismiss", "Descartar"))
                    }
                    .padding(.top, 104)
                    .padding(.trailing, 48)
                }
            },
            name: "03-join-or-dismiss"
        )
    }

    @Test func frame4Started() throws {
        let review = event("review", copy("Design review", "Revisión de diseño"), hour: 11, minutes: 60, provider: .teams)
        try write(
            StoreFrame(
                headline: copy("Stepped away?\nIt waits for you.", "¿Te habías levantado?\nTe espera."),
                subline: copy(
                    "It stays until you react, and tells you how late you are.",
                    "Se queda hasta que reaccionas y te dice cuánto llegas tarde."
                )
            ) {
                DisplayMock(screenSize: Self.canvas, width: StoreGrid.displayWidth) { alert(review, secondsFromStart: 190) }
            },
            name: "04-started"
        )
    }

    @Test func frame5MenuBar() throws {
        setPro(false)
        var state = AppFeature.State()
        state.auth = .signedIn(GoogleAccount(email: "you@example.com"))
        state.calendars = [
            CalendarSummary(id: "work", name: "Work", isPrimary: true),
            CalendarSummary(id: "team", name: "Team"),
            CalendarSummary(id: "personal", name: "Personal"),
        ]
        let events = [
            weekly,
            event("ana", copy("1:1 with Ana", "1:1 con Ana"), hour: 12, minute: 30, provider: .zoom),
            event("review", copy("Design review", "Revisión de diseño"), hour: 15, minutes: 60, provider: .teams),
            event("demo", copy("Client demo", "Demo con cliente"), hour: 16, minute: 30, minutes: 45, provider: .zoom),
            event("retro", "Retro", hour: 17, minute: 30, provider: .webex),
        ]
        state.events = IdentifiedArray(uniqueElements: events)
        state.now = Self.meetingStart.addingTimeInterval(-8 * 60)
        state.nextAlert = ScheduledAlert(event: weekly, fireAt: weekly.start.addingTimeInterval(-TimeInterval(LeadTime.free)))
        let store = Store(initialState: state) { EmptyReducer<AppFeature.State, AppFeature.Action>() }

        try write(
            StoreFrame(
                headline: copy("Quiet until it matters.", "Callada hasta que hace falta."),
                subline: copy(
                    "Today's meetings in your menu bar. No Dock icon, no windows.",
                    "Tus reuniones de hoy en la barra de menús. Sin icono en el Dock."
                )
            ) {
                DisplayMock(screenSize: CGSize(width: 800, height: 500), width: StoreGrid.displayWidth) {
                    DesktopMock(clock: TimeText.time(state.now)) {
                        MenuBarView(store: store)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(white: 0.97)))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.black.opacity(0.12)))
                            .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
                            .environment(\.colorScheme, .light)
                    }
                }
            },
            name: "05-menu-bar"
        )
    }

    @Test func frame6Privacy() throws {
        let onboarding = try snapshot(
            OnboardingView(store: Store(initialState: OnboardingFeature.State()) { EmptyReducer() }),
            size: CGSize(width: 480, height: StoreGrid.stageHeight - StoreGrid.titleBarHeight), background: .white
        )
        try write(
            StoreFrame(
                headline: copy("Your calendar never\nleaves your Mac.", "Tu calendario no sale\nde tu Mac."),
                subline: copy(
                    "Read-only Google sign-in. No Hey You! account, no servers of ours.",
                    "Google en solo lectura. Sin cuenta propia ni servidores nuestros."
                )
            ) {
                WindowMock(image: onboarding, title: "Hey You!")
            },
            name: "06-privacy"
        )
    }

    @Test func frame7Pro() throws {
        setPro(true)
        defer { setPro(false) }
        @Shared(.appSettings) var settings
        $settings.withLock {
            $0 = AppSettings(
                leadTimeSeconds: 30, launchAtLogin: true, ignoreDeclined: true, ignoreWithoutOtherAttendees: true,
                onlyEventsWithMeetingLink: true, sound: .chime, workingHours: nil
            )
        }
        defer { $settings.withLock { $0 = AppSettings() } }

        var state = SettingsFeature.State(account: GoogleAccount(email: "you@example.com"))
        state.launchAtLogin = .enabled
        state.calendars = [
            CalendarSummary(id: "work", name: copy("Work", "Trabajo"), isPrimary: true),
            CalendarSummary(id: "team", name: copy("Team", "Equipo")),
            CalendarSummary(id: "personal", name: "Personal"),
        ]
        // The Alert and Filters sections: the window is scrolled to them and cut right after.
        let windowHeight: CGFloat = 478
        let settingsImage = try Self.cropTop(
            snapshot(
                SettingsView(store: Store(initialState: state) { EmptyReducer() }),
                size: CGSize(width: 520, height: 680), scrollOffset: 236
            ),
            height: windowHeight - StoreGrid.titleBarHeight
        )
        var paywall = PaywallFeature.State(source: .menu)
        paywall.isLoading = false
        paywall.products = [StoreProduct(id: AppConfig.proProductID, displayName: "Hey You! Pro", displayPrice: copy("$5.99", "5,99 €"))]
        let paywallImage = try snapshot(
            PaywallView(store: Store(initialState: paywall) { EmptyReducer() }),
            size: CGSize(width: 420, height: windowHeight), background: .white
        )
        try write(
            StoreFrame(
                headline: copy("Pro: you decide when,\nand for what.", "Pro: tú decides cuándo\ny de qué."),
                subline: copy(
                    "Lead time, filters, calendars and hours. One-time purchase.",
                    "Tiempo de aviso, filtros, calendarios y horario. Compra única."
                )
            ) {
                HStack(alignment: .center, spacing: 48) {
                    WindowMock(image: settingsImage, title: copy("Settings", "Ajustes"))
                    WindowMock(image: paywallImage, title: nil)
                }
            },
            name: "07-pro"
        )
    }

    // MARK: - Rendering

    /// Renders a view with AppKit-backed controls (toggles, sliders, pickers), which `ImageRenderer` can't draw.
    func snapshot(_ view: some View, size: CGSize, background: Color = .clear, scrollOffset: CGFloat = 0) throws -> NSImage {
        let host = NSHostingView(
            rootView: view.frame(width: size.width, height: size.height).background(background)
                .tint(Color.alertCrimson) // the app's AccentColor
                .environment(\.colorScheme, .light)
        )
        host.frame = CGRect(origin: .zero, size: size)
        host.appearance = NSAppearance(named: .aqua)
        let window = ActiveWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        if scrollOffset > 0, let scroll = Self.firstScrollView(in: host) {
            scroll.contentView.scroll(to: NSPoint(x: 0, y: scrollOffset))
            scroll.reflectScrolledClipView(scroll.contentView)
            scroll.hasVerticalScroller = false
            RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        }
        let rep = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size.width * 2), pixelsHigh: Int(size.height * 2), bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        rep.size = size
        host.cacheDisplay(in: host.bounds, to: rep)
        let image = NSImage(size: size)
        image.addRepresentation(rep)
        return image
    }

    /// The top `height` points of a snapshot.
    static func cropTop(_ image: NSImage, height: CGFloat) throws -> NSImage {
        let source = try #require(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let scale = CGFloat(source.width) / image.size.width
        let cropped = try #require(source.cropping(to: CGRect(x: 0, y: 0, width: CGFloat(source.width), height: height * scale)))
        return NSImage(cgImage: cropped, size: CGSize(width: image.size.width, height: height))
    }

    static func firstScrollView(in view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView {
            return scroll
        }
        return view.subviews.lazy.compactMap(firstScrollView(in:)).first
    }

    /// Writes an opaque 2880×1800 PNG (App Store Connect rejects screenshots with an alpha channel).
    func write(_ view: some View, name: String) throws {
        let renderer = ImageRenderer(content: view.environment(\.locale, Locale(identifier: language)))
        renderer.scale = 2
        let rendered = try #require(renderer.cgImage)
        let width = Int(Self.canvas.width * 2)
        let height = Int(Self.canvas.height * 2)
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.draw(rendered, in: CGRect(x: 0, y: 0, width: width, height: height))
        let opaque = try #require(context.makeImage())
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let png = try #require(NSBitmapImageRep(cgImage: opaque).representation(using: .png, properties: [:]))
        try png.write(to: folder.appendingPathComponent("\(name).png"))
    }
}

/// Language of this run. `String(localized:)` follows the process language, and a bundle is normally tied to the
/// language of the main bundle (the test runner, English only), so the runner is told to allow mixed localizations.
enum StoreLanguage {
    static let code: String = {
        let code = ProcessInfo.processInfo.environment["HEYYOU_STORE_LANG"] ?? "en"
        if let info = CFBundleGetInfoDictionary(CFBundleGetMainBundle()) {
            CFDictionarySetValue(
                unsafeBitCast(info, to: CFMutableDictionary.self),
                Unmanaged.passUnretained("CFBundleAllowMixedLocalizations" as CFString).toOpaque(),
                Unmanaged.passUnretained(kCFBooleanTrue).toOpaque()
            )
        }
        UserDefaults.standard.setVolatileDomain(["AppleLanguages": [code]], forName: UserDefaults.argumentDomain)
        return code
    }()
}

/// Off-screen window that reports itself as key, so controls draw in their active (tinted) state.
private final class ActiveWindow: NSWindow {
    override var isKeyWindow: Bool {
        true
    }

    override var isMainWindow: Bool {
        true
    }

    /// AppKit asks these (private) selectors when deciding whether controls get the accent color.
    @objc(hasKeyAppearance) func storeHasKeyAppearance() -> Bool {
        true
    }

    @objc(_hasKeyAppearance) func storeHasKeyAppearancePrivate() -> Bool {
        true
    }

    @objc(hasMainAppearance) func storeHasMainAppearance() -> Bool {
        true
    }

    @objc(_hasActiveAppearance) func storeHasActiveAppearance() -> Bool {
        true
    }
}

// MARK: - Marketing chrome

/// Stage color behind every frame. `HEYYOU_STORE_BG=F9FAFC` overrides it (for trying other colors);
/// the text turns dark on a light background.
private enum StoreTheme {
    static let hex = UInt32(ProcessInfo.processInfo.environment["HEYYOU_STORE_BG"] ?? "", radix: 16) ?? 0xF9FAFC
    static let red = Double((hex >> 16) & 0xFF) / 255
    static let green = Double((hex >> 8) & 0xFF) / 255
    static let blue = Double(hex & 0xFF) / 255
    static let background = Color(red: red, green: green, blue: blue)
    static let isLight = 0.2126 * red + 0.7152 * green + 0.0722 * blue > 0.6
    static let text: Color = isLight ? Color(red: 0.09, green: 0.09, blue: 0.11) : .white
    /// Drop shadows are softer on a light stage.
    static let shadow = Color.black.opacity(isLight ? 0.28 : 0.55)
    static let edge: Color = isLight ? .black.opacity(0.12) : .white.opacity(0.25)
}

/// The grid every frame follows (points on the 1440×900 canvas, multiples of 8):
/// 96 side margins, 72 top and bottom, a 172-tall header, a 64 gap and a 520-tall stage for the app.
/// Everything fits inside the margins; nothing is cropped by the canvas edge.
enum StoreGrid {
    static let sideMargin: CGFloat = 96
    static let verticalMargin: CGFloat = 72
    static let headerHeight: CGFloat = 172
    static let gap: CGFloat = 64
    static let stageHeight: CGFloat = 520
    /// Black frame around a display mock.
    static let bezel: CGFloat = 10
    /// Widest screen that fits the stage at 16:10.
    static let displayWidth: CGFloat = (stageHeight - 2 * bezel) * 1.6
    static let titleBarHeight: CGFloat = 30
}

/// Stage with a soft red glow: a headline and one line of subline centered in the header, the app centered below.
private struct StoreFrame<Content: View>: View {
    let headline: String
    let subline: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                Text(verbatim: headline)
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .tracking(-0.5)
                    .lineSpacing(4)
                    .foregroundStyle(StoreTheme.text)
                    .multilineTextAlignment(.center)
                    .fixedSize()
                Text(verbatim: subline)
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(StoreTheme.text.opacity(0.62))
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(height: StoreGrid.headerHeight)
            content
                .frame(height: StoreGrid.stageHeight)
                .padding(.top, StoreGrid.gap)
        }
        .padding(.vertical, StoreGrid.verticalMargin)
        .padding(.horizontal, StoreGrid.sideMargin)
        .frame(width: 1440, height: 900, alignment: .top)
        .background(
            ZStack {
                StoreTheme.background
                RadialGradient(
                    colors: [
                        Color.alertRed.opacity(StoreTheme.isLight ? 0.1 : 0.55),
                        Color.alertRed.opacity(StoreTheme.isLight ? 0.03 : 0.18),
                        .clear,
                    ],
                    center: UnitPoint(x: 0.5, y: 0.63), startRadius: 0, endRadius: 680
                )
            }
        )
        .clipped()
    }
}

/// A generic display: black bezel around a screen laid out at `screenSize` and scaled to `width`.
private struct DisplayMock<Screen: View>: View {
    let screenSize: CGSize
    let width: CGFloat
    @ViewBuilder var screen: Screen

    var body: some View {
        let scale = width / screenSize.width
        screen
            .frame(width: screenSize.width, height: screenSize.height)
            .clipped()
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: width, height: screenSize.height * scale, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(StoreGrid.bezel)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.black))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.22), lineWidth: 1))
            .shadow(color: StoreTheme.shadow, radius: 40, y: 22)
    }
}

/// A window: title bar with the three dots over a pre-rendered image of the content.
private struct WindowMock: View {
    let image: NSImage
    let title: String?
    var scale: CGFloat = 1

    var body: some View {
        VStack(spacing: 0) {
            if let title {
                ZStack {
                    Color(white: 0.93)
                    HStack(spacing: 8) {
                        Circle().fill(Color(red: 1, green: 0.37, blue: 0.34))
                        Circle().fill(Color(red: 1, green: 0.74, blue: 0.18))
                        Circle().fill(Color(red: 0.16, green: 0.79, blue: 0.25))
                        Spacer()
                    }
                    .frame(height: 12)
                    .padding(.horizontal, 12)
                    Text(verbatim: title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(white: 0.25))
                }
                .frame(height: StoreGrid.titleBarHeight)
            }
            Image(nsImage: image).resizable().frame(width: image.size.width * scale, height: image.size.height * scale)
        }
        .frame(width: image.size.width * scale)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(StoreTheme.edge, lineWidth: 1))
        .shadow(color: StoreTheme.shadow, radius: 36, y: 20)
    }
}

/// The top-right corner of a desktop: a menu bar with the bell, the menu hanging from it and a window behind.
private struct DesktopMock<Menu: View>: View {
    let clock: String
    @ViewBuilder var menu: Menu

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(
                colors: [Color(red: 0.17, green: 0.17, blue: 0.19), Color(red: 0.33, green: 0.34, blue: 0.38)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            VStack(alignment: .leading, spacing: 11) {
                ForEach([0.55, 0.9, 0.8, 0.35, 0.0, 0.7, 0.95, 0.6, 0.85, 0.4, 0.0, 0.75, 0.5], id: \.self) { fraction in
                    Capsule().fill(.white.opacity(fraction == 0 ? 0 : 0.2)).frame(width: 330 * fraction + 1, height: 9)
                }
            }
            .padding(26)
            .frame(width: 400, height: 380, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.black.opacity(0.35)))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 34)
            .padding(.top, 62)

            HStack(spacing: 16) {
                Spacer()
                Image(systemName: "bell.fill")
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 5).fill(.white.opacity(0.28)))
                Image(systemName: "wifi")
                Image(systemName: "battery.75percent")
                Text(verbatim: clock).monospacedDigit()
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 26)
            .background(.black.opacity(0.28))

            menu.padding(.top, 32).padding(.trailing, 96)
        }
    }
}

/// A key with what it does: "⏎ Join".
private struct Keycap: View {
    let key: String
    let label: String

    var body: some View {
        HStack(spacing: 12) {
            Text(verbatim: key)
                .font(.system(size: key.count > 1 ? 16 : 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color(white: 0.15))
                .frame(width: 48, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous).fill(.white)
                        .shadow(color: .black.opacity(0.35), radius: 0, y: 3)
                )
            Text(verbatim: label)
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.leading, 10)
        .padding(.trailing, 18)
        .padding(.vertical, 9)
        .background(Capsule().fill(.black.opacity(0.45)))
    }
}
