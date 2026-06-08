#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="${DERIVED_DATA:-/tmp/CapeForgeNotaryDerivedData}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
APP_NAME="Cape Forge.app"
APP_PATH="$DERIVED_DATA/Build/Products/Release/$APP_NAME"
PRE_NOTARY_ZIP="$DIST_DIR/CapeForge-notary.zip"
FINAL_ZIP="$DIST_DIR/CapeForge.zip"
NOTARY_PROFILE="${NOTARY_PROFILE:-seinel-notary}"

cd "$ROOT_DIR"

rm -rf "$DERIVED_DATA" "$DIST_DIR"
mkdir -p "$DIST_DIR"

xcodebuild \
  -project CapeForge.xcodeproj \
  -scheme CapeForge \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  build

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

ditto -c -k --keepParent "$APP_PATH" "$PRE_NOTARY_ZIP"

xcrun notarytool submit "$PRE_NOTARY_ZIP" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

ditto -c -k --keepParent "$APP_PATH" "$FINAL_ZIP"

echo "Notarized release archive: $FINAL_ZIP"
