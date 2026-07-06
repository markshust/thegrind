#!/bin/bash
# Optional: serve THE GRIND over trusted local HTTPS at a custom domain
# (e.g. https://thegrind.test:8443), running at login via launchd.
#
# It generates a locally-trusted cert (mkcert), an nginx vhost that proxies
# to the app, and a launchd agent so nginx starts at login. nginx binds an
# unprivileged port (8443), so no sudo is needed for the proxy itself — the
# ONLY sudo step is mapping the domain to localhost, which it prints for you
# if the name doesn't already resolve.
#
#   ./scripts/install-proxy.sh
#   DOMAIN=grind.test HTTPS_PORT=8443 PORT=47417 ./scripts/install-proxy.sh
set -euo pipefail

DOMAIN="${DOMAIN:-thegrind.test}"
HTTPS_PORT="${HTTPS_PORT:-8443}"
UPSTREAM="${PORT:-47417}"
LABEL="dev.thegrind.proxy"
BREW="$(brew --prefix 2>/dev/null || echo /opt/homebrew)"
SSL_DIR="$BREW/etc/nginx/ssl"
SITES="$BREW/etc/nginx/sites-enabled"
NGINX_CONF="$BREW/etc/nginx/nginx.conf"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/$LABEL.log"

for bin in nginx mkcert; do
  command -v "$bin" >/dev/null || { echo "✗ $bin not found. Run: brew install nginx mkcert nss" >&2; exit 1; }
done

# 1. trusted cert
mkcert -install >/dev/null 2>&1 || true
mkdir -p "$SSL_DIR"
mkcert -cert-file "$SSL_DIR/thegrind.pem" -key-file "$SSL_DIR/thegrind-key.pem" "$DOMAIN" localhost 127.0.0.1 >/dev/null
echo "✓ cert for $DOMAIN → $SSL_DIR"

# 2. vhost
mkdir -p "$SITES"
cat > "$SITES/thegrind.conf" <<CONF
server {
    server_name $DOMAIN;
    listen [::]:$HTTPS_PORT ssl;
    listen $HTTPS_PORT ssl;
    ssl_certificate     $SSL_DIR/thegrind.pem;
    ssl_certificate_key $SSL_DIR/thegrind-key.pem;
    location / {
        proxy_pass http://127.0.0.1:$UPSTREAM;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header X-Forwarded-Proto https;
    }
}
CONF
echo "✓ vhost → $SITES/thegrind.conf"
grep -q "sites-enabled" "$NGINX_CONF" || echo "⚠ add 'include $SITES/*;' inside the http{} block of $NGINX_CONF"

# 3. validate + launchd agent (nginx foreground so launchd supervises it)
nginx -t >/dev/null 2>&1 || { echo "✗ nginx -t failed. Fix nginx.conf (log paths must be writable), then re-run." >&2; exit 1; }
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
pkill -f "nginx: master" 2>/dev/null || true; sleep 1
cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array><string>$(command -v nginx)</string><string>-g</string><string>daemon off;</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>10</integer>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
PLIST_EOF
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "✓ launchd agent $LABEL (nginx on :$HTTPS_PORT)"

# 4. DNS mapping (only sudo step, and only if not already pointing at localhost)
if [ "$(dscacheutil -q host -a name "$DOMAIN" | awk '/ip_address/{print $2; exit}')" != "127.0.0.1" ]; then
  echo ""
  echo "⚠ $DOMAIN does not resolve to localhost yet. Run this one line (needs sudo):"
  echo "    echo '127.0.0.1 $DOMAIN' | sudo tee -a /etc/hosts"
else
  echo "✓ $DOMAIN already resolves to 127.0.0.1"
fi
echo ""
echo "→ https://$DOMAIN:$HTTPS_PORT"
