import SwiftUI

struct ComparisonBackground: View {
    let style: String

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(style == "Dark" ? Color(white: 0.12) : .white))
            if style == "Grid" {
                let cell: CGFloat = 12
                for y in 0..<Int(ceil(size.height / cell)) {
                    for x in 0..<Int(ceil(size.width / cell)) where (x + y).isMultiple(of: 2) {
                        let rect = CGRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell, width: cell, height: cell)
                        context.fill(Path(rect), with: .color(Color(white: 0.82)))
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}
