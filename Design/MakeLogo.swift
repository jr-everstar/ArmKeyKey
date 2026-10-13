import AppKit
import CoreText
let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let source = dir + "/AppIcon.png"
let font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, 180, nil)
let line = CTLineCreateWithAttributedString(NSAttributedString(string: "ArmKeyKey", attributes: [NSAttributedString.Key(kCTFontAttributeName as String):font]))
let path = CGMutablePath()
for run in CTLineGetGlyphRuns(line) as! [CTRun] {
 let n = CTRunGetGlyphCount(run)
 var glyphs = [CGGlyph](repeating:0,count:n), positions = [CGPoint](repeating:.zero,count:n)
 CTRunGetGlyphs(run, CFRange(location:0,length:0), &glyphs)
 CTRunGetPositions(run, CFRange(location:0,length:0), &positions)
 for i in 0..<n { if let p = CTFontCreatePathForGlyph(font,glyphs[i],nil) { path.addPath(p, transform:CGAffineTransform(translationX:positions[i].x,y:positions[i].y)) } }
}
let bounds = path.boundingBoxOfPath
let width = Int(610 + bounds.width + 90), height = 600
let baseline = 300 - bounds.midY
let cs = CGColorSpaceCreateDeviceRGB()
let context = CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:0,space:cs,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
let data = try Data(contentsOf:URL(fileURLWithPath:source))
let img = NSBitmapImageRep(data:data)!.cgImage!
context.interpolationQuality = .high
context.draw(img,in:CGRect(x:50,y:50,width:500,height:500))
context.saveGState()
context.translateBy(x:610-bounds.minX,y:baseline)
context.setFillColor(CGColor(red:0.09,green:0.12,blue:0.15,alpha:1))
context.addPath(path);context.fillPath();context.restoreGState()
let png = NSBitmapImageRep(cgImage:context.makeImage()!).representation(using:.png,properties:[:])!
try png.write(to:URL(fileURLWithPath:dir+"/armkeykey-logo-final.png"))
var d = ""
path.applyWithBlock { p in
 let e=p.pointee
 func pt(_ i:Int)->String { "\(e.points[i].x),\(e.points[i].y)" }
 switch e.type {
 case .moveToPoint:d += "M\(pt(0)) "
 case .addLineToPoint:d += "L\(pt(0)) "
 case .addQuadCurveToPoint:d += "Q\(pt(0)) \(pt(1)) "
 case .addCurveToPoint:d += "C\(pt(0)) \(pt(1)) \(pt(2)) "
 case .closeSubpath:d += "Z "
 @unknown default:break
 }
}
let svg = """
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="\(width)" height="600" viewBox="0 0 \(width) 600"><title>ArmKeyKey</title><image x="50" y="50" width="500" height="500" xlink:href="data:image/png;base64,\(data.base64EncodedString())"/><path fill="#171f26" transform="translate(\(610-bounds.minX) \(600-baseline)) scale(1 -1)" d="\(d)"/></svg>
"""
try svg.write(toFile:dir+"/armkeykey-logo-final.svg",atomically:true,encoding:.utf8)
print("Saved SVG and transparent PNG: \(width) × \(height)")
