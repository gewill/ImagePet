import SwiftUI

struct DesktopPetView: View {
    @ObservedObject var store: ImagePetStore
    @State private var isDropTargeted = false

    var body: some View {
        let snapshot = store.petSnapshot

        VStack(spacing: 8) {
            // Top Bar
            HStack {
                Button {
                    store.handlePetAction(.openMainApp)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.right.square")
                        Text("App")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Show Main Application")
                .accessibilityIdentifier("desktopPetReturnToAppButton")

                Spacer()

                Button {
                    store.handlePetAction(.hidePet)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .help("Hide Desktop Pet")
                .accessibilityIdentifier("closePetButton")
            }
            .frame(height: 16)

            // Center Avatar
            Text(snapshot.emoji)
                .font(.system(size: 54))
                .frame(width: 68, height: 58)
                .scaleEffect(snapshot.state == .eating ? 1.08 : 1)
                .animation(
                    snapshot.state == .eating ?
                        .easeInOut(duration: 0.6).repeatForever(autoreverses: true) :
                        .default,
                    value: snapshot.state
                )
                .accessibilityIdentifier("desktopPetEmoji")

            // Title
            Text(snapshot.title)
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityIdentifier("desktopPetTitle")

            // Detail Text with dynamic tooltip
            Text(snapshot.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .help(tooltipText(for: snapshot))
                .accessibilityIdentifier("desktopPetDetail")

            // Bottom Actions Bar
            HStack(spacing: 12) {
                let bottomActions = snapshot.secondaryActions.filter { $0 != .hidePet && $0 != .openMainApp }
                ForEach(bottomActions, id: \.self) { action in
                    Button {
                        store.handlePetAction(action)
                    } label: {
                        Image(systemName: symbol(for: action))
                    }
                    .help(helpText(for: action))
                    .accessibilityIdentifier(accessibilityId(for: action))
                }
            }
            .frame(height: 24)
            .buttonStyle(.borderless)
            .font(.system(size: 15, weight: .semibold))
        }
        .padding(12)
        .frame(width: 168, height: 156)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isDropTargeted ? Color.accentColor.opacity(0.12) : Color.clear)
        )
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isDropTargeted ? Color.accentColor : .secondary.opacity(0.18), lineWidth: isDropTargeted ? 2 : 1)
        )
        .dropDestination(for: URL.self) { urls, _ in
            guard snapshot.canAcceptDrop else { return false }
            store.addDroppedURLs(urls)
            return true
        } isTargeted: { isTargeted in
            if snapshot.canAcceptDrop {
                self.isDropTargeted = isTargeted
            } else {
                self.isDropTargeted = false
            }
        }
        .onChange(of: store.showOverwriteConfirmation) { newValue in
            if newValue {
                let isMainKey = NSApp.windows.contains { w in
                    (w.title == "ImagePet" || w.identifier?.rawValue == "main") && w.isKeyWindow
                }
                if !isMainKey {
                    if let window = NSApp.windows.first(where: { w in w.identifier?.rawValue == "DesktopPetWindow" && w.isVisible }) {
                        let alert = NSAlert()
                        alert.messageText = "Overwrite Original Files?"
                        alert.informativeText = "Are you sure you want to overwrite the original images? This will replace your original files and cannot be undone."
                        alert.addButton(withTitle: "Overwrite")
                        alert.addButton(withTitle: "Cancel")
                        
                        alert.beginSheetModal(for: window) { response in
                            if response == .alertFirstButtonReturn {
                                store.confirmOverwriteAndStart()
                            } else {
                                store.cancelOverwrite()
                            }
                        }
                    }
                }
            }
        }
    }

    private func symbol(for action: DesktopPetAction) -> String {
        switch action {
        case .openMainApp:
            return "arrow.up.right.square"
        case .hidePet:
            return "xmark.circle"
        case .addImages:
            return "photo.badge.plus"
        case .revealOutput:
            return "folder"
        case .retryFailed:
            return "arrow.counterclockwise"
        case .compressMore:
            return "plus.circle"
        }
    }

    private func helpText(for action: DesktopPetAction) -> String {
        switch action {
        case .openMainApp:
            return "Show Main Application"
        case .hidePet:
            return "Hide Desktop Pet"
        case .addImages:
            return "Add Images"
        case .revealOutput:
            if let outputDir = store.outputDirectory {
                return "Reveal in Finder: \(outputDir.path)"
            }
            return "Reveal in Finder"
        case .retryFailed:
            return "Retry Failed"
        case .compressMore:
            return "Compress More"
        }
    }

    private func accessibilityId(for action: DesktopPetAction) -> String {
        switch action {
        case .openMainApp:
            return "desktopPetReturnToAppButton"
        case .hidePet:
            return "closePetButton"
        case .addImages:
            return "desktopPetAddImagesButton"
        case .revealOutput:
            return "desktopPetRevealButton"
        case .retryFailed:
            return "desktopPetRetryFailedButton"
        case .compressMore:
            return "desktopPetCompressMoreButton"
        }
    }

    private func tooltipText(for snapshot: DesktopPetSnapshot) -> String {
        if snapshot.state == .idle {
            let formatText = store.outputFormat == .original ? "Original Format" : store.outputFormat.rawValue.uppercased()
            if store.saveLocationMode == .designated, let dir = store.outputDirectory {
                return "Saving as \(formatText) to \(dir.lastPathComponent)"
            } else if store.saveLocationMode == .overwrite {
                return "Overwriting original files"
            } else {
                return "Saving to original folder"
            }
        }
        return snapshot.detail
    }
}
