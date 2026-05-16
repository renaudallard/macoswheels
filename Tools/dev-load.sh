#!/usr/bin/env bash
set -euo pipefail

APP="MacoswheelsContainer.app"
DEXT_ID="it.allard.macoswheels.dext"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -d "$SCRIPT_DIR/$APP" ]; then
    echo "macoswheels: $APP not found next to dev-load.sh" >&2
    echo "Run this from the unzipped CI artifact." >&2
    exit 1
fi

if ! systemextensionsctl developer 2>/dev/null | grep -q "Developer mode is on"; then
    echo "macoswheels: enabling system-extension developer mode..."
    sudo systemextensionsctl developer on
fi

CSR=$(csrutil status 2>/dev/null || true)
if echo "$CSR" | grep -q "System Integrity Protection status: enabled" && \
   ! echo "$CSR" | grep -q "Filesystem Protections: disabled"; then
    echo "macoswheels: SIP appears to be in a strict mode."
    echo "DEXT loading may be blocked. See docs/DEV-MODE-SETUP.md."
fi

open "$SCRIPT_DIR/$APP"
echo "macoswheels: container app launched."
echo "Click 'Activate DEXT' and approve in System Settings > Privacy & Security."
echo ""
echo "Tail the log with:"
echo "  log stream --predicate 'sender == \"MacoswheelsDEXT\"' --level=debug"
