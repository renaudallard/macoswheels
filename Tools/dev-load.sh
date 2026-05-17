#!/usr/bin/env bash
set -euo pipefail

APP="MacoswheelsContainer.app"
DEXT_ID="it.allard.macoswheels.dext"
CLI_NAME="macoswheels"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
warn() { printf "\033[33m%s\033[0m\n" "$*"; }
err()  { printf "\033[31m%s\033[0m\n" "$*"; }

if [ ! -d "$SCRIPT_DIR/$APP" ]; then
    err "macoswheels: $APP not found next to dev-load.sh"
    err "Run this from the unzipped CI artifact."
    exit 1
fi

bold "macoswheels dev-load"
echo

bold "1. System Integrity Protection"
csrutil status 2>/dev/null || true
echo

bold "2. System extension developer mode"
if systemextensionsctl developer 2>/dev/null | grep -q "Developer mode is on"; then
    echo "Developer mode is on."
else
    warn "Developer mode is off. Enabling now (will prompt for password)..."
    sudo systemextensionsctl developer on
fi
echo

bold "3. Installing CLI"
CLI_SRC="$SCRIPT_DIR/$APP/Contents/MacOS/$CLI_NAME"
CLI_DST="/usr/local/bin/$CLI_NAME"
if [ -f "$CLI_SRC" ]; then
    sudo install -m 755 "$CLI_SRC" "$CLI_DST"
    echo "Installed $CLI_DST"
else
    warn "CLI binary not embedded in the bundle; skipping CLI install."
fi
echo

bold "4. Installing man pages"
if [ -d "$SCRIPT_DIR/man" ]; then
    sudo install -d /usr/local/share/man/man1
    sudo install -d /usr/local/share/man/man7
    sudo install -m 644 "$SCRIPT_DIR"/man/*.1 /usr/local/share/man/man1/ 2>/dev/null || true
    sudo install -m 644 "$SCRIPT_DIR"/man/*.7 /usr/local/share/man/man7/ 2>/dev/null || true
    echo "Installed man pages under /usr/local/share/man/"
fi
echo

bold "5. Launching container app"
open "$SCRIPT_DIR/$APP"
echo "Container app launched. Click 'Activate DEXT' and approve in"
echo "System Settings > Privacy & Security if prompted."
echo
echo "To watch the DEXT log:"
echo "    log stream --predicate 'sender == \"MacoswheelsDEXT\"' --level=debug"
