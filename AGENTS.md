# AGENTS.md

## Git Commit Message Conventions

Follow Conventional Commits. Every commit message uses this structure:

```text
<type>(<scope>): <subject>

[optional body]

[optional footer]
```

Examples:

```text
feat(app): add batch compression UI
fix(core): preserve output filename uniqueness
docs(readme): clarify CLI architecture
test(core): cover png to jpg conversion
```

## Project Overview

ImagePet is a macOS 13+ SwiftUI app for local image compression. The MVP flow is:

```text
drop JPG/PNG/HEIC images -> compress locally to JPG -> show per-file and total savings
```

The product boundary is deliberately narrow:

- Input: `JPG / JPEG / PNG / HEIC`
- Output: `JPG` only
- No WebP, AVIF, cloud upload, login, sync, folder watching, extensions, PDF, watermarking, or AI format decisions in the MVP
- App Sandbox must remain enabled

## Source Layout

- `ImagePet.xcodeproj`: committed Xcode project; use this for normal development and CI.
- `Generated/Info.plist`: committed app Info.plist used by the Xcode project.
- `project.yml`: optional XcodeGen helper for AI/scaffolding work; do not make CI depend on running XcodeGen.
- `Package.swift`: retained for fast SwiftPM testing and keeping `ImagePetCore` easy to validate.
- `Sources/ImagePetCore`: reusable compression core with no SwiftUI/AppKit UI dependency.
- `Sources/ImagePet`: macOS SwiftUI GUI layer.
- `Entitlements/ImagePet.entitlements`: sandbox and user-selected file read/write permissions.
- `Tests/ImagePetTests`: unit and local fixture tests.

## Architecture Boundaries

`ImagePetCore` owns compression behavior:

- `CompressionPreset`
- `ImageJob` / `JobStatus`
- `CompressionResult`
- `ImageCompressing`
- `ImageCompressor`
- `OutputNameAllocator`
- `CompressionError`
- `SupportedImageFormat`

Keep GUI-only concerns out of `ImagePetCore`: drag and drop, `NSOpenPanel`, security-scoped bookmarks, Finder reveal, pet state, and SwiftUI presentation state belong in `Sources/ImagePet`.

`Sources/ImagePet` owns app interaction:

- Drop handling
- Output folder selection
- Bookmark persistence and restoration
- Queueing and max 2 concurrent jobs
- Per-job UI updates
- Pet state machine
- `Reveal in Finder`, `Retry Failed`, and `Clear List`

## Sandbox And File Access

Keep these entitlements:

```text
com.apple.security.app-sandbox = true
com.apple.security.files.user-selected.read-write = true
```

For sandbox-sensitive file access:

- Input files should come from user action, currently drag/drop.
- Output directory should come from `NSOpenPanel`.
- Restore output directory through a security-scoped bookmark.
- Call `startAccessingSecurityScopedResource()` before reading input files or writing to the output directory, and stop access with `defer`.
- Never default-write to `~/Pictures` or any other folder without explicit user authorization.

## Build And Test

Preferred app build/test path:

```bash
xcodebuild -project ImagePet.xcodeproj -scheme ImagePet -configuration Debug -derivedDataPath DerivedData -destination 'platform=macOS' test
```

Fast SwiftPM validation:

```bash
swift test
```

Local run path:

```bash
./script/build_and_run.sh
./script/build_and_run.sh --verify
```

`TestImages/` is ignored and may contain local Apple Newsroom fixtures. Do not commit downloaded test images or generated compressed output.

## Xcode Project Policy

`ImagePet.xcodeproj` is committed and is the CI source of truth. Do not require CI or normal builds to run:

```bash
xcodegen generate
```

If you use XcodeGen to make broad project changes:

1. Run `xcodegen generate` locally.
2. Review the generated `.xcodeproj` diff carefully.
3. Commit both `project.yml` and the generated `.xcodeproj` changes.

Do not commit `xcuserdata`, `.xcuserstate`, `.build`, `DerivedData`, or `TestImages`.

## Compression Constraints

Preserve MVP compression constraints unless the product scope is explicitly changed:

- `maxConcurrentJobs = 2`
- Wrap image decode/encode work in `autoreleasepool`
- Output standard sRGB JPG
- Preserve basic orientation information
- Never overwrite an existing output file
- Failure of one file must not abort the full batch
- Use short user-facing error messages:
  - `Unsupported image format`
  - `Permission denied`
  - `Output folder unavailable`
  - `Failed to decode image`
  - `Failed to write output file`
  - `Not enough disk space`
  - `Unknown error`

## CLI Direction

A future command-line tool should depend on `ImagePetCore`, not the GUI target.

Good future target shape:

- Xcode target: `ImagePetCLI`
- SwiftPM executable product: `imagepet`
- Dependency: `ImagePetCore`
- Optional argument parser: Swift Argument Parser

The CLI should not reuse `ImagePetStore`, `ContentView`, `OutputFolderPanel`, or `OutputDirectoryBookmarkStore`.
