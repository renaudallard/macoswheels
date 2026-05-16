#!/usr/bin/env bash
set -euo pipefail

: "${CERT_P12_BASE64:?CERT_P12_BASE64 must be set (GitHub secret)}"
: "${CERT_P12_PWD:?CERT_P12_PWD must be set (GitHub secret)}"

KEYCHAIN="${RUNNER_TEMP:-/tmp}/build.keychain"
KEYCHAIN_PWD="$(uuidgen)"

security create-keychain -p "$KEYCHAIN_PWD" "$KEYCHAIN"
security default-keychain -s "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PWD" "$KEYCHAIN"
security set-keychain-settings -lut 7200 "$KEYCHAIN"

CERT_PATH="${RUNNER_TEMP:-/tmp}/cert.p12"
echo "$CERT_P12_BASE64" | base64 --decode > "$CERT_PATH"

security import "$CERT_PATH" \
    -k "$KEYCHAIN" \
    -P "$CERT_P12_PWD" \
    -T /usr/bin/codesign \
    -T /usr/bin/security

security set-key-partition-list \
    -S apple-tool:,apple: \
    -s -k "$KEYCHAIN_PWD" \
    "$KEYCHAIN"

rm -f "$CERT_PATH"

security find-identity -v -p codesigning "$KEYCHAIN"
