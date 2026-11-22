#!/usr/bin/env swift  // Draws the WatchMyFace app icon and logo.  //
//   swift scripts/generate-icon.swift
//
// A graphite tile lit from above, the notch with its camera at the top, and below it the ring of ticks Face ID setup
// draws when the circle is complete, in Apple's green, around a white tick. Writes every size the asset catalog wants into
// Sources/WatchMyFace/Resources/Assets.xcassets/AppIcon.appiconset, and docs/images/logo.png (1024 px) for the
// README. Coordinates are Core Graphics' own: origin bottom left.

import AppKit
import SwiftUI

let canvas: CGFloat = 1024
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
let green = CGColor(srgbRed: 0.651, green: 0.973, blue: 0.592, alpha: 1)

func color(_ white: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: white, green: white, blue: white, alpha: alpha)
}

func srgbColor(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
}

func gradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: srgb, colors: colors as CFArray, locations: locations)!
}

/// Apple's green, towards mint around the ring.
let ringStart = (r: 0.19, g: 0.82, b: 0.35)
let ringEnd = (r: 0.2, g: 0.88, b: 0.68)

func draw(in context: CGContext) {
    let tilePath = Path(roundedRect: tile, cornerRadius: 185.4, style: .continuous).cgPath

    // The tile, with Apple's template shadow.
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: color(0, 0.4))
    context.addPath(tilePath)
    context.setFillColor(color(0.08))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(tilePath)
    context.clip()

    // Graphite, lit from above, like the lid of a MacBook in a dark room.
    context.drawLinearGradient(
        gradient([srgbColor(0.2, 0.2, 0.22), srgbColor(0.07, 0.07, 0.08), srgbColor(0.03, 0.03, 0.035)], [0, 0.55, 1]),
        start: CGPoint(x: 512, y: tile.maxY), end: CGPoint(x: 512, y: tile.minY), options: [])
    // A faint green bloom where the glyph is.
    context.drawRadialGradient(
        gradient([srgbColor(0.19, 0.82, 0.35, 0.22), srgbColor(0.19, 0.82, 0.35, 0)], [0, 1]),
        startCenter: CGPoint(x: 512, y: 452), startRadius: 0, endCenter: CGPoint(x: 512, y: 452), endRadius: 380,
        options: [])

    // The notch, with its camera.
    let notch = CGRect(x: 512 - 150, y: tile.maxY - 74, width: 300, height: 74)
    let body = UnevenRoundedRectangle(
        topLeadingRadius: 0, bottomLeadingRadius: 20, bottomTrailingRadius: 20, topTrailingRadius: 0, style: .continuous
    ).path(in: CGRect(origin: .zero, size: notch.size)).cgPath
    context.saveGState()
    context.translateBy(x: notch.minX, y: notch.maxY)
    context.scaleBy(x: 1, y: -1)
    context.addPath(body)
    context.setFillColor(color(0))
    context.fillPath()
    context.restoreGState()
    let lens = CGPoint(x: 512, y: notch.midY + 2)
    context.setFillColor(srgbColor(0.07, 0.08, 0.12))
    context.fillEllipse(in: CGRect(x: lens.x - 13, y: lens.y - 13, width: 26, height: 26))
    context.setFillColor(srgbColor(0.16, 0.2, 0.34))
    context.fillEllipse(in: CGRect(x: lens.x - 6, y: lens.y - 6, width: 12, height: 12))
    context.setFillColor(color(1, 0.55))
    context.fillEllipse(in: CGRect(x: lens.x + 1, y: lens.y + 2, width: 4, height: 4))
    context.restoreGState()

    // Light catching the tile's edge: bright along the top, gone by the middle.
    context.saveGState()
    context.addPath(tilePath)
    context.setLineWidth(4)
    context.replacePathWithStrokedPath()
    context.clip()
    context.drawLinearGradient(
        gradient([color(1, 0.32), color(1, 0.04), color(1, 0.08)], [0, 0.5, 1]),
        start: CGPoint(x: 512, y: tile.maxY), end: CGPoint(x: 512, y: tile.minY), options: [])
    context.restoreGState()

    // The ring of ticks, as Face ID setup draws it when the circle is complete, glowing a little.
    let center = CGPoint(x: 512, y: 452)
    let ticks = 60
    context.saveGState()
    context.setShadow(offset: .zero, blur: 26, color: srgbColor(0.19, 0.82, 0.35, 0.55))
    context.setLineCap(.round)
    context.setLineWidth(13)
    for index in 0..<ticks {
        let progress = CGFloat(index) / CGFloat(ticks)
        let angle = .pi / 2 - progress * 2 * .pi
        // Green to mint and back, all the way round.
        let blend = (1 - cos(progress * 2 * .pi)) / 2
        context.setStrokeColor(
            srgbColor(
                ringStart.r + (ringEnd.r - ringStart.r) * blend, ringStart.g + (ringEnd.g - ringStart.g) * blend,
                ringStart.b + (ringEnd.b - ringStart.b) * blend))
        context.move(to: CGPoint(x: center.x + cos(angle) * 236, y: center.y + sin(angle) * 236))
        context.addLine(to: CGPoint(x: center.x + cos(angle) * 282, y: center.y + sin(angle) * 282))
        context.strokePath()
    }
    context.restoreGState()

    // The tick: white, with a soft shadow, drawn the way SF draws a checkmark (a short and a long stroke).
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -6), blur: 18, color: color(0, 0.5))
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setLineWidth(44)
    context.setStrokeColor(color(1))
    context.move(to: CGPoint(x: 424, y: 462))
    context.addLine(to: CGPoint(x: 488, y: 392))
    context.addLine(to: CGPoint(x: 608, y: 538))
    context.strokePath()
    context.restoreGState()
}

func render(pixels: Int) -> Data {
    let context = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.interpolationQuality = .high
    context.scaleBy(x: CGFloat(pixels) / canvas, y: CGFloat(pixels) / canvas)
    draw(in: context)
    let image = context.makeImage()!
    return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconSet = root.appending(path: "Sources/WatchMyFace/Resources/Assets.xcassets/AppIcon.appiconset")
var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try render(pixels: points * scale).write(to: iconSet.appending(path: name))
        images.append(["idiom": "mac", "scale": "\(scale)x", "size": "\(points)x\(points)", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: iconSet.appending(path: "Contents.json"))

let docs = root.appending(path: "docs/images")
try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
try render(pixels: 1024).write(to: docs.appending(path: "logo.png"))
print("Wrote the app icon and docs/images/logo.png")
