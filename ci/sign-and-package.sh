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

# Two paths:
#
# (1) Cert imported (CERT_P12_BASE64 set). Use `xcodebuild archive` with the
#     Developer ID identity. This is the only path that yields a load-on-
#     default-SIP-Mac artifact, and it depends on the team having Apple's
#     DriverKit entitlement grant.
#
# (2) No cert. Apple's tooling rejects ad-hoc signing for DriverKit SDK
#     ("Ad Hoc code signing is not allowed with SDK 'DriverKit ...'"), so
#     instead we run `xcodebuild build` with CODE_SIGNING_ALLOWED=NO and
#     locate the unsigned .app in DerivedData. The DEXT lives embedded
#     inside MacoswheelsContainer.app/Contents/Library/SystemExtensions/.
#     Loadability on a dev-mode Mac depends on the user re-signing locally
#     with their Apple Development cert (e.g. via Xcode's free Personal
#     Team); the README documents that posture.
if [ -n "${CERT_P12_BASE64:-}" ]; then
    echo "sign-and-package: archiving with imported Developer ID cert"
    xcodebuild -project Macoswheels.xcodeproj \
               -scheme "$SCHEME" \
               -configuration "$CONFIG" \
               -destination 'platform=macOS' \
               -archivePath "$ARCHIVE" \
               DRIVERKIT_DEPLOYMENT_TARGET=25.0 \
               archive
    APP_SRC="$ARCHIVE/Products/Applications/MacoswheelsContainer.app"
else
    echo "sign-and-package: no cert -> unsigned build, manual app assembly"
    DERIVED="${RUNNER_TEMP:-/tmp}/macoswheels-derived"
    rm -rf "$DERIVED"
    xcodebuild -project Macoswheels.xcodeproj \
               -scheme "$SCHEME" \
               -configuration "$CONFIG" \
               -destination 'platform=macOS' \
               -derivedDataPath "$DERIVED" \
               DRIVERKIT_DEPLOYMENT_TARGET=25.0 \
               CODE_SIGNING_ALLOWED=NO \
               CODE_SIGN_IDENTITY= \
               CODE_SIGNING_REQUIRED=NO \
               CODE_SIGN_ENTITLEMENTS= \
               ENTITLEMENTS_REQUIRED=NO \
               build
    APP_SRC="$DERIVED/Build/Products/$CONFIG/MacoswheelsContainer.app"
fi

if [ ! -d "$APP_SRC" ]; then
    echo "sign-and-package: expected app not found at $APP_SRC" >&2
    exit 1
fi

rm -rf "$ARTIFACT_DIR"
mkdir -p "$ARTIFACT_DIR"
cp -R "$APP_SRC" "$ARTIFACT_DIR/"
cp -R Tools/dev-load.sh "$ARTIFACT_DIR/"
cp -R Tools/uninstall.sh "$ARTIFACT_DIR/" 2>/dev/null || true
cp -R man "$ARTIFACT_DIR/"

(cd "$BUILD_DIR" && zip -r9 "$(basename "$ZIP")" "$(basename "$ARTIFACT_DIR")")
(cd "$BUILD_DIR" && shasum -a 256 "$(basename "$ZIP")" > "$(basename "$ZIP").sha256")
echo "$ZIP"
echo "$ZIP.sha256"
