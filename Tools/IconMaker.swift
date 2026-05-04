import AppKit
import Foundation

let sizes: [CGFloat] = [16, 32, 128, 256, 512]
let outputPath = CommandLine.arguments.dropFirst().first ?? "build/AppIcon.iconset"
let output = URL(fileURLWithPath: outputPath)

try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let radius = size * 0.22
    let path = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.06, dy: size * 0.06),
                            xRadius: radius,
                            yRadius: radius)

    NSColor(calibratedRed: 0.90, green: 0.96, blue: 1.0, alpha: 1.0).setFill()
    path.fill()

    NSColor(calibratedRed: 0.24, green: 0.52, blue: 0.95, alpha: 1.0).setFill()
    let moon = NSBezierPath(ovalIn: NSRect(x: size * 0.18, y: size * 0.43, width: size * 0.38, height: size * 0.38))
    moon.fill()
    NSColor(calibratedRed: 0.90, green: 0.96, blue: 1.0, alpha: 1.0).setFill()
    let cutout = NSBezierPath(ovalIn: NSRect(x: size * 0.30, y: size * 0.49, width: size * 0.34, height: size * 0.34))
    cutout.fill()

    let dayAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedDigitSystemFont(ofSize: size * 0.36, weight: .bold),
        .foregroundColor: NSColor(calibratedRed: 0.10, green: 0.16, blue: 0.24, alpha: 1.0)
    ]
    let day = "18" as NSString
    let daySize = day.size(withAttributes: dayAttrs)
    day.draw(at: NSPoint(x: (size - daySize.width) / 2, y: size * 0.17), withAttributes: dayAttrs)

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL, pixels: Int) {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                    pixelsWide: pixels,
                                    pixelsHigh: pixels,
                                    bitsPerSample: 8,
                                    samplesPerPixel: 4,
                                    hasAlpha: true,
                                    isPlanar: false,
                                    colorSpaceName: .deviceRGB,
                                    bitmapFormat: [],
                                    bytesPerRow: 0,
                                    bitsPerPixel: 0) else {
        return
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    try? rep.representation(using: .png, properties: [:])?.write(to: url)
}

for size in sizes {
    let image = drawIcon(size: size)
    let base = Int(size)
    writePNG(image, to: output.appendingPathComponent("icon_\(base)x\(base).png"), pixels: base)
    writePNG(image, to: output.appendingPathComponent("icon_\(base)x\(base)@2x.png"), pixels: base * 2)
}
