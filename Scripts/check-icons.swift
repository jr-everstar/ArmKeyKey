import AppKit

// Check visible pixels as well as metadata: a correctly sized Retina canvas can
// still contain a twice-scaled, clipped drawing.
func check(_ rep: NSBitmapImageRep, pixels: Int, points: Int, name: String, fillsCanvas: Bool = false) {
    precondition(rep.pixelsWide == pixels && rep.pixelsHigh == pixels, "Wrong pixel size: \(name)")
    precondition(rep.size == NSSize(width: points, height: points), "Wrong point size: \(name)")
    var minX = pixels, minY = pixels, maxX = -1, maxY = -1
    for y in 0..<pixels {
        for x in 0..<pixels where rep.colorAt(x: x, y: y)!.alphaComponent > 0.1 {
            minX = min(minX, x); minY = min(minY, y)
            maxX = max(maxX, x); maxY = max(maxY, y)
        }
    }
    precondition(maxX >= minX && maxY >= minY, "Empty icon: \(name)")
    if fillsCanvas {
        precondition(minX == 0 && minY == 0 && maxX == pixels - 1 && maxY == pixels - 1, "Menu icon must fill its canvas: \(name)")
        for (x, y) in [(0, 0), (pixels - 1, 0), (0, pixels - 1), (pixels - 1, pixels - 1)] {
            precondition(rep.colorAt(x: x, y: y)!.alphaComponent < 0.1, "Clipped rounded corner: \(name)")
        }
    } else {
        precondition(minX > 0 && minY > 0 && maxX < pixels - 1 && maxY < pixels - 1, "Clipped icon: \(name)")
    }
    precondition(abs(minX - (pixels - 1 - maxX)) <= 1 && abs(minY - (pixels - 1 - maxY)) <= 1, "Off-centre icon: \(name)")
    print("OK \(name): \(pixels)px, \(points)pt, centred and unclipped")
}

let directory = URL(fileURLWithPath: CommandLine.arguments[1])
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        let rep = NSBitmapImageRep(data: try Data(contentsOf: directory.appendingPathComponent(name)))!
        check(rep, pixels: points * scale, points: points, name: name)
    }
}
let image = NSImage(contentsOfFile: CommandLine.arguments[2])!
precondition(image.size == NSSize(width: 16, height: 16))
precondition(Set(image.representations.map { $0.pixelsWide }) == Set([16, 32]))
for rep in image.representations {
    check(rep as! NSBitmapImageRep, pixels: rep.pixelsWide, points: 16, name: "InputSource.tiff", fillsCanvas: true)
}
