#!/usr/bin/env bash
set -euo pipefail

DEXT_ID="it.allard.macoswheels.dext"
LAUNCH_AGENT="it.allard.macoswheels.restore"
PLIST="$HOME/Library/Preferences/it.allard.macoswheels.plist"
AGENT_PLIST="$HOME/Library/LaunchAgents/$LAUNCH_AGENT.plist"

bold() { printf "\033[1m%s\033[0m\n" "$*"; }

bold "macoswheels uninstall"
echo

bold "1. Stopping LaunchAgent"
if [ -f "$AGENT_PLIST" ]; then
    launchctl unload "$AGENT_PLIST" 2>/dev/null || true
    rm -f "$AGENT_PLIST"
    echo "Removed $AGENT_PLIST"
fi
echo

bold "2. Deactivating system extension"
TEAM=$(systemextensionsctl list 2>/dev/null | awk -v id="$DEXT_ID" '$0 ~ id {print $1; exit}')
if [ -n "$TEAM" ]; then
    sudo systemextensionsctl uninstall "$TEAM" "$DEXT_ID" || true
else
    echo "$DEXT_ID not found in systemextensionsctl list (already uninstalled?)."
fi
echo

bold "3. Removing CLI + man pages"
sudo rm -f /usr/local/bin/macoswheels
sudo rm -f /usr/local/share/man/man1/macoswheels.1 \
           /usr/local/share/man/man1/macoswheels-range.1 \
           /usr/local/share/man/man1/macoswheels-autocenter.1 \
           /usr/local/share/man/man7/macoswheels.7
echo "Removed /usr/local/bin/macoswheels and man pages."
echo

bold "4. Removing preferences"
rm -f "$PLIST"
echo "Removed $PLIST"
echo

bold "Done."
echo "MacoswheelsContainer.app in /Applications (if any) may still be present;"
echo "drag it to the Trash manually."
