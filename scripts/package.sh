#!/usr/bin/env bash
set -euo pipefail

APP_NAME="StatusBarSecondRow"
VERSION="${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' packaging/Info.plist)}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
DIST_DIR="${DIST_DIR:-dist}"
APP_DIR="${DIST_DIR}/${APP_NAME}.app"
ZIP_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}.zip"
DMG_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}.dmg"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"

if [[ ! "${VERSION}" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]]; then
  echo "VERSION must contain two or three numeric components (for example, 1.2.3)." >&2
  exit 1
fi

if [[ ! "${BUILD_NUMBER}" =~ ^[0-9]+$ ]]; then
  echo "BUILD_NUMBER must be a non-negative integer." >&2
  exit 1
fi

swift build -c release

mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
cp ".build/release/${APP_NAME}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
cp "packaging/Info.plist" "${APP_DIR}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${APP_DIR}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER}" "${APP_DIR}/Contents/Info.plist"
cp "packaging/AppIcon.icns" "${APP_DIR}/Contents/Resources/AppIcon.icns"
cp "packaging/CollapsedMascot.png" "${APP_DIR}/Contents/Resources/CollapsedMascot.png"
chmod +x "${APP_DIR}/Contents/MacOS/${APP_NAME}"

codesign --force --deep --sign "${SIGNING_IDENTITY}" "${APP_DIR}"
/usr/bin/ditto -c -k --keepParent "${APP_DIR}" "${ZIP_PATH}"
codesign --verify --deep --strict --verbose=2 "${APP_DIR}"

STAGING_DIR="$(mktemp -d)"
trap 'rm -rf "${STAGING_DIR}"' EXIT
/usr/bin/ditto "${APP_DIR}" "${STAGING_DIR}/${APP_NAME}.app"
ln -s /Applications "${STAGING_DIR}/Applications"
hdiutil create -volname "${APP_NAME} ${VERSION}" -srcfolder "${STAGING_DIR}" -ov -format UDZO "${DMG_PATH}"
hdiutil verify "${DMG_PATH}"

echo "Built ${APP_DIR}"
echo "Built ${ZIP_PATH}"
echo "Built ${DMG_PATH}"
