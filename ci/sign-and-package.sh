#!/usr/bin/env bash
set -euo pipefail

SCHEME="${1:-MacoswheelsContainer}"
CONFIG="${2:-Release}"

if [ -n "${GITHUB_REF_NAME:-}" ] && [[ "${GITHUB_REF_TYPE:-}" = "tag" ]]; then
    LABEL="$GITHUB_REF_NAME"
else
    LABEL="${GITHUB_SHA:-$(git rev-parse --short HEAD 2>/dev/null || echo dev)}"
fi

BUILD_DIR="build"
ARCHIVE="$BUILD_DIR/Macoswheels.xcarchive"
ARTIFACT_DIR="$BUILD_DIR/artifact"
ZIP="$BUILD_DIR/macoswheels-${LABEL}.zip"

mkdir -p "$BUILD_DIR"
xcodebuild -project Macoswheels.xcodeproj \
           -scheme "$SCHEME" \
           -configuration "$CONFIG" \
           -destination 'platform=macOS' \
           -archivePath "$ARCHIVE" \
           archive

rm -rf "$ARTIFACT_DIR"
mkdir -p "$ARTIFACT_DIR"
cp -R "$ARCHIVE/Products/Applications/MacoswheelsContainer.app" "$ARTIFACT_DIR/"
cp -R Tools/dev-load.sh "$ARTIFACT_DIR/"
cp -R Tools/uninstall.sh "$ARTIFACT_DIR/" 2>/dev/null || true
cp -R man "$ARTIFACT_DIR/"

(cd "$BUILD_DIR" && zip -r9 "$(basename "$ZIP")" "$(basename "$ARTIFACT_DIR")")
(cd "$BUILD_DIR" && shasum -a 256 "$(basename "$ZIP")" > "$(basename "$ZIP").sha256")
echo "$ZIP"
echo "$ZIP.sha256"
