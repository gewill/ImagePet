# Contributing to ImagePet

First off, thank you for considering contributing to ImagePet! It's people like you that make the open-source community such an amazing place to learn, inspire, and create.

This document outlines the guidelines and best practices for contributing to the repository. Please take a moment to review it before getting started.

---

## 1. Development Prerequisites

To develop, build, and test ImagePet locally, you will need:
- **macOS 13.0 or later**
- **Xcode 14.0 or later** (with command line tools installed)
- **Swift 5.8 or later**
- (Optional) **XcodeGen** if you want to regenerate the project structure, though the committed `.xcodeproj` is the source of truth.

---

## 2. Project Architecture & Boundaries

ImagePet has strict code boundaries. Please respect these when adding new features or fixing bugs:

- **`Sources/ImagePetCore` (Pure Core)**:
  - Contains all image compression, decoding, encoding, metadata stripping, and sizing logic.
  - **No SwiftUI, AppKit, or UI dependencies allowed.** It must remain a pure, cross-platform Swift library (e.g., runnable on Linux command line in the future).
- **`Sources/ImagePet` (SwiftUI GUI App)**:
  - Handles the desktop pet state machine, drag-and-drop actions, system preferences, security-scoped bookmarks, local notifications, and menu bar item.
- **`Sources/ImagePetCLI` (Command Line Tool)**:
  - The standalone command-line executable wrapper around `ImagePetCore`.

---

## 3. Local Setup & Building

You can build and run the application in two ways:

### Code Signing & Developer Team ID
The project is configured by default with the development team ID `RLK76T8Y89` in `project.yml` and `ImagePet.xcodeproj`. 
If you encounter code signing errors while building:
1. Open the project in Xcode.
2. Select the `ImagePet` project in the project navigator, then go to the **Signing & Capabilities** tab of the `ImagePet` target.
3. Change the **Team** setting to your own Apple Developer Team (or select a personal development team).
4. (Optional) If you are using XcodeGen to regenerate the project, you can update the `DEVELOPMENT_TEAM` value in `project.yml` before running `xcodegen generate`.

### Using Xcode
Open the committed [ImagePet.xcodeproj](file:///Users/rxwill/git/MyApps/ImagePet/ImagePet.xcodeproj) directly in Xcode, select the `ImagePet` scheme, and hit **Product -> Run** (⌘R).

### Using the CLI verification script
You can verify the build, signing, sandbox configurations, and test run using the local script:
```bash
./script/build_and_run.sh --verify
```

---

## 4. Testing Guidelines

We value testing highly. Ensure that all tests pass before submitting a Pull Request:
- **Unit Tests**: Run `swift test` or run tests inside Xcode (⌘U).
- **UI Tests**: UI tests are under `Tests/ImagePetUITests` to verify navigation, settings, and main tab flows.
- **Fixture Tests**: If you have local test images, place them in `TestImages/Apple`. If not present, the `AppleFixtureCompressionTests` will automatically skip.

---

## 5. Coding Standards & Git Style

To keep the repository clean and maintainable, please follow these guidelines:

### Sandbox Entitlements
- App Sandbox must remain enabled. Do not disable or alter entitlements in `Entitlements/ImagePet.entitlements` unless discussed in an issue first.
- Read/write access to output files must be performed under security-scoped bookmarks and paired with `defer { url.stopAccessingSecurityScopedResource() }`.

### Concurrency Rules
- Do not exceed the maximum concurrency limit (`maxConcurrentJobs = 2`) for compression tasks to protect system resources.
- Wrap decode and encode routines in `autoreleasepool { ... }` blocks to prevent memory spikes during batch operations.

### Commit Messages
We enforce **Conventional Commits**. Your commit message subject should read:
```text
<type>(<scope>): <subject>
```
**Examples:**
- `feat(app): add batch compression UI`
- `fix(core): preserve output filename uniqueness`
- `docs(repo): add contributing guidelines`

---

## 6. How to Submit a Pull Request (PR)

1. Fork the repository and create your branch from `main` (or the current release candidate branch, e.g. `rc-v0.15`).
2. Make your changes, ensuring code style and boundaries are respected.
3. Add tests verifying your new feature or fix.
4. Clean up any untracked local build assets (e.g., `DerivedData`, `.build`, `.xcuserstate`).
5. Verify tests run successfully.
6. Push to your fork and submit a PR with a clear description of the problem solved.

Thank you again for contributing to ImagePet!
