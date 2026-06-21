# ImagePet App Store Connect Metadata

The canonical metadata source is now `../metadata/`.

This document is a human-readable index for App Store Connect submission work. Do not fork product copy here. Edit the JSON source files instead, then use this page to locate the right fields.

## Canonical Files

- Product identity, version, capabilities, privacy baseline, and public URLs: `../metadata/app.json`
- English public copy: `../metadata/locales/en-US.json`
- App Store Connect field mapping, app information, screenshot plan, and checklist: `../metadata/channels/mac-app-store.json`
- ASC screenshot deck: `../metadata/asc-screenshot-deck.en-US.json`
- Future website route mapping from the same source: `../metadata/channels/website.json`

## App Store Connect Field Map

| ASC field | Source |
| --- | --- |
| App name | `metadata/locales/en-US.json#/appStoreConnect/name` |
| Subtitle | `metadata/locales/en-US.json#/appStoreConnect/subtitle` |
| Promotional text | `metadata/locales/en-US.json#/appStoreConnect/promotionalText` |
| Description | `metadata/locales/en-US.json#/appStoreConnect/description` |
| What's New | `metadata/locales/en-US.json#/appStoreConnect/whatsNew` |
| Keywords | `metadata/locales/en-US.json#/appStoreConnect/keywords` |
| Primary / secondary category | `metadata/channels/mac-app-store.json#/appInformation` |
| Content rights | `metadata/channels/mac-app-store.json#/appInformation/contentRights` |
| Age rating notes | `metadata/channels/mac-app-store.json#/appInformation/ageRating` |
| Price planning note | `metadata/channels/mac-app-store.json#/appInformation/price` |
| Support URL | `metadata/app.json#/links/support` |
| Marketing URL | `metadata/app.json#/links/marketing` |
| Privacy Policy URL | `metadata/app.json#/links/privacyPolicy` |
| App Privacy declaration | `metadata/app.json#/privacy` and `metadata/channels/mac-app-store.json#/appPrivacy` |
| App Review notes | `metadata/locales/en-US.json#/appStoreConnect/reviewNotes` |
| Screenshot plan | `metadata/channels/mac-app-store.json#/screenshotPlan` |
| Screenshot deck | `metadata/asc-screenshot-deck.en-US.json` |
| Submission checklist | `metadata/channels/mac-app-store.json#/submissionChecklist` |

## Submission State

- Distribution target: Mac App Store.
- Build pipeline: Xcode Cloud is configured; branches starting with `build` trigger packaging.
- Build status: packaging path basically works; remaining launch work is App Store Connect metadata submission, screenshots, privacy, review notes, and final manual acceptance.
- Primary language: English recommended for first submission, with Chinese localization optional after the first approved version.

## Guardrails

- Keep user-facing copy factual and aligned with the current submitted build.
- Do not mention unreleased features, benchmark claims that have not been verified, cloud upload, AI compression, or unsupported formats.
- Keep unknown public URLs as `null` in `metadata/app.json` until the real support, privacy, marketing, or Mac App Store page is live.
- Re-check privacy fields before submission against the actual linked SDKs and any support/contact flow.

## Screenshot Workflow

- Manual source captures live in `screenshots/asc/source/en-US/`.
- Edit screenshot copy, output names, accents, and layout in `metadata/asc-screenshot-deck.en-US.json`.
- Generate ASC-ready PNGs with `./script/prepare_asc_screenshots.py`.
- Upload generated PNGs from `screenshots/asc/mac/en-US/`.
- Full workflow: `docs/ASC_SCREENSHOT_WORKFLOW.md`.

## Apple References

- App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Upload app previews and screenshots: https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/
- Screenshot specifications: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
- Manage app privacy: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/
- Set an app age rating: https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/
