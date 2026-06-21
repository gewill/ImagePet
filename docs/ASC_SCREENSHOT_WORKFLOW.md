# ASC Screenshot Workflow

ImagePet App Store screenshots are generated from manually captured app screenshots. The workflow is intentionally local and simple: provide source captures, edit a deck JSON for copy/layout, then render ASC-ready PNG files.

This workflow does not run UI tests, does not launch the app, and does not create App Preview videos.

## Paths

| Purpose | Path |
| --- | --- |
| Manual source screenshots | `screenshots/asc/source/en-US/` |
| Screenshot deck config | `metadata/asc-screenshot-deck.en-US.json` |
| Render script | `script/prepare_asc_screenshots.py` |
| ASC-ready PNG output | `screenshots/asc/mac/en-US/` |

## Capture Inputs

Put manually captured screenshots in `screenshots/asc/source/en-US/`.

Accepted source formats:

- `.png`
- `.jpg`
- `.jpeg`
- `.webp`

The current English deck expects these source files:

```text
01-empty-state.webp
02-drop-to-compress.webp
03-compression.webp
04-settings.webp
```

Source captures may be larger than ASC output. The script scales them into a `1440x900` marketing canvas. The background is generated from each source screenshot itself: the source is cover-cropped, blurred, and tinted so the wrapper matches the screenshot wallpaper.

## Edit Copy And Layout

Edit `metadata/asc-screenshot-deck.en-US.json`.

Each slide supports:

- `sources`: source screenshot filename list.
- `output`: generated PNG filename.
- `eyebrow`: small brand label, usually `ImagePet`.
- `headline`: main App Store screenshot headline.
- `subhead`: one short supporting sentence.
- `accent`: `#RRGGBB` color for the left rail and eyebrow.
- `layout`: `single`, `duo-main`, or `duo-pet`.
- `background`: optional per-slide override for `tint`, `tintAlpha`, or `blurRadius`.

Copy rules:

- Keep one idea per screenshot.
- Keep headlines short enough to read in App Store thumbnails.
- Do not claim unsupported formats, cloud upload, AI compression, or unreleased features.
- Do not expose private filenames, local paths, or personal data.

## Render

Run:

```bash
./script/prepare_asc_screenshots.py
```

Default behavior:

- Reads `metadata/asc-screenshot-deck.en-US.json`.
- Reads source captures from `screenshots/asc/source/en-US/`.
- Recreates `screenshots/asc/mac/en-US/`.
- Writes one `.png` per slide.
- Validates every output is `1440x900`.

Locale and path overrides are available:

```bash
./script/prepare_asc_screenshots.py --locale en-US
./script/prepare_asc_screenshots.py --source-dir /path/to/source --output-dir /path/to/output --deck /path/to/deck.json
```

## Verify Before Upload

Before uploading to App Store Connect:

1. Open every PNG in `screenshots/asc/mac/en-US/`.
2. Verify the UI is from the submitted build.
3. Verify the first screenshot clearly shows the compression workflow.
4. Verify desktop pet visibility where it is part of the message.
5. Verify no screenshot exposes private filenames, local paths, personal data, or unsupported feature claims.
6. Verify every upload file is `.png`, `.jpg`, or `.jpeg`.

## Current Output Set

```text
01-local-first-compression.png
02-drop-to-compress.png
03-watch-progress.png
04-desktop-pet-settings.png
```
