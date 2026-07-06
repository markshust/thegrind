#!/bin/bash
# Remove the THE GRIND nginx HTTPS proxy agent + vhost. Leaves the cert and
# your DNS/hosts entry in place (harmless). Your data is untouched.
set -euo pipefail
LABEL="dev.thegrind.proxy"
BREW="$(brew --prefix 2>/dev/null || echo /opt/homebrew)"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
rm -f "$BREW/etc/nginx/sites-enabled/thegrind.conf"
echo "✓ Removed $LABEL and its vhost (reload nginx to drop the listener)"
