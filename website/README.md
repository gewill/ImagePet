# ImagePet Website

Static official website for ImagePet. The page is built from the shared metadata source in `../metadata/`.

## Local Development

```bash
npm install
npm run dev
```

## Build

```bash
npm run build
```

The static output is written to `dist/`.

## Deploy

```bash
./deploy.sh
```

or:

```bash
npm run deploy
```

The script builds the site, copies `dist/` into a temporary deploy bundle, and runs:

```bash
npx wrangler pages deploy "$DEPLOY_DIR" --project-name="$WRANGLER_PROJECT_NAME"
```

The default project name is `imagepet-website`. Override it when needed:

```bash
WRANGLER_PROJECT_NAME=imagepet-website ./deploy.sh
```

## Cloudflare Pages

Use these settings:

- Project root: `website`
- Build command: `npm run build`
- Build output directory: `dist`
- Node.js version: 22 or newer

When public URLs are live, update `../metadata/app.json`:

- `links.support`
- `links.privacyPolicy`
- `links.marketing`
- `links.macAppStore`
