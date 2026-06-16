#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation

struct AnimationSpec {
    let name: String
    let frames: Int
}

enum EyeStyle {
    case normal
    case blink
    case happy
    case worried
    case dizzy
    case lookUp
    case sleepy
    case content
}

struct Pose {
    var bodyScaleX: CGFloat = 1
    var bodyScaleY: CGFloat = 1
    var bodyOffsetY: CGFloat = 0
    var headOffsetX: CGFloat = 0
    var headOffsetY: CGFloat = 0
    var headRotation: CGFloat = 0
    var tailAngle: CGFloat = 0
    var mouthOpen: CGFloat = 0
    var cheekPuff: CGFloat = 0
    var pawLift: CGFloat = 0
    var earDroop: CGFloat = 0
    var eyeStyle: EyeStyle = .normal
    var showBlush = false
    var showConfetti = false
    var showSweat = false
    var showQuestion = false
    var showImageSnack = false
    var showCrumbs = false
    var showHeart = false
    var showSleepMarks = false
}

let specs: [AnimationSpec] = [
    AnimationSpec(name: "idle", frames: 8),
    AnimationSpec(name: "dragHover", frames: 4),
    AnimationSpec(name: "eating", frames: 6),
    AnimationSpec(name: "done", frames: 12),
    AnimationSpec(name: "issues", frames: 8),
    AnimationSpec(name: "stretch", frames: 12),
    AnimationSpec(name: "yawn", frames: 10),
    AnimationSpec(name: "petting", frames: 8),
    AnimationSpec(name: "sleep", frames: 8)
]

let canvasSize = 256
let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func generateTheme(themeName: String) throws {
    let resourcesURL = rootURL
        .appendingPathComponent("Sources")
        .appendingPathComponent("ImagePet")
        .appendingPathComponent("Resources")
        .appendingPathComponent(themeName)

    try FileManager.default.createDirectory(at: resourcesURL, withIntermediateDirectories: true)

    for spec in specs {
        let folderURL = resourcesURL.appendingPathComponent(spec.name)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        for frame in 0..<spec.frames {
            let image = try renderFrame(themeName: themeName, animation: spec.name, frameIndex: frame, totalFrames: spec.frames)
            let imageRep = NSBitmapImageRep(cgImage: image)
            guard let pngData = imageRep.representation(using: .png, properties: [:]) else {
                throw AssetError.pngEncodingFailed
            }

            let fileURL = folderURL.appendingPathComponent(String(format: "frame_%03d.png", frame))
            try pngData.write(to: fileURL)
        }
    }
    print("Generated \(themeName) assets at \(resourcesURL.path)")
}

enum AssetError: Error {
    case contextCreationFailed
    case imageCreationFailed
    case pngEncodingFailed
    case unknownTheme(String)
}

func renderFrame(themeName: String, animation: String, frameIndex: Int, totalFrames: Int) throws -> CGImage {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

    guard let context = CGContext(
        data: nil,
        width: canvasSize,
        height: canvasSize,
        bitsPerComponent: 8,
        bytesPerRow: 4 * canvasSize,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else {
        throw AssetError.contextCreationFailed
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.clear(CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize))

    context.translateBy(x: 0, y: CGFloat(canvasSize))
    context.scaleBy(x: 1, y: -1)

    let pose = poseFor(animation: animation, frameIndex: frameIndex, totalFrames: totalFrames)
    
    if themeName == "PixelSlime" {
        drawSlime(in: context, pose: pose, themeName: themeName, frameIndex: frameIndex)
    } else if themeName == "MochiBunny" {
        drawBunny(in: context, pose: pose, frameIndex: frameIndex)
    } else {
        drawCatOrShiba(in: context, pose: pose, themeName: themeName, frameIndex: frameIndex)
    }

    guard let image = context.makeImage() else {
        throw AssetError.imageCreationFailed
    }
    return image
}

func poseFor(animation: String, frameIndex: Int, totalFrames: Int) -> Pose {
    let t = CGFloat(frameIndex) / CGFloat(max(totalFrames, 1))
    let wave = sin(t * 2 * .pi)
    let fastWave = sin(t * 4 * .pi)
    var pose = Pose()

    switch animation {
    case "idle":
        pose.bodyScaleY = 1 + 0.05 * wave
        pose.bodyScaleX = 1 - 0.025 * wave
        pose.bodyOffsetY = -3.0 * wave
        pose.headOffsetY = -1.5 * wave
        pose.tailAngle = 0.35 * cos(t * 2 * .pi)
        pose.eyeStyle = frameIndex == 4 ? .blink : .normal
    case "dragHover":
        pose.bodyScaleX = 1.12
        pose.bodyScaleY = 0.88
        pose.headOffsetX = 6
        pose.headOffsetY = -8
        pose.tailAngle = 0.6 + 0.25 * wave
        pose.mouthOpen = 14 + 3.5 * max(0, wave)
        pose.pawLift = 12
        pose.eyeStyle = .lookUp
        pose.showImageSnack = true
    case "eating":
        pose.bodyOffsetY = -3.5 * fastWave
        pose.bodyScaleX = 1 + 0.05 * fastWave
        pose.bodyScaleY = 1 - 0.04 * fastWave
        pose.headOffsetX = 3.5
        pose.mouthOpen = 8 + 7 * max(0, fastWave)
        pose.cheekPuff = 4 + 2.5 * max(0, fastWave)
        pose.tailAngle = 0.45 * cos(t * 4 * .pi)
        pose.eyeStyle = .content
        pose.showCrumbs = true
    case "done":
        let jump = -36 * sin(t * .pi)
        pose.bodyOffsetY = jump
        pose.headOffsetY = jump * 0.22
        pose.bodyScaleX = 1 + 0.12 * sin(t * .pi)
        pose.bodyScaleY = 1 - 0.09 * sin(t * .pi)
        pose.tailAngle = 0.85 * sin(t * 2 * .pi) + 0.4
        pose.eyeStyle = .happy
        pose.showBlush = true
        pose.showConfetti = frameIndex > 1 && frameIndex < totalFrames - 1
    case "issues":
        pose.headRotation = -0.24 + 0.06 * wave
        pose.headOffsetX = -4
        pose.tailAngle = -0.4 + 0.1 * wave
        pose.eyeStyle = frameIndex.isMultiple(of: 2) ? .worried : .dizzy
        pose.showSweat = true
        pose.showQuestion = true
    case "stretch":
        let stretch = sin(t * .pi)
        pose.bodyScaleX = 1 + 0.26 * stretch
        pose.bodyScaleY = 1 - 0.20 * stretch
        pose.headOffsetY = 6 * stretch
        pose.headRotation = -0.12 * stretch
        pose.tailAngle = 0.9 * stretch
        pose.pawLift = -8 * stretch
        pose.eyeStyle = .sleepy
    case "yawn":
        let open = sin(t * .pi)
        pose.bodyScaleY = 0.94 + 0.05 * wave
        pose.headOffsetY = 3.5 * wave
        pose.earDroop = 8 * open
        pose.mouthOpen = 18 * open
        pose.tailAngle = 0.2 * wave
        pose.eyeStyle = .sleepy
    case "petting":
        pose.bodyScaleY = 1 + 0.04 * fastWave
        pose.headOffsetY = -2
        pose.tailAngle = 0.85 * sin(t * 4 * .pi)
        pose.eyeStyle = .content
        pose.showBlush = true
        pose.showHeart = frameIndex > 1
    case "sleep":
        pose.bodyScaleY = 1 + 0.035 * wave
        pose.bodyScaleX = 1 - 0.018 * wave
        pose.headOffsetY = 2.2 * wave
        pose.tailAngle = 0.15 * wave
        pose.eyeStyle = .sleepy
        pose.showSleepMarks = true
    default:
        break
    }

    return pose
}

func drawCatOrShiba(in context: CGContext, pose: Pose, themeName: String, frameIndex: Int) {
    var fur = cgColor(0.96, 0.58, 0.20, 1.0)
    var furLight = cgColor(1.0, 0.71, 0.33, 1.0)
    var outline = cgColor(0.42, 0.24, 0.13, 1.0)
    var cream = cgColor(1.0, 0.92, 0.76, 1.0)
    var innerEar = cgColor(0.98, 0.62, 0.56, 1.0)
    let dark = cgColor(0.22, 0.16, 0.12, 1.0)
    let blush = cgColor(1.0, 0.48, 0.55, 0.58)
    let blue = cgColor(0.20, 0.55, 1.0, 0.9)
    let warning = cgColor(0.95, 0.24, 0.18, 0.9)

    if themeName == "ShibaInu" {
        fur = cgColor(0.85, 0.48, 0.15, 1.0)       // Shiba tan/orange
        furLight = cgColor(0.95, 0.70, 0.45, 1.0)  // Shiba light tan
        outline = cgColor(0.25, 0.15, 0.08, 1.0)   // Dark brown outline
        cream = cgColor(0.98, 0.96, 0.90, 1.0)     // Creamy white belly/paws
        innerEar = cgColor(0.98, 0.65, 0.60, 1.0)
    }

    context.saveGState()
    context.translateBy(x: 0, y: pose.bodyOffsetY + 8)

    drawShadow(in: context)
    drawTail(in: context, fill: fur, stroke: outline, angle: pose.tailAngle, isShiba: themeName == "ShibaInu")
    drawBackPaws(in: context, fill: furLight, stroke: outline, cream: cream)
    drawBody(in: context, fill: fur, stroke: outline, cream: cream, pose: pose)
    drawFrontPaws(in: context, fill: furLight, stroke: outline, cream: cream, lift: pose.pawLift)
    drawHead(in: context, pose: pose, fill: fur, stroke: outline, innerEar: innerEar, dark: dark, cream: cream, blush: blush, isShiba: themeName == "ShibaInu")

    if pose.showImageSnack {
        drawImageSnack(in: context, x: 180, y: 118, rotation: -0.12)
    }
    if pose.showCrumbs {
        drawCrumbs(in: context, frameIndex: frameIndex)
    }
    if pose.showConfetti {
        drawConfetti(in: context, frameIndex: frameIndex)
    }
    if pose.showSweat {
        drawSweat(in: context, color: blue)
    }
    if pose.showQuestion {
        drawQuestionBubble(in: context, color: warning)
    }
    if pose.showHeart {
        drawHeart(in: context)
    }
    if pose.showSleepMarks {
        drawSleepMarks(in: context)
    }

    context.restoreGState()
}

func drawSlime(in context: CGContext, pose: Pose, themeName: String, frameIndex: Int) {
    let slimeColor = cgColor(0.20, 0.68, 0.88, 0.82) // Bright jelly blue/green
    let outline = cgColor(0.08, 0.28, 0.38, 1.0)
    let blush = cgColor(1.0, 0.48, 0.55, 0.58)
    let warning = cgColor(0.95, 0.24, 0.18, 0.9)
    let blue = cgColor(0.20, 0.55, 1.0, 0.9)
    let dark = cgColor(0.08, 0.22, 0.32, 1.0)
    let cream = cgColor(1.0, 1.0, 1.0, 1.0)

    context.saveGState()
    context.translateBy(x: 0, y: pose.bodyOffsetY)

    drawShadow(in: context)

    // Slime Blob Body
    context.saveGState()
    context.translateBy(x: 128, y: 154)
    context.scaleBy(x: pose.bodyScaleX * 1.15, y: pose.bodyScaleY * 0.95)
    
    let path = CGMutablePath()
    path.addEllipse(in: CGRect(x: -56, y: -44, width: 112, height: 88))
    context.addPath(path)
    context.setFillColor(slimeColor)
    context.setStrokeColor(outline)
    context.setLineWidth(4.5)
    context.drawPath(using: .fillStroke)

    // Glossy reflection highlight on the top left
    drawEllipse(in: context, rect: CGRect(x: -34, y: -26, width: 18, height: 9), fill: cgColor(1, 1, 1, 0.42), stroke: nil, lineWidth: 0)

    // Draw a cute green sprout on top of slime head
    context.saveGState()
    context.translateBy(x: 0, y: -44)
    
    let leafColor = cgColor(0.40, 0.80, 0.20, 1.0)
    let leafOutline = cgColor(0.12, 0.35, 0.08, 1.0)
    
    // Stem
    context.beginPath()
    context.move(to: CGPoint(x: 0, y: 2))
    context.addQuadCurve(to: CGPoint(x: -2, y: -10), control: CGPoint(x: -1, y: -4))
    context.setStrokeColor(leafOutline)
    context.setLineWidth(3.0)
    context.setLineCap(.round)
    context.strokePath()
    
    // Left leaf
    let leftLeaf = CGMutablePath()
    leftLeaf.move(to: CGPoint(x: -2, y: -10))
    leftLeaf.addQuadCurve(to: CGPoint(x: -14, y: -15), control: CGPoint(x: -11, y: -9))
    leftLeaf.addQuadCurve(to: CGPoint(x: -2, y: -10), control: CGPoint(x: -6, y: -17))
    leftLeaf.closeSubpath()
    drawPath(in: context, path: leftLeaf, fill: leafColor, stroke: leafOutline, lineWidth: 2.2)
    
    // Right leaf
    let rightLeaf = CGMutablePath()
    rightLeaf.move(to: CGPoint(x: -2, y: -10))
    rightLeaf.addQuadCurve(to: CGPoint(x: 10, y: -13), control: CGPoint(x: 8, y: -7))
    rightLeaf.addQuadCurve(to: CGPoint(x: -2, y: -10), control: CGPoint(x: 4, y: -15))
    rightLeaf.closeSubpath()
    drawPath(in: context, path: rightLeaf, fill: leafColor, stroke: leafOutline, lineWidth: 2.2)
    
    context.restoreGState() // Sprout

    // Draw Face directly on Slime Body
    context.saveGState()
    context.translateBy(x: pose.headOffsetX, y: pose.headOffsetY + 8)
    context.rotate(by: pose.headRotation)

    drawEyes(in: context, style: pose.eyeStyle, dark: dark, cream: cream)
    drawNoseAndMouth(in: context, mouthOpen: pose.mouthOpen, dark: dark)

    if pose.showBlush {
        drawEllipse(in: context, rect: CGRect(x: -32, y: 2, width: 12, height: 7), fill: blush, stroke: nil, lineWidth: 0)
        drawEllipse(in: context, rect: CGRect(x: 20, y: 2, width: 12, height: 7), fill: blush, stroke: nil, lineWidth: 0)
    } else {
        let faintBlush = blush.copy(alpha: blush.alpha * 0.45)!
        drawEllipse(in: context, rect: CGRect(x: -31, y: 2, width: 10, height: 6), fill: faintBlush, stroke: nil, lineWidth: 0)
        drawEllipse(in: context, rect: CGRect(x: 21, y: 2, width: 10, height: 6), fill: faintBlush, stroke: nil, lineWidth: 0)
    }

    context.restoreGState() // Face
    context.restoreGState() // Body

    if pose.showImageSnack {
        drawImageSnack(in: context, x: 180, y: 118, rotation: -0.12)
    }
    if pose.showCrumbs {
        drawCrumbs(in: context, frameIndex: frameIndex)
    }
    if pose.showConfetti {
        drawConfetti(in: context, frameIndex: frameIndex)
    }
    if pose.showSweat {
        drawSweat(in: context, color: blue)
    }
    if pose.showQuestion {
        drawQuestionBubble(in: context, color: warning)
    }
    if pose.showHeart {
        drawHeart(in: context)
    }
    if pose.showSleepMarks {
        drawSleepMarks(in: context)
    }

    context.restoreGState()
}

func drawBunny(in context: CGContext, pose: Pose, frameIndex: Int) {
    let fur = cgColor(0.98, 0.92, 0.84, 1.0)
    let furLight = cgColor(1.0, 0.97, 0.91, 1.0)
    let outline = cgColor(0.36, 0.26, 0.20, 1.0)
    let innerEar = cgColor(1.0, 0.66, 0.70, 1.0)
    let dark = cgColor(0.24, 0.18, 0.15, 1.0)
    let blush = cgColor(1.0, 0.50, 0.58, 0.58)
    let blue = cgColor(0.20, 0.55, 1.0, 0.9)
    let warning = cgColor(0.95, 0.24, 0.18, 0.9)
    let mint = cgColor(0.56, 0.83, 0.70, 1.0)
    let mintDark = cgColor(0.18, 0.47, 0.37, 1.0)

    context.saveGState()
    context.translateBy(x: 0, y: pose.bodyOffsetY)

    drawShadow(in: context)
    drawBunnyTail(in: context, fill: furLight, stroke: outline, wobble: pose.tailAngle)
    drawBunnyEars(in: context, pose: pose, fill: fur, stroke: outline, inner: innerEar)
    drawBunnyBackPaws(in: context, fill: furLight, stroke: outline)
    drawBunnyBody(in: context, fill: fur, stroke: outline, cream: furLight, pose: pose)
    drawBunnyFrontPaws(in: context, fill: furLight, stroke: outline, lift: pose.pawLift)
    drawBunnyHead(in: context, pose: pose, fill: fur, stroke: outline, innerEar: innerEar, dark: dark, blush: blush)
    drawBunnyScarf(in: context, fill: mint, stroke: mintDark)

    if pose.showImageSnack {
        drawImageSnack(in: context, x: 180, y: 120, rotation: -0.12)
    }
    if pose.showCrumbs {
        drawCrumbs(in: context, frameIndex: frameIndex)
    }
    if pose.showConfetti {
        drawConfetti(in: context, frameIndex: frameIndex)
    }
    if pose.showSweat {
        drawSweat(in: context, color: blue)
    }
    if pose.showQuestion {
        drawQuestionBubble(in: context, color: warning)
    }
    if pose.showHeart {
        drawHeart(in: context)
    }
    if pose.showSleepMarks {
        drawSleepMarks(in: context)
    }

    context.restoreGState()
}

func drawBunnyEars(in context: CGContext, pose: Pose, fill: CGColor, stroke: CGColor, inner: CGColor) {
    let headCenter = CGPoint(x: 130 + pose.headOffsetX, y: 126 + pose.headOffsetY)
    drawBunnyEar(
        in: context,
        center: CGPoint(x: headCenter.x - 25, y: headCenter.y - 30 + pose.earDroop * 0.35),
        tilt: -0.30 + pose.tailAngle * 0.10 + pose.headRotation * 0.5,
        fill: fill,
        stroke: stroke,
        inner: inner
    )
    drawBunnyEar(
        in: context,
        center: CGPoint(x: headCenter.x + 27, y: headCenter.y - 30 + pose.earDroop * 0.45),
        tilt: 0.26 + pose.tailAngle * 0.08 + pose.headRotation * 0.5,
        fill: fill,
        stroke: stroke,
        inner: inner
    )
}

func drawBunnyEar(in context: CGContext, center: CGPoint, tilt: CGFloat, fill: CGColor, stroke: CGColor, inner: CGColor) {
    context.saveGState()
    context.translateBy(x: center.x, y: center.y)
    context.rotate(by: tilt)

    let outer = CGPath(roundedRect: CGRect(x: -12, y: -48, width: 24, height: 66), cornerWidth: 13, cornerHeight: 18, transform: nil)
    drawPath(in: context, path: outer, fill: fill, stroke: stroke, lineWidth: 3.5)

    let innerPath = CGPath(roundedRect: CGRect(x: -6, y: -38, width: 12, height: 45), cornerWidth: 7, cornerHeight: 12, transform: nil)
    drawPath(in: context, path: innerPath, fill: inner.copy(alpha: 0.86)!, stroke: nil, lineWidth: 0)
    context.restoreGState()
}

func drawBunnyTail(in context: CGContext, fill: CGColor, stroke: CGColor, wobble: CGFloat) {
    let offset = 2.8 * sin(wobble)
    drawEllipse(in: context, rect: CGRect(x: 172 + offset, y: 158 - offset * 0.4, width: 26, height: 25), fill: fill, stroke: stroke, lineWidth: 3)
    drawEllipse(in: context, rect: CGRect(x: 181 + offset, y: 163 - offset * 0.4, width: 8, height: 7), fill: cgColor(1, 1, 1, 0.45), stroke: nil, lineWidth: 0)
}

func drawBunnyBackPaws(in context: CGContext, fill: CGColor, stroke: CGColor) {
    drawEllipse(in: context, rect: CGRect(x: 77, y: 192, width: 34, height: 19), fill: fill, stroke: stroke, lineWidth: 3)
    drawEllipse(in: context, rect: CGRect(x: 146, y: 192, width: 35, height: 19), fill: fill, stroke: stroke, lineWidth: 3)
    context.setStrokeColor(stroke.copy(alpha: 0.45)!)
    context.setLineWidth(1.3)
    context.beginPath()
    context.move(to: CGPoint(x: 91, y: 198))
    context.addLine(to: CGPoint(x: 91, y: 204))
    context.move(to: CGPoint(x: 162, y: 198))
    context.addLine(to: CGPoint(x: 162, y: 204))
    context.strokePath()
}

func drawBunnyBody(in context: CGContext, fill: CGColor, stroke: CGColor, cream: CGColor, pose: Pose) {
    context.saveGState()
    context.translateBy(x: 128, y: 164)
    context.scaleBy(x: pose.bodyScaleX * 0.98, y: pose.bodyScaleY)
    drawEllipse(in: context, rect: CGRect(x: -43, y: -40, width: 86, height: 80), fill: fill, stroke: stroke, lineWidth: 3.5)
    drawEllipse(in: context, rect: CGRect(x: -25, y: -16, width: 50, height: 42), fill: cream, stroke: nil, lineWidth: 0)
    context.restoreGState()
}

func drawBunnyFrontPaws(in context: CGContext, fill: CGColor, stroke: CGColor, lift: CGFloat) {
    drawEllipse(in: context, rect: CGRect(x: 91, y: 154 - lift, width: 25, height: 18), fill: fill, stroke: stroke, lineWidth: 3)
    drawEllipse(in: context, rect: CGRect(x: 140, y: 154 - lift * 0.75, width: 25, height: 18), fill: fill, stroke: stroke, lineWidth: 3)
}

func drawBunnyHead(
    in context: CGContext,
    pose: Pose,
    fill: CGColor,
    stroke: CGColor,
    innerEar: CGColor,
    dark: CGColor,
    blush: CGColor
) {
    let headCenter = CGPoint(x: 130 + pose.headOffsetX, y: 126 + pose.headOffsetY)

    context.saveGState()
    context.translateBy(x: headCenter.x, y: headCenter.y)
    context.rotate(by: pose.headRotation)

    drawRoundedRect(in: context, rect: CGRect(x: -53, y: -39, width: 106, height: 78), radius: 31, fill: fill, stroke: stroke, lineWidth: 3.5)
    drawEllipse(in: context, rect: CGRect(x: -23, y: 7, width: 46, height: 27), fill: cgColor(1.0, 0.97, 0.91, 0.74), stroke: nil, lineWidth: 0)
    drawBunnyFace(in: context, pose: pose, dark: dark, blush: blush)

    context.restoreGState()
}

func drawBunnyFace(in context: CGContext, pose: Pose, dark: CGColor, blush: CGColor) {
    if pose.cheekPuff > 0 {
        drawEllipse(in: context, rect: CGRect(x: -34, y: -2, width: 18 + pose.cheekPuff, height: 14), fill: cgColor(1.0, 0.97, 0.91, 0.55), stroke: nil, lineWidth: 0)
        drawEllipse(in: context, rect: CGRect(x: 16, y: -2, width: 18 + pose.cheekPuff, height: 14), fill: cgColor(1.0, 0.97, 0.91, 0.55), stroke: nil, lineWidth: 0)
    }

    drawEyes(in: context, style: pose.eyeStyle, dark: dark, cream: cgColor(1, 1, 1, 1))

    drawEllipse(in: context, rect: CGRect(x: -5, y: 2, width: 10, height: 7), fill: cgColor(1.0, 0.44, 0.55, 1.0), stroke: dark, lineWidth: 1.4)

    context.setStrokeColor(dark)
    context.setLineWidth(2.2)
    context.setLineCap(.round)
    if pose.mouthOpen > 1 {
        drawEllipse(in: context, rect: CGRect(x: -6, y: 10, width: 12, height: max(7, pose.mouthOpen)), fill: cgColor(0.72, 0.22, 0.25, 1), stroke: dark, lineWidth: 2)
    } else {
        context.beginPath()
        context.move(to: CGPoint(x: 0, y: 8))
        context.addCurve(to: CGPoint(x: -8, y: 14), control1: CGPoint(x: -2, y: 13), control2: CGPoint(x: -6, y: 15))
        context.move(to: CGPoint(x: 0, y: 8))
        context.addCurve(to: CGPoint(x: 8, y: 14), control1: CGPoint(x: 2, y: 13), control2: CGPoint(x: 6, y: 15))
        context.strokePath()
    }

    context.setStrokeColor(dark.copy(alpha: 0.38)!)
    context.setLineWidth(1.3)
    context.beginPath()
    context.move(to: CGPoint(x: -31, y: 8))
    context.addLine(to: CGPoint(x: -45, y: 5))
    context.move(to: CGPoint(x: -31, y: 14))
    context.addLine(to: CGPoint(x: -46, y: 15))
    context.move(to: CGPoint(x: 31, y: 8))
    context.addLine(to: CGPoint(x: 45, y: 5))
    context.move(to: CGPoint(x: 31, y: 14))
    context.addLine(to: CGPoint(x: 46, y: 15))
    context.strokePath()

    let blushAlpha = pose.showBlush ? blush.alpha : blush.alpha * 0.45
    drawEllipse(in: context, rect: CGRect(x: -39, y: 3, width: 14, height: 9), fill: blush.copy(alpha: blushAlpha)!, stroke: nil, lineWidth: 0)
    drawEllipse(in: context, rect: CGRect(x: 25, y: 3, width: 14, height: 9), fill: blush.copy(alpha: blushAlpha)!, stroke: nil, lineWidth: 0)
}

func drawBunnyScarf(in context: CGContext, fill: CGColor, stroke: CGColor) {
    drawRoundedRect(in: context, rect: CGRect(x: 98, y: 141, width: 61, height: 15), radius: 7, fill: fill, stroke: stroke, lineWidth: 2.2)

    let knot = CGMutablePath()
    knot.move(to: CGPoint(x: 151, y: 150))
    knot.addLine(to: CGPoint(x: 174, y: 145))
    knot.addLine(to: CGPoint(x: 169, y: 165))
    knot.closeSubpath()
    drawPath(in: context, path: knot, fill: fill, stroke: stroke, lineWidth: 2.0)
}

func drawShadow(in context: CGContext) {
    context.setFillColor(cgColor(0.0, 0.0, 0.0, 0.10))
    context.fillEllipse(in: CGRect(x: 73, y: 205, width: 112, height: 17))
}

func drawTail(in context: CGContext, fill: CGColor, stroke: CGColor, angle: CGFloat, isShiba: Bool) {
    context.saveGState()
    
    if isShiba {
        // Shiba curled tail
        context.translateBy(x: 85, y: 148)
        let tail = CGMutablePath()
        tail.addArc(center: CGPoint(x: -15, y: -15), radius: 20, startAngle: 0, endAngle: .pi * 1.6, clockwise: false)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.addPath(tail)
        context.setStrokeColor(stroke)
        context.setLineWidth(20)
        context.strokePath()
        
        context.addPath(tail)
        context.setStrokeColor(fill)
        context.setLineWidth(14)
        context.strokePath()
    } else {
        // Cat long tail
        context.translateBy(x: 83, y: 151)
        context.rotate(by: angle)

        let tail = CGMutablePath()
        tail.move(to: CGPoint(x: 3, y: 20))
        tail.addCurve(to: CGPoint(x: -38, y: -20), control1: CGPoint(x: -22, y: 10), control2: CGPoint(x: -36, y: -2))
        tail.addCurve(to: CGPoint(x: -24, y: -61), control1: CGPoint(x: -39, y: -42), control2: CGPoint(x: -28, y: -57))

        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.addPath(tail)
        context.setStrokeColor(stroke)
        context.setLineWidth(18)
        context.strokePath()

        context.addPath(tail)
        context.setStrokeColor(fill)
        context.setLineWidth(12)
        context.strokePath()
    }

    context.restoreGState()
}

func drawBackPaws(in context: CGContext, fill: CGColor, stroke: CGColor, cream: CGColor) {
    drawEllipse(in: context, rect: CGRect(x: 77, y: 190, width: 27, height: 21), fill: fill, stroke: stroke, lineWidth: 3)
    drawEllipse(in: context, rect: CGRect(x: 150, y: 190, width: 28, height: 21), fill: fill, stroke: stroke, lineWidth: 3)
    drawEllipse(in: context, rect: CGRect(x: 82, y: 194, width: 17, height: 12), fill: cream, stroke: nil, lineWidth: 0)
    drawEllipse(in: context, rect: CGRect(x: 155, y: 194, width: 17, height: 12), fill: cream, stroke: nil, lineWidth: 0)
}

func drawBody(in context: CGContext, fill: CGColor, stroke: CGColor, cream: CGColor, pose: Pose) {
    context.saveGState()
    context.translateBy(x: 124, y: 157)
    context.scaleBy(x: pose.bodyScaleX, y: pose.bodyScaleY)
    drawEllipse(in: context, rect: CGRect(x: -43, y: -38, width: 86, height: 76), fill: fill, stroke: stroke, lineWidth: 3.5)
    drawEllipse(in: context, rect: CGRect(x: -27, y: -17, width: 54, height: 40), fill: cream, stroke: nil, lineWidth: 0)
    context.restoreGState()
}

func drawFrontPaws(in context: CGContext, fill: CGColor, stroke: CGColor, cream: CGColor, lift: CGFloat) {
    drawEllipse(in: context, rect: CGRect(x: 91, y: 151 - lift, width: 24, height: 19), fill: fill, stroke: stroke, lineWidth: 3)
    drawEllipse(in: context, rect: CGRect(x: 139, y: 151 - lift * 0.75, width: 24, height: 19), fill: fill, stroke: stroke, lineWidth: 3)
    drawEllipse(in: context, rect: CGRect(x: 96, y: 156 - lift, width: 13, height: 9), fill: cream, stroke: nil, lineWidth: 0)
    drawEllipse(in: context, rect: CGRect(x: 144, y: 156 - lift * 0.75, width: 13, height: 9), fill: cream, stroke: nil, lineWidth: 0)
}

func drawHead(
    in context: CGContext,
    pose: Pose,
    fill: CGColor,
    stroke: CGColor,
    innerEar: CGColor,
    dark: CGColor,
    cream: CGColor,
    blush: CGColor,
    isShiba: Bool
) {
    let headCenter = CGPoint(x: 137 + pose.headOffsetX, y: 96 + pose.headOffsetY)

    context.saveGState()
    context.translateBy(x: headCenter.x, y: headCenter.y)
    context.rotate(by: pose.headRotation)

    if isShiba {
        // Shiba triangle ears
        drawShibaEar(in: context, baseX: -35, baseY: -24, tipX: -44, tipY: -58 + pose.earDroop, fill: fill, stroke: stroke, inner: innerEar)
        drawShibaEar(in: context, baseX: 29, baseY: -24, tipX: 38, tipY: -56 + pose.earDroop, fill: fill, stroke: stroke, inner: innerEar)
    } else {
        // Cat curved ears
        drawEar(in: context, baseX: -34, baseY: -24, tipX: -46, tipY: -60 + pose.earDroop, fill: fill, stroke: stroke, inner: innerEar)
        drawEar(in: context, baseX: 31, baseY: -24, tipX: 50, tipY: -58 + pose.earDroop, fill: fill, stroke: stroke, inner: innerEar)
    }

    drawRoundedRect(in: context, rect: CGRect(x: -52, y: -37, width: 104, height: 74), radius: 26, fill: fill, stroke: stroke, lineWidth: 3.5)
    
    if isShiba {
        // Draw white snout for shiba
        drawEllipse(in: context, rect: CGRect(x: -18, y: 3, width: 36, height: 23), fill: cream, stroke: stroke, lineWidth: 2)
    } else {
        drawEllipse(in: context, rect: CGRect(x: -24, y: 8, width: 48, height: 26), fill: cgColor(1, 0.76, 0.42, 0.35), stroke: nil, lineWidth: 0)
    }

    drawFace(in: context, pose: pose, dark: dark, cream: cream, blush: blush, isShiba: isShiba)
    context.restoreGState()
}

func drawEar(
    in context: CGContext,
    baseX: CGFloat,
    baseY: CGFloat,
    tipX: CGFloat,
    tipY: CGFloat,
    fill: CGColor,
    stroke: CGColor,
    inner: CGColor
) {
    let side: CGFloat = tipX < 0 ? -1 : 1
    let outer = CGMutablePath()
    outer.move(to: CGPoint(x: baseX, y: baseY))
    outer.addQuadCurve(to: CGPoint(x: tipX, y: tipY), control: CGPoint(x: baseX + 4 * side, y: tipY + 19))
    outer.addQuadCurve(to: CGPoint(x: baseX + 24 * side, y: baseY + 5), control: CGPoint(x: tipX + 15 * side, y: tipY + 20))
    outer.closeSubpath()
    drawPath(in: context, path: outer, fill: fill, stroke: stroke, lineWidth: 3.5)

    let innerPath = CGMutablePath()
    innerPath.move(to: CGPoint(x: baseX + 6 * side, y: baseY - 2))
    innerPath.addLine(to: CGPoint(x: tipX + 4 * side, y: tipY + 15))
    innerPath.addLine(to: CGPoint(x: baseX + 18 * side, y: baseY + 4))
    innerPath.closeSubpath()
    drawPath(in: context, path: innerPath, fill: inner, stroke: nil, lineWidth: 0)
}

func drawShibaEar(
    in context: CGContext,
    baseX: CGFloat,
    baseY: CGFloat,
    tipX: CGFloat,
    tipY: CGFloat,
    fill: CGColor,
    stroke: CGColor,
    inner: CGColor
) {
    let side: CGFloat = tipX < 0 ? -1 : 1
    let path = CGMutablePath()
    path.move(to: CGPoint(x: baseX, y: baseY))
    path.addLine(to: CGPoint(x: tipX, y: tipY))
    path.addLine(to: CGPoint(x: baseX + 20 * side, y: baseY + 3))
    path.closeSubpath()
    drawPath(in: context, path: path, fill: fill, stroke: stroke, lineWidth: 3.5)
    
    let innerPath = CGMutablePath()
    innerPath.move(to: CGPoint(x: baseX + 4 * side, y: baseY - 1))
    innerPath.addLine(to: CGPoint(x: tipX + 3 * side, y: tipY + 10))
    innerPath.addLine(to: CGPoint(x: baseX + 15 * side, y: baseY + 2))
    innerPath.closeSubpath()
    drawPath(in: context, path: innerPath, fill: inner, stroke: nil, lineWidth: 0)
}

func drawFace(in context: CGContext, pose: Pose, dark: CGColor, cream: CGColor, blush: CGColor, isShiba: Bool) {
    if pose.cheekPuff > 0 {
        drawEllipse(in: context, rect: CGRect(x: -34, y: -5, width: 18 + pose.cheekPuff, height: 14), fill: cream.copy(alpha: 0.55)!, stroke: nil, lineWidth: 0)
        drawEllipse(in: context, rect: CGRect(x: 16, y: -5, width: 18 + pose.cheekPuff, height: 14), fill: cream.copy(alpha: 0.55)!, stroke: nil, lineWidth: 0)
    }

    drawEyes(in: context, style: pose.eyeStyle, dark: dark, cream: cream)
    drawNoseAndMouth(in: context, mouthOpen: pose.mouthOpen, dark: dark)
    
    if !isShiba {
        drawWhiskers(in: context, dark: dark)
    }

    if pose.showBlush {
        drawEllipse(in: context, rect: CGRect(x: -38, y: 3, width: 14, height: 9), fill: blush, stroke: nil, lineWidth: 0)
        drawEllipse(in: context, rect: CGRect(x: 24, y: 3, width: 14, height: 9), fill: blush, stroke: nil, lineWidth: 0)
    } else {
        let faintBlush = blush.copy(alpha: blush.alpha * 0.45)!
        drawEllipse(in: context, rect: CGRect(x: -37, y: 3, width: 12, height: 7), fill: faintBlush, stroke: nil, lineWidth: 0)
        drawEllipse(in: context, rect: CGRect(x: 25, y: 3, width: 12, height: 7), fill: faintBlush, stroke: nil, lineWidth: 0)
    }
}

func drawEyes(in context: CGContext, style: EyeStyle, dark: CGColor, cream: CGColor) {
    let left = CGPoint(x: -21, y: -7)
    let right = CGPoint(x: 18, y: -7)

    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setStrokeColor(dark)
    context.setFillColor(dark)
    context.setLineWidth(3)

    switch style {
    case .normal:
        drawEyeDot(in: context, center: left, cream: cream, dark: dark)
        drawEyeDot(in: context, center: right, cream: cream, dark: dark)
    case .lookUp:
        drawEyeDot(in: context, center: CGPoint(x: left.x, y: left.y - 3), cream: cream, dark: dark)
        drawEyeDot(in: context, center: CGPoint(x: right.x, y: right.y - 3), cream: cream, dark: dark)
    case .blink:
        drawArcEye(in: context, center: left, happy: false)
        drawArcEye(in: context, center: right, happy: false)
    case .happy, .content:
        drawArcEye(in: context, center: left, happy: true)
        drawArcEye(in: context, center: right, happy: true)
    case .sleepy:
        drawClosedEye(in: context, center: left)
        drawClosedEye(in: context, center: right)
    case .worried:
        drawEyeDot(in: context, center: left, cream: cream, dark: dark)
        drawEyeDot(in: context, center: right, cream: cream, dark: dark)
        context.beginPath()
        context.move(to: CGPoint(x: -28, y: -17))
        context.addLine(to: CGPoint(x: -16, y: -20))
        context.move(to: CGPoint(x: 12, y: -20))
        context.addLine(to: CGPoint(x: 26, y: -16))
        context.strokePath()
    case .dizzy:
        drawCrossEye(in: context, center: left)
        drawCrossEye(in: context, center: right)
    }
}

func drawEyeDot(in context: CGContext, center: CGPoint, cream: CGColor, dark: CGColor) {
    context.setFillColor(dark)
    context.fillEllipse(in: CGRect(x: center.x - 6.5, y: center.y - 6.5, width: 13, height: 13))
    context.setFillColor(cream)
    context.fillEllipse(in: CGRect(x: center.x - 3.5, y: center.y - 4.5, width: 4.5, height: 4.5))
    context.setFillColor(dark)
}

func drawArcEye(in context: CGContext, center: CGPoint, happy: Bool) {
    context.beginPath()
    if happy {
        context.addArc(center: center, radius: 6, startAngle: .pi * 0.12, endAngle: .pi * 0.88, clockwise: false)
    } else {
        context.addArc(center: center, radius: 5, startAngle: .pi * 0.1, endAngle: .pi * 0.9, clockwise: true)
    }
    context.strokePath()
}

func drawClosedEye(in context: CGContext, center: CGPoint) {
    context.beginPath()
    context.move(to: CGPoint(x: center.x - 6, y: center.y))
    context.addCurve(to: CGPoint(x: center.x + 6, y: center.y), control1: CGPoint(x: center.x - 2, y: center.y + 3), control2: CGPoint(x: center.x + 2, y: center.y + 3))
    context.strokePath()
}

func drawCrossEye(in context: CGContext, center: CGPoint) {
    context.beginPath()
    context.move(to: CGPoint(x: center.x - 5, y: center.y - 5))
    context.addLine(to: CGPoint(x: center.x + 5, y: center.y + 5))
    context.move(to: CGPoint(x: center.x + 5, y: center.y - 5))
    context.addLine(to: CGPoint(x: center.x - 5, y: center.y + 5))
    context.strokePath()
}

func drawNoseAndMouth(in context: CGContext, mouthOpen: CGFloat, dark: CGColor) {
    context.setFillColor(dark)
    let nose = CGMutablePath()
    nose.move(to: CGPoint(x: -4, y: 1))
    nose.addLine(to: CGPoint(x: 4, y: 1))
    nose.addQuadCurve(to: CGPoint(x: 0, y: 6), control: CGPoint(x: 2, y: 4))
    nose.closeSubpath()
    context.addPath(nose)
    context.fillPath()

    context.setStrokeColor(dark)
    context.setLineWidth(2.3)
    if mouthOpen > 1 {
        let rect = CGRect(x: -5, y: 8, width: 10, height: max(6, mouthOpen))
        drawEllipse(in: context, rect: rect, fill: cgColor(0.72, 0.22, 0.25, 1), stroke: dark, lineWidth: 2)
    } else {
        context.beginPath()
        context.move(to: CGPoint(x: 0, y: 6))
        context.addCurve(to: CGPoint(x: -8, y: 10), control1: CGPoint(x: -2, y: 10), control2: CGPoint(x: -6, y: 11))
        context.move(to: CGPoint(x: 0, y: 6))
        context.addCurve(to: CGPoint(x: 8, y: 10), control1: CGPoint(x: 2, y: 10), control2: CGPoint(x: 6, y: 11))
        context.strokePath()
    }
}

func drawWhiskers(in context: CGContext, dark: CGColor) {
    context.setStrokeColor(dark.copy(alpha: 0.45)!)
    context.setLineWidth(1.7)
    context.setLineCap(.round)
    context.beginPath()
    context.move(to: CGPoint(x: -34, y: 5))
    context.addLine(to: CGPoint(x: -49, y: 2))
    context.move(to: CGPoint(x: -34, y: 11))
    context.addLine(to: CGPoint(x: -50, y: 12))
    context.move(to: CGPoint(x: 34, y: 5))
    context.addLine(to: CGPoint(x: 50, y: 2))
    context.move(to: CGPoint(x: 34, y: 11))
    context.addLine(to: CGPoint(x: 51, y: 12))
    context.strokePath()
}

func drawImageSnack(in context: CGContext, x: CGFloat, y: CGFloat, rotation: CGFloat) {
    context.saveGState()
    context.translateBy(x: x, y: y)
    context.rotate(by: rotation)
    drawRoundedRect(in: context, rect: CGRect(x: -15, y: -12, width: 30, height: 24), radius: 5, fill: cgColor(0.94, 0.98, 1.0, 1), stroke: cgColor(0.22, 0.54, 0.90, 1), lineWidth: 2)
    context.setFillColor(cgColor(0.34, 0.74, 0.48, 1))
    context.fillEllipse(in: CGRect(x: 4, y: -7, width: 5, height: 5))
    context.setFillColor(cgColor(0.30, 0.61, 0.93, 1))
    let hill = CGMutablePath()
    hill.move(to: CGPoint(x: -10, y: 8))
    hill.addLine(to: CGPoint(x: -1, y: -1))
    hill.addLine(to: CGPoint(x: 5, y: 7))
    hill.addLine(to: CGPoint(x: 11, y: -2))
    hill.addLine(to: CGPoint(x: 11, y: 9))
    hill.addLine(to: CGPoint(x: -10, y: 9))
    hill.closeSubpath()
    context.addPath(hill)
    context.fillPath()
    context.restoreGState()
}

func drawCrumbs(in context: CGContext, frameIndex: Int) {
    let colors = [cgColor(1.0, 0.82, 0.22, 0.9), cgColor(0.45, 0.72, 1.0, 0.8), cgColor(1.0, 0.55, 0.45, 0.8)]
    for index in 0..<5 {
        context.setFillColor(colors[(index + frameIndex) % colors.count])
        let x = 161 + CGFloat(index * 7) + CGFloat(frameIndex % 2) * 2
        let y = 114 + CGFloat((index + frameIndex) % 3) * 5
        context.fillEllipse(in: CGRect(x: x, y: y, width: 4, height: 4))
    }
}

func drawConfetti(in context: CGContext, frameIndex: Int) {
    let colors = [
        cgColor(1.0, 0.35, 0.35, 0.85),
        cgColor(0.25, 0.76, 0.45, 0.85),
        cgColor(0.25, 0.54, 1.0, 0.85),
        cgColor(1.0, 0.78, 0.22, 0.85)
    ]

    for index in 0..<9 {
        context.saveGState()
        let x = 68 + CGFloat(index * 15) + CGFloat(sin(Double(index + frameIndex))) * 6
        let y = 55 + CGFloat((index * 11 + frameIndex * 7) % 43)
        context.translateBy(x: x, y: y)
        context.rotate(by: CGFloat(index + frameIndex) * 0.35)
        context.setFillColor(colors[(index + frameIndex) % colors.count])
        context.fill(CGRect(x: -3, y: -2, width: 7, height: 4))
        context.restoreGState()
    }
}

func drawSweat(in context: CGContext, color: CGColor) {
    context.saveGState()
    context.translateBy(x: 183, y: 60)
    context.setFillColor(color)
    let drop = CGMutablePath()
    drop.move(to: CGPoint(x: 0, y: -10))
    drop.addCurve(to: CGPoint(x: 7, y: 3), control1: CGPoint(x: 6, y: -3), control2: CGPoint(x: 7, y: 0))
    drop.addCurve(to: CGPoint(x: 0, y: 9), control1: CGPoint(x: 7, y: 8), control2: CGPoint(x: 2, y: 10))
    drop.addCurve(to: CGPoint(x: -7, y: 3), control1: CGPoint(x: -2, y: 10), control2: CGPoint(x: -7, y: 8))
    drop.addCurve(to: CGPoint(x: 0, y: -10), control1: CGPoint(x: -7, y: 0), control2: CGPoint(x: -6, y: -3))
    drop.closeSubpath()
    context.addPath(drop)
    context.fillPath()
    context.restoreGState()
}

func drawQuestionBubble(in context: CGContext, color: CGColor) {
    drawEllipse(in: context, rect: CGRect(x: 56, y: 48, width: 26, height: 26), fill: cgColor(1.0, 0.94, 0.86, 0.95), stroke: color, lineWidth: 2.4)
    context.setStrokeColor(color)
    context.setFillColor(color)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setLineWidth(3)
    context.beginPath()
    context.move(to: CGPoint(x: 65, y: 58))
    context.addCurve(to: CGPoint(x: 70, y: 54), control1: CGPoint(x: 65, y: 53), control2: CGPoint(x: 70, y: 51))
    context.addCurve(to: CGPoint(x: 67, y: 63), control1: CGPoint(x: 76, y: 56), control2: CGPoint(x: 72, y: 61))
    context.addLine(to: CGPoint(x: 67, y: 66))
    context.strokePath()
    context.fillEllipse(in: CGRect(x: 65, y: 69, width: 4, height: 4))
}

func drawHeart(in context: CGContext) {
    let heart = CGMutablePath()
    heart.move(to: CGPoint(x: 177, y: 67))
    heart.addCurve(to: CGPoint(x: 166, y: 58), control1: CGPoint(x: 169, y: 62), control2: CGPoint(x: 166, y: 55))
    heart.addCurve(to: CGPoint(x: 177, y: 81), control1: CGPoint(x: 166, y: 68), control2: CGPoint(x: 177, y: 76))
    heart.addCurve(to: CGPoint(x: 188, y: 58), control1: CGPoint(x: 177, y: 76), control2: CGPoint(x: 188, y: 68))
    heart.addCurve(to: CGPoint(x: 177, y: 67), control1: CGPoint(x: 188, y: 55), control2: CGPoint(x: 184, y: 62))
    heart.closeSubpath()
    drawPath(in: context, path: heart, fill: cgColor(1.0, 0.42, 0.52, 0.88), stroke: nil, lineWidth: 0)
}

func drawSleepMarks(in context: CGContext) {
    let color = cgColor(0.30, 0.43, 0.70, 0.75)
    drawZMark(in: context, rect: CGRect(x: 174, y: 53, width: 17, height: 16), color: color, lineWidth: 3)
    drawZMark(in: context, rect: CGRect(x: 191, y: 42, width: 12, height: 12), color: color, lineWidth: 2.4)
}

func drawZMark(in context: CGContext, rect: CGRect, color: CGColor, lineWidth: CGFloat) {
    context.setStrokeColor(color)
    context.setLineWidth(lineWidth)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.beginPath()
    context.move(to: CGPoint(x: rect.minX, y: rect.minY))
    context.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
    context.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
    context.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    context.strokePath()
}

func drawEllipse(in context: CGContext, rect: CGRect, fill: CGColor, stroke: CGColor?, lineWidth: CGFloat) {
    context.setFillColor(fill)
    context.fillEllipse(in: rect)
    if let stroke {
        context.setStrokeColor(stroke)
        context.setLineWidth(lineWidth)
        context.strokeEllipse(in: rect)
    }
}

func drawRoundedRect(in context: CGContext, rect: CGRect, radius: CGFloat, fill: CGColor, stroke: CGColor?, lineWidth: CGFloat) {
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    drawPath(in: context, path: path, fill: fill, stroke: stroke, lineWidth: lineWidth)
}

func drawPath(in context: CGContext, path: CGPath, fill: CGColor, stroke: CGColor?, lineWidth: CGFloat) {
    context.addPath(path)
    context.setFillColor(fill)
    if let stroke {
        context.setStrokeColor(stroke)
        context.setLineWidth(lineWidth)
        context.drawPath(using: .fillStroke)
    } else {
        context.fillPath()
    }
}

func cgColor(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat) -> CGColor {
    CGColor(red: red, green: green, blue: blue, alpha: alpha)
}

let allThemes = [
    "CuteCat",
    "ShibaInu",
    "PixelSlime",
    "MochiBunny"
]

let requestedThemes = Array(CommandLine.arguments.dropFirst())
let themesToGenerate = requestedThemes.isEmpty ? allThemes : requestedThemes

do {
    for theme in themesToGenerate {
        guard allThemes.contains(theme) else {
            throw AssetError.unknownTheme(theme)
        }
        try generateTheme(themeName: theme)
    }
} catch {
    print("Theme generation failed: \(error)")
    exit(1)
}
