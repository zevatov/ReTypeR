#!/bin/bash

# Exit on error
set -e

PROJECT_DIR="/Users/stanislav/Desktop/проекты/ReTypeR"

log() {
    echo "[BuildDMG] $1"
}

# 1. Prepare assets (crops logo, overwrites appiconset files and builds ICNS)
log "Running prepare_assets.swift..."
swift "$PROJECT_DIR/scripts/prepare_assets.swift"

# 2. Clean previous build caches to force Xcode to compile the new icons
log "Cleaning up old build cache..."
rm -f "$PROJECT_DIR/ReTypeR.dmg"
rm -rf "$PROJECT_DIR/dist"
rm -rf "$PROJECT_DIR/build"
mkdir -p "$PROJECT_DIR/dist"

# Regenerate xcode project with new bundle identifier
log "Regenerating Xcode project using xcodegen..."
xcodegen generate

# 3. Rebuild the application from scratch
log "Compiling ReTypeR app with new icon assets..."
xcodebuild -project "$PROJECT_DIR/ReTypeR.xcodeproj" \
           -scheme ReTypeR \
           -configuration Release \
           -derivedDataPath "$PROJECT_DIR/build/DerivedData" \
           CODE_SIGN_IDENTITY="" \
           CODE_SIGNING_REQUIRED=NO \
           CODE_SIGNING_ALLOWED=NO

# 4. Strip iCloud metadata/extended attributes from build folder and sign
log "Stripping attributes and signing app bundle..."
xattr -cr "$PROJECT_DIR/build/DerivedData/Build/Products/Release/ReTypeR.app"
codesign --force --sign - --timestamp=none "$PROJECT_DIR/build/DerivedData/Build/Products/Release/ReTypeR.app"

# 5. Copy built app to dist/
BUILT_APP="$PROJECT_DIR/build/DerivedData/Build/Products/Release/ReTypeR.app"
log "Copying built app to dist/..."
cp -R "$BUILT_APP" "$PROJECT_DIR/dist/"
xattr -cr "$PROJECT_DIR/dist/ReTypeR.app"

# Force register with LaunchServices and touch app bundle to notify Finder of icon change
log "Force registering app bundle with LaunchServices to bypass cache..."
touch "$PROJECT_DIR/dist/ReTypeR.app"
touch "$PROJECT_DIR/dist/ReTypeR.app/Contents/Info.plist"
touch "$PROJECT_DIR/dist/ReTypeR.app/Contents/Resources/AppIcon.icns"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$PROJECT_DIR/dist/ReTypeR.app"

# 6. Generate the DMG via dmgbuild with a new Volume Name to bypass Finder cache
log "Running dmgbuild to generate ReTypeR.dmg..."
dmgbuild -s "$PROJECT_DIR/dmg_settings.py" "ReTypeR Installer" "$PROJECT_DIR/ReTypeR.dmg"

# 7. Apply the custom desktop icon to the DMG file itself
log "Setting custom icon on the DMG file itself..."
swift "$PROJECT_DIR/scripts/set_dmg_icon.swift"

# 8. Relaunch Finder to force clear its internal icon display cache
log "Relaunching Finder to force icon cache refresh..."
killall Finder || true

log "DMG generated successfully at: $PROJECT_DIR/ReTypeR.dmg"
