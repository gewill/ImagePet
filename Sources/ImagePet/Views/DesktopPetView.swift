import SwiftUI

struct DesktopPetView: View {
    @ObservedObject var store: ImagePetStore
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()

                Button {
                    store.hideDesktopPet()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .help("Hide Desktop Pet")
            }
            .frame(height: 16)

            Text(petEmoji)
                .font(.system(size: 54))
                .frame(width: 68, height: 58)
                .scaleEffect(store.petState == .eating ? 1.08 : 1)
                .animation(.easeInOut(duration: 0.6).repeatCount(store.petState == .eating ? 8 : 1, autoreverses: true), value: store.petState)

            Text(title)
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            HStack(spacing: 10) {
                Button {
                    store.chooseInputImages()
                } label: {
                    Image(systemName: "photo.badge.plus")
                }
                .help("Add Images")

                if store.isCompleted {
                    Button {
                        store.revealOutputDirectory()
                    } label: {
                        Image(systemName: "folder")
                    }
                    .help("Reveal in Finder")
                }
            }
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
            store.addDroppedURLs(urls)
            return true
        } isTargeted: { isTargeted in
            self.isDropTargeted = isTargeted
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
            return "Ready"
        case .eating:
            return "Eating"
        case .happy:
            return "Done"
        case .error:
            return "Issues"
        }
    }

    private var detail: String {
        switch store.petState {
        case .idle:
            return "Waiting for images"
        case .eating:
            return "\(store.completedCount) / \(store.jobs.count)"
        case .happy:
            return "Saved \(FileSizeFormatting.string(from: store.savedTotal))"
        case .error:
            return "\(store.succeededCount) ok, \(store.failedCount) failed"
        }
    }
}
