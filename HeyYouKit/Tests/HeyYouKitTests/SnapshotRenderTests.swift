import AppKit
import ComposableArchitecture
@testable import HeyYouKit
import SwiftUI
import Testing

/// Renders the main screens to PNG for docs/screenshots. Opt-in:
/// `HEYYOU_SNAPSHOTS=$PWD/../docs/screenshots swift test --filter SnapshotRenderTests`
@MainActor
@Suite(.enabled(if: ProcessInfo.processInfo.environment["HEYYOU_SNAPSHOTS"] != nil))
struct SnapshotRenderTests {
    var folder: URL {
        URL(fileURLWithPath: ProcessInfo.processInfo.environment["HEYYOU_SNAPSHOTS"] ?? ".")
    }

    func write(_ view: some View, size: CGSize, name: String, colorScheme: ColorScheme = .light) throws {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height)
            .environment(\.colorScheme, colorScheme))
        renderer.scale = 2
        let image = try #require(renderer.nsImage)
        let tiff = try #require(image.tiffRepresentation)
        let png = try #require(NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]))
        try png.write(to: folder.appendingPathComponent("\(name).png"))
    }

    static let start = Date(timeIntervalSince1970: 1_793_700_000)

    @Test func alerts() throws {
        let weekly = CalendarEvent(
            id: "w", title: "Weekly sync", start: Self.start, end: Self.start.addingTimeInterval(1800),
            meetingLink: MeetingLink(provider: .googleMeet, url: AppConfig.projectURL)
        )
        try write(
            AlertView(store: Store(initialState: AlertFeature.State(event: weekly, now: Self.start.addingTimeInterval(-47))) {
                AlertFeature()
            } withDependencies: { $0.context = .preview }, animateEntrance: false),
            size: CGSize(width: 1440, height: 900), name: "alert-countdown"
        )
        let retro = CalendarEvent(
            id: "r", title: "Retro", start: Self.start, end: Self.start.addingTimeInterval(3600),
            meetingLink: MeetingLink(provider: .zoom, url: AppConfig.projectURL), attendeeStatus: .declined
        )
        try write(
            AlertView(store: Store(initialState: AlertFeature.State(
                event: retro, additionalCount: 1, proHook: .declined, now: Self.start.addingTimeInterval(190)
            )) {
                AlertFeature()
            } withDependencies: { $0.context = .preview }, animateEntrance: false),
            size: CGSize(width: 1440, height: 900), name: "alert-started-hook"
        )
    }

    @Test func windows() throws {
        try write(
            PaywallView(store: Store(initialState: {
                var state = PaywallFeature.State(source: .menu)
                state.isLoading = false
                state.products = [StoreProduct(id: AppConfig.proProductID, displayName: "Hey You! Pro", displayPrice: "5,99 €")]
                return state
            }()) { PaywallFeature() } withDependencies: { $0.context = .preview }).background(Color.white),
            size: CGSize(width: 420, height: 560), name: "paywall"
        )
        try write(
            OnboardingView(store: Store(initialState: OnboardingFeature.State()) { OnboardingFeature() } withDependencies: {
                $0.context = .preview
            }).background(Color.white),
            size: CGSize(width: 480, height: 620), name: "onboarding"
        )
    }
}
