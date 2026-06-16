import ImagePetCore
import SwiftUI

struct ContentView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var store: ImagePetStore

    var body: some View {
        TabView(selection: $store.selectedMainTab) {
            ZStack {
                SoftNativeStyle.workspaceBackground

                ScrollView {
                    VStack(spacing: 14) {
                        HeaderView(store: store)
                        ControlsView(store: store)
                        DropZoneView(isTargeted: store.isDropTargeted, hasJobs: !store.jobs.isEmpty)
                        JobListView(jobs: store.jobs)
                        SummaryView(store: store)
                    }
                    .padding(20)
                }
            }
            .tabItem {
                Label("Compress", systemImage: "doc.on.doc")
            }
            .tag(AppMainTab.compress)

            AppSettingsView(store: store)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(AppMainTab.settings)
        }
        .tint(SoftNativeStyle.accent)
        .frame(minWidth: 860, minHeight: 660)
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
            store.setHelpWindowOpener {
                openWindow(id: "help")
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

private struct SoftNativeCard: ViewModifier {
    let radius: CGFloat
    let tint: Color

    func body(content: Content) -> some View {
        content
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .background(tint.opacity(0.58), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(SoftNativeStyle.border)
            )
            .shadow(color: Color.black.opacity(0.055), radius: 18, y: 8)
    }
}

private extension View {
    func softNativeCard(radius: CGFloat = 10, tint: Color = SoftNativeStyle.surface) -> some View {
        modifier(SoftNativeCard(radius: radius, tint: tint))
    }
}

private struct HeaderView: View {
    @ObservedObject var store: ImagePetStore

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Text("ImagePet")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(SoftNativeStyle.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    Button {
                        store.toggleDesktopPet()
                    } label: {
                        Label(store.isDesktopPetVisible ? "Hide Pet" : "Show Pet", systemImage: "pawprint")
                    }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                    .disabled(!store.isDesktopPetEnabled)
                    .help("Toggle Desktop Pet (⇧⌘P)")
                    .accessibilityIdentifier("togglePetButton")

                    Button {
                        store.chooseInputImages()
                    } label: {
                        Label("Add Images", systemImage: "photo.badge.plus")
                    }
                    .keyboardShortcut("o", modifiers: [.command])
                    .buttonStyle(.borderedProminent)
                    .tint(SoftNativeStyle.accent)
                    .help("Add Images (⌘O)")
                    .accessibilityIdentifier("addImagesButton")
                }
            }

            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(title)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .accessibilityIdentifier("petTitleLabel")
                        .accessibilityLabel(title)

                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .accessibilityIdentifier("petSubtitleLabel")
                        .accessibilityLabel(subtitle)

                    if store.isProcessing {
                        ProgressView(value: Double(store.completedCount), total: Double(max(store.jobs.count, 1)))
                            .tint(SoftNativeStyle.secondary)
                            .frame(maxWidth: 340)
                    }
                }

                Spacer(minLength: 18)

                Group {
                    if let cgImage = petImage {
                        Image(decorative: cgImage, scale: 1.0)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 82, height: 82)
                    } else {
                        Color.clear
                            .frame(width: 82, height: 82)
                    }
                }
                .frame(width: 116, height: 104)
                .background {
                    ZStack {
                        SoftNativeStyle.accentSoft
                        Circle()
                            .fill(SoftNativeStyle.secondary.opacity(0.16))
                            .frame(width: 92, height: 92)
                            .blur(radius: 16)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(SoftNativeStyle.accent.opacity(0.20))
                )
                .accessibilityLabel("Desktop Pet \(store.petState == .idle ? "Idle" : store.petState == .eating ? "Eating" : store.petState == .happy ? "Happy" : "Error")")
                .accessibilityIdentifier("petEmojiLabel")
            }
        }
        .padding(16)
        .softNativeCard(radius: 14)
    }

    private var petImage: CGImage? {
        let anim: PetAnimation
        switch store.petState {
        case .idle:
            anim = .idle
        case .eating:
            anim = .eating
        case .happy:
            anim = .done
        case .error:
            anim = .issues
        }
        return ThemeCache.loadStaticImage(themeName: store.selectedThemeName, animation: anim)
    }

    private var title: String {
        switch store.petState {
        case .idle:
            return "Ready to shrink images"
        case .eating:
            return "Eating images"
        case .happy:
            return "Saved space"
        case .error:
            return "Done with issues"
        }
    }

    private var subtitle: String {
        switch store.petState {
        case .idle:
            return "Drop JPG, PNG, HEIC, or WebP files. ImagePet keeps compression choices visible before work starts."
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
        VStack(alignment: .leading, spacing: store.isParametersExpanded ? 12 : 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    store.isParametersExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.body)
                        .foregroundStyle(SoftNativeStyle.accent)

                    Text("Compression Parameters")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if !store.isParametersExpanded {
                        HStack(spacing: 6) {
                            Text("•")
                            Text("Quality: \(store.qualitySummary)")
                            Text("•")
                            Text("Format: \(store.outputFormat.displayName)")
                            if store.maxDimension != .none {
                                Text("•")
                                Text("Max Edge: \(store.maxDimension.displayName)")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(store.isParametersExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("toggleParametersButton")

            if store.isParametersExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    controlOptions

                    if store.qualityMode == .custom && store.outputFormat != .png {
                        HStack(spacing: 10) {
                            Text("Quality \(store.customQuality)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 70, alignment: .leading)
                            Slider(
                                value: Binding(
                                    get: { Double(store.customQuality) },
                                    set: { store.customQuality = Int($0.rounded()) }
                                ),
                                in: 30...95,
                                step: 1
                            )
                            .disabled(store.isProcessing)
                            .accessibilityIdentifier("customQualitySlider")
                        }
                        .padding(.horizontal, 4)
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
                            HStack(alignment: .center, spacing: 16) {
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

                                Spacer(minLength: 8)
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
                                    .keyboardShortcut("o", modifiers: [.command, .shift])
                                    .disabled(store.isProcessing)
                                    .help("Choose Output Folder (⇧⌘O)")
                                    .accessibilityIdentifier("chooseFolderButton")

                                    Spacer()
                                }
                                .font(.callout)
                            }
                        }
                    }

                    // Option Toggles (Metadata and PNG Lossless notice)
                    HStack(spacing: 18) {
                        Toggle("Strip Metadata (GPS/EXIF/Camera Info)", isOn: $store.stripMetadata)
                            .disabled(store.isProcessing)
                            .accessibilityIdentifier("stripMetadataToggle")

                        if store.canUseAdvancedJPEG {
                            Toggle("Advanced JPEG", isOn: Binding(
                                get: { store.jpegEncodingMode == .advanced },
                                set: { store.jpegEncodingMode = $0 ? .advanced : .standard }
                            ))
                            .disabled(store.isProcessing)
                            .help("Smaller JPEG output for web sharing.")
                            .accessibilityIdentifier("advancedJPEGToggle")
                        }

                        if store.outputFormat == .png {
                            Label("PNG uses lossless compression. Quality does not apply.", systemImage: "info.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if store.canUseAdvancedJPEG && store.jpegEncodingMode == .advanced {
                            Label("Smaller JPEG output for web sharing.", systemImage: "info.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if store.outputFormat == .webp {
                            Label("Best for web sharing. Static images only.", systemImage: "info.circle")
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
                            .foregroundStyle(SoftNativeStyle.secondary)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .softNativeCard(radius: 10, tint: SoftNativeStyle.elevated)
    }

    private var outputFolderText: String {
        guard let outputDirectory = store.outputDirectory else {
            return "Output Folder: Choose Folder"
        }

        return "Output Folder: \(outputDirectory.path)"
    }

    @ViewBuilder
    private var controlOptions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                qualityCard
                    .frame(minWidth: 240, maxWidth: .infinity)
                formatCard
                    .frame(minWidth: 240, maxWidth: .infinity)
                maxEdgeCard
                    .frame(minWidth: 240, maxWidth: .infinity)
                saveToCard
                    .frame(minWidth: 240, maxWidth: .infinity)
            }

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    qualityCard
                    formatCard
                }

                HStack(spacing: 8) {
                    maxEdgeCard
                    saveToCard
                }
            }
        }
    }

    private var qualityCard: some View {
        ControlCard(title: "Quality") {
            Picker("Quality", selection: $store.qualityMode) {
                ForEach(CompressionQualityMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(store.isProcessing || store.outputFormat == .png)
            .accessibilityIdentifier("presetPicker")
        }
    }

    private var formatCard: some View {
        ControlCard(title: "Format") {
            Picker("Format", selection: $store.outputFormat) {
                ForEach(store.availableOutputFormats) { format in
                    Text(format.displayName).tag(format)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(store.isProcessing || store.saveLocationMode == .overwrite)
            .accessibilityIdentifier("formatPicker")
        }
    }

    private var maxEdgeCard: some View {
        ControlCard(title: "Max edge") {
            Picker("Max Dimension", selection: $store.maxDimension) {
                ForEach(MaxDimensionLimit.allCases) { limit in
                    Text(limit.displayName).tag(limit)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(store.isProcessing)
            .accessibilityIdentifier("maxDimensionPicker")
        }
    }

    private var saveToCard: some View {
        ControlCard(title: "Save to") {
            Picker("Location", selection: $store.saveLocationMode) {
                ForEach(SaveLocationMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(store.isProcessing)
            .accessibilityIdentifier("locationModePicker")
        }
    }
}

private struct ControlCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.bold))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(.secondary)

            content
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        .background(SoftNativeStyle.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(SoftNativeStyle.border)
        )
    }
}

private struct DropZoneView: View {
    let isTargeted: Bool
    let hasJobs: Bool

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: isTargeted ? "tray.and.arrow.down.fill" : "tray.and.arrow.down")
                .font(.system(size: hasJobs ? 22 : 32, weight: .medium))
                .foregroundStyle(isTargeted ? SoftNativeStyle.accent : .secondary)

            Text(hasJobs ? "Drop more images" : "Drop JPG, PNG, HEIC, or WebP images")
                .font(hasJobs ? .callout.weight(.medium) : .headline)
                .foregroundStyle(isTargeted ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: hasJobs ? 76 : 112)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isTargeted ? SoftNativeStyle.accent.opacity(0.15) : SoftNativeStyle.accentSoft.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isTargeted ? SoftNativeStyle.accent : SoftNativeStyle.accent.opacity(0.42),
                    style: StrokeStyle(lineWidth: 1.5, dash: [8, 6])
                )
        )
        .shadow(color: SoftNativeStyle.accent.opacity(isTargeted ? 0.18 : 0.06), radius: isTargeted ? 14 : 8, y: 4)
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.15), value: isTargeted)
        .animation(.easeOut(duration: 0.15), value: hasJobs)
    }
}

private struct JobListView: View {
    let jobs: [ImageJob]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("File")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Status")
                    .frame(width: 160, alignment: .leading)
                Text("Size / Saved")
                    .frame(width: 240, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .font(.caption2.weight(.bold))
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(.secondary)
            .background(SoftNativeStyle.elevated.opacity(0.86))

            ScrollView {
                LazyVStack(spacing: 0) {
                    if jobs.isEmpty {
                        EmptyJobListView()
                    } else {
                        ForEach(jobs) { job in
                            JobRowView(job: job)
                        }
                    }
                }
            }
        }
        .clipShape(Rectangle())
        .overlay(
            Rectangle()
                .stroke(SoftNativeStyle.border)
        )
        .frame(height: jobs.isEmpty ? 150 : 260)
        .softNativeCard(radius: 0)
    }
}

private struct EmptyJobListView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 40))
                .foregroundStyle(SoftNativeStyle.accent.opacity(0.32))
                .padding(.top, 24)

            VStack(spacing: 4) {
                Text("No images in queue")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("Drag images here or click Add to begin")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .multilineTextAlignment(.center)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(SoftNativeStyle.surface.opacity(0.48))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("emptyJobsLabel")
        .accessibilityLabel("No images in queue. Drag images here or click Add to begin.")
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
        .frame(minHeight: 38)
        .background(SoftNativeStyle.surface.opacity(0.70))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(SoftNativeStyle.border)
                .frame(height: 1)
        }
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
            return SoftNativeStyle.secondary
        case .done:
            return SoftNativeStyle.accent
        case .failed:
            return .red
        case .skipped:
            return SoftNativeStyle.secondary
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
            return job.errorMessage ?? "Skipped"
        }
    }

    private var statusColor: Color {
        switch job.status {
        case .failed:
            return .red
        case .skipped:
            return SoftNativeStyle.secondary
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
        HStack(spacing: 10) {
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
                .buttonStyle(.bordered)
                .help("Reveal in Finder")
                .accessibilityIdentifier("revealInFinderButton")

                if store.hasFailedJobs {
                    Button {
                        store.retryFailed()
                    } label: {
                        Label("Retry Failed", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut("r", modifiers: [.command])
                    .help("Retry Failed (⌘R)")
                    .accessibilityIdentifier("retryFailedButton")
                }

                Button {
                    store.clearList()
                } label: {
                    Label("Clear List", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
                .keyboardShortcut("n", modifiers: [.command])
                .help("Clear List (⌘N)")
                .accessibilityIdentifier("clearListButton")
            } else if store.isProcessing {
                SummaryMetric(title: "Processing", value: "\(store.completedCount) / \(store.jobs.count)")
                Spacer()
            } else {
                SummaryMetric(title: "Quality", value: store.qualitySummary)
                SummaryMetric(title: "Output", value: store.outputFormat.displayName)
                Spacer()
            }
        }
        .padding(12)
        .softNativeCard(radius: 10, tint: SoftNativeStyle.elevated)
    }
}

private struct SummaryMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.bold))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("summaryMetricTitle_\(title)")
            Text(value)
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .accessibilityIdentifier("summaryMetricValue_\(title)")
                .accessibilityLabel(value)
        }
        .padding(10)
        .frame(minWidth: 116, alignment: .leading)
        .background(SoftNativeStyle.surface.opacity(0.70), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(SoftNativeStyle.border)
        )
    }
}
