import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Sources/HistoryBrowser/Assets.xcassets/AppIcon.appiconset", isDirectory: true)

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let sizes = [16, 32, 64, 128, 256, 512, 1024]

for size in sizes {
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fatalError("Could not create drawing context.")
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    let bounds = CGRect(x: 0, y: 0, width: CGFloat(size), height: CGFloat(size))
    let scale = CGFloat(size) / 1024.0

    let background = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor(calibratedRed: 0.05, green: 0.15, blue: 0.19, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.08, green: 0.36, blue: 0.38, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.97, green: 0.77, blue: 0.36, alpha: 1).cgColor
        ] as CFArray,
        locations: [0.0, 0.58, 1.0]
    )!

    let cornerRadius = 228 * scale
    let backgroundPath = CGPath(
        roundedRect: bounds.insetBy(dx: 32 * scale, dy: 32 * scale),
        cornerWidth: cornerRadius,
        cornerHeight: cornerRadius,
        transform: nil
    )
    context.addPath(backgroundPath)
    context.clip()
    context.drawLinearGradient(
        background,
        start: CGPoint(x: 0, y: size),
        end: CGPoint(x: size, y: 0),
        options: []
    )

    context.resetClip()

    context.setFillColor(NSColor(calibratedWhite: 0, alpha: 0.18).cgColor)
    let shadowPath = CGPath(
        roundedRect: CGRect(x: 180, y: 148, width: 664, height: 684).applying(CGAffineTransform(scaleX: scale, y: scale)),
        cornerWidth: 96 * scale,
        cornerHeight: 96 * scale,
        transform: nil
    )
    context.addPath(shadowPath)
    context.fillPath()

    context.setFillColor(NSColor(calibratedRed: 0.98, green: 0.97, blue: 0.91, alpha: 1).cgColor)
    let pageRect = CGRect(x: 170, y: 176, width: 648, height: 680).applying(CGAffineTransform(scaleX: scale, y: scale))
    let pagePath = CGPath(
        roundedRect: pageRect,
        cornerWidth: 86 * scale,
        cornerHeight: 86 * scale,
        transform: nil
    )
    context.addPath(pagePath)
    context.fillPath()

    context.setStrokeColor(NSColor(calibratedRed: 0.10, green: 0.24, blue: 0.28, alpha: 1).cgColor)
    context.setLineWidth(max(3, 28 * scale))
    context.setLineCap(.round)
    for y in [680, 570, 460] {
        context.move(to: CGPoint(x: 286 * scale, y: CGFloat(y) * scale))
        context.addLine(to: CGPoint(x: 706 * scale, y: CGFloat(y) * scale))
        context.strokePath()
    }

    context.setStrokeColor(NSColor(calibratedRed: 0.90, green: 0.46, blue: 0.20, alpha: 1).cgColor)
    context.setLineWidth(max(4, 46 * scale))
    let clockCenter = CGPoint(x: 356 * scale, y: 324 * scale)
    context.addEllipse(in: CGRect(x: 246, y: 214, width: 220, height: 220).applying(CGAffineTransform(scaleX: scale, y: scale)))
    context.strokePath()
    context.move(to: clockCenter)
    context.addLine(to: CGPoint(x: 356 * scale, y: 386 * scale))
    context.strokePath()
    context.move(to: clockCenter)
    context.addLine(to: CGPoint(x: 418 * scale, y: 324 * scale))
    context.strokePath()

    context.setFillColor(NSColor(calibratedRed: 0.17, green: 0.48, blue: 0.50, alpha: 1).cgColor)
    let magnifierCircle = CGRect(x: 536, y: 230, width: 168, height: 168).applying(CGAffineTransform(scaleX: scale, y: scale))
    context.addEllipse(in: magnifierCircle)
    context.fillPath()

    context.setStrokeColor(NSColor.white.withAlphaComponent(0.88).cgColor)
    context.setLineWidth(max(3, 28 * scale))
    context.addEllipse(in: CGRect(x: 560, y: 254, width: 120, height: 120).applying(CGAffineTransform(scaleX: scale, y: scale)))
    context.strokePath()
    context.move(to: CGPoint(x: 672 * scale, y: 256 * scale))
    context.addLine(to: CGPoint(x: 746 * scale, y: 182 * scale))
    context.strokePath()

    guard let cgImage = context.makeImage() else {
        fatalError("Could not create icon image \(size).")
    }

    let outputURL = outputDirectory.appendingPathComponent("AppIcon-\(size).png")
    guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Could not create PNG destination for \(size).")
    }

    CGImageDestinationAddImage(destination, cgImage, nil)
    guard CGImageDestinationFinalize(destination) else {
        fatalError("Could not write icon size \(size).")
    }
}
