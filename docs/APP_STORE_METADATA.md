# ImagePet App Store Connect Metadata

This document is the working source for ImagePet Mac App Store metadata. Keep user-facing copy factual and aligned with the current build. Do not mention unreleased features, benchmark claims that have not been verified, or distribution paths outside the Mac App Store.

Apple references:

- App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Upload app previews and screenshots: https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/
- Screenshot specifications: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
- Manage app privacy: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/
- Set an app age rating: https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/

## Current Submission State

- Distribution target: Mac App Store.
- Build pipeline: Xcode Cloud is configured; branches starting with `build` trigger packaging.
- Build status: packaging path basically works; remaining launch work is App Store Connect metadata, screenshots, privacy, review notes, and final manual acceptance.
- Primary language: English recommended for first submission, with Chinese localization optional after the first approved version.

## App Information

| Field | Draft |
| --- | --- |
| App name | ImagePet |
| Subtitle | Local image compression |
| Primary category | Graphics & Design |
| Secondary category | Utilities |
| Content rights | ImagePet uses original app UI/assets and third-party open source libraries listed in `docs/THIRD_PARTY_NOTICES.md`. |
| Age rating | Complete the ASC questionnaire; expected low-age rating because the app has no user-generated content, networking, accounts, ads, purchases, gambling, or unrestricted web access. |
| Price | To decide in ASC. Default planning assumption: free first release unless business model changes. |

## Product Page Copy

### Promotional Text

Compress JPG, PNG, HEIC, and WebP images locally on your Mac with a playful desktop pet and no cloud upload.

### Description

ImagePet is a local-first image compression app for macOS. Drop images into the window, choose a quality preset and output format, then let the pet shrink them on your Mac.

ImagePet supports JPG, PNG, HEIC, and WebP inputs. Outputs can keep the original format or be written as JPEG, PNG, HEIC, or WebP, depending on the selected workflow and available encoder support. For JPEG output, ImagePet can use its standard encoder or Advanced JPEG when available.

The app is designed for everyday cleanup work: batch image compression, optional max-edge resizing, metadata stripping, safe output naming, and clear per-file results. It can save to a chosen folder, save next to originals, or overwrite originals only after confirmation.

ImagePet also includes macOS-native workflow helpers:

- Finder Quick Action / Services support
- Shortcuts integration
- Folder Watching for authorized local folders
- Optional local notifications for background work
- A small desktop pet that reflects compression progress

Privacy is simple: ImagePet processes images locally and does not upload your files. It does not require an account, cloud sync, or online service to compress images.

### What's New

Initial Mac App Store release.

### Keywords

image compression,compress photos,HEIC,JPG,PNG,WebP,mac image optimizer,batch resize,local

Verify final keyword length inside App Store Connect before submission.

### Support URL

TODO: Add public support URL before submission.

Recommended minimum content:

- How to contact support or file an issue.
- Supported formats and output behavior.
- Explanation that image processing is local.
- Troubleshooting for output folder permissions, Shortcuts, Finder Quick Action, Folder Watching, and notifications.

### Marketing URL

Optional for first release. If omitted, make sure Support URL and Privacy Policy URL are complete.

### Privacy Policy URL

TODO: Add public privacy policy URL before submission.

Minimum policy statements:

- ImagePet processes selected images locally on the Mac.
- ImagePet does not upload images to a server.
- ImagePet does not require account login.
- ImagePet does not include third-party analytics, ads, or tracking in the planned first Mac App Store release.
- Folder Watching uses user-selected local folders and security-scoped access.
- Notifications are local macOS notifications.
- Support requests may include user-provided diagnostic details, but users should not send private images unless they intentionally choose to.

## App Privacy

Planned App Privacy declaration:

- Data collected: None.
- Tracking: No.
- Third-party advertising: No.
- Third-party analytics: No.

Re-check this before submission against the actual linked SDKs and any support/contact flow. If crash reporting, analytics, telemetry, or external support widgets are added later, update this section and ASC before shipping.

## App Review Notes

Draft:

ImagePet is a local image compression utility for macOS. It does not require login, account setup, network access, or backend services.

Basic review flow:

1. Launch the app.
2. Drag JPG, PNG, HEIC, or WebP images into the main window, or use Add Images.
3. Choose a quality preset and output format.
4. Choose an output folder if prompted.
5. Confirm that compressed output files are created and per-file results are shown.

Additional macOS integrations available for review:

- Finder Quick Action / Services: select supported images in Finder and invoke ImagePet.
- Shortcuts: use the ImagePet compression action from the Shortcuts app.
- Folder Watching: configure a watched input folder and output folder in Settings, then drop supported images into the watched folder.
- Notifications: enable local notifications in Settings to review completion and attention-needed alerts.

The app uses sandboxed, user-selected file access. It only reads files and folders selected by the user. Overwrite Original mode requires explicit confirmation.

## Screenshot Plan

Apple requires one to ten screenshots in `.jpeg`, `.jpg`, or `.png` format. App previews are optional.

Recommended first set:

1. Main Soft Native compression workspace with files queued or completed.
2. Drag-and-drop empty state with mascot visible.
3. Completed batch showing saved space and per-file results.
4. Settings showing output, notifications, or folder watching.
5. Desktop Pet visible beside the main app.

Capture requirements:

- Use the actual submitted build.
- Do not show private image names or personal folders.
- Do not promise unsupported formats or cloud features.
- Keep captions factual and short if adding marketing frames.
- Prefer a clean light-mode set first; dark-mode screenshots can be added only if they look polished.

## Submission Checklist

- [ ] Xcode Cloud `build*` branch produced an ASC build.
- [ ] Version number and build number match `docs/PROGRESS.md`.
- [ ] App icon is final in the submitted build.
- [ ] Product page copy pasted and proofread.
- [ ] Keywords length verified in ASC.
- [ ] Support URL is live.
- [ ] Privacy Policy URL is live.
- [ ] App Privacy answers match the actual binary and dependencies.
- [ ] Age rating questionnaire completed.
- [ ] Screenshots uploaded for macOS.
- [ ] App Review notes pasted.
- [ ] Export compliance / encryption questions answered.
- [ ] Price and availability configured.
- [ ] Final manual smoke passed from the exact ASC build.
