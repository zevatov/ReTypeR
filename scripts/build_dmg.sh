#!/bin/bash
# Builds ReTypeR.app (Release) and packages it into a drag-and-drop DMG
# ("ReTypeR 1.3 Бета") at the repo root.
#
# The DMG contains the app next to an /Applications symlink, so installation
# is a single drag in Finder.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="ReTypeR"
# Installed .app name is versioned so multiple installed versions are
# distinguishable in /Applications (owner request). The BUILD product stays
# "ReTypeR.app" (renaming it broke the test host and re-linked binaries after
# signing); the rename to the versioned name happens in STAGING below, with a
# re-sign of the renamed bundle.
INSTALLED_NAME="ReTypeR 1.3.3"
DMG_TITLE="$INSTALLED_NAME"
DMG_PATH="$ROOT/$INSTALLED_NAME.dmg"
BUILD_DIR="$ROOT/build/DerivedData"
APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"
STAGING="$ROOT/build/dmg-staging"
STAGED_APP_PATH="$STAGING/$INSTALLED_NAME.app"
SIGN_IDENTITY="Apple Development"

echo "==> Building Release configuration…"
xcodebuild build \
    -project "$ROOT/$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -destination 'platform=macOS' \
    -derivedDataPath "$BUILD_DIR" \
    -quiet

if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: $APP_PATH not found after build" >&2
    exit 1
fi

echo "==> Cleaning extended attributes (codesign detritus guard)…"
xattr -cr "$APP_PATH" 2>/dev/null || true

echo "==> Preparing drag-and-drop staging folder (copying to versioned name)…"
rm -rf "$STAGING"
mkdir -p "$STAGING"
# Copying straight to the versioned name IS the rename.
cp -R "$APP_PATH" "$STAGED_APP_PATH"

echo "==> Re-signing the RENAMED bundle (Apple Development identity, hardened runtime)…"
# TCC (Accessibility; Screen Recording removed 2026-09-14 with OCR mode) persists per code signature. Ad-hoc
# signatures change on every rebuild, so granted permissions silently reset.
# The Apple Development identity carries a stable Team ID — sign with it so
# permissions granted once survive rebuilds and updates. Signing happens AFTER
# the rename so the seal covers the final bundle shape.
xattr -cr "$STAGED_APP_PATH" 2>/dev/null || true
codesign --force --deep --sign "$SIGN_IDENTITY" --options runtime --timestamp=none "$STAGED_APP_PATH"

echo "==> Verifying signature…"
codesign --verify --deep --strict "$STAGED_APP_PATH" || {
    echo "ERROR: codesign verification failed" >&2
    exit 1
}
codesign -dv "$STAGED_APP_PATH" 2>&1 | grep -E "Authority|TeamIdentifier" || true

echo "==> Staged app size:"
du -sh "$STAGED_APP_PATH"

# Drag-and-drop target: standard /Applications symlink.
ln -s /Applications "$STAGING/Applications"

echo "==> Removing stale DMG…"
rm -f "$DMG_PATH"

echo "==> Creating DMG…"
hdiutil create -volname "$DMG_TITLE" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGING"

echo "==> Done: $DMG_PATH"
ls -lh "$DMG_PATH"
