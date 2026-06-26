import SwiftUI

struct HelpView: View {
    @State private var selectedTopicID: HelpTopic.ID? = HelpContent.topics.first?.id

    var body: some View {
        NavigationSplitView {
            List(HelpContent.topics, selection: $selectedTopicID) { topic in
                Label(topic.title, systemImage: topic.systemImage)
                    .tag(topic.id)
                    .accessibilityIdentifier("helpTopic_\(topic.id)")
            }
            .navigationTitle("ImagePet Help")
            .accessibilityIdentifier("helpTopicList")
        } detail: {
            if let topic = selectedTopic {
                HelpTopicDetailView(topic: topic)
            } else {
                Text("Choose a help topic")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 760, minHeight: 520)
        .accessibilityIdentifier("helpView")
    }

    private var selectedTopic: HelpTopic? {
        HelpContent.topics.first { $0.id == selectedTopicID } ?? HelpContent.topics.first
    }
}

private struct HelpTopicDetailView: View {
    let topic: HelpTopic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 12) {
                    Image(systemName: topic.systemImage)
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 28)
                        .accessibilityHidden(true)

                    Text(topic.title)
                        .font(.title2.weight(.semibold))
                        .accessibilityIdentifier("helpTitle_\(topic.id)")
                }

                ForEach(topic.sections) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(section.title)
                            .font(.headline)

                        ForEach(section.paragraphs, id: \.self) { paragraph in
                            Text(paragraph)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if !section.bullets.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(section.bullets, id: \.self) { bullet in
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Image(systemName: "checkmark.circle")
                                            .font(.caption)
                                            .foregroundStyle(.green)
                                            .accessibilityHidden(true)
                                        Text(bullet)
                                            .font(.body)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(28)
            .frame(maxWidth: 720, alignment: .leading)
        }
    }
}

private struct HelpTopic: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String
    let sections: [HelpSection]
}

private struct HelpSection: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let paragraphs: [String]
    let bullets: [String]

    init(_ title: String, paragraphs: [String] = [], bullets: [String] = []) {
        self.title = title
        self.paragraphs = paragraphs
        self.bullets = bullets
    }
}

private enum HelpContent {
    static let topics: [HelpTopic] = [
        HelpTopic(
            id: "quickStart",
            title: "Quick Start",
            systemImage: "play.circle",
            sections: [
                HelpSection(
                    "Compress images",
                    paragraphs: [
                        "Add images with the Add Images button or drag supported files into the Compress tab."
                    ],
                    bullets: [
                        "Choose an output folder before the first batch.",
                        "Pick quality, output format, max edge, and metadata options.",
                        "Use Reveal in Finder when a batch finishes.",
                        "Clear List (⌘N) clears the completed queue and lets you start a new batch."
                    ]
                )
            ]
        ),
        HelpTopic(
            id: "formats",
            title: "Formats and Quality",
            systemImage: "photo",
            sections: [
                HelpSection(
                    "Supported formats",
                    paragraphs: [
                        "ImagePet accepts JPG, JPEG, PNG, HEIC, and WebP input when the bundled encoder capability is available."
                    ],
                    bullets: [
                        "Original keeps each file's source format when possible.",
                        "JPEG, PNG, HEIC, and WebP are selectable output formats outside overwrite mode.",
                        "Advanced JPEG only affects JPEG output and stays hidden when unavailable."
                    ]
                ),
                HelpSection(
                    "Quality",
                    paragraphs: [
                        "High, Balanced, Small, and Custom quality affect lossy output. PNG output is lossless, so quality does not apply."
                    ]
                )
            ]
        ),
        HelpTopic(
            id: "permissions",
            title: "Save Locations and Permissions",
            systemImage: "folder.badge.gearshape",
            sections: [
                HelpSection(
                    "Sandbox access",
                    paragraphs: [
                        "ImagePet runs sandboxed. It can read files you add and write only to folders you authorize."
                    ],
                    bullets: [
                        "Designated Folder writes to the folder selected with Choose Folder.",
                        "Original Folder asks for parent-folder permission when needed.",
                        "If a saved bookmark stops working, choose the folder again."
                    ]
                )
            ]
        ),
        HelpTopic(
            id: "overwrite",
            title: "Overwrite Original Safety",
            systemImage: "exclamationmark.triangle",
            sections: [
                HelpSection(
                    "Before replacing files",
                    paragraphs: [
                        "Overwrite Original is intentionally guarded because it replaces source files."
                    ],
                    bullets: [
                        "ImagePet shows a confirmation before writing.",
                        "The output format stays Original in overwrite mode.",
                        "Canceling the confirmation stops the pending batch."
                    ]
                )
            ]
        ),
        HelpTopic(
            id: "desktopPet",
            title: "Desktop Pet",
            systemImage: "pawprint",
            sections: [
                HelpSection(
                    "Pet controls",
                    paragraphs: [
                        "The desktop pet mirrors compression status while staying separate from advanced compression settings."
                    ],
                    bullets: [
                        "Show or hide the pet from the main window, Settings, or View menu.",
                        "Click the mini pet to expand controls.",
                        "The pet remembers its visibility across app restarts.",
                        "Launch at Login starts the pet quietly when enabled."
                    ]
                ),
                HelpSection(
                    "Themes and appearance",
                    paragraphs: [
                        "Choose a pet theme in Settings → Desktop Pet."
                    ],
                    bullets: [
                        "Dog, Pufferfish, Squirrel, Hamster, Cat, Rabbit, and Clownfish themes are available.",
                        "Hover the mini pet and drag the bottom-right resize handle to adjust size within the supported range.",
                        "Each theme uses its own default animation pacing.",
                        "Enable Idle Variants lets the pet yawn or stretch during inactivity.",
                        "Enable Hover Feedback animates the pet when the pointer hovers over it.",
                        "Energy Saving Mode reduces animation frame rate for lower CPU usage."
                    ]
                )
            ]
        ),
        HelpTopic(
            id: "folderWatching",
            title: "Folder Watching",
            systemImage: "folder.badge.gearshape",
            sections: [
                HelpSection(
                    "Automated compression",
                    paragraphs: [
                        "Monitor folders and compress newly added images in the background."
                    ],
                    bullets: [
                        "Go to Settings → Folder Watching and click Add Monitored Folder.",
                        "Select a source folder to watch and a separate destination folder for output.",
                        "Source and destination folders must be different to prevent recursive compression loops.",
                        "The desktop pet will show eating animations while background files are compressed."
                    ]
                )
            ]
        ),
        HelpTopic(
            id: "notifications",
            title: "Notifications",
            systemImage: "bell.badge",
            sections: [
                HelpSection(
                    "Notification settings",
                    paragraphs: [
                        "ImagePet can notify you when compression finishes or needs attention. Configure in Settings → Notifications."
                    ],
                    bullets: [
                        "Background Completion alerts when background batches finish.",
                        "Attention Needed alerts when a folder, permission, or failed file needs review.",
                        "Foreground Completion also notifies when ImagePet is already active.",
                        "Folder Watching Success notifies when watched-folder batches complete.",
                        "Recent compression history is visible in the Notifications settings panel."
                    ]
                )
            ]
        ),
        HelpTopic(
            id: "integration",
            title: "System Integration",
            systemImage: "cpu",
            sections: [
                HelpSection(
                    "Apple Shortcuts",
                    paragraphs: [
                        "ImagePet provides a native 'Compress Images with ImagePet' shortcut action."
                    ],
                    bullets: [
                        "Open the Shortcuts app on macOS.",
                        "Search for ImagePet to locate the custom compression action.",
                        "Configure input files, quality preset, output format, maximum edge dimension, and metadata preservation."
                    ]
                ),
                HelpSection(
                    "Finder Services",
                    paragraphs: [
                        "Compress images directly from Finder without opening the main application window."
                    ],
                    bullets: [
                        "Right-click one or more images in Finder.",
                        "Choose Services (or Quick Actions) → Compress with ImagePet.",
                        "Compressed files will be saved in the same directory as the originals, named with the '_compressed' suffix."
                    ]
                )
            ]
        ),
        HelpTopic(
            id: "cli",
            title: "Command Line (CLI)",
            systemImage: "terminal",
            sections: [
                HelpSection(
                    "Install",
                    paragraphs: [
                        "You can download the pre-compiled binary from GitHub Releases, install it via Homebrew, or compile it yourself using SwiftPM."
                    ],
                    bullets: [
                        "Via Homebrew: brew install gewill/tap/imagepet",
                        "Via GitHub: Download from github.com/gewill/ImagePet/releases",
                        "Build from source: swift build -c release && cp .build/release/imagepet /usr/local/bin/"
                    ]
                ),
                HelpSection(
                    "Basic Usage",
                    paragraphs: [
                        "imagepet [options] <input-files...>",
                        "Pass one or more image files or directories. Directories are scanned recursively for supported images (JPG, PNG, HEIC, WebP)."
                    ]
                ),
                HelpSection(
                    "Options",
                    bullets: [
                        "-o <dir>        Output directory. Omit to save next to originals.",
                        "-p <preset>     Quality preset: high, balanced (default), small.",
                        "-q <1–100>      Custom quality. Cannot be combined with -p.",
                        "-f <format>     Output format: original (default), jpeg, png, heic, webp.",
                        "-m <limit>      Max edge dimension: none (default), 1024, 1920, 2048, 3840.",
                        "--keep-metadata  Preserve EXIF/GPS metadata (default strips metadata).",
                        "--overwrite      Replace original files in place. Cannot be combined with -o.",
                        "--help           Show help and exit."
                    ]
                ),
                HelpSection(
                    "Examples",
                    bullets: [
                        "imagepet photo.jpg                        Compress one file to the same folder.",
                        "imagepet -o ~/Output ~/Photos              Compress a folder to ~/Output.",
                        "imagepet -p small -f jpeg *.png            Convert PNGs to small JPEG.",
                        "imagepet -q 60 -m 1920 image.heic         Custom quality, limit to 1920 px.",
                        "imagepet --overwrite photo.jpg             Replace the original file.",
                        "imagepet --keep-metadata -o out/ *.jpg     Keep EXIF and save to out/."
                    ]
                ),
                HelpSection(
                    "Output",
                    paragraphs: [
                        "The CLI prints per-file results and a batch summary showing total files, successes, failures, original size (Ate), compressed size (Pooped), and bytes saved. The exit code is 0 on full success, 1 if any file fails."
                    ]
                ),
                HelpSection(
                    "Notes",
                    bullets: [
                        "The CLI always uses the Advanced JPEG engine for best compression.",
                        "Compressed files are named with a '_compressed' suffix unless --overwrite is used.",
                        "Max concurrency is 2 parallel jobs, matching the GUI app.",
                        "The CLI does not require App Sandbox permissions."
                    ]
                )
            ]
        ),
        HelpTopic(
            id: "shortcuts",
            title: "Keyboard Shortcuts",
            systemImage: "keyboard",
            sections: [
                HelpSection(
                    "Built-in shortcuts",
                    bullets: [
                        "Command-O adds images.",
                        "Shift-Command-O chooses the output folder.",
                        "Shift-Command-P shows or hides the desktop pet.",
                        "Command-N clears a completed queue.",
                        "Command-R retries failed jobs when failures exist.",
                        "Command-comma opens Settings.",
                        "Command-1 through Command-6 switch Settings sections: General, Folder Watching, Notifications, Desktop Pet, Keyboard Shortcuts, and Help & About."
                    ]
                ),
                HelpSection(
                    "Global shortcuts",
                    paragraphs: [
                        "Global shortcuts are unset by default. Record them in Settings → Keyboard Shortcuts if you want ImagePet to respond while another app is active."
                    ]
                )
            ]
        ),
        HelpTopic(
            id: "troubleshooting",
            title: "Troubleshooting",
            systemImage: "wrench.and.screwdriver",
            sections: [
                HelpSection(
                    "Common messages",
                    bullets: [
                        "Unsupported image format: add JPG, PNG, HEIC, or WebP files.",
                        "Permission denied: authorize the source or output folder again.",
                        "Output folder unavailable: choose a valid output folder.",
                        "Failed to decode image: the file may be corrupt.",
                        "Failed to write output file: check folder access and disk space.",
                        "Not enough disk space: free storage or choose another volume."
                    ]
                )
            ]
        ),
        HelpTopic(
            id: "privacy",
            title: "Privacy",
            systemImage: "lock.shield",
            sections: [
                HelpSection(
                    "Local processing",
                    paragraphs: [
                        "ImagePet processes images locally on your Mac. Help and shortcuts do not add network upload, telemetry, accounts, or sync."
                    ]
                )
            ]
        )
    ]
}
