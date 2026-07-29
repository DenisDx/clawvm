# Getting Started

Choose one deployment mode for a ClawVM checkout: plain Docker Compose or
sndbx. Both modes mount the same `data/` directory as `/home/clawvm`, but do not
run both modes against the same `data/` directory at the same time.

## 1. Start ClawVM

### Docker Compose only

Use these commands when running ClawVM without sndbx:

```bash
cd /path/to/clawvm
cp .env.example .env
docker compose build
docker compose up -d
docker compose exec clawvm bash
```

Docker-only settings belong in `.env`:

```text
OPENCLAW_BIND_HOST=127.0.0.1
OPENCLAW_HOST_PORT=18789
OPENCLAW_GATEWAY_PORT=18789
```

### sndbx only

Use these steps when ClawVM is managed by sndbx:

```bash
cd /<pathto>/sndbx
docker build -t clawvm:latest images/clawvm
```

The active root `config.json5` already registers the `clawvm` sandbox and the
`clawvm-env-token` environment. Start the sandbox through the sndbx Web UI or
the existing MCP `sandbox_start` operation, then open an sndbx console for that
sandbox. When using a different sndbx installation, merge
`images/clawvm/config.sndbx.json5` into its root configuration and set
`CLAWVM_HOST_ROOT` to the absolute ClawVM checkout path.

sndbx-only port settings belong in the root sndbx `.env`:

```text
CLAWVM_BIND_HOST=127.0.0.1
CLAWVM_HOST_PORT=18789
CLAWVM_GATEWAY_PORT=18789
```

The configured `CLAWVM_GATEWAY_PORT` must match the port used by
`data/config/start.sh`.

## 2. Install OpenClaw in either mode

The Docker shell or sndbx console runs as `clawvm` with
`HOME=/home/clawvm`. The host `data/` directory is that home directory inside
the VM.

Run the official current local-prefix installer in the VM:

```bash
curl -fsSL https://openclaw.ai/install-cli.sh | bash
openclaw --help
```

Complete OpenClaw's own onboarding and configure the channels, authentication,
workspace, and gateway settings that you need.

## 3. Make OpenClaw start after restart

Run these commands in the VM in either deployment mode:

```bash
cp ~/config/start.sh.example ~/config/start.sh
chmod 0750 ~/config/start.sh
```

The supplied script uses gateway port `18789`. Edit `~/config/start.sh` when
your official OpenClaw setup uses a different documented command or port.

Restart using only the command appropriate for the selected mode:

```bash
# Docker Compose only
docker compose restart clawvm
```

For sndbx, restart the `clawvm` sandbox through its Web UI or existing MCP
stop/start operations. Do not use `docker compose` to control an sndbx-managed
sandbox.

## 4. Open the gateway

The default gateway URL is `http://127.0.0.1:18789/` in both modes. Change only
the Docker `.env` variables for Docker Compose, or only the root sndbx `.env`
variables for sndbx, then restart the selected deployment. Use a non-loopback
bind address only when intentional LAN access is required.

## 5. Share files safely in either mode

Your OpenClaw workspace is:

```text
data/.openclaw/workspace
```

Use `SAMBA_SETUP.md` to share only that directory with authorized host users.
Do not share the full `data/` directory.

## 6. Keep a backup

Stop the selected deployment before copying `data/`: use `docker compose stop
clawvm` for Docker Compose, or stop the `clawvm` sandbox through sndbx. Then
preserve ownership, ACLs, extended attributes, and dotfiles:

```bash
rsync -aAX --numeric-ids data/ /backup/clawvm-data/
```

Read `README.md` for updates, security boundaries, diagnostics, and detailed
deployment information.