#!/bin/bash
# Install THE GRIND as a macOS launchd service so it starts at login and stays
# running (restarts if it ever crashes). No sudo required — it's a user agent
# bound to an unprivileged port. Re-run any time to update it.
#
#   ./scripts/install-service.sh
#
# Override the port:  PORT=50000 ./scripts/install-service.sh
set -euo pipefail

PORT="${PORT:-47417}"
LABEL="dev.thegrind.server"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
NODE="$(command -v node || true)"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/$LABEL.log"

if [ -z "$NODE" ]; then
  echo "✗ node not found on PATH. Install Node 22.5+ first (e.g. brew install node)." >&2
  exit 1
fi

mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"

cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$NODE</string>
    <string>--experimental-sqlite</string>
    <string>$REPO/server.mjs</string>
  </array>
  <key>WorkingDirectory</key><string>$REPO</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PORT</key><string>$PORT</string>
    <key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
  </dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>10</integer>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
PLIST_EOF

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo "✓ Installed $LABEL"
echo "  App:  http://localhost:$PORT"
echo "  Log:  $LOG"
echo "  Data: $REPO/grind.db"
