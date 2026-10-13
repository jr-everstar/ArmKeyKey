import AppKit

let destination = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
// Keep the approved artwork in the project so every build uses the same identity.
let sourceURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().appendingPathComponent("Design/AppIcon.png")
guard let artwork = NSImage(contentsOf: sourceURL) else { fatalError("Missing icon: \(sourceURL.path)") }

// Explicit bitmap dimensions avoid lockFocus() inheriting the display's Retina scale.
func drawIcon(points: Int, scale: Int, menuIcon: Bool = false) -> NSBitmapImageRep {
    let pixels = points * scale
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB,
                                  bytesPerRow: 0, bitsPerPixel: 0)!
    bitmap.size = NSSize(width: points, height: points)
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    // AppKit already maps the bitmap's point size to its pixel dimensions.
    // Applying another scale here crops and offsets the Retina representation.
    let size = CGFloat(points)
    let bounds = NSRect(x: 0, y: 0, width: size, height: size)
    // Retain the supplied artwork, including its background and rounded corners.
    // App icons use macOS canvas padding; input-source icons fill 16 points.
    let inset = menuIcon ? 0 : size * 0.08
    context.imageInterpolation = .high
    artwork.draw(in: bounds.insetBy(dx: inset, dy: inset), from: .zero,
                 operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let bitmap = drawIcon(points: points, scale: scale)
        try bitmap.representation(using: .png, properties: [:])!.write(to:
            destination.appendingPathComponent("icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"))
    }
}

// Input-source menus need a small image with a stable logical size, separate from
// the app icon. Both TIFF representations describe the same 16-point canvas.
if CommandLine.arguments.count > 2 {
    let representations = [drawIcon(points: 16, scale: 1, menuIcon: true), drawIcon(points: 16, scale: 2, menuIcon: true)]
    let image = NSImage(size: NSSize(width: 16, height: 16))
    representations.forEach { image.addRepresentation($0) }
    let tiff = image.tiffRepresentation!
    try tiff.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
}
