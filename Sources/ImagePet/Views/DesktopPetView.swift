import SwiftUI

struct DesktopPetView: View {
    @ObservedObject var store: ImagePetStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDropTargeted = false

    var body: some View {
        let snapshot = store.petSnapshot

        Group {
            if store.petViewMode == .mini {
                miniView(for: snapshot)
            } else {
                fullView(for: snapshot)
            }
        }
        .frame(width: store.petViewMode == .mini ? 80 : 192, height: store.petViewMode == .mini ? 80 : 176)
        .background(
            Group {
                if store.petViewMode == .mini {
                    Circle()
                        .fill(isDropTargeted ? Color.accentColor.opacity(0.14) : Color.clear)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isDropTargeted ? Color.accentColor.opacity(0.14) : accentColor(for: snapshot.state).opacity(0.04))
                }
            }
        )
        .background(
            Group {
                if store.petViewMode != .mini {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.regularMaterial)
                }
            }
        )
        .overlay(
            Group {
                if store.petViewMode == .mini {
                    if isDropTargeted {
                        Circle()
                            .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    }
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            isDropTargeted ? Color.accentColor : accentColor(for: snapshot.state).opacity(0.24),
                            style: StrokeStyle(lineWidth: isDropTargeted ? 2 : 1, dash: isDropTargeted ? [6, 4] : [])
                        )
                }
            }
        )
        .scaleEffect(isDropTargeted && !reduceMotion ? 1.02 : 1)
        .contentShape(RoundedRectangle(cornerRadius: store.petViewMode == .mini ? 40 : 8))
        .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.82), value: isDropTargeted)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: snapshot.state)
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
        .onHover { isHovered in
            if isHovered {
                store.resetPetIdleTimer()
            }
        }
        .contextMenu {
            if store.petViewMode == .mini {
                Button("Show Panel") {
                    store.petViewMode = .full
                }
            } else {
                Button("Collapse to Mini") {
                    store.petViewMode = .mini
                }
            }
            Button("Open App") {
                store.handlePetAction(.openMainApp)
            }
            Button("Hide Pet") {
                store.handlePetAction(.hidePet)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                store.handlePetAction(.openMainApp)
            } label: {
                PetTopActionLabel(title: "App", systemImage: "arrow.up.right.square")
            }
            .buttonStyle(.plain)
            .help("Show Main Application")
            .accessibilityLabel("Show Main Application")
            .accessibilityIdentifier("desktopPetReturnToAppButton")

            Spacer()

            Button {
                store.handlePetAction(.collapse)
            } label: {
                PetIconButton(systemImage: "arrow.down.right.and.arrow.up.left", accent: .secondary)
            }
            .buttonStyle(.plain)
            .help("Collapse to Mini Pet")
            .accessibilityLabel("Collapse to Mini Pet")
            .accessibilityIdentifier("collapsePetButton")

            Button {
                store.handlePetAction(.hidePet)
            } label: {
                PetIconButton(systemImage: "xmark", accent: .secondary)
            }
            .buttonStyle(.plain)
            .help("Hide Desktop Pet")
            .accessibilityLabel("Hide Desktop Pet")
            .accessibilityIdentifier("closePetButton")
        }
        .frame(height: 22)
    }

    private func petFace(for snapshot: DesktopPetSnapshot) -> some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(accentColor(for: snapshot.state).opacity(isDropTargeted ? 0.22 : 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(accentColor(for: snapshot.state).opacity(0.22), lineWidth: 1)
                )

            Text(snapshot.emoji)
                .font(.system(size: 48))
                .frame(width: 64, height: 56)
                .scaleEffect(faceScale(for: snapshot.state))
                .animation(faceAnimation(for: snapshot.state), value: snapshot.state)
                .accessibilityLabel("Desktop pet, \(snapshot.title), double click to show controls")
                .accessibilityIdentifier("desktopPetEmoji")

            if store.petViewMode == .full {
                Image(systemName: badgeSymbol(for: snapshot.state))
                    .font(.system(size: 12, weight: .bold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(accentColor(for: snapshot.state))
                    .frame(width: 22, height: 22)
                    .background(.regularMaterial, in: Circle())
                    .overlay(Circle().stroke(.secondary.opacity(0.18), lineWidth: 1))
                    .padding(2)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 72, height: 60)
        .shadow(color: accentColor(for: snapshot.state).opacity(0.18), radius: isDropTargeted ? 10 : 6, y: 3)
    }

    private func miniView(for snapshot: DesktopPetSnapshot) -> some View {
        petFace(for: snapshot)
            .frame(width: 72, height: 72)
            .contentShape(RoundedRectangle(cornerRadius: 18))
            .onTapGesture {
                store.petViewMode = .full
            }
    }

    @ViewBuilder
    private func fullView(for snapshot: DesktopPetSnapshot) -> some View {
        VStack(spacing: 7) {
            topBar

            petFace(for: snapshot)

            VStack(spacing: 2) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(accentColor(for: snapshot.state))
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)

                    Text(snapshot.title)
                        .font(.system(.callout, design: .rounded, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .accessibilityIdentifier("desktopPetTitle")
                }
                .frame(height: 18)

                Text(detailText(for: snapshot))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .help(tooltipText(for: snapshot))
                    .accessibilityIdentifier("desktopPetDetail")
            }
            .frame(height: 34)

            if snapshot.state == .eating {
                ProgressView(
                    value: Double(store.completedCount),
                    total: Double(max(store.jobs.count, 1))
                )
                .controlSize(.small)
                .tint(accentColor(for: snapshot.state))
                .frame(height: 6)
                .padding(.horizontal, 8)
                .transition(.opacity)
            }

            actionBar(for: snapshot)
        }
        .padding(10)
    }

    @ViewBuilder
    private func actionBar(for snapshot: DesktopPetSnapshot) -> some View {
        let primaryAction = visiblePrimaryAction(for: snapshot)
        let secondaryActions = visibleSecondaryActions(for: snapshot, primaryAction: primaryAction)

        HStack(spacing: 6) {
            if let primaryAction {
                Button {
                    store.handlePetAction(primaryAction)
                } label: {
                    PetActionLabel(
                        title: shortTitle(for: primaryAction),
                        systemImage: symbol(for: primaryAction),
                        accent: accentColor(for: snapshot.state),
                        isPrimary: true,
                        reduceMotion: reduceMotion
                    )
                }
                .buttonStyle(.plain)
                .help(helpText(for: primaryAction))
                .accessibilityLabel(helpText(for: primaryAction))
                .accessibilityIdentifier(accessibilityId(for: primaryAction))
            }

            ForEach(secondaryActions, id: \.self) { action in
                Button {
                    store.handlePetAction(action)
                } label: {
                    PetActionLabel(
                        title: nil,
                        systemImage: symbol(for: action),
                        accent: accentColor(for: snapshot.state),
                        isPrimary: false,
                        reduceMotion: reduceMotion
                    )
                }
                .buttonStyle(.plain)
                .help(helpText(for: action))
                .accessibilityLabel(helpText(for: action))
                .accessibilityIdentifier(accessibilityId(for: action))
            }
        }
        .frame(height: 30)
    }

    private func visiblePrimaryAction(for snapshot: DesktopPetSnapshot) -> DesktopPetAction? {
        guard let action = snapshot.primaryAction else { return nil }
        return action == .openMainApp || action == .hidePet ? nil : action
    }

    private func visibleSecondaryActions(for snapshot: DesktopPetSnapshot, primaryAction: DesktopPetAction?) -> [DesktopPetAction] {
        snapshot.secondaryActions.filter { action in
            action != .hidePet && action != .openMainApp && action != primaryAction
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
            return "folder.fill"
        case .retryFailed:
            return "arrow.clockwise"
        case .compressMore:
            return "plus.circle"
        case .collapse:
            return "arrow.down.right.and.arrow.up.left"
        }
    }

    private func shortTitle(for action: DesktopPetAction) -> String {
        switch action {
        case .openMainApp:
            return "App"
        case .hidePet:
            return "Hide"
        case .addImages:
            return "Add"
        case .revealOutput:
            return "Reveal"
        case .retryFailed:
            return "Retry"
        case .compressMore:
            return "More"
        case .collapse:
            return "Collapse"
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
        case .collapse:
            return "Collapse to Mini Pet"
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
        case .collapse:
            return "collapsePetButton"
        }
    }

    private func detailText(for snapshot: DesktopPetSnapshot) -> String {
        if isDropTargeted && snapshot.canAcceptDrop {
            return "Release to compress"
        }
        return snapshot.detail
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

    private func accentColor(for state: DesktopPetDisplayState) -> Color {
        switch state {
        case .idle:
            return .accentColor
        case .needsSetup, .confirm:
            return .orange
        case .eating:
            return .accentColor
        case .done:
            return .green
        case .issues, .permission:
            return .red
        }
    }

    private func badgeSymbol(for state: DesktopPetDisplayState) -> String {
        switch state {
        case .idle:
            return "sparkles"
        case .needsSetup:
            return "folder.badge.questionmark"
        case .eating:
            return "arrow.triangle.2.circlepath"
        case .done:
            return "checkmark.circle.fill"
        case .issues:
            return "exclamationmark.triangle.fill"
        case .confirm:
            return "exclamationmark.shield.fill"
        case .permission:
            return "lock.fill"
        }
    }

    private func faceScale(for state: DesktopPetDisplayState) -> CGFloat {
        guard !reduceMotion else { return 1 }
        switch state {
        case .eating:
            return 1.08
        case .done:
            return 1.04
        default:
            return 1
        }
    }

    private func faceAnimation(for state: DesktopPetDisplayState) -> Animation? {
        guard !reduceMotion else { return nil }
        if state == .eating {
            return .easeInOut(duration: 0.55).repeatForever(autoreverses: true)
        }
        return .spring(response: 0.24, dampingFraction: 0.72)
    }
}

private struct PetTopActionLabel: View {
    let title: String
    let systemImage: String
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
            Text(title)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(isHovered ? Color.accentColor : Color.secondary)
        .padding(.horizontal, 6)
        .frame(height: 22)
        .background(isHovered ? Color.accentColor.opacity(0.10) : Color.clear, in: Capsule())
        .contentShape(Capsule())
        .onHover { isHovered = $0 }
    }
}

private struct PetIconButton: View {
    let systemImage: String
    let accent: Color
    @State private var isHovered = false

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(isHovered ? accent : Color.secondary)
            .frame(width: 22, height: 22)
            .background(isHovered ? accent.opacity(0.12) : Color.clear, in: Circle())
            .contentShape(Circle())
            .onHover { isHovered = $0 }
    }
}

private struct PetActionLabel: View {
    let title: String?
    let systemImage: String
    let accent: Color
    let isPrimary: Bool
    let reduceMotion: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: title == nil ? 0 : 5) {
            Image(systemName: systemImage)
                .font(.system(size: isPrimary ? 13 : 14, weight: .semibold))

            if let title {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .foregroundStyle(foregroundStyle)
        .padding(.horizontal, title == nil ? 0 : 9)
        .frame(width: title == nil ? 30 : nil, height: 28)
        .background(backgroundStyle, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(borderStyle, lineWidth: 1)
        )
        .scaleEffect(isHovered && !reduceMotion ? 1.04 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .animation(reduceMotion ? nil : .spring(response: 0.18, dampingFraction: 0.82), value: isHovered)
        .onHover { isHovered = $0 }
    }

    private var foregroundStyle: Color {
        if isPrimary {
            return .white
        }
        return isHovered ? accent : .secondary
    }

    private var backgroundStyle: Color {
        if isPrimary {
            return isHovered ? accent.opacity(0.92) : accent
        }
        return isHovered ? accent.opacity(0.12) : Color.secondary.opacity(0.08)
    }

    private var borderStyle: Color {
        if isPrimary {
            return Color.white.opacity(0.16)
        }
        return isHovered ? accent.opacity(0.32) : Color.secondary.opacity(0.14)
    }
}
