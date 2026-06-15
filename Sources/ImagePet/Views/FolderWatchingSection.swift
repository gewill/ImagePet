import SwiftUI

struct FolderWatchingSection: View {
    @ObservedObject var store: ImagePetStore

    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsSectionHeader(
                title: "Folder Watching",
                subtitle: "Automatically compress images dropped into monitored folders.",
                systemImage: "folder.badge.gearshape"
            )

            VStack(alignment: .leading, spacing: 16) {
                if store.folderWatchManager.tasks.isEmpty {
                    VStack(alignment: .center, spacing: 12) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("No Monitored Folders")
                            .font(.headline)
                        Text("Add a folder to automatically compress images added to it.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                } else {
                    ForEach(store.folderWatchManager.tasks) { task in
                        FolderWatchTaskCard(
                            task: task,
                            manager: store.folderWatchManager,
                            onRemove: { store.folderWatchManager.removeTask(id: task.id) }
                        )
                    }
                }

                Button {
                    addFolderWatchTask()
                } label: {
                    Label("Add Monitored Folder...", systemImage: "plus")
                }
            }
        }
        .alert(isPresented: $showingError) {
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
    }

    private func addFolderWatchTask() {
        let sourcePanel = NSOpenPanel()
        sourcePanel.message = "Select a folder to monitor for new images"
        sourcePanel.canChooseDirectories = true
        sourcePanel.canChooseFiles = false
        sourcePanel.allowsMultipleSelection = false
        sourcePanel.prompt = "Select Source"

        guard sourcePanel.runModal() == .OK, let sourceURL = sourcePanel.url else { return }

        let outputPanel = NSOpenPanel()
        outputPanel.message = "Select the destination folder for compressed images"
        outputPanel.canChooseDirectories = true
        outputPanel.canChooseFiles = false
        outputPanel.allowsMultipleSelection = false
        outputPanel.prompt = "Select Destination"

        guard outputPanel.runModal() == .OK, let outputURL = outputPanel.url else { return }

        if sourceURL.standardizedFileURL == outputURL.standardizedFileURL {
            errorMessage = "Source and destination folders cannot be the same. This would cause an infinite loop."
            showingError = true
            return
        }

        do {
            try store.folderWatchManager.addTask(sourceURL: sourceURL, outputURL: outputURL)
        } catch {
            errorMessage = "Failed to add folder: \(error.localizedDescription)"
            showingError = true
        }
    }
}

struct FolderWatchTaskCard: View {
    let task: FolderWatchTask
    @ObservedObject var manager: FolderWatchManager
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.blue)
                    Text(manager.resolvedSourceURLs[task.id]?.path ?? "Unknown Source")
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .font(.subheadline.weight(.semibold))
                }

                HStack {
                    Image(systemName: "arrow.turn.down.right")
                        .foregroundColor(.secondary)
                    Text(manager.resolvedOutputURLs[task.id]?.path ?? "Unknown Destination")
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(role: .destructive, action: onRemove) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.red)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
}
