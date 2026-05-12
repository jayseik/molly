#!/usr/bin/env bash
# Build Molly for direct download: thin Apple Silicon (arm64) Release binary.
# Requires: macOS, Xcode 15+, XcodeGen (brew install xcodegen), and valid
# Developer ID signing + notarization on the machine (or Xcode account).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v xcodegen >/dev/null 2>&1; then
	echo "Install XcodeGen: brew install xcodegen" >&2
	exit 1
fi

xcodegen generate

DERIVED="${ROOT}/build/DerivedData"
ARCHIVE="${ROOT}/build/Molly.xcarchive"
DIST="${ROOT}/dist"
EXPORT_PLIST="${ROOT}/Supporting/ExportOptions-direct-developer-id.plist"

rm -rf "${DERIVED}" "${ARCHIVE}" "${DIST}"
mkdir -p "${DIST}" "${ROOT}/build"

echo "→ Archiving (Release, arm64)…"
xcodebuild archive \
	-project Molly.xcodeproj \
	-scheme Molly \
	-configuration Release \
	-archivePath "${ARCHIVE}" \
	-destination "generic/platform=macOS" \
	ARCHS=arm64 \
	ONLY_ACTIVE_ARCH=NO

echo "→ Exporting Developer ID-signed .app…"
xcodebuild -exportArchive \
	-archivePath "${ARCHIVE}" \
	-exportPath "${DIST}/export" \
	-exportOptionsPlist "${EXPORT_PLIST}"

APP="${DIST}/export/Molly.app"
if [[ ! -d "${APP}" ]]; then
	echo "Expected ${APP} after export; check Organizer / signing." >&2
	exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${APP}/Contents/Info.plist" 2>/dev/null || echo "0.0.0")"
ZIP_NAME="Molly-${VERSION}-arm64-direct.zip"
(
	cd "${DIST}/export"
	ditto -c -k --sequesterRsrc --keepParent Molly.app "${DIST}/${ZIP_NAME}"
)

echo ""
echo "Signed app: ${APP}"
echo "Zip (for hosting): ${DIST}/${ZIP_NAME}"
echo ""
echo "Notarize before wide distribution:"
echo "  xcrun notarytool submit \"${DIST}/${ZIP_NAME}\" --wait --keychain-profile AC_NOTARY"
echo "  xcrun stapler staple \"${APP}\""
