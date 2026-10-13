import AppKit

// Preserve the user-supplied artwork and colours. Package the active PNG at 16pt
// with 1x/2x representations; no display-dependent lockFocus scaling.
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
for (source, output) in [("armkeykey-transparent.png", "TransparentStatusIcon.tiff")] {
    let sourceURL = root.appendingPathComponent("Design/\(source)")
    let data = try Data(contentsOf: sourceURL)
    let original = NSBitmapImageRep(data: data)!
    precondition(original.pixelsWide == 32 && original.pixelsHigh == 32)
    let artwork = NSImage(data: data)!
    let image = NSImage(size: NSSize(width: 16, height: 16))
    for scale in [1, 2] {
        let rep: NSBitmapImageRep
        if scale == 2 {
            // Keep the supplied Retina pixels unchanged.
            rep = NSBitmapImageRep(data: data)!
            rep.size = image.size
        } else {
            rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 16, pixelsHigh: 16,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB,
                                  bytesPerRow: 0, bitsPerPixel: 0)!
            rep.size = image.size
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)!
            NSGraphicsContext.current!.imageInterpolation = .high
            artwork.draw(in: NSRect(origin: .zero, size: image.size))
            NSGraphicsContext.restoreGraphicsState()
        }
        image.addRepresentation(rep)
    }
    let destination = root.appendingPathComponent("Resources/\(output)")
    try image.tiffRepresentation!.write(to: destination)
    let decoded = NSImage(contentsOf: destination)!
    precondition(decoded.size == image.size)
    precondition(Set(decoded.representations.map { $0.pixelsWide }) == Set([16, 32]))
    precondition(decoded.representations.allSatisfy { $0.size == image.size })
    let retina = decoded.representations.first { $0.pixelsWide == 32 } as! NSBitmapImageRep
    for y in 0..<32 { for x in 0..<32 {
        precondition(retina.colorAt(x: x, y: y) == original.colorAt(x: x, y: y), "Changed source pixel")
    } }
    print("Verified \(output): 16pt, 1x/2x, original Retina pixels preserved")
}
