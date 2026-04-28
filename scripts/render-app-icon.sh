#!/usr/bin/env bash
# Renders the NeoWispr F-deep Night logo to all macOS AppIcon sizes.
#
# Source of truth: scripts/app-icon.svg (mirrors NeoWispr Logo.html final).
# Targets:         NeoWispr/Resources/Assets.xcassets/AppIcon.appiconset/

set -euo pipefail

cd "$(dirname "$0")/.."

SVG="scripts/app-icon.svg"
OUT="NeoWispr/Resources/Assets.xcassets/AppIcon.appiconset"

if ! command -v rsvg-convert >/dev/null 2>&1; then
  echo "FEHLER: rsvg-convert fehlt — brew install librsvg"
  exit 1
fi
if [ ! -f "$SVG" ]; then
  echo "FEHLER: $SVG fehlt"
  exit 1
fi

declare -a SIZES=(
  "icon_16.png:16"
  "icon_16@2x.png:32"
  "icon_32.png:32"
  "icon_32@2x.png:64"
  "icon_64.png:64"
  "icon_64@2x.png:128"
  "icon_128.png:128"
  "icon_128@2x.png:256"
  "icon_256.png:256"
  "icon_256@2x.png:512"
  "icon_512.png:512"
  "icon_512@2x.png:1024"
  "icon_1024.png:1024"
)

for entry in "${SIZES[@]}"; do
  name="${entry%%:*}"
  px="${entry##*:}"
  rsvg-convert "$SVG" -w "$px" -h "$px" -o "$OUT/$name"
  echo "  $name (${px}px)"
done

echo "Done. Run ./scripts/build-app.sh to bundle + install."
