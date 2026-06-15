import KeyboardShortcuts
import ImagePetCore
import SwiftUI

struct AppSettingsView: View {
    @ObservedObject var store: ImagePetStore

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(selection: $store.selectedSettingsSection)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    switch store.selectedSettingsSection {
                    case .general:
                        GeneralSettingsSection(store: store)
                    case .folderWatching:
                        FolderWatchingSection(store: store)
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
    }
}

private struct SettingsSidebar: View {
    @Binding var selection: SettingsSection

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(SettingsSection.allCases) { section in
                Button {
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

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            SettingsThemeCard(
                                name: "Shiba Inu",
                                description: "An energetic, loyal puppy.",
                                themeName: "ShibaInu",
                                selectedTheme: $store.selectedThemeName
                            )
                            .accessibilityIdentifier("themeCard_ShibaInu")

                            SettingsThemeCard(
                                name: "Cute Cat",
                                description: "A playful, hand-drawn kitty.",
                                themeName: "CuteCat",
                                selectedTheme: $store.selectedThemeName
                            )
                            .accessibilityIdentifier("themeCard_CuteCat")

                            SettingsThemeCard(
                                name: "Pixel Slime",
                                description: "Retro bounce pixel slime.",
                                themeName: "PixelSlime",
                                selectedTheme: $store.selectedThemeName
                            )
                            .accessibilityIdentifier("themeCard_PixelSlime")
                        }
                    }
                }

                Divider()

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
            SettingSummaryRow(title: "Third-party notices", value: "docs/THIRD_PARTY_NOTICES.md")
        }
        .accessibilityIdentifier("helpAboutSummary")
    }
}

private struct SettingsThemeCard: View {
    let name: String
    let description: String
    let themeName: String
    @Binding var selectedTheme: String

    @State private var isHovered = false

    private var isSelected: Bool {
        selectedTheme == themeName
    }

    var body: some View {
        Button {
            selectedTheme = themeName
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06))

                    if let image = ThemeCache.loadStaticImage(themeName: themeName, animation: .idle) {
                        Image(decorative: image, scale: 1.0)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48)
                    } else {
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 72)

                Text(name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(isSelected ? "Selected" : "Select")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(isSelected ? Color.accentColor : Color.secondary)
            }
            .padding(12)
            .frame(width: 150, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.35), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: .black.opacity(isHovered ? 0.12 : 0.04), radius: isHovered ? 8 : 2, y: 2)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel("Theme: \(name)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
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
