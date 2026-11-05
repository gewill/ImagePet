import SwiftUI

struct ImageComparisonCanvas: View {
    let pair: ComparisonImageLoader.Pair
    let fullResolution: Bool
    let background: String
    @Binding var split: Double
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { geometry in
            let output = pair.output
            let fit = min(geometry.size.width / CGFloat(output.width), geometry.size.height / CGFloat(output.height))
            let scale = fullResolution ? 1 / max(1, displayScale) : min(fit, 1 / max(1, displayScale))
            let size = CGSize(width: CGFloat(output.width) * scale, height: CGFloat(output.height) * scale)
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .leading) {
                    ComparisonBackground(style: background)
                    if let original = pair.original {
                        // Clip BOTH sides: transparent output must not expose the original beneath it.
                        Image(decorative: original.image, scale: 1)
                            .resizable().interpolation(fullResolution ? .none : .high)
                            .frame(width: size.width, height: size.height)
                            .mask(alignment: .leading) { Rectangle().frame(width: size.width * split) }
                    }
                    Image(decorative: output.image, scale: 1)
                        .resizable().interpolation(fullResolution ? .none : .high)
                        .frame(width: size.width, height: size.height)
                        .mask(alignment: .trailing) {
                            Rectangle().frame(width: pair.original == nil ? size.width : size.width * (1 - split))
                        }
                    if pair.original != nil {
                        Rectangle().fill(.white).frame(width: 2)
                            .shadow(color: .black.opacity(0.6), radius: 1)
                            .offset(x: max(0, size.width * split - 1))
                    }
                }
                .frame(width: size.width, height: size.height)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    guard pair.original != nil, size.width > 0 else { return }
                    split = min(1, max(0, value.location.x / size.width))
                })
                .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
            }
        }
        .background(Color(nsColor: .underPageBackgroundColor))
        .clipped()
        .accessibilityLabel(pair.original == nil ? "Saved result preview" : "Original on left, result on right")
        .accessibilityIdentifier("comparisonCanvas")
    }
}
