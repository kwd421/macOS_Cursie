#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="${DERIVED_DATA:-/tmp/CursieNotaryDerivedData}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
APP_NAME="Cursie.app"
APP_PATH="$DERIVED_DATA/Build/Products/Release/$APP_NAME"
PRE_NOTARY_ZIP="$DIST_DIR/Cursie-notary.zip"
FINAL_ZIP="$DIST_DIR/Cursie.zip"
FINAL_DMG="$DIST_DIR/Cursie.dmg"
NOTARY_PROFILE="${NOTARY_PROFILE:-seinel-notary}"
SPARKLE_ACCOUNT="${SPARKLE_ACCOUNT:-seinel-capeforge}"
SPARKLE_SIGN_UPDATE="${SPARKLE_SIGN_UPDATE:-$ROOT_DIR/.build/artifacts/sparkle/Sparkle/bin/sign_update}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application: Wondong Ko (DRUFU8Q688)}"

cd "$ROOT_DIR"

configure_dmg_layout() {
  local staging_path="$1"

  echo "Configuring DMG Finder layout..."
  /usr/bin/osascript <<APPLESCRIPT
tell application "Finder"
  set dmgFolder to POSIX file "$staging_path" as alias
  open dmgFolder
  delay 0.2
  set dmgWindow to container window of dmgFolder
  set current view of dmgWindow to icon view
  set toolbar visible of dmgWindow to false
  set statusbar visible of dmgWindow to false
  set bounds of dmgWindow to {220, 160, 740, 460}

  set viewOptions to icon view options of dmgWindow
  set arrangement of viewOptions to not arranged
  set icon size of viewOptions to 128
  set text size of viewOptions to 13

  set position of item "Cursie.app" of dmgFolder to {150, 150}
  set position of item "Applications" of dmgFolder to {380, 150}

  update dmgFolder without registering applications
  delay 0.2
  close dmgWindow
end tell
APPLESCRIPT
}

rm -rf "$DERIVED_DATA" "$DIST_DIR"
mkdir -p "$DIST_DIR"

xcodebuild \
  -project CapeForge.xcodeproj \
  -scheme Cursie \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  build

SPARKLE_FRAMEWORK="$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/B"
cp "$ROOT_DIR/LICENSE" "$APP_PATH/Contents/Resources/"
cp "$ROOT_DIR/THIRD_PARTY_NOTICES.md" "$APP_PATH/Contents/Resources/"
codesign --force --sign "$SIGNING_IDENTITY" --timestamp --options runtime "$SPARKLE_FRAMEWORK/Autoupdate"
codesign --force --sign "$SIGNING_IDENTITY" --timestamp --options runtime "$SPARKLE_FRAMEWORK/XPCServices/Downloader.xpc"
codesign --force --sign "$SIGNING_IDENTITY" --timestamp --options runtime "$SPARKLE_FRAMEWORK/XPCServices/Installer.xpc"
codesign --force --sign "$SIGNING_IDENTITY" --timestamp --options runtime "$SPARKLE_FRAMEWORK/Updater.app"
codesign --force --sign "$SIGNING_IDENTITY" --timestamp --options runtime "$SPARKLE_FRAMEWORK"
codesign --force --sign "$SIGNING_IDENTITY" --timestamp --options runtime --entitlements CapeForgeApp/CapeForge.entitlements "$APP_PATH"

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

ditto -c -k --keepParent "$APP_PATH" "$PRE_NOTARY_ZIP"

xcrun notarytool submit "$PRE_NOTARY_ZIP" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

ditto -c -k --keepParent "$APP_PATH" "$FINAL_ZIP"

echo "Notarized release archive: $FINAL_ZIP"
if [[ -x "$SPARKLE_SIGN_UPDATE" ]]; then
  echo "Sparkle enclosure attributes:"
  "$SPARKLE_SIGN_UPDATE" --account "$SPARKLE_ACCOUNT" "$FINAL_ZIP"
else
  echo "Sparkle sign_update not found at: $SPARKLE_SIGN_UPDATE" >&2
  echo "Run swift build or set SPARKLE_SIGN_UPDATE to Sparkle's sign_update tool." >&2
fi

# Create DMG for initial distribution (drag-to-Applications UX)
echo ""
echo "Creating DMG..."
DMG_STAGING="$(mktemp -d)"
cp -R "$APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"
configure_dmg_layout "$DMG_STAGING"

hdiutil create \
  -volname "Cursie" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  "$FINAL_DMG"

rm -rf "$DMG_STAGING"

codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$FINAL_DMG"
codesign --verify --verbose=2 "$FINAL_DMG"

# Notarize the DMG itself
xcrun notarytool submit "$FINAL_DMG" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

xcrun stapler staple "$FINAL_DMG"

echo "DMG for distribution: $FINAL_DMG"
