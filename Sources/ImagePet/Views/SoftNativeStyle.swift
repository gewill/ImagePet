import AppKit
import SwiftUI

enum SoftNativeStyle {
    static let cream = adaptiveColor(
        light: NSColor(calibratedRed: 0.985, green: 0.965, blue: 0.92, alpha: 1),
        dark: NSColor(calibratedRed: 0.075, green: 0.095, blue: 0.09, alpha: 1)
    )
    static let surface = adaptiveColor(
        light: NSColor(calibratedRed: 1.0, green: 0.995, blue: 0.975, alpha: 1),
        dark: NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.13, alpha: 1)
    )
    static let elevated = adaptiveColor(
        light: NSColor(calibratedRed: 0.985, green: 0.975, blue: 0.945, alpha: 1),
        dark: NSColor(calibratedRed: 0.16, green: 0.18, blue: 0.17, alpha: 1)
    )
    static let accent = adaptiveColor(
        light: NSColor(calibratedRed: 0.24, green: 0.62, blue: 0.48, alpha: 1),
        dark: NSColor(calibratedRed: 0.36, green: 0.78, blue: 0.62, alpha: 1)
    )
    static let accentSoft = adaptiveColor(
        light: NSColor(calibratedRed: 0.88, green: 0.965, blue: 0.925, alpha: 1),
        dark: NSColor(calibratedRed: 0.12, green: 0.24, blue: 0.20, alpha: 1)
    )
    static let secondary = adaptiveColor(
        light: NSColor(calibratedRed: 0.9, green: 0.58, blue: 0.22, alpha: 1),
        dark: NSColor(calibratedRed: 1.0, green: 0.70, blue: 0.34, alpha: 1)
    )
    static let secondarySoft = adaptiveColor(
        light: NSColor(calibratedRed: 0.99, green: 0.91, blue: 0.78, alpha: 1),
        dark: NSColor(calibratedRed: 0.30, green: 0.22, blue: 0.13, alpha: 1)
    )
    static let success = adaptiveColor(
        light: NSColor(calibratedRed: 0.2, green: 0.58, blue: 0.38, alpha: 1),
        dark: NSColor(calibratedRed: 0.40, green: 0.82, blue: 0.58, alpha: 1)
    )
    static let danger = adaptiveColor(
        light: NSColor(calibratedRed: 0.78, green: 0.25, blue: 0.22, alpha: 1),
        dark: NSColor(calibratedRed: 1.0, green: 0.42, blue: 0.38, alpha: 1)
    )
    static let border = adaptiveColor(
        light: NSColor.black.withAlphaComponent(0.10),
        dark: NSColor.white.withAlphaComponent(0.14)
    )
    static let cardShadow = adaptiveColor(
        light: NSColor.black.withAlphaComponent(0.055),
        dark: NSColor.black.withAlphaComponent(0.35)
    )

    static var workspaceBackground: some View {
        LinearGradient(
            colors: [
                cream,
                adaptiveColor(
                    light: NSColor(calibratedRed: 0.975, green: 0.985, blue: 0.955, alpha: 1),
                    dark: NSColor(calibratedRed: 0.095, green: 0.12, blue: 0.115, alpha: 1)
                )
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private static func adaptiveColor(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
            return bestMatch == .darkAqua ? dark : light
        })
    }
}
