#!/bin/bash
# Remove the THE GRIND launchd service. Your data (grind.db) is left untouched.
set -euo pipefail
LABEL="dev.thegrind.server"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$PLIST"
echo "✓ Removed $LABEL (grind.db kept)"
