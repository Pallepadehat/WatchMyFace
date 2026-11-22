#!/usr/bin/env swift  // Draws the WatchMyFace app icon and logo.
//
//   swift scripts/generate-icon.swift
//
// A black tile, like a MacBook's screen edge, with the notch at the top, and the unlock glyph (a ring with a tick) in
// the notch's green below it. Writes every size the asset catalog wants into
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

func draw(in context: CGContext) {
    // The tile: Apple's continuous corners and template shadow.
    let tilePath = Path(roundedRect: tile, cornerRadius: 185.4, style: .continuous).cgPath
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: color(0, 0.35))
    context.addPath(tilePath)
    context.setFillColor(color(0.06))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(tilePath)
    context.clip()
    // A faint glow from below, so the black reads as glass rather than a hole.
    let glow = CGGradient(
        colorsSpace: srgb, colors: [color(0.2), color(0.04)] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(
        glow, start: CGPoint(x: 512, y: tile.minY), end: CGPoint(x: 512, y: tile.maxY), options: [])

    // The notch: the housing at the top edge, with its flared corners.
    let notch = CGRect(x: 512 - 170, y: tile.maxY - 86, width: 340, height: 86)
    let body = UnevenRoundedRectangle(
        topLeadingRadius: 0, bottomLeadingRadius: 22, bottomTrailingRadius: 22, topTrailingRadius: 0, style: .continuous
    ).path(in: CGRect(x: 0, y: 0, width: notch.width, height: notch.height)).cgPath
    context.saveGState()
    // SwiftUI paths are top-down; flip into the notch's rect.
    context.translateBy(x: notch.minX, y: notch.maxY)
    context.scaleBy(x: 1, y: -1)
    context.addPath(body)
    context.setFillColor(color(0))
    context.fillPath()
    context.restoreGState()
    context.restoreGState()

    // A hairline around the tile.
    context.addPath(tilePath)
    context.setStrokeColor(color(1, 0.12))
    context.setLineWidth(3)
    context.strokePath()

    // The unlock glyph, as the notch shows it on a match: a ring with a tick, in the notch's green. Drawn here rather
    // than taken from SF Symbols, whose license doesn't allow them in app icons.
    context.saveGState()
    context.setShadow(offset: .zero, blur: 44, color: green.copy(alpha: 0.5)!)
    context.setStrokeColor(green)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setLineWidth(46)
    context.strokeEllipse(in: CGRect(x: 512 - 200, y: 440 - 200, width: 400, height: 400))
    context.setLineWidth(50)
    context.move(to: CGPoint(x: 432, y: 448))
    context.addLine(to: CGPoint(x: 492, y: 382))
    context.addLine(to: CGPoint(x: 600, y: 524))
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
