#!/usr/bin/env bash
# Build the marketing site and the /docs Starlight site, compose them into one
# dist/, and gate the result. Used by CI and reproducible locally.
set -euo pipefail
export PATH="$HOME/.cargo/bin:$HOME/.volta/bin:/opt/homebrew/bin:$PATH"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$HERE"

echo "→ building marketing site"
npm run build

echo "→ building /docs"
( cd docs-site && pnpm build )

echo "→ composing docs into dist/docs"
rm -rf dist/docs
mkdir -p dist/docs
# The docs build already emits /docs-prefixed URLs; its dist root maps to /docs.
cp -R docs-site/dist/. dist/docs/

# Starlight emits a sitemap because `site` is set, and a sitemap would list
# every page we just marked noindex — advertising exactly what we chose not to
# link. The marketing site emits no sitemap of its own, so simply drop these.
rm -f dist/docs/sitemap-index.xml dist/docs/sitemap-0.xml

echo "→ leak-scan gate over the composed output"
bash scripts/leak-scan.sh dist

echo "✓ build OK — marketing site at /, docs at /docs"
