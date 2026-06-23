import KeyboardShortcuts
import ImagePetCore
import SwiftUI
import AppKit
import OSLog

private let logger = Logger(subsystem: "org.gewill.ImagePet", category: "AppSettingsView")

struct AppSettingsView: View {
    @ObservedObject var store: ImagePetStore

    init(store: ImagePetStore) {
        let activeStore = ImagePetStore.shared ?? store
        logger.warning("AppSettingsView init: activeStore=\(String(describing: ObjectIdentifier(activeStore))), passedStore=\(String(describing: ObjectIdentifier(store))), sharedStore=\(ImagePetStore.shared != nil ? String(describing: ObjectIdentifier(ImagePetStore.shared!)) : "nil")")
        self._store = ObservedObject(wrappedValue: activeStore)
    }

    var body: some View {
        logger.warning("AppSettingsView body: store=\(String(describing: ObjectIdentifier(store))), selectedSection=\(store.selectedSettingsSection.rawValue)")
        return HStack(spacing: 0) {
            SettingsSidebar(selection: $store.selectedSettingsSection)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    switch store.selectedSettingsSection {
                    case .general:
                        GeneralSettingsSection(store: store)
                    case .folderWatching:
                        FolderWatchingSection(store: store)
                    case .notifications:
                        NotificationsSection(manager: store.notificationManager)
                    case .desktopPet:
                        DesktopPetSection(store: store)
                    case .keyboardShortcuts:
                        KeyboardShortcutsSection()
                    case .helpAbout:
                        HelpAboutSection(store: store)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 680, maxWidth: .infinity, minHeight: 480, maxHeight: .infinity)
        .background(SettingsWindowConfigurator())
    }
}

private struct SettingsWindowConfigurator: NSViewRepresentable {
    private let minimumSize = CGSize(width: 680, height: 480)

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(window: view.window, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: nsView.window, coordinator: context.coordinator)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(minimumSize: minimumSize)
    }

    private func configure(window: NSWindow?, coordinator: Coordinator) {
        guard let window else { return }

        let maximumSize = CGSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        window.title = "Settings"
        window.styleMask.insert([.resizable, .miniaturizable])
        window.minSize = minimumSize
        window.contentMinSize = minimumSize
        window.maxSize = maximumSize
        window.contentMaxSize = maximumSize
        window.collectionBehavior.insert(.fullScreenPrimary)

        if window.frame.width < window.minSize.width || window.frame.height < window.minSize.height {
            var frame = window.frame
            frame.size.width = max(frame.width, window.minSize.width)
            frame.size.height = max(frame.height, window.minSize.height)
            window.setFrame(frame, display: true)
        }

        window.standardWindowButton(.miniaturizeButton)?.isEnabled = true
        window.standardWindowButton(.zoomButton)?.isEnabled = true

        if window.delegate == nil || window.delegate === coordinator {
            coordinator.window = window
            window.delegate = coordinator
        }
    }

    final class Coordinator: NSObject, NSWindowDelegate {
        weak var window: NSWindow?
        private let minimumSize: CGSize

        init(minimumSize: CGSize) {
            self.minimumSize = minimumSize
        }

        func windowWillUseStandardFrame(_ window: NSWindow, defaultFrame newFrame: NSRect) -> NSRect {
            guard let screen = window.screen ?? NSScreen.main else {
                return newFrame
            }

            let visibleFrame = screen.visibleFrame.insetBy(dx: 24, dy: 24)
            return NSRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY,
                width: max(visibleFrame.width, minimumSize.width),
                height: max(visibleFrame.height, minimumSize.height)
            )
        }
    }
}

private struct SettingsSidebar: View {
    @Binding var selection: SettingsSection

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(SettingsSection.allCases.enumerated()), id: \.element.id) { index, section in
                Button {
                    logger.warning("SettingsSidebar button clicked: \(section.rawValue)")
                    selection = section
                } label: {
                    Label(section.title, systemImage: section.systemImage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderless)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selection == section ? Color.accentColor.opacity(0.14) : Color.clear)
                )
                .accessibilityIdentifier("settingsSection_\(section.id)")
                .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: [.command])
            }

            Spacer()
        }
        .padding(12)
        .frame(width: 210)
    }
}

private struct GeneralSettingsSection: View {
    @ObservedObject var store: ImagePetStore

    var body: some View {
        SettingsSectionHeader(
            title: "General",
            subtitle: "Current compression defaults and common actions.",
            systemImage: "slider.horizontal.3"
        )

        VStack(alignment: .leading, spacing: 14) {
            SettingSummaryRow(title: "Quality", value: store.qualitySummary)
            SettingSummaryRow(title: "Output", value: store.outputFormat.displayName)
            SettingSummaryRow(title: "Save Location", value: store.saveLocationMode.displayName)
            SettingSummaryRow(title: "Max Edge", value: store.maxDimension.displayName)
            SettingSummaryRow(title: "Metadata", value: store.stripMetadata ? "Strip metadata" : "Keep metadata")
        }
        .accessibilityIdentifier("generalSettingsSummary")
    }
}

private struct DesktopPetSection: View {
    @ObservedObject var store: ImagePetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 20) {
                SettingsSectionHeader(
                    title: "Desktop Pet",
                    subtitle: "Theme, launch, and animation behavior.",
                    systemImage: "pawprint"
                )

                Spacer()

                Button {
                    store.toggleDesktopPet()
                } label: {
                    Label(store.isDesktopPetVisible ? "Hide Pet" : "Show Pet", systemImage: "pawprint")
                }
                .disabled(!store.isDesktopPetEnabled)
                .help(store.isDesktopPetVisible ? "Hide Desktop Pet" : "Show Desktop Pet")
                .accessibilityIdentifier("showPetButton")

                Toggle(isOn: $store.isDesktopPetEnabled) {
                    Text(store.isDesktopPetEnabled ? "Enabled" : "Disabled")
                        .font(.headline)
                }
                .toggleStyle(.switch)
                .accessibilityIdentifier("petSettingsEnabledToggle")
            }

            Group {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Theme")
                        .font(.headline)

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 150, maximum: 160), spacing: 16, alignment: .top)],
                        alignment: .leading,
                        spacing: 16
                    ) {
                        ForEach(store.builtInThemes) { theme in
                            SettingsThemeCard(
                                theme: theme,
                                selectedTheme: $store.selectedThemeName
                            )
                            .accessibilityIdentifier("themeCard_\(theme.id)")
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    Toggle(isOn: $store.launchAtLoginEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Launch at Login")
                                .fontWeight(.medium)
                            Text("Start the desktop pet when you log in.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("launchAtLoginToggle")

                    if let error = store.launchAtLoginError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("launchAtLoginErrorLabel")
                    }

                    Divider()

                    Toggle(isOn: $store.enableIdleVariants) {
                        SettingToggleLabel(
                            title: "Enable Idle Variants",
                            detail: "Let the pet yawn or stretch during inactivity."
                        )
                    }
                    .accessibilityIdentifier("enableIdleVariantsToggle")

                    Toggle(isOn: $store.enableHoverFeedback) {
                        SettingToggleLabel(
                            title: "Enable Hover Feedback",
                            detail: "Animate the pet when the pointer hovers over it."
                        )
                    }
                    .accessibilityIdentifier("enableHoverFeedbackToggle")

                    Toggle(isOn: $store.enableSuccessSound) {
                        SettingToggleLabel(
                            title: "Play Success Sound",
                            detail: "Play a gentle chime after a fully successful batch."
                        )
                    }
                    .accessibilityIdentifier("enableSuccessSoundToggle")

                    Divider()

                    Toggle(isOn: $store.energySavingMode) {
                        SettingToggleLabel(
                            title: "Energy Saving Mode",
                            detail: "Reduce animation frame rate for lower CPU usage."
                        )
                    }
                    .accessibilityIdentifier("energySavingModeToggle")
                }
            }
            .disabled(!store.isDesktopPetEnabled)
        }
    }
}

private struct KeyboardShortcutsSection: View {
    var body: some View {
        SettingsSectionHeader(
            title: "Keyboard Shortcuts",
            subtitle: "Global shortcuts are unset until you record them.",
            systemImage: "keyboard"
        )
        .accessibilityIdentifier("keyboardShortcutsHeader")

        Text("Not set by default")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("shortcutsDefaultUnsetLabel")

        VStack(alignment: .leading, spacing: 16) {
            ForEach(ImagePetShortcutAction.all) { action in
                VStack(alignment: .leading, spacing: 6) {
                    KeyboardShortcuts.Recorder(action.title, name: action.name)
                        .accessibilityIdentifier("shortcutRecorder_\(action.id)")

                    Text(action.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .contain)
            }
        }

        Button {
            KeyboardShortcuts.reset(ImagePetShortcutAction.all.map(\.name))
        } label: {
            Label("Clear All Shortcuts", systemImage: "xmark.circle")
        }
        .accessibilityIdentifier("clearShortcutsButton")
    }
}

private struct NotificationsSection: View {
    @ObservedObject var manager: LocalNotificationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsSectionHeader(
                title: "Notifications",
                subtitle: "Background compression results and attention-needed alerts.",
                systemImage: "bell.badge"
            )
            .accessibilityIdentifier("notificationsHeader")

            VStack(alignment: .leading, spacing: 14) {
                SettingSummaryRow(title: "System Permission", value: manager.authorizationState.displayName)

                HStack(spacing: 10) {
                    if manager.authorizationState == .notDetermined || manager.authorizationState == .unknown {
                        Button {
                            manager.requestAuthorization()
                        } label: {
                            Label("Allow Notifications...", systemImage: "bell.badge")
                        }
                        .accessibilityIdentifier("enableNotificationsButton")
                    }

                    if manager.authorizationState == .denied {
                        Button {
                            manager.openSystemNotificationSettings()
                        } label: {
                            Label("Open System Settings", systemImage: "gearshape")
                        }
                        .accessibilityIdentifier("openNotificationSettingsButton")
                    }
                }

                Divider()

                Toggle(isOn: $manager.notificationsEnabled) {
                    SettingToggleLabel(
                        title: "ImagePet Notifications",
                        detail: "Allow ImagePet to send local alerts when macOS permission is granted."
                    )
                }
                .accessibilityIdentifier("notificationsEnabledToggle")

                if !manager.authorizationState.canDeliverNotifications {
                    Text("Notifications will not be delivered until macOS permission is allowed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("notificationPermissionDeliveryWarning")
                }

                Divider()

                Text("Notification Types")
                    .font(.headline)

                Toggle(isOn: $manager.notifyBackgroundCompletion) {
                    SettingToggleLabel(
                        title: "Background Completion",
                        detail: "Notify when background compression finishes."
                    )
                }
                .accessibilityIdentifier("notifyBackgroundCompletionToggle")
                .disabled(!manager.notificationsEnabled)

                Toggle(isOn: $manager.notifyAttentionNeeded) {
                    SettingToggleLabel(
                        title: "Attention Needed",
                        detail: "Notify when a folder, permission, or failed file needs review."
                    )
                }
                .accessibilityIdentifier("notifyAttentionNeededToggle")
                .disabled(!manager.notificationsEnabled)

                Toggle(isOn: $manager.notifyForegroundCompletion) {
                    SettingToggleLabel(
                        title: "Foreground Completion",
                        detail: "Also notify when ImagePet is already active."
                    )
                }
                .accessibilityIdentifier("notifyForegroundCompletionToggle")
                .disabled(!manager.notificationsEnabled)

                Toggle(isOn: $manager.notifyFolderWatchingCompletion) {
                    SettingToggleLabel(
                        title: "Folder Watching Success",
                        detail: "Notify when folder watching successfully compresses files."
                    )
                }
                .accessibilityIdentifier("notifyFolderWatchingCompletionToggle")
                .disabled(!manager.notificationsEnabled)

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Compression History")
                        .font(.headline)

                    if manager.recentSummaries.isEmpty {
                        Text("No compression history yet")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(manager.recentSummaries) { summary in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(summary.source.displayName)
                                            .font(.subheadline.weight(.semibold))
                                        Spacer()
                                        Text(summary.completedAt, style: .time)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    HStack {
                                        Text("\(summary.successfulCount) ok, \(summary.failedCount) failed, \(summary.skippedCount) skipped")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        
                                        Spacer()
                                        
                                        if summary.successfulCount > 0 {
                                            Text("Saved \(FileSizeFormatting.string(from: summary.savedBytes))")
                                                .font(.caption.weight(.medium))
                                                .foregroundStyle(.green)
                                        } else {
                                            Text(summary.statusText)
                                                .font(.caption)
                                                .foregroundStyle(summary.hasFailures ? .red : .secondary)
                                        }
                                    }
                                    
                                    if let errMsg = summary.primaryErrorMessage {
                                        Text(errMsg)
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                    }
                                }
                                .padding(8)
                                .background(Color.secondary.opacity(0.05))
                                .cornerRadius(6)
                            }
                        }
                    }

                    Text(manager.lastDeliveryStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .accessibilityIdentifier("recentNotificationSummary")

                #if DEBUG
                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Notification Debug (Debug Build Only)")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Button("Test Success") {
                            manager.triggerDebugNotification(type: .success)
                        }
                        .accessibilityIdentifier("debugTestSuccessButton")

                        Button("Test Failure") {
                            manager.triggerDebugNotification(type: .failure)
                        }
                        .accessibilityIdentifier("debugTestFailureButton")

                        Button("Test Permission") {
                            manager.triggerDebugNotification(type: .permission)
                        }
                        .accessibilityIdentifier("debugTestPermissionButton")

                        Button("Test Folder Watch") {
                            manager.triggerDebugNotification(type: .folderWatch)
                        }
                        .accessibilityIdentifier("debugTestFolderWatchButton")
                    }
                }
                #endif
            }
        }
        .onAppear {
            manager.refreshAuthorizationStatus()
        }
    }
}

private struct HelpAboutSection: View {
    @ObservedObject var store: ImagePetStore

    var body: some View {
        SettingsSectionHeader(
            title: "Help & About",
            subtitle: "Reference, version, and notices.",
            systemImage: "questionmark.circle"
        )

        Button {
            store.openHelp()
        } label: {
            Label("Open Help", systemImage: "questionmark.circle")
        }
        .accessibilityIdentifier("openHelpButton")

        VStack(alignment: .leading, spacing: 10) {
            SettingSummaryRow(title: "Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
            SettingSummaryRow(title: "Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
            SettingSummaryRow(title: "Privacy", value: "Local processing, no uploads")
            
            HStack(alignment: .firstTextBaseline) {
                Text("Third-party notices")
                    .foregroundStyle(.secondary)
                    .frame(width: 150, alignment: .leading)
                
                Button("View THIRD_PARTY_NOTICES.md") {
                    openThirdPartyNotices()
                }
                .buttonStyle(.link)
                .font(.callout)
                .help("Open Third-party notices file in default editor")
                .accessibilityIdentifier("openThirdPartyNoticesButton")
            }
            
            Divider()
                .padding(.vertical, 4)
            
            HStack(alignment: .firstTextBaseline) {
                Text("Website")
                    .foregroundStyle(.secondary)
                    .frame(width: 150, alignment: .leading)
                
                Link("imagepet.gewill.org", destination: URL(string: "https://imagepet.gewill.org")!)
                    .font(.callout)
                    .accessibilityIdentifier("aboutWebsiteLink")
            }
            
            HStack(alignment: .firstTextBaseline) {
                Text("Support")
                    .foregroundStyle(.secondary)
                    .frame(width: 150, alignment: .leading)
                
                Link("GitHub Issues", destination: URL(string: "https://github.com/gewill/ImagePet/issues")!)
                    .font(.callout)
                    .accessibilityIdentifier("aboutSupportLink")
            }
            
            HStack(alignment: .firstTextBaseline) {
                Text("Privacy Policy")
                    .foregroundStyle(.secondary)
                    .frame(width: 150, alignment: .leading)
                
                Link("View Privacy Policy", destination: URL(string: "https://imagepet.gewill.org/en/privacy")!)
                    .font(.callout)
                    .accessibilityIdentifier("aboutPrivacyLink")
            }
            
            HStack(alignment: .firstTextBaseline) {
                Text("Terms of Use")
                    .foregroundStyle(.secondary)
                    .frame(width: 150, alignment: .leading)
                
                Link("View Terms of Use", destination: URL(string: "https://imagepet.gewill.org/en/terms")!)
                    .font(.callout)
                    .accessibilityIdentifier("aboutTermsLink")
            }
        }
        .accessibilityIdentifier("helpAboutSummary")
    }

    private func openThirdPartyNotices() {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        
        if let url = bundle.url(forResource: "THIRD_PARTY_NOTICES", withExtension: "md") {
            NSWorkspace.shared.open(url)
        } else if let fallbackUrl = bundle.url(forResource: "Resources/THIRD_PARTY_NOTICES", withExtension: "md") {
            NSWorkspace.shared.open(fallbackUrl)
        } else {
            let localDocs = URL(fileURLWithPath: "docs/THIRD_PARTY_NOTICES.md")
            if FileManager.default.fileExists(atPath: localDocs.path) {
                NSWorkspace.shared.open(localDocs)
            }
        }
    }
}

private struct SettingsThemeCard: View {
    let theme: BuiltInPetTheme
    @Binding var selectedTheme: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false
    @State private var previewFrames: [CGImage] = []
    @State private var frameIndex = 0

    private var isSelected: Bool {
        selectedTheme == theme.id
    }

    private var previewImage: CGImage? {
        guard !previewFrames.isEmpty else { return nil }
        return previewFrames[min(frameIndex, previewFrames.count - 1)]
    }

    private var shouldAnimatePreview: Bool {
        !reduceMotion && previewFrames.count > 1 && (isSelected || isHovered)
    }

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) {
                selectedTheme = theme.id
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06))

                    if let image = previewImage {
                        Image(decorative: image, scale: 1.0)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 58, height: 58)
                            .scaleEffect(isHovered ? 1.06 : 1.0)
                            .animation(.easeOut(duration: 0.16), value: isHovered)
                    } else {
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                    }

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.accentColor)
                            .font(.system(size: 18, weight: .semibold))
                            .padding(8)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(height: 82)

                Text(theme.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(theme.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

            }
            .padding(12)
            .frame(width: 150, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.35), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: .black.opacity(isHovered ? 0.12 : 0.04), radius: isHovered ? 8 : 2, y: 2)
            .scaleEffect(isHovered ? 1.015 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .task(id: theme.id) {
            previewFrames = await ThemePreviewLoader.loadFrames(themeName: theme.id)
            frameIndex = 0
        }
        .task(id: shouldAnimatePreview) {
            guard shouldAnimatePreview else {
                frameIndex = 0
                return
            }

            let framesPerSecond = max(1, min(theme.defaultFPS, 8))
            let interval = 1_000_000_000 / UInt64(framesPerSecond)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: interval)
                guard !Task.isCancelled else { return }
                frameIndex = (frameIndex + 1) % previewFrames.count
            }
        }
        .accessibilityLabel("Theme: \(theme.displayName)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

private enum ThemePreviewLoader {
    static func loadFrames(themeName: String) async -> [CGImage] {
        await Task.detached(priority: .utility) {
            ThemeCache.loadPreviewFrames(themeName: themeName, animation: .idle)
        }.value
    }
}

struct SettingsSectionHeader: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2.weight(.semibold))

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct SettingSummaryRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 150, alignment: .leading)

            Text(value)
                .fontWeight(.medium)
                .textSelection(.enabled)
        }
        .font(.callout)
    }
}

private struct SettingToggleLabel: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .fontWeight(.medium)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
