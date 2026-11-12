#!/bin/bash
# Renders the Mac App Store screenshots (2880×1800, en + es) into docs/store/screenshots
# from the real views, via StoreScreenshotTests. Usage: ./scripts/make-store-screenshots.sh [output-dir]
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh
out="${1:-$PWD/docs/store/screenshots}"

cd HeyYouKit
for language in en es; do
    HEYYOU_STORE_SHOTS="$out/$language" HEYYOU_STORE_LANG="$language" swift test --filter StoreScreenshotTests
done
echo "Screenshots written to $out"

# Product Hunt gallery: the English set scaled to 760 tall and padded to 1270 wide with the stage color,
# so the margins stay even.
if [ -z "${1:-}" ]; then
    gallery="$(dirname "$out")/product-hunt"
    mkdir -p "$gallery"
    for file in "$out"/en/*.png; do
        sips -z 760 1216 "$file" --out "$gallery/$(basename "$file")" >/dev/null
        sips -p 760 1270 --padColor F9FAFC "$gallery/$(basename "$file")" >/dev/null
    done
    echo "Product Hunt gallery written to $gallery"
fi
