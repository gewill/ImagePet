import Foundation
import CoreGraphics
import CoreText
import ImageIO
import CryptoKit

// Procedural test inputs, not product artwork. Generated content and this fixture recipe: CC0.
// Variant 2 is held out. Keep assignments and generator hash fixed before evaluating candidates.
@main enum GenerateFixtures {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else { fatalError("Usage: generate-fixtures NEW_OUTPUT_DIRECTORY") }
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        guard !FileManager.default.fileExists(atPath: directory.path) else { fatalError("Output directory must be new") }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var manifest: [[String: Any]] = []
        for category in ["text", "palette", "gradient", "alpha", "orientation", "wide-gamut", "heic"] {
            for variant in 0..<3 {
                let width = 1024 + variant * 17, height = 768 + variant * 13
                let colorSpace = CGColorSpace(name: category == "wide-gamut" ? CGColorSpace.displayP3 : CGColorSpace.sRGB)!
                guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                              bytesPerRow: width * 4, space: colorSpace,
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { fatalError("Bitmap allocation failed") }
                if category != "alpha" {
                    context.setFillColor(CGColor(colorSpace: colorSpace, components: [0.97, 0.97, 0.96, 1])!)
                    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
                }
                switch category {
                case "gradient", "wide-gamut", "heic":
                    let colors = [CGColor(colorSpace: colorSpace, components: [1, 0.05, 0.02, 1])!,
                                  CGColor(colorSpace: colorSpace, components: [0.02, 1, 0.12, 1])!,
                                  CGColor(colorSpace: colorSpace, components: [0.05, 0.12, 1, 1])!]
                    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0, 0.43, 1])!
                    context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: width, y: height), options: [])
                case "palette":
                    context.setShouldAntialias(false)
                    for y in stride(from: 0, to: height, by: 13) {
                        for x in stride(from: 0, to: width, by: 17) {
                            let color = (x / 17 + y / 13 + variant) % 8
                            context.setFillColor(CGColor(red: CGFloat(color & 1), green: CGFloat((color >> 1) & 1), blue: CGFloat((color >> 2) & 1), alpha: 1))
                            context.fill(CGRect(x: x, y: y, width: 17, height: 13))
                        }
                    }
                case "alpha":
                    for i in 0..<24 {
                        context.setFillColor(CGColor(red: CGFloat((i + variant) % 3) / 2,
                                                     green: 0.25, blue: 0.8, alpha: CGFloat(i + 1) / 24))
                        context.fillEllipse(in: CGRect(x: 20 + i * 35, y: 30 + (i % 4) * 120, width: 160, height: 180))
                    }
                default:
                    for row in 0..<24 {
                        let text = "ImagePet 0123456789 — Small text / 細節比較 / Variant \(variant)"
                        let attributes: [NSAttributedString.Key: Any] = [
                            NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, CGFloat(10 + row % 5), nil),
                            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: CGFloat(row % 4) / 5, alpha: 1)
                        ]
                        context.textPosition = CGPoint(x: 20 + variant * 3, y: 20 + row * 30)
                        CTLineDraw(CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes)), context)
                        context.setStrokeColor(CGColor(gray: 0.15, alpha: 1))
                        context.setLineWidth(1)
                        context.stroke(CGRect(x: 600, y: 20 + row * 30, width: 320, height: 18))
                    }
                }
                let ext = category == "heic" ? "heic" : category == "orientation" ? "jpg" : "png"
                let type = ext == "heic" ? "public.heic" : ext == "jpg" ? "public.jpeg" : "public.png"
                let url = directory.appendingPathComponent("fixture-\(category)-\(variant).\(ext)")
                guard let image = context.makeImage(), let destination = CGImageDestinationCreateWithURL(url as CFURL, type as CFString, 1, nil) else { fatalError("Encoder unavailable: \(type)") }
                var properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.95]
                if category == "orientation" { properties[kCGImagePropertyOrientation] = [3, 6, 8][variant] }
                CGImageDestinationAddImage(destination, image, properties as CFDictionary)
                guard CGImageDestinationFinalize(destination) else { fatalError("Encode failed: \(url.path)") }
                let bytes = try Data(contentsOf: url)
                manifest.append([
                    "path": url.path, "category": category, "split": variant == 2 ? "holdout" : "tuning",
                    "source": "ImagePet script/benchmark/generate_fixtures.swift, procedural variant \(variant)",
                    "license": "CC0-1.0 (generated test content)",
                    "sha256": SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined(),
                    "notes": category == "orientation" ? "EXIF orientation \([3, 6, 8][variant]); visible orientation must be retained" : "Generated coverage fixture; not representative of a whole real-image category"
                ])
            }
        }
        let data = try JSONSerialization.data(withJSONObject: ["schema_version": 1, "images": manifest], options: [.prettyPrinted, .sortedKeys])
        try data.write(to: directory.appendingPathComponent("manifest.json"))
        print("Generated \(manifest.count) fixtures at \(directory.path)")
    }
}
