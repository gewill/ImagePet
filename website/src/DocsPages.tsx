import React from "react";

interface DocsPageProps {
  onBack: () => void;
  activePetIndex: number;
  setActivePetIndex: React.Dispatch<React.SetStateAction<number>>;
  petThemes: Array<{ name: string; description: string; image: string }>;
}

interface DocSection {
  id: string;
  group: string;
  title: string;
  content: React.ReactNode;
}

const docSections: DocSection[] = [
  {
    id: "quick-start",
    group: "Getting Started",
    title: "Quick Start",
    content: (
      <>
        <div className="docs-intro-box">
          <p>Compress images with ImagePet in four steps.</p>
        </div>
        <ol>
          <li>
            Add images with the <strong>Add Images</strong> button or drag supported files into
            the Compress tab.
          </li>
          <li>Choose an output folder before the first batch.</li>
          <li>Pick quality, output format, max edge, and metadata options.</li>
          <li>
            Use <strong>Reveal in Finder</strong> when a batch finishes.
            <br />
            <strong>Clear List</strong> (⌘N) clears the completed queue and lets you start a
            new batch.
          </li>
        </ol>
      </>
    )
  },
  {
    id: "formats-and-quality",
    group: "Guides",
    title: "Formats and Quality",
    content: (
      <>
        <h3>Supported formats</h3>
        <p>
          ImagePet accepts JPG, JPEG, PNG, HEIC, and WebP input when the bundled encoder
          capability is available.
        </p>
        <div className="docs-table-wrap">
          <table className="docs-table">
            <thead>
              <tr>
                <th>Direction</th>
                <th>Formats</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td>Input</td>
                <td>JPG, JPEG, PNG, HEIC, WebP</td>
              </tr>
              <tr>
                <td>Output</td>
                <td>Original, JPEG, PNG, HEIC, WebP</td>
              </tr>
            </tbody>
          </table>
        </div>
        <ul>
          <li>
            <strong>Original</strong> keeps each file's source format when possible.
          </li>
          <li>
            <strong>JPEG, PNG, HEIC, and WebP</strong> are selectable output formats outside
            overwrite mode.
          </li>
          <li>
            <strong>Advanced JPEG</strong> only affects JPEG output and stays hidden when
            unavailable.
          </li>
        </ul>

        <h3>Quality</h3>
        <p>
          High, Balanced, Small, and Custom quality affect lossy output. PNG output is lossless,
          so quality does not apply.
        </p>
      </>
    )
  },
  {
    id: "save-locations",
    group: "Guides",
    title: "Save Locations and Permissions",
    content: (
      <>
        <div className="docs-intro-box">
          <p>
            ImagePet runs sandboxed. It can read files you add and write only to folders you
            authorize.
          </p>
        </div>
        <ul>
          <li>
            <strong>Designated Folder</strong> writes to the folder selected with Choose Folder.
          </li>
          <li>
            <strong>Original Folder</strong> asks for parent-folder permission when needed.
          </li>
          <li>
            If a saved bookmark stops working, choose the folder again.
          </li>
        </ul>
      </>
    )
  },
  {
    id: "overwrite",
    group: "Guides",
    title: "Overwrite Original Safety",
    content: (
      <>
        <div className="docs-intro-box">
          <p>
            Overwrite Original is intentionally guarded because it replaces source files.
          </p>
        </div>
        <ul>
          <li>ImagePet shows a confirmation before writing.</li>
          <li>The output format stays Original in overwrite mode.</li>
          <li>Canceling the confirmation stops the pending batch.</li>
        </ul>
      </>
    )
  },
  {
    id: "desktop-pet",
    group: "Guides",
    title: "Desktop Pet",
    content: (
      <>
        <h3>Pet controls</h3>
        <p>
          The desktop pet mirrors compression status while staying separate from advanced
          compression settings.
        </p>
        <ul>
          <li>
            Show or hide the pet from the main window, Settings, or View menu.
          </li>
          <li>Click the mini pet to expand controls.</li>
          <li>The pet remembers its visibility across app restarts.</li>
          <li>
            Launch at Login starts the pet quietly when enabled.
          </li>
        </ul>

        <h3>Themes and appearance</h3>
        <p>Choose a pet theme in Settings → Desktop Pet.</p>

        <div className="docs-pet-grid">
          <div className="docs-pet-card">
            <img src="/pets/dog.png" alt="Dog pet theme" />
            <strong>Dog</strong>
          </div>
          <div className="docs-pet-card">
            <img src="/pets/pufferfish.png" alt="Pufferfish pet theme" />
            <strong>Pufferfish</strong>
          </div>
          <div className="docs-pet-card">
            <img src="/pets/squirrel.png" alt="Squirrel pet theme" />
            <strong>Squirrel</strong>
          </div>
          <div className="docs-pet-card">
            <img src="/pets/hamster.png" alt="Hamster pet theme" />
            <strong>Hamster</strong>
          </div>
          <div className="docs-pet-card">
            <img src="/pets/cat.png" alt="Cat pet theme" />
            <strong>Cat</strong>
          </div>
          <div className="docs-pet-card">
            <img src="/pets/rabbit.png" alt="Rabbit pet theme" />
            <strong>Rabbit</strong>
          </div>
        </div>

        <ul>
          <li>
            Six themes are available: Dog, Pufferfish, Squirrel, Hamster, Cat, and Rabbit.
          </li>
          <li>
            Hover the mini pet and drag the bottom-right resize handle to adjust size within
            the supported range.
          </li>
          <li>Each theme uses its own default animation pacing.</li>
          <li>
            Enable <strong>Idle Variants</strong> lets the pet yawn or stretch during inactivity.
          </li>
          <li>
            Enable <strong>Hover Feedback</strong> animates the pet when the pointer hovers
            over it.
          </li>
          <li>
            <strong>Energy Saving Mode</strong> reduces animation frame rate for lower CPU usage.
          </li>
        </ul>
      </>
    )
  },
  {
    id: "folder-watching",
    group: "Guides",
    title: "Folder Watching",
    content: (
      <>
        <div className="docs-intro-box">
          <p>Monitor folders and compress newly added images in the background.</p>
        </div>
        <ul>
          <li>
            Go to <strong>Settings → Folder Watching</strong> and click{" "}
            <strong>Add Monitored Folder</strong>.
          </li>
          <li>
            Select a source folder to watch and a separate destination folder for output.
          </li>
          <li>
            Source and destination folders must be different to prevent recursive compression
            loops.
          </li>
          <li>
            The desktop pet will show eating animations while background files are compressed.
          </li>
        </ul>
      </>
    )
  },
  {
    id: "notifications",
    group: "Guides",
    title: "Notifications",
    content: (
      <>
        <p>
          ImagePet can notify you when compression finishes or needs attention. Configure in
          Settings → Notifications.
        </p>
        <ul>
          <li>
            <strong>Background Completion</strong> alerts when background batches finish.
          </li>
          <li>
            <strong>Attention Needed</strong> alerts when a folder, permission, or failed file
            needs review.
          </li>
          <li>
            <strong>Foreground Completion</strong> also notifies when ImagePet is already active.
          </li>
          <li>
            <strong>Folder Watching Success</strong> notifies when watched-folder batches
            complete.
          </li>
          <li>
            Recent compression history is visible in the Notifications settings panel.
          </li>
        </ul>
      </>
    )
  },
  {
    id: "system-integration",
    group: "Guides",
    title: "System Integration",
    content: (
      <>
        <h3>Apple Shortcuts</h3>
        <p>
          ImagePet provides a native "Compress Images with ImagePet" shortcut action.
        </p>
        <ul>
          <li>Open the Shortcuts app on macOS.</li>
          <li>Search for ImagePet to locate the custom compression action.</li>
          <li>
            Configure input files, quality preset, output format, maximum edge dimension, and
            metadata preservation.
          </li>
        </ul>

        <h3>Finder Services</h3>
        <p>
          Compress images directly from Finder without opening the main application window.
        </p>
        <ul>
          <li>Right-click one or more images in Finder.</li>
          <li>
            Choose <strong>Services</strong> (or <strong>Quick Actions</strong>) →{" "}
            <strong>Compress with ImagePet</strong>.
          </li>
          <li>
            Compressed files will be saved in the same directory as the originals, named with
            the "_compressed" suffix.
          </li>
        </ul>
      </>
    )
  },
  {
    id: "cli",
    group: "Reference",
    title: "Command Line (CLI)",
    content: (
      <>
        <h3>Install</h3>
        <p>
          You can download the pre-compiled binary from GitHub Releases, install it via Homebrew,
          or compile it yourself using SwiftPM.
        </p>
        <ul>
          <li>
            <strong>Via Homebrew:</strong>{" "}
            <code>brew install gewill/tap/imagepet</code>
          </li>
          <li>
            <strong>Via GitHub:</strong> Download from{" "}
            <a href="https://github.com/gewill/ImagePet/releases">
              github.com/gewill/ImagePet/releases
            </a>
          </li>
          <li>
            <strong>Build from source:</strong>{" "}
            <code>swift build -c release && cp .build/release/imagepet /usr/local/bin/</code>
          </li>
        </ul>

        <h3>Basic Usage</h3>
        <p>
          <code>imagepet [options] &lt;input-files...&gt;</code>
        </p>
        <p>
          Pass one or more image files or directories. Directories are scanned recursively for
          supported images (JPG, PNG, HEIC, WebP).
        </p>

        <h3>Options</h3>
        <div className="docs-table-wrap">
          <table className="docs-table">
            <thead>
              <tr>
                <th>Flag</th>
                <th>Description</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td><code>-o &lt;dir&gt;</code></td>
                <td>Output directory. Omit to save next to originals.</td>
              </tr>
              <tr>
                <td><code>-p &lt;preset&gt;</code></td>
                <td>Quality preset: high, balanced (default), small.</td>
              </tr>
              <tr>
                <td><code>-q &lt;1–100&gt;</code></td>
                <td>Custom quality. Cannot be combined with -p.</td>
              </tr>
              <tr>
                <td><code>-f &lt;format&gt;</code></td>
                <td>Output format: original (default), jpeg, png, heic, webp.</td>
              </tr>
              <tr>
                <td><code>-m &lt;limit&gt;</code></td>
                <td>
                  Max edge dimension: none (default), 1024, 1920, 2048, 3840.
                </td>
              </tr>
              <tr>
                <td><code>--keep-metadata</code></td>
                <td>Preserve EXIF/GPS metadata (default strips metadata).</td>
              </tr>
              <tr>
                <td><code>--overwrite</code></td>
                <td>
                  Replace original files in place. Cannot be combined with -o.
                </td>
              </tr>
              <tr>
                <td><code>--help</code></td>
                <td>Show help and exit.</td>
              </tr>
            </tbody>
          </table>
        </div>

        <h3>Examples</h3>
        <div className="docs-table-wrap">
          <table className="docs-table">
            <thead>
              <tr>
                <th>Command</th>
                <th>Description</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td><code>imagepet photo.jpg</code></td>
                <td>Compress one file to the same folder.</td>
              </tr>
              <tr>
                <td><code>imagepet -o ~/Output ~/Photos</code></td>
                <td>Compress a folder to ~/Output.</td>
              </tr>
              <tr>
                <td><code>imagepet -p small -f jpeg *.png</code></td>
                <td>Convert PNGs to small JPEG.</td>
              </tr>
              <tr>
                <td><code>imagepet -q 60 -m 1920 image.heic</code></td>
                <td>Custom quality, limit to 1920 px.</td>
              </tr>
              <tr>
                <td><code>imagepet --overwrite photo.jpg</code></td>
                <td>Replace the original file.</td>
              </tr>
              <tr>
                <td><code>imagepet --keep-metadata -o out/ *.jpg</code></td>
                <td>Keep EXIF and save to out/.</td>
              </tr>
            </tbody>
          </table>
        </div>

        <h3>Output</h3>
        <p>
          The CLI prints per-file results and a batch summary showing total files, successes,
          failures, original size (Ate), compressed size (Pooped), and bytes saved. The exit
          code is 0 on full success, 1 if any file fails.
        </p>

        <h3>Notes</h3>
        <ul>
          <li>
            The CLI always uses the Advanced JPEG engine for best compression.
          </li>
          <li>
            Compressed files are named with a "_compressed" suffix unless --overwrite is used.
          </li>
          <li>Max concurrency is 2 parallel jobs, matching the GUI app.</li>
          <li>The CLI does not require App Sandbox permissions.</li>
        </ul>
      </>
    )
  },
  {
    id: "keyboard-shortcuts",
    group: "Reference",
    title: "Keyboard Shortcuts",
    content: (
      <>
        <h3>Built-in shortcuts</h3>
        <div className="docs-table-wrap">
          <table className="docs-table">
            <thead>
              <tr>
                <th>Shortcut</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td><kbd>⌘O</kbd></td>
                <td>Add images</td>
              </tr>
              <tr>
                <td><kbd>⇧⌘O</kbd></td>
                <td>Choose output folder</td>
              </tr>
              <tr>
                <td><kbd>⇧⌘P</kbd></td>
                <td>Show or hide the desktop pet</td>
              </tr>
              <tr>
                <td><kbd>⌘N</kbd></td>
                <td>Clear a completed queue</td>
              </tr>
              <tr>
                <td><kbd>⌘R</kbd></td>
                <td>Retry failed jobs when failures exist</td>
              </tr>
              <tr>
                <td><kbd>⌘,</kbd></td>
                <td>Open Settings</td>
              </tr>
              <tr>
                <td><kbd>⌘1</kbd> – <kbd>⌘6</kbd></td>
                <td>
                  Switch Settings sections: General, Folder Watching, Notifications, Desktop Pet,
                  Keyboard Shortcuts, Help &amp; About
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <h3>Global shortcuts</h3>
        <p>
          Global shortcuts are unset by default. Record them in Settings → Keyboard Shortcuts
          if you want ImagePet to respond while another app is active.
        </p>
      </>
    )
  },
  {
    id: "troubleshooting",
    group: "FAQ",
    title: "Troubleshooting",
    content: (
      <>
        <div className="docs-intro-box">
          <p>Common messages and what they mean.</p>
        </div>
        <dl className="docs-dl">
          <dt>Unsupported image format</dt>
          <dd>Add JPG, PNG, HEIC, or WebP files.</dd>
          <dt>Permission denied</dt>
          <dd>Authorize the source or output folder again.</dd>
          <dt>Output folder unavailable</dt>
          <dd>Choose a valid output folder.</dd>
          <dt>Failed to decode image</dt>
          <dd>The file may be corrupt.</dd>
          <dt>Failed to write output file</dt>
          <dd>Check folder access and disk space.</dd>
          <dt>Not enough disk space</dt>
          <dd>Free storage or choose another volume.</dd>
        </dl>
      </>
    )
  },
  {
    id: "privacy",
    group: "FAQ",
    title: "Privacy",
    content: (
      <>
        <div className="docs-intro-box">
          <p>
            ImagePet processes images locally on your Mac. Help and shortcuts do not add network
            upload, telemetry, accounts, or sync.
          </p>
        </div>
      </>
    )
  }
];

function Sidebar({
  sections,
  activeId,
  onSelect
}: {
  sections: typeof docSections;
  activeId: string | null;
  onSelect: (id: string) => void;
}) {
  const groups = new Map<string, typeof docSections>();
  for (const s of sections) {
    const g = groups.get(s.group) ?? [];
    g.push(s);
    groups.set(s.group, g);
  }

  return (
    <aside className="docs-sidebar">
      <div className="docs-sidebar-card">
        <nav className="docs-sidebar-nav">
          {Array.from(groups.entries()).map(([group, items]) => (
            <div key={group} className="docs-sidebar-group">
              <h3>{group}</h3>
              {items.map((item) => (
                <button
                  key={item.id}
                  type="button"
                  className={`docs-sidebar-link${activeId === item.id ? " active" : ""}`}
                  onClick={() => onSelect(item.id)}
                >
                  {item.title}
                </button>
              ))}
            </div>
          ))}
        </nav>
      </div>
    </aside>
  );
}

export function DocsPage({ onBack, activePetIndex, setActivePetIndex, petThemes }: DocsPageProps) {
  const [activeSection, setActiveSection] = React.useState<string | null>(null);

  const activeData = activeSection
    ? docSections.find((s) => s.id === activeSection)
    : null;

  return (
    <div className="docs-shell">
      <button className="docs-back-btn" onClick={onBack}>
        ← Back to Home
      </button>

      <div className="docs-layout">
        <Sidebar
          sections={docSections}
          activeId={activeSection}
          onSelect={(id) => setActiveSection(id)}
        />

        <main className="docs-content">
          {activeData ? (
            <article className="docs-article-card docs-prose">
              <h1>{activeData.title}</h1>
              {activeData.content}
            </article>
          ) : (
            <article className="docs-article-card docs-prose">
              <h1>Documentation</h1>
              <div className="docs-intro-box">
                <p>
                  Learn how to install, configure, and use ImagePet for local image compression
                  on macOS.
                </p>
              </div>
              <p className="docs-index-hint">
                Select a topic from the sidebar to get started.
              </p>
            </article>
          )}
        </main>
      </div>

      <div
        className="floating-desktop-pet"
        onClick={() => setActivePetIndex((prev) => (prev + 1) % petThemes.length)}
        title="Click to switch theme"
      >
        <div className="floating-pet-tooltip">
          <strong>Desktop Pet: {petThemes[activePetIndex].name}</strong>
          <span>{petThemes[activePetIndex].description}</span>
          <span className="tooltip-hint">Click to switch theme</span>
        </div>
        <div className="floating-pet-card">
          <img
            src={petThemes[activePetIndex].image}
            alt={`ImagePet desktop pet ${petThemes[activePetIndex].name} theme`}
            key={activePetIndex}
            className="floating-pet-img"
          />
        </div>
      </div>
    </div>
  );
}
