import XCTest
import AppKit

final class CuteCatAssetGenerator: XCTestCase {
    
    func testGenerateCuteCatAssets() throws {
        let currentFile = URL(fileURLWithPath: #filePath)
        let projectRoot = currentFile
            .deletingLastPathComponent() // ImagePetTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // root
        
        let resourcesURL = projectRoot
            .appendingPathComponent("Sources")
            .appendingPathComponent("ImagePet")
            .appendingPathComponent("Resources")
            .appendingPathComponent("CuteCat")
        
        let fm = FileManager.default
        try fm.createDirectory(at: resourcesURL, withIntermediateDirectories: true)
        
        let states: [(name: String, frames: Int)] = [
            ("idle", 8),
            ("dragHover", 4),
            ("eating", 6),
            ("done", 12),
            ("issues", 8),
            ("stretch", 12),
            ("yawn", 10),
            ("petting", 8),
            ("sleep", 8)
        ]
        
        let width = 256
        let height = 256
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        
        for state in states {
            let folderURL = resourcesURL.appendingPathComponent(state.name)
            try fm.createDirectory(at: folderURL, withIntermediateDirectories: true)
            
            for i in 0..<state.frames {
                guard let context = CGContext(
                    data: nil,
                    width: width,
                    height: height,
                    bitsPerComponent: bitsPerComponent,
                    bytesPerRow: bytesPerRow,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo
                ) else {
                    XCTFail("Failed to create CGContext")
                    return
                }
                
                drawCat(
                    context: context,
                    width: CGFloat(width),
                    height: CGFloat(height),
                    animation: state.name,
                    frameIndex: i,
                    totalFrames: state.frames
                )
                
                guard let cgImage = context.makeImage() else {
                    XCTFail("Failed to make CGImage")
                    return
                }
                
                let imageRep = NSBitmapImageRep(cgImage: cgImage)
                guard let pngData = imageRep.representation(using: .png, properties: [:]) else {
                    XCTFail("Failed to get PNG data")
                    return
                }
                
                let fileName = String(format: "frame_%03d.png", i)
                let fileURL = folderURL.appendingPathComponent(fileName)
                try pngData.write(to: fileURL)
            }
        }
        
        print("Generated all Cute Cat animation assets at: \(resourcesURL.path)")
    }
    
    private func drawCat(
        context: CGContext,
        width: CGFloat,
        height: CGFloat,
        animation: String,
        frameIndex: Int,
        totalFrames: Int
    ) {
        // Fill background transparent
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        
        // Save context state to flip and scale
        context.saveGState()
        
        // Flip vertically (origin bottom-left to top-left)
        context.translateBy(x: 0, y: height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        // Center-scaled zoom by 2.1x to make the pet larger
        let cx = width / 2.0
        let cy = height / 2.0
        context.translateBy(x: cx, y: cy)
        context.scaleBy(x: 2.1, y: 2.1)
        context.translateBy(x: -cx, y: -cy)
        
        // Shift the cat down by 15 points to center it vertically within the 256x256 canvas
        context.translateBy(x: 0, y: 15)
        
        // Colors
        let orangeColor = CGColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0)
        let whiteColor = CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        let pinkColor = CGColor(red: 1.0, green: 0.75, blue: 0.8, alpha: 1.0)
        let darkGrayColor = CGColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        let sweatBlue = CGColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0)
        
        var bodyScaleY: CGFloat = 1.0
        var bodyScaleX: CGFloat = 1.0
        var bodyOffsetY: CGFloat = 0.0
        var headOffsetY: CGFloat = 0.0
        var tailAngle: CGFloat = 0.0
        var mouthOpen: CGFloat = 0.0
        var eyeType: String = "normal" // "normal", "dizzy", "happy", "lookUp", "closed"
        var drawSweat = false
        var drawCheekBlush = false
        var drawConfetti = false
        var headRotation: CGFloat = 0.0
        
        let progress = Double(frameIndex) / Double(totalFrames)
        let angleRad = progress * 2.0 * Double.pi
        
        switch animation {
        case "idle":
            bodyScaleY = 1.0 + 0.04 * CGFloat(sin(angleRad))
            bodyScaleX = 1.0 - 0.02 * CGFloat(sin(angleRad))
            tailAngle = 0.2 * CGFloat(cos(angleRad))
            if frameIndex == 4 {
                eyeType = "closed"
            }
        case "sleep":
            bodyScaleY = 1.0 + 0.03 * CGFloat(sin(angleRad))
            bodyScaleX = 1.0 - 0.015 * CGFloat(sin(angleRad))
            tailAngle = 0.1 * CGFloat(cos(angleRad))
            eyeType = "closed"
        case "dragHover":
            bodyScaleY = 0.95
            bodyScaleX = 1.05
            mouthOpen = 8.0
            eyeType = "lookUp"
            headOffsetY = -2.0
        case "eating":
            bodyOffsetY = 3.0 * CGFloat(sin(angleRad * 2.0))
            bodyScaleY = 1.0 + 0.05 * CGFloat(sin(angleRad * 2.0))
            mouthOpen = 6.0 * (1.0 + CGFloat(sin(angleRad * 2.0)))
            tailAngle = 0.3 * CGFloat(cos(angleRad * 2.0))
        case "done":
            let jumpY = -18.0 * CGFloat(sin(progress * Double.pi))
            bodyOffsetY = jumpY
            tailAngle = 0.5 * CGFloat(sin(angleRad * 2.0))
            eyeType = "happy"
            drawCheekBlush = true
            if jumpY < -15.0 {
                drawConfetti = true
            }
        case "issues":
            headRotation = 0.15 * CGFloat(sin(angleRad * 2.0))
            eyeType = "dizzy"
            drawSweat = true
        case "stretch":
            bodyScaleX = 1.15 - 0.1 * CGFloat(sin(angleRad))
            bodyScaleY = 0.9 + 0.05 * CGFloat(sin(angleRad))
            tailAngle = 0.4 * CGFloat(sin(angleRad))
        case "yawn":
            bodyScaleY = 0.9 + 0.05 * CGFloat(sin(angleRad))
            headOffsetY = 2.0 * CGFloat(sin(angleRad))
            mouthOpen = 14.0 * CGFloat(sin(progress * Double.pi))
            eyeType = "closed"
        case "petting":
            bodyScaleY = 1.0 + 0.03 * CGFloat(sin(angleRad * 2.0))
            eyeType = "closed"
            tailAngle = 0.5 * CGFloat(sin(angleRad * 2.0))
            drawCheekBlush = true
        default:
            break
        }
        
        // 1. Draw Tail (from back of body)
        context.saveGState()
        context.translateBy(x: cx - 25, y: cy - 10 + bodyOffsetY)
        context.rotate(by: tailAngle)
        context.setStrokeColor(orangeColor)
        context.setLineWidth(8.0)
        context.setLineCap(.round)
        context.beginPath()
        context.move(to: CGPoint(x: 0, y: 0))
        context.addCurve(to: CGPoint(x: -15, y: -25), control1: CGPoint(x: -10, y: -10), control2: CGPoint(x: -15, y: -18))
        context.strokePath()
        context.restoreGState()
        
        // 2. Draw Body
        context.saveGState()
        context.translateBy(x: cx, y: cy + bodyOffsetY)
        context.scaleBy(x: bodyScaleX, y: bodyScaleY)
        
        // Orange body
        context.setFillColor(orangeColor)
        let bodyRect = CGRect(x: -35, y: -25, width: 70, height: 50)
        context.fillEllipse(in: bodyRect)
        
        // White belly overlay
        context.setFillColor(whiteColor)
        let bellyRect = CGRect(x: -20, y: -15, width: 40, height: 30)
        context.fillEllipse(in: bellyRect)
        
        // Paws
        context.setFillColor(orangeColor)
        context.fillEllipse(in: CGRect(x: -28, y: 15, width: 14, height: 12))
        context.fillEllipse(in: CGRect(x: 14, y: 15, width: 14, height: 12))
        context.setFillColor(whiteColor)
        context.fillEllipse(in: CGRect(x: -26, y: 20, width: 10, height: 8))
        context.fillEllipse(in: CGRect(x: 16, y: 20, width: 10, height: 8))
        
        context.restoreGState()
        
        // 3. Draw Head
        context.saveGState()
        context.translateBy(x: cx + 10, y: cy - 25 + bodyOffsetY + headOffsetY)
        context.rotate(by: headRotation)
        
        // Head rounded rect
        context.setFillColor(orangeColor)
        let headRect = CGRect(x: -22, y: -20, width: 44, height: 36)
        let headPath = CGPath(roundedRect: headRect, cornerWidth: 14, cornerHeight: 14, transform: nil)
        context.addPath(headPath)
        context.fillPath()
        
        // Left Ear
        context.setFillColor(orangeColor)
        context.beginPath()
        context.move(to: CGPoint(x: -18, y: -16))
        context.addLine(to: CGPoint(x: -22, y: -32))
        context.addLine(to: CGPoint(x: -6, y: -18))
        context.closePath()
        context.fillPath()
        
        context.setFillColor(pinkColor)
        context.beginPath()
        context.move(to: CGPoint(x: -16, y: -17))
        context.addLine(to: CGPoint(x: -19, y: -28))
        context.addLine(to: CGPoint(x: -9, y: -18))
        context.closePath()
        context.fillPath()
        
        // Right Ear
        context.setFillColor(orangeColor)
        context.beginPath()
        context.move(to: CGPoint(x: 6, y: -18))
        context.addLine(to: CGPoint(x: 22, y: -32))
        context.addLine(to: CGPoint(x: 18, y: -16))
        context.closePath()
        context.fillPath()
        
        context.setFillColor(pinkColor)
        context.beginPath()
        context.move(to: CGPoint(x: 9, y: -18))
        context.addLine(to: CGPoint(x: 19, y: -28))
        context.addLine(to: CGPoint(x: 16, y: -17))
        context.closePath()
        context.fillPath()
        
        // Eyes
        context.setFillColor(darkGrayColor)
        context.setStrokeColor(darkGrayColor)
        context.setLineWidth(2.5)
        context.setLineCap(.round)
        
        let leftEyeCenter = CGPoint(x: -10, y: -4)
        let rightEyeCenter = CGPoint(x: 6, y: -4)
        
        switch eyeType {
        case "closed":
            context.beginPath()
            context.addArc(center: leftEyeCenter, radius: 3.0, startAngle: 0, endAngle: CGFloat.pi, clockwise: true)
            context.strokePath()
            
            context.beginPath()
            context.addArc(center: rightEyeCenter, radius: 3.0, startAngle: 0, endAngle: CGFloat.pi, clockwise: true)
            context.strokePath()
        case "happy":
            context.beginPath()
            context.addArc(center: leftEyeCenter, radius: 3.0, startAngle: CGFloat.pi, endAngle: 0, clockwise: true)
            context.strokePath()
            
            context.beginPath()
            context.addArc(center: rightEyeCenter, radius: 3.0, startAngle: CGFloat.pi, endAngle: 0, clockwise: true)
            context.strokePath()
        case "dizzy":
            context.beginPath()
            context.move(to: CGPoint(x: leftEyeCenter.x - 3, y: leftEyeCenter.y - 3))
            context.addLine(to: CGPoint(x: leftEyeCenter.x + 3, y: leftEyeCenter.y + 3))
            context.move(to: CGPoint(x: leftEyeCenter.x + 3, y: leftEyeCenter.y - 3))
            context.addLine(to: CGPoint(x: leftEyeCenter.x - 3, y: leftEyeCenter.y + 3))
            context.strokePath()
            
            context.beginPath()
            context.move(to: CGPoint(x: rightEyeCenter.x - 3, y: rightEyeCenter.y - 3))
            context.addLine(to: CGPoint(x: rightEyeCenter.x + 3, y: rightEyeCenter.y + 3))
            context.move(to: CGPoint(x: rightEyeCenter.x + 3, y: rightEyeCenter.y - 3))
            context.addLine(to: CGPoint(x: rightEyeCenter.x - 3, y: rightEyeCenter.y + 3))
            context.strokePath()
        case "lookUp":
            context.setFillColor(darkGrayColor)
            context.fillEllipse(in: CGRect(x: leftEyeCenter.x - 3, y: leftEyeCenter.y - 4, width: 6, height: 6))
            context.fillEllipse(in: CGRect(x: rightEyeCenter.x - 3, y: rightEyeCenter.y - 4, width: 6, height: 6))
            context.setFillColor(whiteColor)
            context.fillEllipse(in: CGRect(x: leftEyeCenter.x - 1, y: leftEyeCenter.y - 3, width: 2, height: 2))
            context.fillEllipse(in: CGRect(x: rightEyeCenter.x - 1, y: rightEyeCenter.y - 3, width: 2, height: 2))
        default:
            context.fillEllipse(in: CGRect(x: leftEyeCenter.x - 2.5, y: leftEyeCenter.y - 2.5, width: 5, height: 5))
            context.fillEllipse(in: CGRect(x: rightEyeCenter.x - 2.5, y: rightEyeCenter.y - 2.5, width: 5, height: 5))
            context.setFillColor(whiteColor)
            context.fillEllipse(in: CGRect(x: leftEyeCenter.x - 1, y: leftEyeCenter.y - 1.5, width: 1.5, height: 1.5))
            context.fillEllipse(in: CGRect(x: rightEyeCenter.x - 1, y: rightEyeCenter.y - 1.5, width: 1.5, height: 1.5))
        }
        
        // Nose
        context.setFillColor(darkGrayColor)
        context.beginPath()
        context.move(to: CGPoint(x: -2, y: 0))
        context.addLine(to: CGPoint(x: 2, y: 0))
        context.addLine(to: CGPoint(x: 0, y: 2))
        context.closePath()
        context.fillPath()
        
        // Mouth
        context.setStrokeColor(darkGrayColor)
        context.setLineWidth(1.8)
        if mouthOpen > 0 {
            context.setFillColor(pinkColor)
            let mouthRect = CGRect(x: -3, y: 2, width: 6, height: mouthOpen)
            context.fillEllipse(in: mouthRect)
            context.strokeEllipse(in: mouthRect)
        } else {
            context.beginPath()
            context.addArc(center: CGPoint(x: -1.5, y: 1), radius: 1.5, startAngle: 0, endAngle: CGFloat.pi, clockwise: false)
            context.move(to: CGPoint(x: 0, y: 1))
            context.addArc(center: CGPoint(x: 1.5, y: 1), radius: 1.5, startAngle: 0, endAngle: CGFloat.pi, clockwise: false)
            context.strokePath()
        }
        
        // Whiskers
        context.setStrokeColor(darkGrayColor.copy(alpha: 0.5)!)
        context.setLineWidth(1.2)
        context.beginPath()
        context.move(to: CGPoint(x: -16, y: 0))
        context.addLine(to: CGPoint(x: -24, y: -2))
        context.move(to: CGPoint(x: -16, y: 3))
        context.addLine(to: CGPoint(x: -25, y: 3))
        context.move(to: CGPoint(x: 16, y: 0))
        context.addLine(to: CGPoint(x: 24, y: -2))
        context.move(to: CGPoint(x: 16, y: 3))
        context.addLine(to: CGPoint(x: 25, y: 3))
        context.strokePath()
        
        // Blush
        if drawCheekBlush {
            context.setFillColor(pinkColor.copy(alpha: 0.6)!)
            context.fillEllipse(in: CGRect(x: -16, y: 0, width: 6, height: 4))
            context.fillEllipse(in: CGRect(x: 10, y: 0, width: 6, height: 4))
        }
        
        context.restoreGState()
        
        // 4. Sweat
        if drawSweat {
            context.saveGState()
            context.translateBy(x: cx + 32, y: cy - 40 + bodyOffsetY)
            context.setFillColor(sweatBlue)
            context.beginPath()
            context.move(to: CGPoint(x: 0, y: -6))
            context.addCurve(to: CGPoint(x: 3, y: 2), control1: CGPoint(x: 2, y: -3), control2: CGPoint(x: 3, y: -1))
            context.addArc(center: CGPoint(x: 0, y: 2), radius: 3.0, startAngle: 0, endAngle: CGFloat.pi, clockwise: false)
            context.addCurve(to: CGPoint(x: 0, y: -6), control1: CGPoint(x: -3, y: -1), control2: CGPoint(x: -2, y: -3))
            context.closePath()
            context.fillPath()
            context.restoreGState()
        }
        
        // 5. Confetti
        if drawConfetti {
            context.saveGState()
            let colors = [
                CGColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 0.8),
                CGColor(red: 0.3, green: 0.9, blue: 0.3, alpha: 0.8),
                CGColor(red: 0.3, green: 0.3, blue: 1.0, alpha: 0.8),
                CGColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 0.8)
            ]
            
            let seed = frameIndex
            for j in 0..<6 {
                let color = colors[(seed + j) % colors.count]
                context.setFillColor(color)
                let rx = cx + CGFloat(sin(Double(j + seed) * 1.5)) * 40.0
                let ry = cy - 40.0 + CGFloat(cos(Double(j * 2 + seed))) * 15.0
                context.fillEllipse(in: CGRect(x: rx, y: ry, width: 4, height: 4))
            }
            context.restoreGState()
        }
        
        // Restore context state
        context.restoreGState()
    }
}
