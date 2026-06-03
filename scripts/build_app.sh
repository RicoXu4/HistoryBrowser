#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="HistoryBrowser"
CONFIGURATION="${CONFIGURATION:-release}"
XCODE_CONFIGURATION="$(tr '[:lower:]' '[:upper:]' <<< "${CONFIGURATION:0:1}")${CONFIGURATION:1}"
BUILD_ROOT="$ROOT_DIR/.build/xcode"
PRODUCT_DIR="$BUILD_ROOT/Build/Products/$XCODE_CONFIGURATION"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"

cd "$ROOT_DIR"
xcodebuild \
    -project "$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration "$XCODE_CONFIGURATION" \
    -derivedDataPath "$BUILD_ROOT" \
    CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED:-NO}" \
    build

rm -rf "$APP_DIR"
mkdir -p "$ROOT_DIR/dist"
cp -R "$PRODUCT_DIR/$APP_NAME.app" "$APP_DIR"

echo "Built $APP_DIR"
