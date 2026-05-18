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

# If no Apple Developer cert was imported, build ad-hoc signed. The DEXT
# still gets a (cdhash-only) signature, which is what
# `systemextensionsctl developer on` + SIP-relaxed Macs accept. Apple-gated
# entitlements stay embedded but unvalidated -- the same dev-mode posture
# README.md and docs/DEV-MODE-SETUP.md describe.
SIGN_FLAGS=()
if [ -z "${CERT_P12_BASE64:-}" ]; then
    echo "sign-and-package: no Apple cert -> ad-hoc signing"
    SIGN_FLAGS=(
        CODE_SIGN_STYLE=Manual
        CODE_SIGN_IDENTITY=-
        DEVELOPMENT_TEAM=
        CODE_SIGNING_REQUIRED=YES
        CODE_SIGNING_ALLOWED=YES
        PROVISIONING_PROFILE_SPECIFIER=
    )
else
    echo "sign-and-package: using imported Developer ID cert"
fi

xcodebuild -project Macoswheels.xcodeproj \
           -scheme "$SCHEME" \
           -configuration "$CONFIG" \
           -destination 'platform=macOS' \
           -archivePath "$ARCHIVE" \
           DRIVERKIT_DEPLOYMENT_TARGET=25.0 \
           "${SIGN_FLAGS[@]}" \
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
