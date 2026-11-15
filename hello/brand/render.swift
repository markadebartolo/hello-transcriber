// Render the measured spoken-"hello" envelope into native macOS brand assets.
// Run: swift hello/brand/render.swift /absolute/path/to/repository
import AppKit
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let brand = root.appendingPathComponent("hello/brand")
let data = try Data(contentsOf: brand.appendingPathComponent("waveform.json"))
let metadata = try JSONSerialization.jsonObject(with: data) as! [String: Any]
let measured = metadata["rms"] as! [Double]

func levels(_ count: Int) -> [CGFloat] {
    (0..<count).map { index in
        let start = index * measured.count / count
        let end = max(start + 1, (index + 1) * measured.count / count)
        let values = measured[start..<end]
        return CGFloat(values.reduce(0, +) / Double(values.count))
    }
}

func drawWave(_ context: CGContext, in rect: CGRect, count: Int, color: CGColor) {
    let amplitudes = levels(count)
    let step = rect.width / CGFloat(count)
    let width = step * 0.56
    context.setFillColor(color)
    for (index, amplitude) in amplitudes.enumerated() {
        let height = max(width, rect.height * amplitude)
        let bar = CGRect(x: rect.minX + CGFloat(index) * step + (step - width) / 2,
                         y: rect.midY - height / 2, width: width, height: height)
        context.addPath(CGPath(roundedRect: bar, cornerWidth: width / 2, cornerHeight: width / 2, transform: nil))
        context.fillPath()
    }
}

func renderIcon(_ size: Int, to url: URL) throws {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                            bytesPerRow: size * 4, space: colorSpace,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    let tile = CGPath(roundedRect: CGRect(x: 80, y: 80, width: 864, height: 864),
                      cornerWidth: 202, cornerHeight: 202, transform: nil)
    context.saveGState()
    context.addPath(tile); context.clip()
    let gradient = CGGradient(colorsSpace: colorSpace, colors: [
        CGColor(red: 0.09, green: 0.36, blue: 0.91, alpha: 1),
        CGColor(red: 0.18, green: 0.56, blue: 1, alpha: 1)
    ] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(gradient, start: CGPoint(x: 300, y: 80), end: CGPoint(x: 724, y: 944), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    context.restoreGState()
    drawWave(context, in: CGRect(x: 190, y: 285, width: 644, height: 454),
             count: size <= 32 ? 9 : 25, color: CGColor(gray: 1, alpha: 1))
    let representation = NSBitmapImageRep(cgImage: context.makeImage()!)
    try representation.representation(using: .png, properties: [:])!.write(to: url)
}

let assets = root.appendingPathComponent("hello/Assets.xcassets")
let iconDirectory = assets.appendingPathComponent("AppIcon.appiconset")
for pointSize in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        try renderIcon(pointSize * scale, to: iconDirectory.appendingPathComponent("hello-\(pointSize)@\(scale)x.png"))
    }
}
try renderIcon(1024, to: brand.appendingPathComponent("hello-preview.png"))
let menuDirectory = assets.appendingPathComponent("HelloWaveform.imageset")
try FileManager.default.createDirectory(at: menuDirectory, withIntermediateDirectories: true)
var mediaBox = CGRect(x: 0, y: 0, width: 28, height: 18)
let consumer = CGDataConsumer(url: menuDirectory.appendingPathComponent("hello-waveform.pdf") as CFURL)!
let pdf = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)!
pdf.beginPDFPage(nil)
drawWave(pdf, in: CGRect(x: 1, y: 2, width: 26, height: 14), count: 13, color: CGColor(gray: 0, alpha: 1))
pdf.endPDFPage(); pdf.closePDF()
let contents = """
{"images":[{"filename":"hello-waveform.pdf","idiom":"universal"}],"info":{"author":"xcode","version":1},"properties":{"preserves-vector-representation":true,"template-rendering-intent":"template"}}
"""
try contents.write(to: menuDirectory.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

var svg = """
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024" role="img" aria-label="Hello: the waveform of hello spoken aloud">
<title>Hello — the sound of hello</title>
<defs><linearGradient id="blue" x1="0.3" y1="1" x2="0.7" y2="0"><stop stop-color="#175ce8"/><stop offset="1" stop-color="#2e8fff"/></linearGradient></defs>
<rect x="80" y="80" width="864" height="864" rx="202" fill="url(#blue)"/>
<g fill="white">
"""
let step = 644.0 / 25
for (index, amplitude) in measured.enumerated() {
    let width = step * 0.56, height = max(width, 454 * amplitude)
    svg += String(format: "<rect x=\"%.3f\" y=\"%.3f\" width=\"%.3f\" height=\"%.3f\" rx=\"%.3f\"/>\n",
                  190 + Double(index) * step + (step - width) / 2, 512 - height / 2, width, height, width / 2)
}
svg += "</g>\n</svg>\n"
try svg.write(to: brand.appendingPathComponent("hello.svg"), atomically: true, encoding: .utf8)
print("Rendered Hello icons and vector menu mark from the measured spoken-word envelope.")
