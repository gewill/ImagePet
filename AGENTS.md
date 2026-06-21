# AGENTS.md

Keep this file short. Prune stale guidance instead of appending forever.

## Commits

Use Conventional Commits:

```text
<type>(<scope>): <subject>
```

Examples: `feat(app): add batch compression UI`, `fix(core): preserve output filename uniqueness`.

## Product Boundary

ImagePet is a macOS 13+ SwiftUI app for local image compression:

```text
drop JPG/PNG/HEIC/WebP -> compress locally to Original/JPEG/PNG/HEIC/WebP -> show savings
```

MVP excludes AVIF, cloud, login/sync, PDF, watermarking, and AI format decisions.

## Code Boundaries

- `Sources/ImagePetCore`: compression behavior only; no SwiftUI/AppKit UI concerns.
- `Sources/ImagePet`: drag/drop, panels, bookmarks, queue UI, Finder reveal, pet state.
- `ImagePet.xcodeproj` is the committed CI source of truth. `project.yml` is optional scaffolding only.

## Sandbox

Keep app sandbox and user-selected read/write entitlements enabled. Read inputs and write outputs only through user-granted access; restore output folders with security-scoped bookmarks and pair access with `defer`.

## Compression Rules

Preserve unless explicitly scoped otherwise:

- Input `JPG/JPEG/PNG/HEIC/WebP`; output `Original/JPEG/PNG/HEIC/WebP` when encoder capabilities allow it.
- `maxConcurrentJobs = 2`.
- Wrap decode/encode work in `autoreleasepool`.
- Output standard sRGB where applicable and preserve basic orientation.
- Never overwrite existing output files in non-overwrite modes.
- Overwrite Original mode must require explicit confirmation and preserve the original format.
- One file failure must not abort the batch.
- User-facing compression errors stay short.

## Build/Test

```bash
xcodebuild -project ImagePet.xcodeproj -scheme ImagePet -configuration Debug -derivedDataPath DerivedData -destination 'platform=macOS' test
swift test
./script/build_and_run.sh --verify
```

Do not commit `xcuserdata`, `.xcuserstate`, `.build`, `DerivedData`, `TestImages`, downloaded fixtures, or generated compressed outputs.
