#!/usr/bin/env bash
set -euo pipefail

APP_NAME="SimDeck"
VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
ARCH="${ARCH:-arm64}"
BUNDLE_ID="${BUNDLE_ID:-com.nurislamov.simdeck}"
MIN_SYSTEM_VERSION="${MIN_SYSTEM_VERSION:-13.0}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application: Timur Nurislamov (8LYLFMC6CF)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-simdeck-notary}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist/release"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
NOTARY_ZIP="$DIST_DIR/$APP_NAME-$VERSION-notary.zip"
FINAL_ZIP="$DIST_DIR/$APP_NAME-$VERSION.zip"

log() {
  printf '==> %s\n' "$1"
}

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required tool: %s\n' "$1" >&2
    exit 1
  fi
}

require_tool swift
require_tool codesign
require_tool xcrun
require_tool ditto
require_tool shasum

if ! /usr/bin/security find-identity -p codesigning -v | /usr/bin/grep -F "$SIGNING_IDENTITY" >/dev/null; then
  printf 'Signing identity not found: %s\n' "$SIGNING_IDENTITY" >&2
  exit 1
fi

log "Running tests"
swift test

log "Building $APP_NAME $VERSION for $ARCH"
swift build -c release --arch "$ARCH"
BUILD_BINARY="$(swift build -c release --arch "$ARCH" --show-bin-path)/$APP_NAME"

log "Assembling app bundle"
rm -rf "$DIST_DIR"
mkdir -p "$APP_MACOS"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.developer-tools</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

plutil -lint "$INFO_PLIST"

log "Signing app bundle"
codesign --force \
  --sign "$SIGNING_IDENTITY" \
  --options runtime \
  --timestamp \
  "$APP_BUNDLE"

log "Verifying signature before notarization"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

log "Creating notarization archive"
rm -f "$NOTARY_ZIP" "$FINAL_ZIP"
ditto -c -k --keepParent "$APP_BUNDLE" "$NOTARY_ZIP"

log "Submitting to Apple notarization"
xcrun notarytool submit "$NOTARY_ZIP" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

log "Stapling notarization ticket"
xcrun stapler staple "$APP_BUNDLE"
xcrun stapler validate "$APP_BUNDLE"

log "Creating final release archive"
ditto -c -k --keepParent "$APP_BUNDLE" "$FINAL_ZIP"

log "Validating final app"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
spctl -a -vv --type execute "$APP_BUNDLE"

SHA256="$(shasum -a 256 "$FINAL_ZIP" | /usr/bin/awk '{print $1}')"

printf '\nRelease artifact: %s\n' "$FINAL_ZIP"
printf 'SHA-256: %s\n' "$SHA256"
