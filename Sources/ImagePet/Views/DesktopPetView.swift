import AppKit
import SwiftUI

struct DesktopPetView: View {
    @ObservedObject var store: ImagePetStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDropTargeted = false
    @State private var isHovering = false
    @State private var interactionState: PetInteractionState = .none
    @StateObject private var animator: FrameAnimator

    @State private var currentMode: DesktopPetViewMode = .mini
    @State private var controlsOpacity: CGFloat = 0.0
    @State private var controlsOffset: CGFloat = 8.0

    @State private var resizeStartPetSize: CGFloat?

    private var sizeMetrics: DesktopPetSizeMetrics {
        DesktopPetSizeMetrics(petSize: store.petSize)
    }

    private var currentWindowSize: CGSize {
        sizeMetrics.windowSize(for: currentMode)
    }

    init(store: ImagePetStore) {
        self.store = store
        self._animator = StateObject(wrappedValue: FrameAnimator(themeName: store.selectedThemeName))
    }

    @ViewBuilder
    private func configuredPetView(for snapshot: DesktopPetSnapshot) -> some View {
        Group {
            if currentMode == .mini {
                miniView(for: snapshot)
            } else {
                fullView(for: snapshot)
            }
        }
        .frame(width: currentWindowSize.width, height: currentWindowSize.height)
        .background(
            Group {
                if currentMode == .mini {
                    Circle()
                        .fill(isDropTargeted ? SoftNativeStyle.accentSoft.opacity(0.86) : Color.clear)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isDropTargeted ? SoftNativeStyle.accentSoft : stateSurfaceColor(for: snapshot.state))
                }
            }
        )
        .background(
            Group {
                if currentMode != .mini {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.regularMaterial)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(SoftNativeStyle.surface.opacity(0.62))
                }
            }
        )
        .overlay(
            Group {
                if currentMode == .mini {
                    if isDropTargeted {
                        Circle()
                            .strokeBorder(SoftNativeStyle.accent, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    }
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            isDropTargeted ? SoftNativeStyle.accent : accentColor(for: snapshot.state).opacity(0.24),
                            style: StrokeStyle(lineWidth: isDropTargeted ? 2 : 1, dash: isDropTargeted ? [6, 4] : [])
                        )
                }
            }
        )
        .scaleEffect(isDropTargeted && !reduceMotion ? 1.02 : 1)
        .contentShape(RoundedRectangle(cornerRadius: currentMode == .mini ? currentWindowSize.width / 2 : 8))
        .overlay(alignment: .bottomTrailing) {
            if currentMode == .mini {
                resizeButton
                    .padding(3)
            }
        }
    }

    var body: some View {
        let snapshot = store.petSnapshot

        configuredPetView(for: snapshot)
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
                updateInteraction()
            }
            .onContinuousHover(coordinateSpace: .local) { phase in
                if case .active = phase {
                    store.resetPetIdleTimer()
                }
            }
            .onHover { isHovering in
                self.isHovering = isHovering
                store.setPetHovering(isHovering)
                updateInteraction()
            }
            .contextMenu {
                if currentMode == .mini {
                    Button("Show Panel") {
                        store.handlePetAction(.expand)
                    }
                } else {
                    Button("Collapse to Mini") {
                        store.handlePetAction(.collapse)
                    }
                }
                Button("Open App") {
                    store.handlePetAction(.openMainApp)
                }
                Button("Hide Pet") {
                    store.handlePetAction(.hidePet)
                }
            }
            .onAppear {
                animator.enableIdleVariants = store.enableIdleVariants
                animator.energySavingMode = store.energySavingMode
                animator.isPaused = !store.isDesktopPetVisible || reduceMotion
                updateAnimator()

                currentMode = store.petViewMode
                controlsOpacity = store.petViewMode == .full ? 1.0 : 0.0
                controlsOffset = store.petViewMode == .full ? 0.0 : 8.0
            }
            .onDisappear {
                animator.isPaused = true
            }
            .onChange(of: store.isDesktopPetVisible) { val in
                animator.isPaused = !val || reduceMotion
            }
            .onChange(of: store.petSnapshot.state) { _ in updateAnimator() }
            .onChange(of: store.issuesVisuallyDegraded) { _ in updateAnimator() }
            .onChange(of: interactionState) { _ in updateAnimator() }
            .onChange(of: store.selectedThemeName) { newTheme in
                animator.updateTheme(themeName: newTheme)
                updateAnimator()
            }
            .onChange(of: store.petSize) { _ in
                currentMode = store.petViewMode
            }
            .onChange(of: store.enableIdleVariants) { val in
                animator.enableIdleVariants = val
                updateAnimator()
            }
            .onChange(of: store.energySavingMode) { val in
                animator.energySavingMode = val
                updateAnimator()
            }
            .onChange(of: reduceMotion) { val in
                animator.isPaused = val || !store.isDesktopPetVisible
            }
            .onChange(of: store.petViewMode) { newMode in
                if newMode == .full {
                    currentMode = .full
                    withAnimation(.easeOut(duration: 0.25).delay(0.12)) {
                        controlsOpacity = 1.0
                        controlsOffset = 0.0
                    }
                } else {
                    currentMode = .mini
                    controlsOpacity = 0.0
                    controlsOffset = 8.0
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .desktopPetWillCollapse)) { _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    controlsOpacity = 0.0
                    controlsOffset = 8.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    store.performCollapse()
                }
            }
    }

    private func updateInteraction() {
        if isDropTargeted {
            interactionState = .dragHover
        } else if isHovering && store.enableHoverFeedback {
            interactionState = .hover
        } else {
            interactionState = .none
        }
    }

    private func updateAnimator() {
        animator.updateState(
            displayState: store.petSnapshot.state,
            interactionState: interactionState,
            isVisuallyDegraded: store.issuesVisuallyDegraded
        )
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
                PetIconButton(systemImage: "arrow.down.right.and.arrow.up.left", accent: SoftNativeStyle.secondary)
            }
            .buttonStyle(.plain)
            .help("Collapse to Mini Pet")
            .accessibilityLabel("Collapse to Mini Pet")
            .accessibilityIdentifier("collapsePetButton")

            Button {
                store.handlePetAction(.hidePet)
            } label: {
                PetIconButton(systemImage: "xmark", accent: SoftNativeStyle.secondary)
            }
            .buttonStyle(.plain)
            .help("Hide Desktop Pet")
            .accessibilityLabel("Hide Desktop Pet")
            .accessibilityIdentifier("closePetButton")
        }
        .frame(height: 22)
    }

    private var resizeButton: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(isHovering ? SoftNativeStyle.accent : Color.secondary)
            .frame(width: 24, height: 24)
            .background(.regularMaterial, in: Circle())
            .background(SoftNativeStyle.surface.opacity(0.78), in: Circle())
            .overlay(Circle().stroke(SoftNativeStyle.border.opacity(0.9), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.12), radius: 4, y: 2)
            .contentShape(Circle())
            .overlay {
                DesktopPetResizeEventCatcher(
                    onChanged: { diagonalDelta in
                        let startSize = resizeStartPetSize ?? store.petSize
                        resizeStartPetSize = startSize
                        store.setDesktopPetSize(startSize + diagonalDelta)
                    },
                    onEnded: {
                        resizeStartPetSize = nil
                    }
                )
                .frame(width: 32, height: 32)
            }
            .help("Drag to resize pet")
            .accessibilityElement()
            .accessibilityLabel("Resize Desktop Pet")
            .accessibilityValue(sizeMetrics.accessibilityValue)
            .accessibilityIdentifier("desktopPetResizeButton")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    store.setDesktopPetSize(store.petSize + DesktopPetSizeMetrics.accessibilityStep)
                case .decrement:
                    store.setDesktopPetSize(store.petSize - DesktopPetSizeMetrics.accessibilityStep)
                @unknown default:
                    break
                }
            }
            .opacity(isHovering ? 1 : 0)
            .scaleEffect(isHovering && !reduceMotion ? 1 : 0.92)
            .allowsHitTesting(isHovering)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: isHovering)
    }

    private func petFace(for snapshot: DesktopPetSnapshot) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(faceBackgroundColor(for: snapshot.state))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(faceBorderColor(for: snapshot.state), lineWidth: 0.5)
                )

            ZStack {
                if let frame = animator.currentFrame {
                    Image(decorative: frame, scale: 1.0)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Color.clear
                }
            }
            .frame(width: sizeMetrics.petArtFrame.width, height: sizeMetrics.petArtFrame.height)
            .scaleEffect(faceScale(for: snapshot.state))
            .animation(reduceMotion ? nil : faceAnimation(for: snapshot.state), value: snapshot.state)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel(for: snapshot))
            .accessibilityHint(accessibilityHint(for: snapshot))
            .accessibilityAddTraits(currentMode == .mini ? .isButton : [])
            .accessibilityAction {
                if currentMode == .mini {
                    store.handlePetAction(.expand)
                }
            }
            .accessibilityIdentifier("desktopPetEmoji")

            if currentMode == .full {
                Image(systemName: badgeSymbol(for: snapshot.state))
                    .font(.system(size: 12, weight: .bold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(accentColor(for: snapshot.state))
                    .frame(width: 22, height: 22)
                    .background(.regularMaterial, in: Circle())
                    .background(SoftNativeStyle.surface.opacity(0.78), in: Circle())
                    .overlay(Circle().stroke(SoftNativeStyle.border, lineWidth: 1))
                    .padding(2)
                    .accessibilityHidden(true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .frame(width: sizeMetrics.petFaceFrame.width, height: sizeMetrics.petFaceFrame.height)
        .shadow(
            color: accentColor(for: snapshot.state).opacity(currentMode == .mini ? 0.08 : 0.18),
            radius: currentMode == .mini ? 3 : (isDropTargeted ? 10 : 6),
            y: currentMode == .mini ? 1.5 : 3
        )
    }

    private func miniView(for snapshot: DesktopPetSnapshot) -> some View {
        petFace(for: snapshot)
            .frame(width: sizeMetrics.miniPetFrame.width, height: sizeMetrics.miniPetFrame.height)
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .onTapGesture {
                store.handlePetAction(.expand)
            }
    }

    @ViewBuilder
    private func fullView(for snapshot: DesktopPetSnapshot) -> some View {
        VStack(spacing: 7) {
            topBar
                .opacity(controlsOpacity)
                .offset(y: controlsOffset)

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
            .opacity(controlsOpacity)
            .offset(y: controlsOffset)

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
                .opacity(controlsOpacity)
                .offset(y: controlsOffset)
            }

            actionBar(for: snapshot)
                .opacity(controlsOpacity)
                .offset(y: controlsOffset)
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
        case .clearList:
            return "plus.circle"
        case .expand:
            return "arrow.up.left.and.arrow.down.right"
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
        case .clearList:
            return "Clear"
        case .expand:
            return "Show"
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
        case .clearList:
            return "Clear List"
        case .expand:
            return "Show Pet Controls"
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
        case .clearList:
            return "desktopPetClearListButton"
        case .expand:
            return "desktopPetExpandButton"
        case .collapse:
            return "collapsePetButton"
        }
    }

    private func accessibilityLabel(for snapshot: DesktopPetSnapshot) -> String {
        if currentMode == .mini {
            return "ImagePet desktop pet, \(snapshot.title), drop images or click to show controls"
        }
        return "ImagePet desktop pet, \(snapshot.title), \(snapshot.detail)"
    }

    private func accessibilityHint(for snapshot: DesktopPetSnapshot) -> String {
        if currentMode == .mini {
            return snapshot.canAcceptDrop ? "Drop images or click to show controls" : "Click to show controls"
        }
        return snapshot.canAcceptDrop ? "Drop images to add them" : "Open the app for the next step"
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
            return SoftNativeStyle.accent
        case .needsSetup, .confirm:
            return SoftNativeStyle.secondary
        case .eating:
            return SoftNativeStyle.accent
        case .done:
            return SoftNativeStyle.success
        case .issues, .permission:
            return SoftNativeStyle.danger
        }
    }

    private func stateSurfaceColor(for state: DesktopPetDisplayState) -> Color {
        switch state {
        case .idle, .eating, .done:
            return SoftNativeStyle.accentSoft.opacity(0.48)
        case .needsSetup, .confirm:
            return SoftNativeStyle.secondarySoft.opacity(0.58)
        case .issues, .permission:
            return SoftNativeStyle.surface.opacity(0.66)
        }
    }

    private func faceSurfaceColor(for state: DesktopPetDisplayState) -> Color {
        switch state {
        case .idle, .eating, .done:
            return SoftNativeStyle.accentSoft
        case .needsSetup, .confirm:
            return SoftNativeStyle.secondarySoft
        case .issues, .permission:
            return SoftNativeStyle.elevated
        }
    }

    private func faceBackgroundColor(for state: DesktopPetDisplayState) -> Color {
        guard currentMode != .mini else { return .clear }
        return faceSurfaceColor(for: state).opacity(isDropTargeted ? 1.0 : 0.92)
    }

    private func faceBorderColor(for state: DesktopPetDisplayState) -> Color {
        guard currentMode != .mini else { return .clear }
        return accentColor(for: state).opacity(0.22)
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
        .foregroundStyle(isHovered ? SoftNativeStyle.accent : Color.secondary)
        .padding(.horizontal, 6)
        .frame(height: 22)
        .background(isHovered ? SoftNativeStyle.accentSoft : Color.clear, in: Capsule())
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

private struct DesktopPetResizeEventCatcher: NSViewRepresentable {
    var onChanged: (CGFloat) -> Void
    var onEnded: () -> Void

    func makeNSView(context: Context) -> ResizeEventView {
        ResizeEventView(onChanged: onChanged, onEnded: onEnded)
    }

    func updateNSView(_ nsView: ResizeEventView, context: Context) {
        nsView.onChanged = onChanged
        nsView.onEnded = onEnded
    }

    final class ResizeEventView: NSView {
        var onChanged: (CGFloat) -> Void
        var onEnded: () -> Void
        private var dragStartLocation: NSPoint?

        override var mouseDownCanMoveWindow: Bool { false }

        init(onChanged: @escaping (CGFloat) -> Void, onEnded: @escaping () -> Void) {
            self.onChanged = onChanged
            self.onEnded = onEnded
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
            true
        }

        override func mouseDown(with event: NSEvent) {
            dragStartLocation = event.locationInWindow
        }

        override func mouseDragged(with event: NSEvent) {
            guard let dragStartLocation else { return }
            let translationX = event.locationInWindow.x - dragStartLocation.x
            let translationY = event.locationInWindow.y - dragStartLocation.y
            onChanged((translationX - translationY) / 2)
        }

        override func mouseUp(with event: NSEvent) {
            dragStartLocation = nil
            onEnded()
        }
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
