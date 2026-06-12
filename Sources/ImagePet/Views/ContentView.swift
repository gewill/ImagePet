import ImagePetCore
import SwiftUI

struct ContentView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var store: ImagePetStore

    var body: some View {
        VStack(spacing: 16) {
            HeaderView(store: store)
            ControlsView(store: store)
            DropZoneView(isTargeted: store.isDropTargeted, hasJobs: !store.jobs.isEmpty)
            JobListView(jobs: store.jobs)
            SummaryView(store: store)
        }
        .padding(20)
        .frame(minWidth: 780, minHeight: 560)
        .dropDestination(for: URL.self) { urls, _ in
            store.addDroppedURLs(urls)
            return true
        } isTargeted: { isTargeted in
            store.isDropTargeted = isTargeted
        }
        .task {
            store.promptForOutputFolderOnFirstLaunch()
        }
        .onAppear {
            store.setMainWindowOpener {
                openWindow(id: "main")
            }
        }
        .background {
            DesktopPetPresenter(store: store)
        }
        .confirmationDialog(
            "Overwrite Original Files?",
            isPresented: $store.showOverwriteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Overwrite", role: .destructive) {
                store.confirmOverwriteAndStart()
            }
            Button("Cancel", role: .cancel) {
                store.cancelOverwrite()
            }
        } message: {
            Text("Are you sure you want to overwrite the original images? This will replace your original files and cannot be undone.")
        }
    }
}

private struct HeaderView: View {
    @ObservedObject var store: ImagePetStore

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            Text(petEmoji)
                .font(.system(size: 64))
                .frame(width: 86, height: 86)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .accessibilityIdentifier("petEmojiLabel")

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 28, weight: .semibold))
                    .lineLimit(1)
                    .accessibilityIdentifier("petTitleLabel")
                    .accessibilityLabel(title)

                Text(subtitle)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .accessibilityIdentifier("petSubtitleLabel")
                    .accessibilityLabel(subtitle)

                if store.isProcessing {
                    ProgressView(value: Double(store.completedCount), total: Double(max(store.jobs.count, 1)))
                        .frame(maxWidth: 320)
                }
            }

            Spacer()
        }
    }

    private var petEmoji: String {
        switch store.petState {
        case .idle:
            return "🐡"
        case .eating:
            return "😋"
        case .happy:
            return "🥳"
        case .error:
            return "😵"
        }
    }

    private var title: String {
        switch store.petState {
        case .idle:
            return "Drop images here"
        case .eating:
            return "nom nom nom..."
        case .happy:
            return "Done!"
        case .error:
            return "Done with issues"
        }
    }

    private var subtitle: String {
        switch store.petState {
        case .idle:
            return "Eat more, poop less."
        case .eating:
            return "Processing \(store.completedCount) / \(store.jobs.count)"
        case .happy:
            let mainStr = "Ate \(FileSizeFormatting.string(from: store.successfulOriginalTotal)); pooped \(FileSizeFormatting.string(from: store.compressedTotal))."
            if store.skippedCount > 0 {
                return mainStr + " (Skipped \(store.skippedCount))"
            }
            return mainStr
        case .error:
            var parts: [String] = []
            parts.append("\(store.succeededCount) succeeded")
            if store.skippedCount > 0 {
                parts.append("\(store.skippedCount) skipped")
            }
            parts.append("\(store.failedCount) failed")
            return parts.joined(separator: ", ")
        }
    }
}

private struct ControlsView: View {
    @ObservedObject var store: ImagePetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // First Row: Quality and Max Dimension
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quality Preset")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Quality", selection: $store.preset) {
                        ForEach(CompressionPreset.allCases) { preset in
                            Text(preset.displayName).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 250)
                    .disabled(store.isProcessing || store.outputFormat == .png)
                    .accessibilityIdentifier("presetPicker")
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Max Edge Limit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Max Dimension", selection: $store.maxDimension) {
                        ForEach(MaxDimensionLimit.allCases) { limit in
                            Text(limit.displayName).tag(limit)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                    .disabled(store.isProcessing)
                    .accessibilityIdentifier("maxDimensionPicker")
                }
                
                Spacer()
                
                Button {
                    store.toggleDesktopPet()
                } label: {
                    Label(store.isDesktopPetVisible ? "Hide Pet" : "Show Pet", systemImage: "pawprint")
                }
                .accessibilityIdentifier("togglePetButton")

                Button {
                    store.chooseInputImages()
                } label: {
                    Label("Add Images", systemImage: "photo.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("addImagesButton")
            }

            Divider()

            // Second Row: Output Format and Save Destination
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Output Format")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Format", selection: $store.outputFormat) {
                        ForEach(OutputFormat.allCases) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 280)
                    .disabled(store.isProcessing || store.saveLocationMode == .overwrite)
                    .accessibilityIdentifier("formatPicker")
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Save Location")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Location", selection: $store.saveLocationMode) {
                        ForEach(SaveLocationMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 320)
                    .disabled(store.isProcessing)
                    .accessibilityIdentifier("locationModePicker")
                }
            }

            // Options details based on selection
            Group {
                if store.saveLocationMode == .overwrite {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text("Mode Overwrite will replace your source files directly and keep each file's original format. This action cannot be undone.")
                            .font(.callout)
                            .foregroundStyle(.red.opacity(0.85))
                            .fontWeight(.semibold)
                    }
                    .padding(8)
                    .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                } else {
                    HStack(alignment: .center, spacing: 20) {
                        // Suffix configurations
                        HStack(spacing: 8) {
                            Text("Filename Suffix:")
                                .font(.callout)
                            TextField("Suffix", text: $store.filenameSuffix)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 130)
                                .disabled(store.isProcessing)
                                .accessibilityIdentifier("filenameSuffixField")
                                .onChange(of: store.filenameSuffix) { _ in
                                    store.sanitizeFilenameSuffix()
                                }
                        }
                        
                        Text(store.filenamePreview)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .accessibilityIdentifier("filenamePreviewLabel")
                    }
                    
                    if store.saveLocationMode == .designated {
                        HStack(spacing: 8) {
                            Image(systemName: "folder.badge.gearshape")
                                .foregroundStyle(.secondary)

                            Text(outputFolderText)
                                .foregroundStyle(store.outputDirectory == nil ? .secondary : .primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .accessibilityIdentifier("outputFolderLabel")

                            Button("Choose Folder") {
                                store.chooseOutputDirectory()
                            }
                            .disabled(store.isProcessing)
                            .accessibilityIdentifier("chooseFolderButton")

                            Spacer()
                        }
                        .font(.callout)
                    }
                }
            }

            // Option Toggles (Metadata and PNG Lossless notice)
            HStack(spacing: 24) {
                Toggle("Strip Metadata (GPS/EXIF/Camera Info)", isOn: $store.stripMetadata)
                    .disabled(store.isProcessing)
                    .accessibilityIdentifier("stripMetadataToggle")

                if store.outputFormat == .png {
                    Label("PNG is compressed losslessly", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Label(
                        "HDR or wide-gamut images will be exported as standard sRGB.",
                        systemImage: "info.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            
            if let message = store.outputFolderMessage, store.saveLocationMode == .designated {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private var outputFolderText: String {
        guard let outputDirectory = store.outputDirectory else {
            return "Output Folder: Choose Folder"
        }

        return "Output Folder: \(outputDirectory.path)"
    }
}

private struct DropZoneView: View {
    let isTargeted: Bool
    let hasJobs: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: isTargeted ? "tray.and.arrow.down.fill" : "tray.and.arrow.down")
                .font(.system(size: hasJobs ? 24 : 34, weight: .medium))
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)

            Text(hasJobs ? "Drop more images" : "Drop JPG, PNG, or HEIC images")
                .font(hasJobs ? .callout : .headline)
                .foregroundStyle(isTargeted ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: hasJobs ? 72 : 118)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isTargeted ? Color.accentColor.opacity(0.10) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                    style: StrokeStyle(lineWidth: 1.5, dash: [8, 6])
                )
        )
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.15), value: isTargeted)
        .animation(.easeOut(duration: 0.15), value: hasJobs)
    }
}

private struct JobListView: View {
    let jobs: [ImageJob]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("File")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Status")
                    .frame(width: 160, alignment: .leading)
                Text("Size / Saved")
                    .frame(width: 240, alignment: .trailing)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

            ScrollView {
                LazyVStack(spacing: 6) {
                    if jobs.isEmpty {
                        EmptyJobListView()
                    } else {
                        ForEach(jobs) { job in
                            JobRowView(job: job)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .frame(maxHeight: .infinity)
    }
}

private struct EmptyJobListView: View {
    var body: some View {
        Text("No images yet")
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 34)
            .accessibilityIdentifier("emptyJobsLabel")
            .accessibilityLabel("No images yet")
    }
}

private struct JobRowView: View {
    let job: ImageJob

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .frame(width: 18)
                .accessibilityIdentifier("jobIcon_\(job.fileName)")

            Text(job.fileName)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("jobFileName_\(job.fileName)")
                .accessibilityLabel(job.fileName)

            Text(statusText)
                .foregroundStyle(statusColor)
                .lineLimit(1)
                .frame(width: 160, alignment: .leading)
                .accessibilityIdentifier("jobStatusText_\(job.fileName)")
                .accessibilityLabel(statusText)

            Text(sizeText)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(width: 240, alignment: .trailing)
                .accessibilityIdentifier("jobSizeText_\(job.fileName)")
                .accessibilityLabel(sizeText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private var iconName: String {
        switch job.status {
        case .pending:
            return "clock"
        case .processing:
            return "arrow.triangle.2.circlepath"
        case .done:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.octagon.fill"
        case .skipped:
            return "arrow.right.circle"
        }
    }

    private var iconColor: Color {
        switch job.status {
        case .pending:
            return .secondary
        case .processing:
            return .accentColor
        case .done:
            return .green
        case .failed:
            return .red
        case .skipped:
            return .orange
        }
    }

    private var statusText: String {
        switch job.status {
        case .pending:
            return "Pending"
        case .processing:
            return "Processing..."
        case .done:
            return "Done"
        case .failed:
            return "Failed: \(job.errorMessage ?? "Unknown error")"
        case .skipped:
            return "Skipped"
        }
    }

    private var statusColor: Color {
        switch job.status {
        case .failed:
            return .red
        case .skipped:
            return .orange
        default:
            return .secondary
        }
    }

    private var sizeText: String {
        switch job.status {
        case .done:
            guard let compressedSize = job.compressedSize else {
                return FileSizeFormatting.string(from: job.originalSize)
            }
            let savedPercent = job.savedRatio.map(FileSizeFormatting.percent) ?? "0.0%"
            return "\(FileSizeFormatting.string(from: job.originalSize)) -> \(FileSizeFormatting.string(from: compressedSize)) / \(savedPercent)"
        case .skipped:
            return "\(FileSizeFormatting.string(from: job.originalSize)) -> Skipped"
        case .failed:
            return FileSizeFormatting.string(from: job.originalSize)
        default:
            return FileSizeFormatting.string(from: job.originalSize)
        }
    }
}

private struct SummaryView: View {
    @ObservedObject var store: ImagePetStore

    var body: some View {
        HStack(spacing: 14) {
            if store.isCompleted {
                SummaryMetric(title: "Ate", value: FileSizeFormatting.string(from: store.successfulOriginalTotal))
                SummaryMetric(title: "Pooped", value: FileSizeFormatting.string(from: store.compressedTotal))
                SummaryMetric(
                    title: "Saved",
                    value: "\(FileSizeFormatting.string(from: store.savedTotal)) / \(FileSizeFormatting.percent(store.savedRatio))"
                )

                Spacer()

                Button {
                    store.revealOutputDirectory()
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }
                .accessibilityIdentifier("revealInFinderButton")

                if store.hasFailedJobs {
                    Button {
                        store.retryFailed()
                    } label: {
                        Label("Retry Failed", systemImage: "arrow.clockwise")
                    }
                    .keyboardShortcut("r", modifiers: [.command])
                    .accessibilityIdentifier("retryFailedButton")
                }

                Button {
                    store.compressMore()
                } label: {
                    Label("Compress More", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: [.command])
                .accessibilityIdentifier("compressMoreButton")
            } else if store.isProcessing {
                SummaryMetric(title: "Processing", value: "\(store.completedCount) / \(store.jobs.count)")
                Spacer()
            } else {
                SummaryMetric(title: "Quality", value: store.preset.displayName)
                SummaryMetric(title: "Output", value: store.outputFormat.displayName)
                Spacer()
            }
        }
        .padding(.top, 2)
    }
}

private struct SummaryMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("summaryMetricTitle_\(title)")
            Text(value)
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .accessibilityIdentifier("summaryMetricValue_\(title)")
                .accessibilityLabel(value)
        }
        .frame(minWidth: 110, alignment: .leading)
    }
}
