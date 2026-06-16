import SwiftUI

enum SoftNativeStyle {
    static let cream = Color(red: 0.985, green: 0.965, blue: 0.92)
    static let surface = Color(red: 1.0, green: 0.995, blue: 0.975)
    static let elevated = Color(red: 0.985, green: 0.975, blue: 0.945)
    static let accent = Color(red: 0.24, green: 0.62, blue: 0.48)
    static let accentSoft = Color(red: 0.88, green: 0.965, blue: 0.925)
    static let secondary = Color(red: 0.9, green: 0.58, blue: 0.22)
    static let secondarySoft = Color(red: 0.99, green: 0.91, blue: 0.78)
    static let success = Color(red: 0.2, green: 0.58, blue: 0.38)
    static let danger = Color(red: 0.78, green: 0.25, blue: 0.22)
    static let border = Color.black.opacity(0.10)

    static var workspaceBackground: some View {
        LinearGradient(
            colors: [
                cream,
                Color(red: 0.975, green: 0.985, blue: 0.955)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
