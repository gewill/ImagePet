import ImagePetCore
import SwiftUI
import OSLog

private let logger = Logger(subsystem: "org.gewill.ImagePet", category: "ContentView")

struct ContentView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var store: ImagePetStore

    var body: some View {
        logger.warning("ContentView body: store=\(String(describing: ObjectIdentifier(store)))")
        return ZStack {
            SoftNativeStyle.workspaceBackground

            HStack(spacing: 16) {
                // Left Collapsible Sidebar
                if store.isSettingsExpanded {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Parameters")
                                .font(.headline)
                                .foregroundStyle(SoftNativeStyle.accent)
                                .accessibilityAddTraits(.isHeader)

                            Spacer()

                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    store.isSettingsExpanded = false
                                }
                            } label: {
                                Image(systemName: "sidebar.left")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Collapse settings")
                            .accessibilityIdentifier("collapseSettingsButton")
                            .accessibilityLabel("Collapse settings")
                        }

                        ScrollView {
                            VStack(spacing: 12) {
                                ControlsView(store: store)
                            }
                        }

                        HStack {
                            Button {
                                store.showSettings(.general)
                            } label: {
                                Image(systemName: "gearshape")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Settings")
                            .accessibilityIdentifier("Settings")
                            .accessibilityLabel("Settings")
                            Spacer()
                        }
                        .padding(.top, 8)
                    }
                    .frame(width: 420)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                } else {
                    // Collapsed thin bar
                    VStack(spacing: 16) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                store.isSettingsExpanded = true
                            }
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.title3)
                                    .foregroundStyle(SoftNativeStyle.accent)

                                Text("Params")
                                    .font(.caption2.weight(.bold))
                                    .textCase(.uppercase)
                                    .tracking(0.6)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 6)
                        }
                        .buttonStyle(.plain)
                        .help("Expand parameters")
                        .accessibilityIdentifier("expandSettingsButton")
                        .accessibilityLabel("Expand parameters")

                        Spacer()

                        Button {
                            store.showSettings(.general)
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Settings")
                        .accessibilityIdentifier("Settings")
                        .accessibilityLabel("Settings")
                        .padding(.bottom, 12)
                    }
                    .frame(width: 50)
                    .softNativeCard(radius: 10, tint: SoftNativeStyle.surface.opacity(0.3))
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }

                // Right Main Panel
                VStack(spacing: 14) {
                    HeaderView(store: store)
                    DropZoneView(isTargeted: store.isDropTargeted, hasJobs: !store.jobs.isEmpty)
                    JobListView(store: store)
                    SummaryView(store: store)
                }
            }
            .padding(20)
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
            .shadow(color: SoftNativeStyle.cardShadow, radius: 18, y: 8)
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
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 16) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        appTitle
                        headerActions
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        appTitle
                        headerActions
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

                    Spacer(minLength: 90)
                }
            }
            .padding(16)

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
            .accessibilityLabel("Desktop Pet \(store.petState == .idle ? "Idle" : store.petState == .eating ? "Eating" : store.petState == .happy ? "Happy" : "Error")")
            .accessibilityIdentifier("petEmojiLabel")
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .softNativeCard(radius: 14)
    }

    private var appTitle: some View {
        Text("ImagePet")
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundStyle(SoftNativeStyle.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerActions: some View {
        HStack(spacing: 8) {
            Button {
                store.toggleDesktopPet()
            } label: {
                Label(store.isDesktopPetVisible ? "Hide Pet" : "Show Pet", systemImage: "pawprint")
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .disabled(!store.isDesktopPetEnabled)
            .help(store.isDesktopPetVisible ? "Hide Desktop Pet (⇧⌘P)" : "Show Desktop Pet (⇧⌘P)")
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
                        .minimumScaleFactor(0.82)
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

                    // Option Toggles (Metadata and PNG Lossless notice)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 18) {
                            metadataToggle
                            advancedJPEGToggle
                            compressionHint
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            metadataToggle
                            advancedJPEGToggle
                            compressionHint
                        }
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
        VStack(spacing: 8) {
            qualityCard
            formatCard
            maxEdgeCard
            saveToCard
            thumbnailSizeCard
        }
    }

    private var customQualitySlider: some View {
        HStack(spacing: 10) {
            Text("Quality \(store.customQuality)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            qualitySlider
        }
    }

    private var qualitySlider: some View {
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

    private var suffixRow: some View {
        HStack(alignment: .center, spacing: 16) {
            suffixEditor
            filenamePreview
            Spacer(minLength: 8)
        }
    }

    private var suffixEditor: some View {
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
    }

    private var filenamePreview: some View {
        let preview = store.filenamePreview
        let suffix = store.filenameSuffix
        
        return Group {
            if !suffix.isEmpty, let suffixRange = preview.range(of: suffix, options: .backwards) {
                let prefixIndex = suffixRange.lowerBound
                let suffixIndex = suffixRange.upperBound
                
                let prefixPart = String(preview[..<prefixIndex])
                let suffixPart = String(preview[suffixRange])
                let extensionPart = String(preview[suffixIndex...])
                
                HStack(spacing: 0) {
                    Text(prefixPart)
                        .foregroundStyle(.secondary)
                    Text(suffixPart)
                        .foregroundStyle(SoftNativeStyle.accent)
                        .fontWeight(.bold)
                    Text(extensionPart)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(preview)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(.caption, design: .monospaced))
        .lineLimit(1)
        .accessibilityIdentifier("filenamePreviewLabel")
    }

    private var outputFolderRow: some View {
        HStack(spacing: 8) {
            outputFolderLabel
            chooseOutputFolderButton
            Spacer()
        }
    }

    private var outputFolderLabel: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "folder.badge.gearshape")
                .foregroundStyle(.secondary)
                .alignmentGuide(.firstTextBaseline) { d in d[.bottom] - 2 }

            Text(outputFolderText)
                .foregroundStyle(store.outputDirectory == nil ? .secondary : .primary)
                .lineLimit(3)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("outputFolderLabel")
        }
    }

    private var chooseOutputFolderButton: some View {
        Button("Choose Folder") {
            store.chooseOutputDirectory()
        }
        .keyboardShortcut("o", modifiers: [.command, .shift])
        .disabled(store.isProcessing)
        .help("Choose Output Folder (⇧⌘O)")
        .accessibilityIdentifier("chooseFolderButton")
    }

    private var metadataToggle: some View {
        Toggle("Strip Metadata (GPS/EXIF/Camera Info)", isOn: $store.stripMetadata)
            .disabled(store.isProcessing)
            .accessibilityIdentifier("stripMetadataToggle")
    }

    @ViewBuilder
    private var advancedJPEGToggle: some View {
        if store.canUseAdvancedJPEG {
            Toggle("Advanced JPEG", isOn: Binding(
                get: { store.jpegEncodingMode == .advanced },
                set: { store.jpegEncodingMode = $0 ? .advanced : .standard }
            ))
            .disabled(store.isProcessing)
            .help("Smaller JPEG output for web sharing.")
            .accessibilityIdentifier("advancedJPEGToggle")
        }
    }

    private var compressionHint: some View {
        Label(compressionHintText, systemImage: "info.circle")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var compressionHintText: String {
        if store.outputFormat == .png {
            return "PNG uses lossless compression. Quality does not apply."
        } else if store.canUseAdvancedJPEG && store.jpegEncodingMode == .advanced {
            return "Smaller JPEG output for web sharing."
        } else if store.outputFormat == .webp {
            return "Best for web sharing. Static images only."
        } else {
            return "HDR or wide-gamut images will be exported as standard sRGB."
        }
    }

    private var qualityCard: some View {
        ControlCard(title: "Quality") {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Quality", selection: $store.qualityMode) {
                    ForEach(CompressionQualityMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .disabled(store.isProcessing || store.outputFormat == .png)
                .accessibilityIdentifier("presetPicker")

                if store.qualityMode == .custom && store.outputFormat != .png {
                    ViewThatFits(in: .horizontal) {
                        customQualitySlider

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Quality \(store.customQuality)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            qualitySlider
                        }
                    }
                    .padding(.top, 4)
                }
            }
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
            VStack(alignment: .leading, spacing: 8) {
                Picker("Location", selection: $store.saveLocationMode) {
                    ForEach(SaveLocationMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .disabled(store.isProcessing)
                .accessibilityIdentifier("locationModePicker")

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
                    .padding(.top, 4)
                } else {
                    ViewThatFits(in: .horizontal) {
                        suffixRow

                        VStack(alignment: .leading, spacing: 8) {
                            suffixEditor
                            filenamePreview
                        }
                    }
                    .padding(.top, 4)

                    if store.saveLocationMode == .designated {
                        Divider()
                            .padding(.vertical, 2)

                        ViewThatFits(in: .horizontal) {
                            outputFolderRow

                            VStack(alignment: .leading, spacing: 8) {
                                outputFolderLabel
                                chooseOutputFolderButton
                            }
                        }
                        .font(.callout)

                        if let message = store.outputFolderMessage {
                            Label(message, systemImage: "exclamationmark.triangle")
                                .font(.callout)
                                .foregroundStyle(SoftNativeStyle.secondary)
                        }
                    }
                }
            }
        }
    }

    private var thumbnailSizeCard: some View {
        ControlCard(title: "Thumbnail Size") {
            Picker("Thumbnail Size", selection: $store.thumbnailSize) {
                ForEach(ThumbnailSize.allCases) { size in
                    Text(size.displayName).tag(size)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityIdentifier("thumbnailSizePicker")
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
    @ObservedObject var store: ImagePetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            compactHeader
                .padding(.horizontal, 12)
                .frame(height: 34)
                .font(.caption2.weight(.bold))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(.secondary)
                .background(SoftNativeStyle.elevated.opacity(0.86))

            ScrollView {
                LazyVStack(spacing: 0) {
                    if store.jobs.isEmpty {
                        EmptyJobListView()
                    } else {
                        ForEach(store.jobs) { job in
                            JobRowView(store: store, job: job)
                        }
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(SoftNativeStyle.border)
        )
        .frame(maxHeight: .infinity)
        .softNativeCard(radius: 10)
    }

    private var compactHeader: some View {
        HStack {
            Text("Queue")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(store.jobs.count) \(store.jobs.count == 1 ? "image" : "images")")
        }
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
    @ObservedObject var store: ImagePetStore
    let job: ImageJob
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .frame(width: 18)
                .accessibilityIdentifier("jobIcon_\(job.fileName)")

            thumbnailView
                .frame(width: store.thumbnailSize.size, height: store.thumbnailSize.size)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(job.fileName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .font(.body)
                    .accessibilityIdentifier("jobFileName_\(job.fileName)")
                    .accessibilityLabel(job.fileName)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(statusText)
                        .foregroundStyle(statusColor)
                        .lineLimit(1)
                        .font(.caption)
                        .minimumScaleFactor(0.85)
                        .help(statusText)
                        .accessibilityIdentifier("jobStatusText_\(job.fileName)")
                        .accessibilityLabel(statusText)

                    Spacer(minLength: 4)

                    Text(sizeText)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .accessibilityIdentifier("jobSizeText_\(job.fileName)")
                        .accessibilityLabel(sizeText)
                }
            }

            if isHovering && job.status != .processing {
                HStack(spacing: 6) {
                    Button {
                        store.revealInFinder(for: job)
                    } label: {
                        Image(systemName: "folder")
                            .font(.caption)
                            .foregroundStyle(SoftNativeStyle.accent)
                    }
                    .buttonStyle(.plain)
                    .help("Reveal in Finder")
                    .accessibilityLabel("Reveal \(job.fileName) in Finder")

                    Button {
                        store.removeJob(id: job.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Remove from queue")
                    .accessibilityLabel("Remove \(job.fileName) from queue")
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, store.thumbnailSize == .small ? 6 : store.thumbnailSize == .medium ? 10 : 14)
        .background(isHovering ? SoftNativeStyle.surface.opacity(0.9) : SoftNativeStyle.surface.opacity(0.7))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(SoftNativeStyle.border)
                .frame(height: 1)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.isHovering = hovering
            }
        }
        .contextMenu {
            if job.status != .processing {
                Button {
                    store.revealInFinder(for: job)
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }

                Button(role: .destructive) {
                    store.removeJob(id: job.id)
                } label: {
                    Label("Remove from Queue", systemImage: "trash")
                }
            } else {
                Text("Processing... cannot modify")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let cgImage = store.thumbnails[job.id] {
            Image(cgImage, scale: 1.0, label: Text("Thumbnail"))
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Image(systemName: "photo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(4)
                .foregroundStyle(.tertiary)
                .background(SoftNativeStyle.elevated)
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
        case .canceled:
            return "slash.circle"
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
        case .canceled:
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
            return job.errorMessage ?? "Skipped"
        case .canceled:
            return "Canceled"
        }
    }

    private var statusColor: Color {
        switch job.status {
        case .failed:
            return .red
        case .skipped:
            return SoftNativeStyle.secondary
        case .canceled:
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
        case .pending, .processing, .canceled:
            return FileSizeFormatting.string(from: job.originalSize)
        }
    }
}

private struct SummaryView: View {
    @ObservedObject var store: ImagePetStore

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ViewThatFits(in: .horizontal) {
                horizontalContent
                verticalContent
            }

            Spacer()

            SummaryControlsView(store: store)
        }
        .padding(12)
        .softNativeCard(radius: 10, tint: SoftNativeStyle.elevated)
    }

    private var horizontalContent: some View {
        HStack(spacing: 10) {
            if store.isCompleted {
                completedMetrics
            } else if store.isProcessing {
                SummaryMetric(title: "Processing", value: "\(store.completedCount) / \(store.jobs.count)")
            } else {
                SummaryMetric(title: "Quality", value: store.qualitySummary)
                SummaryMetric(title: "Output", value: store.outputFormat.displayName)
            }
            Spacer()
        }
    }

    private var verticalContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if store.isCompleted {
                completedMetrics
            } else if store.isProcessing {
                SummaryMetric(title: "Processing", value: "\(store.completedCount) / \(store.jobs.count)")
            } else {
                HStack(spacing: 10) {
                    SummaryMetric(title: "Quality", value: store.qualitySummary)
                    SummaryMetric(title: "Output", value: store.outputFormat.displayName)
                }
            }
        }
    }

    private var completedMetrics: some View {
        HStack(spacing: 10) {
            SummaryMetric(title: "Ate", value: FileSizeFormatting.string(from: store.successfulOriginalTotal))
            SummaryMetric(title: "Pooped", value: FileSizeFormatting.string(from: store.compressedTotal))
            SummaryMetric(
                title: "Saved",
                value: "\(FileSizeFormatting.string(from: store.savedTotal)) / \(FileSizeFormatting.percent(store.savedRatio))"
            )
        }
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
        .frame(minWidth: 112, maxWidth: .infinity, alignment: .leading)
        .background(SoftNativeStyle.surface.opacity(0.70), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(SoftNativeStyle.border)
        )
    }
}

private struct SummaryControlsView: View {
    @ObservedObject var store: ImagePetStore

    var body: some View {
        HStack(spacing: 8) {
            if store.isProcessing {
                Button(role: .cancel) {
                    store.cancelProcessing()
                } label: {
                    if store.isCanceling {
                        Label("Canceling...", systemImage: "stop.circle")
                    } else {
                        Label("Cancel", systemImage: "stop.circle")
                    }
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(store.isCanceling)
                .keyboardShortcut(".", modifiers: [.command])
                .help("Cancel processing (⌘.)")
                .accessibilityIdentifier("cancelButton")
            } else if store.isCompleted {
                Button {
                    store.revealOutputDirectory()
                } label: {
                    Label("Reveal", systemImage: "folder")
                }
                .buttonStyle(.bordered)
                .help("Reveal output directory")
                .accessibilityIdentifier("revealInFinderButton")

                if store.hasFailedJobs {
                    Button {
                        store.retryFailed()
                    } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut("r", modifiers: [.command])
                    .help("Retry Failed (⌘R)")
                    .accessibilityIdentifier("retryFailedButton")
                }

                Button {
                    store.clearList()
                } label: {
                    Label("Clear", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
                .keyboardShortcut("n", modifiers: [.command])
                .help("Clear List (⌘N)")
                .accessibilityIdentifier("clearListButton")
            }
        }
    }
}
