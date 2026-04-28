#!/usr/bin/env bash
# NeoWispr Build Script
# Macht swift build + .app-Bundle + Apple Dev Sign + Install + Launch in einem Rutsch.
#
# Usage:
#   ./scripts/build-app.sh                # debug build, install, run
#   ./scripts/build-app.sh --release      # release build
#   ./scripts/build-app.sh --no-install   # nur build, kein /Applications copy
#   ./scripts/build-app.sh --no-run       # build + install, nicht starten
#   ./scripts/build-app.sh --clean        # vorher .build löschen

set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="debug"
DO_INSTALL=1
DO_RUN=1
DO_CLEAN=0
ENTITLEMENTS="NeoWispr/Resources/NeoWispr.entitlements"

# Sign-Identity ermitteln:
# 1. ENV-Override (für CI / spezifische Cert): NEOWISPR_SIGN_IDENTITY=<hash-or-name>
# 2. Erste lokale "Apple Development"/"Developer ID"-Cert (per SHA-1-Hash, eindeutig)
# 3. Fallback: ad-hoc ("-") — App läuft lokal, nicht für Distribution geeignet
detect_sign_identity() {
  if [ -n "${NEOWISPR_SIGN_IDENTITY:-}" ]; then
    echo "$NEOWISPR_SIGN_IDENTITY"
    return
  fi
  # awk '{print $2}' liefert den SHA-1 Hash — eindeutig auch bei mehreren Certs gleichen Namens
  local hash
  hash=$(security find-identity -v -p codesigning 2>/dev/null \
            | grep -E 'Apple Development|Developer ID Application' \
            | head -1 \
            | awk '{print $2}')
  if [ -n "$hash" ]; then
    echo "$hash"
  else
    echo "-"  # ad-hoc
  fi
}
SIGN_IDENTITY=$(detect_sign_identity)
SIGN_LABEL="$SIGN_IDENTITY"
# Lesbares Label für die Build-Ausgabe (Name + Team-ID statt Hash)
if [ "$SIGN_IDENTITY" != "-" ]; then
  SIGN_LABEL=$(security find-identity -v -p codesigning 2>/dev/null \
                 | grep "$SIGN_IDENTITY" \
                 | head -1 \
                 | sed -E 's/.*"([^"]+)".*/\1/')
fi

for arg in "$@"; do
  case "$arg" in
    --release)    CONFIG="release" ;;
    --debug)      CONFIG="debug" ;;
    --no-install) DO_INSTALL=0 ;;
    --no-run)     DO_RUN=0 ;;
    --clean)      DO_CLEAN=1 ;;
    --help|-h)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *) echo "Unbekanntes Flag: $arg"; exit 1 ;;
  esac
done

if [ "$DO_CLEAN" = "1" ]; then
  echo "[1/6] Clean: .build entfernen..."
  swift package clean
fi

echo "[2/6] swift build ($CONFIG)..."
if [ "$CONFIG" = "release" ]; then
  swift build -c release
  BUILD_DIR=".build/arm64-apple-macosx/release"
else
  swift build
  BUILD_DIR=".build/arm64-apple-macosx/debug"
fi

APP="$BUILD_DIR/NeoWispr.app"
BIN="$BUILD_DIR/NeoWispr"

if [ ! -x "$BIN" ]; then
  echo "FEHLER: Binary nicht gefunden: $BIN"
  exit 1
fi

echo "[3/6] Bundle zusammenbauen..."
# Altes Bundle in /tmp parken (kein rm -rf auf Wildcards)
if [ -e "$APP" ]; then
  mv "$APP" "/tmp/neowispr-old-$(date +%s)" 2>/dev/null || true
fi
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN" "$APP/Contents/MacOS/NeoWispr"
cp NeoWispr/Resources/Info.plist "$APP/Contents/Info.plist"

# SPM Resource Bundle (wenn vorhanden)
if [ -e "$BUILD_DIR/NeoWispr_NeoWispr.bundle" ]; then
  cp -R "$BUILD_DIR/NeoWispr_NeoWispr.bundle" "$APP/Contents/Resources/"
fi

# Sparkle wird von SwiftPM als Framework in der Build-Toolchain abgelegt.
SPARKLE_FRAMEWORK="$(find .build -path '*/Sparkle.framework' -type d -print -quit)"
if [ -n "$SPARKLE_FRAMEWORK" ]; then
  ditto "$SPARKLE_FRAMEWORK" "$APP/Contents/Frameworks/Sparkle.framework"
fi

# SwiftPM verlinkt Sparkle als @rpath-Framework, setzt bei einem manuell gebauten
# .app-Bundle aber keinen RPATH auf Contents/Frameworks. Ohne diesen Eintrag
# crasht die installierte App direkt beim Launch mit "Library missing".
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/NeoWispr"

echo "[4/6] Assets.car kompilieren..."
xcrun actool NeoWispr/Resources/Assets.xcassets \
  --compile "$APP/Contents/Resources" \
  --platform macosx \
  --minimum-deployment-target 14.0 \
  --app-icon AppIcon \
  --output-partial-info-plist /tmp/neowispr-icon-info.plist \
  --output-format human-readable-text > /dev/null

if [ "$SIGN_IDENTITY" = "-" ]; then
  echo "[5/6] Code signing (ad-hoc — keine Apple Dev Cert in Keychain)..."
  echo "  → App läuft lokal. Für Distribution: \$NEOWISPR_SIGN_IDENTITY mit Apple Dev Cert setzen."
  codesign --force --deep --sign - "$APP" 2>&1 | tail -1
else
  echo "[5/6] Code signing mit \"$SIGN_LABEL\"..."
  codesign --force --deep --options=runtime \
    --entitlements "$ENTITLEMENTS" \
    --sign "$SIGN_IDENTITY" \
    "$APP" 2>&1 | tail -1
fi

# Verifizieren (ad-hoc-Signaturen passieren --verify ohne --deep --strict)
if [ "$SIGN_IDENTITY" = "-" ]; then
  codesign --verify "$APP" && echo "  Signature OK (ad-hoc)"
else
  codesign --verify --deep --strict "$APP" && echo "  Signature OK"
fi

if [ "$CONFIG" = "release" ]; then
  if command -v generate_appcast >/dev/null 2>&1; then
    echo "  Appcast aktualisieren..."
    generate_appcast "$BUILD_DIR" >/dev/null
  else
    echo "  Appcast übersprungen: generate_appcast nicht im PATH"
  fi
fi

if [ "$DO_INSTALL" = "1" ]; then
  echo "[6/6] Install nach /Applications..."
  pkill -9 -f "Applications/NeoWispr" 2>/dev/null || true
  sleep 1
  if [ -e /Applications/NeoWispr.app ]; then
    mv /Applications/NeoWispr.app "$HOME/.Trash/NeoWispr.app.bak.$(date +%s)"
  fi
  ditto "$APP" /Applications/NeoWispr.app

  # Force macOS Dock + Finder to pick up the new app icon (IconServices caches aggressively)
  touch /Applications/NeoWispr.app
  find "$HOME/Library/Caches/com.apple.iconservices.store" -type f -delete 2>/dev/null || true
  killall Dock 2>/dev/null || true
  killall Finder 2>/dev/null || true

  if [ "$DO_RUN" = "1" ]; then
    open /Applications/NeoWispr.app
    sleep 2
    PID="$(pgrep -f "Applications/NeoWispr" 2>/dev/null | head -1 || true)"
    if [ -n "$PID" ]; then
      echo "  NeoWispr läuft, PID $PID"
    else
      echo "  NeoWispr gestartet"
    fi
  fi
else
  echo "[6/6] Install übersprungen (--no-install)"
  echo "  Bundle: $APP"
fi

echo ""
echo "Fertig."
