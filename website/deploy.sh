#!/usr/bin/env bash
# ImagePet Website - Deploy to Cloudflare Pages

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="${WRANGLER_PROJECT_NAME:-imagepet-website}"
DEPLOY_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$DEPLOY_DIR"
}
trap cleanup EXIT

cd "$SCRIPT_DIR"

if [[ ! -d node_modules ]]; then
  echo "Installing dependencies..."
  npm ci
fi

echo "Building static site..."
npm run build

echo "Preparing static deploy bundle..."
cp -R dist/. "$DEPLOY_DIR"/

echo "Deploying to Cloudflare Pages project: $PROJECT_NAME"
npx wrangler pages deploy "$DEPLOY_DIR" --project-name="$PROJECT_NAME"

echo "Deployment complete."
