# ImagePet Release Candidate Checklist

This document contains the manual acceptance criteria for validating a Release Candidate (RC) of ImagePet. Execute these tests sequentially to verify sandboxing, notifications, background integrations, and core workflows.

---

## 1. Clean Startup & Permissions

- **Test Case 1.1: First-Time Launch**
  1. Delete `~/Library/Containers/org.gewill.ImagePet` (if exists) or reset defaults:
     ```bash
     defaults delete org.gewill.ImagePet
     ```
  2. Launch the app.
  3. Verify the app starts in **Mini** view mode (Pet only), and does **NOT** present any notification permission dialogs automatically.
  4. Verify the settings screen can be opened and show all sections.

- **Test Case 1.2: Notification Authorization Request**
  1. Open Settings -> **Notifications**.
  2. Under System Permission, click **Enable Notifications**.
  3. Verify the system prompt appears. Choose **Allow**.
  4. Verify the permission status in settings updates to **Enabled**.

- **Test Case 1.3: Revoking Permission Recovery**
  1. Go to System Settings -> Notifications -> ImagePet. Turn off notifications.
  2. Bring ImagePet to the foreground and open Settings -> Notifications.
  3. Verify the System Permission status updates to **Denied**.
  4. Verify that the **Open System Settings** button is displayed. Click it and verify it opens macOS System Settings to the Notifications section.

---

## 2. Notification Debug Tests (Debug Build Only)

1. Open Settings -> **Notifications**.
2. Scroll to the **Notification Debug** section.
3. Click **Test Success**:
   - Verify a notification banner appears with the title: `"ImagePet finished compressing 3 images"` and details about saved bytes.
   - Click the notification banner itself; verify it opens/activates the main window.
4. Click **Test Failure**:
   - Verify a notification banner appears with the title: `"ImagePet compressed 2 of 3 images"` and body `"1 need attention..."`.
   - Click the notification action **Review Failed**; verify the app opens, navigates to the **Compress** tab, and expands the pet to **Full** view mode.
5. Click **Test Permission**:
   - Verify a notification banner appears with the title: `"ImagePet needs attention"` and body `"Permission denied"`.
6. Click **Test Folder Watch**:
   - Verify a notification banner appears with the title: `"Folder Watching needs attention"`.

---

## 3. Folder Watching Integration & Policies

- **Test Case 3.1: Successful Folder Watch (Default Mode)**
  1. In Settings -> **Notifications**, ensure **Folder Watching Success** is **OFF** (default).
  2. Configure a Folder Watching folder (e.g., watch `~/Desktop/WatchInput` to output `~/Desktop/WatchOutput`).
  3. Drop 3 valid images into `WatchInput` with ImagePet in the background.
  4. Verify images are compressed to `WatchOutput` but **NO** notification banner is displayed (silent success).
  5. Open ImagePet Settings -> Notifications. Verify the batch appears in the **Recent Compression History** list as a success.

- **Test Case 3.2: Successful Folder Watch (Notification Enabled)**
  1. In Settings -> **Notifications**, turn **Folder Watching Success** **ON**.
  2. Drop 3 valid images into `WatchInput` with ImagePet in the background.
  3. Verify a notification banner appears summarizing the compression.

- **Test Case 3.3: Folder Watch 2-Second Coalescing**
  1. Drop 3 images into `WatchInput`.
  2. 0.5 seconds later, drop 2 more images into `WatchInput`.
  3. Verify that only **ONE** combined notification is delivered (representing 5 images) rather than two separate alerts.

- **Test Case 3.4: Folder Watch Failure Notification**
  1. Drop a corrupt or unsupported file format (e.g., a `.txt` file renamed to `.jpg`) into `WatchInput`.
  2. Verify that a notification banner is delivered indicating failure/attention needed (even if success notification is toggled off).

---

## 4. Shortcuts Integration

- **Test Case 4.1: Successful Shortcut Run (Silent)**
  1. Open the macOS **Shortcuts** app and create a shortcut using the **Compress Images with ImagePet** action.
  2. Run the shortcut with 3 valid images.
  3. Verify that the compressed images are returned successfully in the Shortcuts workflow and **NO** ImagePet notification banner is posted.

- **Test Case 4.2: Partial Failure Shortcut Run (Alert)**
  1. Run the shortcut passing 2 valid images and 1 corrupt file.
  2. Verify that an ImagePet notification banner appears indicating that some files need attention.

---

## 5. Sandboxing & Bookmark Restoration

- **Test Case 5.1: App Termination & Restoring Access**
  1. Configure folder watching and designate a custom output directory.
  2. Force quit the app.
  3. Relaunch the app.
  4. Verify that the custom output directory bookmark restores successfully (no warnings).
  5. Drop images into the watched folder and verify they compress successfully, confirming security-scoped bookmark restoration works perfectly.

---

## 6. Mac App Store Submission Metadata

- **Test Case 6.1: Xcode Cloud Build**
  1. Push a branch whose name starts with `build`.
  2. Verify Xcode Cloud starts the packaging workflow.
  3. Verify the produced build appears in App Store Connect and can be selected for submission or TestFlight review.
  4. Record branch, commit, version, build number, and Xcode Cloud result.

- **Test Case 6.2: App Store Connect Metadata**
  1. Open `metadata/README.md`, `metadata/app.json`, `metadata/locales/en-US.json`, and `metadata/channels/mac-app-store.json`.
  2. Verify App name, subtitle, description, promotional text, keywords, category, age rating, support URL, privacy policy URL, and review notes are complete in ASC.
  3. Verify metadata does not mention unreleased features, cloud upload, AI compression, unsupported formats, or Developer ID distribution.
  4. Verify App Review notes explain how to test the app without login or backend access.

- **Test Case 6.3: Privacy and Compliance**
  1. Verify ASC App Privacy answers match the actual binary and dependencies.
  2. Verify privacy policy URL is live and states that image processing is local.
  3. Verify export compliance / encryption questions are answered.
  4. Verify age rating questionnaire is completed.

- **Test Case 6.4: Screenshots**
  1. Upload one to ten macOS screenshots in `.jpeg`, `.jpg`, or `.png` format.
  2. Verify screenshots are captured from the submitted build.
  3. Verify screenshots do not expose private filenames, local paths, user data, or unsupported feature claims.
  4. Verify first screenshot clearly shows the main compression workflow.
