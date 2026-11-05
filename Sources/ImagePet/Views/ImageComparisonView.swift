import ImagePetCore
import SwiftUI

struct ImageComparisonView: View {
    let job: ImageJob
    let accessDirectory: URL?
    @Environment(\.dismiss) private var dismiss
    @State private var pair: ComparisonImageLoader.Pair?
    @State private var error: String?
    @State private var loading = true
    @State private var fullResolution = false
    @State private var background = "Grid"
    @State private var split = 0.5
    @AppStorage("ImagePetComparisonInterfaceScale") private var storedInterfaceScale = 1.0

    private var interfaceScale: Double {
        [1.0, 1.1, 1.25, 1.5].contains(storedInterfaceScale) ? storedInterfaceScale : 1.0
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical) {
                comparisonContent(canvasHeight: max(180, geometry.size.height - 320 * interfaceScale))
            }
        }
        .frame(minWidth: 600, idealWidth: 820, maxWidth: .infinity, minHeight: 480, idealHeight: 640, maxHeight: .infinity)
        .task(id: fullResolution) { await load() }
        .onDisappear { pair = nil }
    }

    private func comparisonContent(canvasHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12 * interfaceScale) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Compare Result").font(.system(size: 22 * interfaceScale, weight: .bold))
                    Text(job.fileName).font(.system(size: 13 * interfaceScale)).lineLimit(2).textSelection(.enabled)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("closeComparisonButton")
            }
            ViewThatFits(in: .horizontal) {
                HStack { zoomPicker; Spacer(); backgroundPicker }
                    .fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading) { zoomPicker; backgroundPicker }
            }
            interfaceScalePicker
            if let pair {
                HStack(alignment: .top) {
                    if let original = pair.original {
                        imageDetails("Original", picture: original)
                    }
                    Spacer()
                    imageDetails("Result", picture: pair.output)
                }
                if let saved = job.savedSize, let ratio = job.savedRatio {
                    Text("Saved \(ByteCountFormatter.string(fromByteCount: saved, countStyle: .file)) · \(ratio, format: .percent.precision(.fractionLength(1)))")
                        .font(.system(size: 12 * interfaceScale)).foregroundStyle(.secondary)
                }
                if let reason = pair.originalUnavailableReason {
                    Text(reason).font(.system(size: 12 * interfaceScale)).foregroundStyle(.secondary)
                } else if let original = pair.original, original.width != pair.output.width || original.height != pair.output.height {
                    Text("Dimensions changed. Both images are aligned to the output size.")
                        .font(.system(size: 12 * interfaceScale)).foregroundStyle(.secondary)
                }
                ImageComparisonCanvas(pair: pair, fullResolution: fullResolution && pair.output.isFullResolution,
                                      background: background, split: $split)
                    .frame(height: canvasHeight)
                    .overlay { if loading { ProgressView("Loading image…").padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8)) } }
                if pair.original != nil {
                    HStack {
                        Text("Original")
                        Slider(value: $split, in: 0...1) { Text("Comparison split") }
                            .labelsHidden()
                            .accessibilityIdentifier("comparisonSplitSlider")
                        Text("Result")
                    }
                }
                Text(pair.canLoadFullResolution ? "1:1 shows one output pixel per display pixel. Scroll to inspect details." : "Fit preview. Full-resolution comparison is limited to 16 megapixels per image.")
                    .font(.system(size: 12 * interfaceScale)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                Spacer()
                if loading { ProgressView("Loading image…").frame(maxWidth: .infinity) }
                Spacer()
            }
            if let error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.system(size: 13 * interfaceScale))
        .controlSize(interfaceScale >= 1.25 ? .large : .regular)
        .padding(20)
    }

    private var interfaceScalePicker: some View {
        ViewThatFits(in: .horizontal) {
            HStack { interfaceScaleLabel.fixedSize(horizontal: true, vertical: false); Spacer(); interfaceScaleOptions }
            VStack(alignment: .leading, spacing: 6) { interfaceScaleLabel; interfaceScaleOptions }
        }
    }

    private var interfaceScaleLabel: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Comparison interface")
            Text("Text and controls; image zoom is separate.")
                .font(.system(size: 11 * interfaceScale)).foregroundStyle(.secondary)
        }
    }

    private var interfaceScaleOptions: some View {
        Picker("Comparison interface", selection: $storedInterfaceScale) {
            Text("100%").tag(1.0)
            Text("110%").tag(1.1)
            Text("125%").tag(1.25)
            Text("150%").tag(1.5)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: 290 * interfaceScale)
        .accessibilityIdentifier("comparisonInterfaceScalePicker")
    }

    private var zoomPicker: some View {
        Picker("Image zoom", selection: $fullResolution) {
            Text("Fit").tag(false)
            Text("1:1").tag(true).disabled(pair?.canLoadFullResolution != true)
        }
        .pickerStyle(.segmented).frame(maxWidth: 220 * interfaceScale)
        .disabled(loading)
        .accessibilityIdentifier("comparisonZoomPicker")
    }

    private var backgroundPicker: some View {
        Picker("Background", selection: $background) {
            Text("Grid").tag("Grid")
            Text("White").tag("White")
            Text("Dark").tag("Dark")
        }
        .pickerStyle(.segmented).frame(maxWidth: 290 * interfaceScale)
        .accessibilityIdentifier("comparisonBackgroundPicker")
    }

    private func imageDetails(_ title: String, picture: ComparisonImageLoader.Picture) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 13 * interfaceScale, weight: .semibold))
            Text("\(picture.width) × \(picture.height) · \(ByteCountFormatter.string(fromByteCount: picture.bytes, countStyle: .file))")
                .font(.system(size: 12 * interfaceScale)).foregroundStyle(.secondary)
        }
    }

    @MainActor private func load() async {
        loading = true
        error = nil
        guard let output = job.outputURL else {
            error = "Result unavailable."
            loading = false
            return
        }
        do {
            let loaded = try await ComparisonImageLoader.shared.load(input: job.inputURL, output: output,
                                                                     accessDirectory: accessDirectory, fullResolution: fullResolution)
            try Task.checkCancellation()
            pair = loaded
            loading = false
        } catch is CancellationError {
            // A dismissed sheet or superseded request owns no further UI updates.
        } catch {
            guard !Task.isCancelled else { return }
            self.error = "Image unavailable. Check the file and folder access."
            loading = false
        }
    }
}
