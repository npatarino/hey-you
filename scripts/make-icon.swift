#!/usr/bin/env swift
// Generates the app icon (white bell on a red rounded square) as PNGs for AppIcon.appiconset.
// Usage: swift scripts/make-icon.swift App/Assets.xcassets/AppIcon.appiconset
import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "App/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func render(pixels: Int) -> Data? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return nil }
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let size = CGFloat(pixels)
    // macOS icon grid: 824/1024 body centered, corner radius ~185/1024.
    let inset = size * 100 / 1024
    let body = NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    let radius = size * 185 / 1024
    let path = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)

    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowBlurRadius = size * 0.02
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.01)
    shadow.set()
    NSColor(red: 142 / 255, green: 15 / 255, blue: 30 / 255, alpha: 1).setFill()
    path.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    let gradient = NSGradient(colors: [
        NSColor(red: 240 / 255, green: 64 / 255, blue: 80 / 255, alpha: 1),
        NSColor(red: 224 / 255, green: 38 / 255, blue: 58 / 255, alpha: 1),
        NSColor(red: 142 / 255, green: 15 / 255, blue: 30 / 255, alpha: 1),
    ])
    gradient?.draw(in: path, relativeCenterPosition: NSPoint(x: 0, y: 0.25))

    let config = NSImage.SymbolConfiguration(pointSize: size * 0.48, weight: .bold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    if let bell = NSImage(systemSymbolName: "bell.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
        let bellSize = bell.size
        let origin = NSPoint(x: (size - bellSize.width) / 2, y: (size - bellSize.height) / 2 - size * 0.01)
        bell.draw(in: NSRect(origin: origin, size: bellSize))
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
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
