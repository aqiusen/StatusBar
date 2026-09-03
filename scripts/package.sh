#!/usr/bin/env bash
set -euo pipefail

APP_NAME="StatusBarSecondRow"
APP_DIR="dist/${APP_NAME}.app"

swift build -c release

mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
cp ".build/release/${APP_NAME}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
cp "packaging/Info.plist" "${APP_DIR}/Contents/Info.plist"
cp "packaging/AppIcon.icns" "${APP_DIR}/Contents/Resources/AppIcon.icns"
cp "packaging/CollapsedMascot.png" "${APP_DIR}/Contents/Resources/CollapsedMascot.png"
chmod +x "${APP_DIR}/Contents/MacOS/${APP_NAME}"

codesign --force --deep --sign - "${APP_DIR}"
/usr/bin/ditto -c -k --keepParent "${APP_DIR}" "dist/${APP_NAME}.zip"
codesign --verify --deep --strict --verbose=2 "${APP_DIR}"

echo "Built ${APP_DIR}"
echo "Built dist/${APP_NAME}.zip"
