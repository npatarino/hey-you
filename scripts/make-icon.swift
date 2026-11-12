#!/usr/bin/env swift
// Generates the app icon (a spotlight falling on an exclamation mark: amber at the lamp, red on
// the floor, over neutral charcoal) as PNGs for AppIcon.appiconset.
// Usage: swift scripts/make-icon.swift App/Assets.xcassets/AppIcon.appiconset
import AppKit
import CoreImage

let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "App/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

/// Background gradient, top and bottom. `HEYYOU_ICON_BG=2C2C30,0A0A0C` overrides it (for trying other colors).
let background: (top: UInt32, bottom: UInt32) = {
    let parts = (ProcessInfo.processInfo.environment["HEYYOU_ICON_BG"] ?? "").split(separator: ",").compactMap { UInt32($0, radix: 16) }
    return parts.count == 2 ? (parts[0], parts[1]) : (0x2C2C30, 0x0A0A0C)
}()

/// Color of the exclamation mark. `HEYYOU_ICON_MARK=1E1A1C` overrides it.
let markColor = UInt32(ProcessInfo.processInfo.environment["HEYYOU_ICON_MARK"] ?? "", radix: 16) ?? 0xFFFFFF

guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { fatalError("no sRGB color space") }
let ciContext = CIContext(options: [.workingColorSpace: colorSpace, .outputColorSpace: colorSpace])

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: alpha
    )
}

func gradient(_ colors: [CGColor]) -> CGGradient {
    guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: nil) else {
        fatalError("gradient failed")
    }
    return gradient
}

func makeContext(pixels: Int) -> CGContext {
    guard let context = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { fatalError("context failed") }
    return context
}

/// The artwork is drawn on a 100×100 design grid (y down) that maps onto the icon body.
/// macOS icon grid: 824/1024 body centered, corner radius ~185/1024.
struct Grid {
    let pixels: Int
    var size: CGFloat {
        CGFloat(pixels)
    }

    var inset: CGFloat {
        size * 100 / 1024
    }

    var unit: CGFloat {
        (size - 2 * inset) / 100
    }

    var body: CGRect {
        CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    }

    var bodyPath: CGPath {
        let radius = size * 185 / 1024
        return CGPath(roundedRect: body, cornerWidth: radius, cornerHeight: radius, transform: nil)
    }

    func apply(to context: CGContext) {
        context.translateBy(x: inset, y: size - inset)
        context.scaleBy(x: unit, y: -unit)
    }
}

/// Draws on the design grid into an offscreen layer and blurs it by `sigma` grid units.
func blurredLayer(_ grid: Grid, sigma: CGFloat, draw: (CGContext) -> Void) -> CGImage? {
    let context = makeContext(pixels: grid.pixels)
    grid.apply(to: context)
    draw(context)
    guard let image = context.makeImage() else { return nil }
    guard sigma > 0 else { return image }
    let extent = CGRect(x: 0, y: 0, width: grid.pixels, height: grid.pixels)
    let blurred = CIImage(cgImage: image).applyingGaussianBlur(sigma: sigma * grid.unit).cropped(to: extent)
    return ciContext.createCGImage(blurred, from: extent)
}

let amber: UInt32 = 0xFFC44D
let red: UInt32 = 0xFF4A3D
let pool: UInt32 = 0xFF5A4A
let poolCore: UInt32 = 0xFFB58F

func render(pixels: Int) -> Data? {
    let grid = Grid(pixels: pixels)
    let context = makeContext(pixels: pixels)
    let full = CGRect(x: 0, y: 0, width: pixels, height: pixels)

    // Body with a soft drop shadow.
    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -grid.size * 0.01), blur: grid.size * 0.02, color: rgb(0x000000, 0.3)
    )
    context.addPath(grid.bodyPath)
    context.setFillColor(rgb(background.bottom))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(grid.bodyPath)
    context.clip()

    // Charcoal background and the ambient glow the floor light throws back.
    context.saveGState()
    grid.apply(to: context)
    context.drawLinearGradient(
        gradient([rgb(background.top), rgb(background.bottom)]), start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: 100), options: []
    )
    context.drawRadialGradient(
        gradient([rgb(pool, 0.5), rgb(pool, 0)]), startCenter: CGPoint(x: 50, y: 80), startRadius: 0,
        endCenter: CGPoint(x: 50, y: 80), endRadius: 62, options: []
    )
    context.restoreGState()

    // Beam: amber at the lamp, red on the floor, crisp edges.
    let beam = blurredLayer(grid, sigma: 0) { layer in
        layer.move(to: CGPoint(x: 43, y: -4))
        layer.addLine(to: CGPoint(x: 57, y: -4))
        layer.addLine(to: CGPoint(x: 93.5, y: 82))
        layer.addLine(to: CGPoint(x: 6.5, y: 82))
        layer.closePath()
        layer.clip()
        layer.drawLinearGradient(
            gradient([rgb(amber, 0.95), rgb(red, 0.38)]), start: CGPoint(x: 0, y: -4), end: CGPoint(x: 0, y: 82),
            options: []
        )
    }
    if let beam {
        context.draw(beam, in: full)
    }

    // Pool of light: a wide glow, then the lit ellipse itself.
    let glow = blurredLayer(grid, sigma: 5) { layer in
        layer.setFillColor(rgb(pool, 0.85))
        layer.fillEllipse(in: CGRect(x: 2, y: 70, width: 96, height: 24))
    }
    if let glow {
        context.draw(glow, in: full)
    }

    context.saveGState()
    grid.apply(to: context)
    context.translateBy(x: 50, y: 82)
    context.scaleBy(x: 1, y: 10.0 / 44.0)
    context.addEllipse(in: CGRect(x: -44, y: -44, width: 88, height: 88))
    context.clip()
    context.drawRadialGradient(
        gradient([rgb(poolCore), rgb(pool)]), startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 44,
        options: []
    )
    context.restoreGState()

    // Exclamation mark standing in the light. Slightly heavier at small sizes so it survives.
    context.saveGState()
    grid.apply(to: context)
    let weight: CGFloat = pixels <= 64 ? 1.3 : 1
    context.translateBy(x: 50, y: 78)
    context.scaleBy(x: weight, y: weight)
    context.translateBy(x: -50, y: -78)
    context.setFillColor(rgb(0x000000, 0.22))
    context.fillEllipse(in: CGRect(x: 40, y: 76.2, width: 20, height: 5.2))
    context.setFillColor(rgb(markColor))
    context.addPath(CGPath(
        roundedRect: CGRect(x: 45.5, y: 30, width: 9, height: 31), cornerWidth: 4.5, cornerHeight: 4.5, transform: nil
    ))
    context.fillPath()
    context.fillEllipse(in: CGRect(x: 44.4, y: 66.9, width: 11.2, height: 11.2))
    context.restoreGState()

    context.restoreGState()

    // Thin light rim around the body.
    let rimWidth = 1.2 * grid.unit
    let rimRect = grid.body.insetBy(dx: rimWidth / 2, dy: rimWidth / 2)
    let rimRadius = grid.size * 185 / 1024 - rimWidth / 2
    context.addPath(CGPath(roundedRect: rimRect, cornerWidth: rimRadius, cornerHeight: rimRadius, transform: nil))
    context.setStrokeColor(rgb(0xFFFFFF, 0.2))
    context.setLineWidth(rimWidth)
    context.strokePath()

    guard let image = context.makeImage() else { return nil }
    return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
}

var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        guard let data = render(pixels: points * scale) else { fatalError("render failed") }
        try data.write(to: output.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": name])
    }
}

let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: output.appendingPathComponent("Contents.json"))
print("Wrote \(images.count) icons to \(output.path)")
