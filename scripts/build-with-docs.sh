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

# Starlight injects <link rel="sitemap"> into every page's <head>. We delete
# the sitemap itself above, so leaving the tag would ship a 404 reference on
# all ~534 pages. Strip it so "no sitemap anywhere" is actually true. This
# runs every build, since the docs build regenerates dist/docs from scratch.
find dist/docs -name '*.html' -print0 \
  | xargs -0 sed -i '' -E 's#<link rel="sitemap"[^>]*/>##g'

# grep -l exits 1 on zero matches (the expected outcome here); under
# pipefail that would otherwise kill the script via set -e before this
# check can report anything, so neutralize the pipeline's exit status —
# the count itself is unaffected.
remaining_sitemap_refs="$( { grep -rl 'rel="sitemap"' dist/docs --include='*.html' || true; } | wc -l | tr -d ' ')"
if [ "$remaining_sitemap_refs" != "0" ]; then
  echo "✗ $remaining_sitemap_refs docs page(s) still reference a sitemap after stripping" >&2
  exit 1
fi
echo "  stripped sitemap tag from all docs pages (0 remaining references)"

echo "→ leak-scan gate over the composed output"
bash scripts/leak-scan.sh dist

echo "✓ build OK — marketing site at /, docs at /docs"
