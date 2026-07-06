#!/bin/bash
# Double-click to open THE GRIND. If the server isn't already running (e.g. via
# scripts/install-service.sh), this starts it in the foreground first.
cd "$(dirname "$0")"
PORT="${PORT:-47417}"
URL="http://localhost:$PORT"
if curl -s -o /dev/null "$URL"; then
  open "$URL"
else
  open "$URL"
  exec node --experimental-sqlite server.mjs
fi
