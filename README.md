# THE GRIND — small wins machine

<p align="center"><img src="assets/thegrind.png" alt="THE GRIND — small wins machine" width="720"></p>

An arcade-themed progress tracker that turns grind-y work into frequent, tangible
wins. Every item you clear drops a coin into a cash-register counter (ka-ching,
confetti, the works), and coins cash out for real rewards in the Prize Vault.

Built on one idea: consistency comes from frequent small payouts, not big infrequent
swings. Score reps, not winners.

- **Three checklist tracks** — name them anything; each completed item banks coins.
- **A streak tracker** — log a personal best (reps, a run, a rally); new records bank coins.
- **Prize Vault** — spend banked coins on real rewards you define.
- **Real persistence** — progress lives in a SQLite file on disk, not the browser.

---

## Requirements

- **macOS** (the "run at login" and HTTPS sections are macOS-specific; the app itself is cross-platform).
- **Node 22.5 or newer** — the server uses Node's built-in `node:sqlite`, so there are **no npm dependencies to install**.
  ```bash
  node --version        # must be >= 22.5
  brew install node     # if you don't have it
  ```

---

## Quick start (any machine, 30 seconds)

```bash
git clone git@github.com:markshust/thegrind.git
cd thegrind
npm start
```

Then open the URL it prints — **http://localhost:47417**. That's the whole app.

Change the port with `PORT=50000 npm start`.

> `npm start` runs `node --experimental-sqlite server.mjs`. The `--experimental-sqlite`
> flag is required until `node:sqlite` graduates from experimental (stable in Node 24+).

---

## Keep it running at login (macOS, no sudo)

So it's always up and survives reboots — installs a launchd **user agent** on an
unprivileged port (no password needed):

```bash
./scripts/install-service.sh          # or: npm run install-service
```

This starts `server.mjs` now, relaunches it at every login, and restarts it if it
ever crashes. Manage it:

```bash
tail -f ~/Library/Logs/dev.thegrind.server.log   # watch logs
./scripts/uninstall-service.sh                    # remove (keeps your data)
```

Override the port: `PORT=50000 ./scripts/install-service.sh`.

---

## Pretty local HTTPS at a custom domain (optional, advanced)

Want `https://thegrind.test:8443` instead of `localhost:47417`? This adds a trusted
certificate and an nginx reverse proxy that starts at login. All Homebrew, all on
an unprivileged port (`:8443`) so nginx needs no root.

```bash
brew install dnsmasq nginx mkcert nss
```

### Scripted (recommended)

```bash
./scripts/install-proxy.sh          # or: npm run install-proxy
```

It generates the cert, writes the nginx vhost, and installs a launchd agent
(`dev.thegrind.proxy`) so nginx runs at login. The only thing it can't do for you
is the one-line DNS mapping (needs sudo) — it prints the exact command if the
domain isn't already pointing at localhost. Customize with env vars:

```bash
DOMAIN=grind.test HTTPS_PORT=8443 PORT=47417 ./scripts/install-proxy.sh
```

Remove it with `./scripts/uninstall-proxy.sh`. Then open **https://thegrind.test:8443**.

> Bare `https://thegrind.test` (no port) requires nginx to bind 443, which needs a
> root LaunchDaemon. The `:8443` setup stays password-free.

### Manual (if you'd rather do it by hand)

**1. Resolve a local TLD to your machine** (`.test` is reserved for exactly this —
avoid `.dev`, which is a real, HSTS-forced TLD):

```bash
echo 'address=/.test/127.0.0.1' >> $(brew --prefix)/etc/dnsmasq.conf
sudo brew services start dnsmasq
sudo mkdir -p /etc/resolver
echo 'nameserver 127.0.0.1' | sudo tee /etc/resolver/test
```

**2. Create a locally-trusted certificate:**

```bash
mkcert -install                                   # one-time: trust the local CA
mkdir -p $(brew --prefix)/etc/nginx/ssl && cd $(brew --prefix)/etc/nginx/ssl
mkcert -cert-file thegrind.pem -key-file thegrind-key.pem thegrind.test
```

**3. Add the nginx vhost** (template included at `deploy/nginx-thegrind.conf`):

```bash
mkdir -p $(brew --prefix)/etc/nginx/sites-enabled
cp deploy/nginx-thegrind.conf $(brew --prefix)/etc/nginx/sites-enabled/thegrind.conf
# ensure nginx.conf includes sites-enabled and logs to a writable path, then:
nginx -t && nginx           # or: brew services start nginx
```

Now open **https://thegrind.test:8443**.

---

## Make it yours (all in the UI)

There are no config files — **click anything to edit it**, and it saves to `grind.db`:

- The **app title** and **subtitle** (the neon header)
- Each **track title** and the **set label** over the progress bar
- Each track's **coin value** — click the number in its tag (the "N 🪙 each" line);
  the tag text is generated from that number
- The **streak** title and its coin value
- **Prizes** — click a name or cost to edit, ✕ to remove, "+ add prize" to add
- **Items** — click to rename, ✕ to remove, "+ add unit" to add

Everything persists instantly. A fresh install starts from neutral defaults
(Tasks / Projects / Milestones, a Streak, a starter prize list) — rename to taste.

---

## Your data & backups

Everything you track lives in **`grind.db`** (SQLite, in the repo folder, gitignored).
It survives clearing browser data, reinstalls, and moving machines.

```bash
cp grind.db grind.db.backup          # back it up
sqlite3 grind.db 'SELECT data FROM state;'   # inspect it (data is one JSON blob)
```

The browser also mirrors state to `localStorage` as an offline cache for when the
server isn't running.

---

## Troubleshooting

- **`SQLite is an experimental feature` warning** — expected on Node 22–23; harmless.
- **Blank page / can't connect** — is the server running? `npm start`, or check the
  service log. On a custom port, make sure you're hitting the right one.
- **502 from nginx** — the node app isn't up on `127.0.0.1:47417`, or it bound IPv6
  only; `server.mjs` pins `127.0.0.1` to avoid this.
- **`.dev` won't load over HTTP** — `.dev` is HSTS-preloaded (forced HTTPS). Use
  `.test` for local work, as above.

---

## How it works

A tiny Node server (`server.mjs`) owns `grind.db` and serves the single-page app
(`index.html`). The page auto-syncs every change to `PUT /api/state`, so the data
lives outside the browser. Fonts load from Google Fonts; sound is synthesized with
the Web Audio API. No build step, no framework, no dependencies.
