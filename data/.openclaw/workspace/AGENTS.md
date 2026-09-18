# ClawVM Agent Guide

You are running as the unprivileged `clawvm` user in a Debian Bookworm
container. Your home directory is `/home/clawvm`; it is a writable host mount
and is the only persistent area. Your current OpenClaw workspace is
`/home/clawvm/.openclaw/workspace`.

## Persistence and Write Locations

- Keep work, source checkouts, notes, generated artifacts, and user-facing
  files in the workspace or elsewhere below `/home/clawvm`.
- Persistent OpenClaw state: `/home/clawvm/.openclaw`.
- Persistent configuration and startup files: `/home/clawvm/config`.
- User-local tools: `/home/clawvm/.local/bin`.
- User caches: `/home/clawvm/.cache`.
- Caddy state and internal CA: `/home/clawvm/.local/share/caddy`.
- `/tmp` and `/run` are writable but ephemeral; do not store work there that
  must survive a restart.
- The container root filesystem is read-only. Do not use `apt`, write to
  `/usr`, `/etc`, or `/opt`, or try to install system packages at runtime.
- You have no sudo access. Request a base-image change when a missing system
  package is required.

## OpenClaw

- `openclaw` is available through `/usr/local/bin/openclaw`; it resolves the
  installer-managed CLI under `~/.openclaw/tools/node-*/bin/openclaw`.
- If OpenClaw has not been installed, run its official installer:
  `curl -fsSL https://openclaw.ai/install-cli.sh | bash`.
- The normal persistent startup script is `/home/clawvm/config/start.sh`.
  Create it from `/home/clawvm/config/start.sh.example` after setup and make
  it executable with `chmod 0750 ~/config/start.sh`.
- The configured Gateway is intentionally loopback-only at
  `127.0.0.1:${OPENCLAW_GATEWAY_PORT:-18789}`. Do not expose it directly or
  enable Gateway TLS: Caddy is the external TLS endpoint.
- Private runtime values are loaded from `/home/clawvm/.env`. Never print,
  copy, commit, or disclose its contents. It can contain Gateway credentials.
- The OpenClaw CLI path is also available through
  `~/.openclaw/bin`; use `export PATH="$HOME/.openclaw/bin:$PATH"` only for
  compatibility with an older image.

## HTTPS and Networking

- Caddy is installed as `caddy`. The startup script runs it with
  `/home/clawvm/config/Caddyfile`; create that file from
  `/home/clawvm/config/Caddyfile.example` if it is absent.
- Caddy serves HTTPS on `${CLAWVM_HTTPS_PORT:-8880}` and proxies the Gateway
  plus WebSocket traffic. Its certificate is signed by the Caddy internal CA.
- Do not add forwarded headers or OpenClaw trusted-proxy settings: the supplied
  Caddy configuration strips forwarded headers so the upstream stays direct
  loopback.
- Ports `8881` through `8885` may be published by the deployment for services
  you intentionally run. Confirm a listener with `ss -ltnp` before using one.
- Normal outbound networking is available. Use `curl`, `wget`, `git`, `ssh`,
  `rclone`, or `rsync` as needed, but do not send secrets or private workspace
  files to an untrusted destination.

## Browser Automation

- Playwright `1.62.0` and Chromium are preinstalled. Browser binaries live in
  the image at `/ms-playwright`; do not download a second browser copy.
- Run `playwright --version` to verify the CLI.
- Example: `playwright screenshot --device="Desktop Chrome" https://example.com /tmp/example.png`.
- For Node scripts, import Playwright from
  `/usr/local/lib/node_modules/playwright`.
- Use `chromiumSandbox: false` with the default Docker seccomp policy. Do not
  add `SYS_ADMIN` or weaken container isolation to support browsing.
- Store screenshots, downloads, browser profiles, and final artifacts below
  `/home/clawvm` when they need to persist.

## Installed Tools

- Development: Node.js with Corepack, npm, Python 3 with pip/venv/pipx,
  `gcc`, `g++`, `make`, `build-essential`, `pkg-config`.
- Source and text: `git`, `rg`, `fd`, `jq`, `yq`, `sed`, `awk`, `vim`, `nano`,
  `less`, `tree`, `file`, `diff`.
- Data and databases: `psql`, `mysql`, `sqlite3`, `redis-cli`.
- Network and diagnostics: `curl`, `wget`, `ssh`, `scp`, `rsync`, `rclone`,
  `dig`, `ping`, `nc`, `nmap`, `ss`, `lsof`, `strace`, `btop`, `htop`.
- Archives and crypto: `tar`, `zip`, `unzip`, `7z`, `gzip`, `bzip2`, `xz`,
  `zstd`, `age`, `openssl`, `gpg`.
- Shell and process control: Bash, `tmux`, `screen`, `parallel`, `entr`,
  `ps`, `pgrep`, `pkill`, `timeout`.
- Use `fd` instead of `fdfind`; the compatibility alias is already installed.

## SSH

- SSH client tools are available. SSH server access, when provided, is
  key-only for user `clawvm` and is managed by sndbx at deployment time.
- Never edit `/etc/ssh` or expect host keys under `/run` to persist.

## Operational Commands

```bash
# Identify the current identity, storage, processes, and network listeners.
id
df -h "$HOME" /tmp
ps aux
ss -ltnp

# Inspect OpenClaw and proxy status without revealing secrets.
openclaw --help
test -x ~/config/start.sh && sed -n '1,160p' ~/config/start.sh
test -f ~/config/Caddyfile && caddy validate --config ~/config/Caddyfile --adapter caddyfile

# Work in the persistent workspace.
cd ~/.openclaw/workspace
```

## Safety Rules

- Treat every file outside the workspace as potentially sensitive, especially
  `~/.env`, `~/.openclaw`, SSH material, Caddy state, and browser profiles.
- Do not delete, overwrite, rotate, or disclose credentials, OpenClaw state,
  gateway configuration, or certificates unless the user explicitly asks.
- Before a destructive command, inspect the target and confirm its scope.
- Keep changes focused on the user's task. Report commands run, files changed,
  validation performed, and blockers clearly.