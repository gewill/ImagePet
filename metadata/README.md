# ImagePet Metadata Source

This folder is the canonical source for public ImagePet metadata.

Use it for:

- Mac App Store Connect copy and submission fields.
- Website copy, support pages, and privacy pages.
- Future automation that generates App Store Connect payloads, website pages, release pages, or screenshot manifests.

Do not use it for secrets, API tokens, unreleased roadmap promises, downloaded screenshots, generated website builds, or local App Store Connect exports.

## Files

- `app.json`: product identity, version, capabilities, privacy baseline, links, and source references.
- `locales/en-US.json`: localized public copy for App Store Connect and the website.
- `channels/mac-app-store.json`: App Store Connect field mapping, review metadata, screenshot plan, and submission checklist.
- `channels/website.json`: website route and section mapping that consumes the shared localized copy.

## Source Rules

- Public copy lives in `locales/*.json`.
- Channel files should reference localized copy by JSON pointer instead of duplicating it.
- Unknown public URLs stay `null` until the real page is live.
- Update `docs/APP_STORE_METADATA.md` only as a human-readable index; do not fork a second copy source there.
- Keep claims aligned with the submitted binary. Do not mention unreleased features, cloud upload, AI compression, or unsupported formats.

## Planned Workflow

1. Edit the relevant JSON source in this folder.
2. Validate JSON syntax.
3. Copy ASC fields from `channels/mac-app-store.json` plus the referenced locale fields, or generate them with a future script.
4. Build website pages from `channels/website.json` plus the referenced locale fields.
