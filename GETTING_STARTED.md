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
OPENCLAW_GATEWAY_PORT=18789
CLAWVM_HTTPS_BIND_HOST=127.0.0.1
CLAWVM_HTTPS_HOST=127.0.0.1
CLAWVM_HTTPS_PORT=8880
CLAWVM_HTTPS_HOST_PORT=8880
```

Both deployment modes also publish general-purpose ports `8881` through `8885`
with identical host and VM port numbers. They use `CLAWVM_HTTPS_BIND_HOST`, so
set it to `0.0.0.0` only when LAN access to those services is intended.

Create it from the tracked template before the first start. It contains
`OPENCLAW_GATEWAY_TOKEN`; replace its placeholder with a long random value and
do not commit the real file:

```bash
cp .env.example .env
chmod 0600 .env
```

### sndbx only

Use these steps when ClawVM is managed by sndbx:

```bash
cd /<pathto>/sndbx
docker build -t clawvm:latest images/clawvm
```

OR use webUI for building (sndbx restart may be required)

The active root `config.json5` already registers the `clawvm` sandbox and the
`clawvm-env-token` environment. Start the sandbox through the sndbx Web UI or
the existing MCP `sandbox_start` operation, then open an sndbx console for that
sandbox. When using a different sndbx installation, merge
`images/clawvm/config.sndbx.json5` into its root configuration and set
`CLAWVM_HOST_ROOT` to the absolute ClawVM checkout path.

sndbx-only port settings belong in the root sndbx `.env`:

```text
CLAWVM_GATEWAY_PORT=18789
CLAWVM_HTTPS_BIND_HOST=127.0.0.1
CLAWVM_HTTPS_HOST=127.0.0.1
CLAWVM_HTTPS_PORT=8880
CLAWVM_HTTPS_HOST_PORT=8880
CLAWVM_SSH_BIND_HOST=127.0.0.1
CLAWVM_SSH_HOST_PORT=2222
```

The same general-purpose ports `8881` through `8885` are published through the
configured `CLAWVM_HTTPS_BIND_HOST`.

For sndbx, create `images/clawvm/.env` from the same template. It is mounted
read-only at `~/.env` and loaded for the Gateway and interactive `clawvm` Bash
sessions:

```bash
cd images/clawvm
cp .env.example .env
chmod 0600 .env
```

The configured `CLAWVM_GATEWAY_PORT` must match the port used by
`data/config/start.sh`.

To enable key-only SSH, add public keys to `ssh_keys` in the `clawvm` sandbox
definition, restart the sandbox, then connect from the host:

```bash
ssh -p 2222 clawvm@127.0.0.1
```

This is an sndbx-only feature. It provisions SSH but does not install or start
OpenClaw.

## 2. Install OpenClaw in either mode

The Docker shell or sndbx console runs as `clawvm` with
`HOME=/home/clawvm`. The host `data/` directory is that home directory inside
the VM.

Run the official current local-prefix installer in the VM:

```bash
curl -fsSL https://openclaw.ai/install-cli.sh | bash
openclaw --help
```

The current ClawVM image provides a stable `openclaw` launcher that resolves
the installer-managed versioned CLI path. An existing container created before
that image rebuild needs this command in its current shell:

```bash
export PATH="$HOME/.openclaw/bin:$PATH"
openclaw --help
```

The supplied `start.sh.example` includes that path, so copying it after the
installation makes future starts work without rebuilding the current container.

Complete OpenClaw's own onboarding and configure the channels, authentication,
workspace, and gateway settings that you need.

Before the first gateway start, run its setup command. Without this, OpenClaw
exits with a missing-configuration error and Caddy has no upstream to proxy:

```bash
openclaw setup
```

## 3. Make OpenClaw start after restart

Run these commands in the VM in either deployment mode:

```bash
cp ~/config/start.sh.example ~/config/start.sh
chmod 0750 ~/config/start.sh
```

The supplied script uses gateway port `18789`. Edit `~/config/start.sh` when
your official OpenClaw setup uses a different documented command or port.
It restarts the Gateway automatically when OpenClaw stops or restarts it, while
Caddy remains available on port `8880`. Before recovery, it waits up to 10
seconds for an OpenClaw-managed replacement to bind the port; set
`OPENCLAW_GATEWAY_RESTART_GRACE_SECONDS` in `.env` to change that interval.

Restart using only the command appropriate for the selected mode:

```bash
# Docker Compose only
docker compose restart clawvm
```

For sndbx, restart the `clawvm` sandbox through its Web UI or existing MCP
stop/start operations. Do not use `docker compose` to control an sndbx-managed
sandbox.

## 4. Open the HTTPS Control UI

The default URL is `https://127.0.0.1:8880/` in both modes. The Gateway itself
stays on loopback port `18789`; Caddy provides the HTTPS endpoint and proxies
its UI and WebSocket as one origin.

For a LAN URL such as `https://192.168.1.111:8880/`, set
`CLAWVM_HTTPS_BIND_HOST=0.0.0.0` and set `CLAWVM_HTTPS_HOST` to the host LAN IP
in the `.env` for the selected deployment mode. Recreate the service or
sandbox. In sndbx, port bindings are immutable for an existing Docker
container, so the `clawvm` sandbox must be removed and created again instead
of only stopped and started. Install the Caddy root certificate once on each
trusted client:

```bash
scp -P 2222 clawvm@192.168.1.111:.local/share/caddy/pki/authorities/local/root.crt ./clawvm-caddy-root.crt

# OR copy it to the ~ folder for manual install
cp ~/.local/share/caddy/pki/authorities/local/root.crt ~/clawvm-caddy-root.crt
chmod 0644 ~/clawvm-caddy-root.crt
```

Import that certificate into the client trusted-root store before opening the
URL. Do not use insecure HTTP or disable OpenClaw device authentication.

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

----------------
# openclaw setup:

Run the OpenClaw setup wizard from the ClawVM console:

```bash
openclaw setup
```

For this deployment, keep the Gateway private and let Caddy provide HTTPS:

- Bind the Gateway to loopback (`127.0.0.1` or `loopback`).
- Use port `18789`, or the value configured as `OPENCLAW_GATEWAY_PORT`.
- Disable `gateway.tls`. Do not configure a certificate or private key in
	OpenClaw: Caddy terminates TLS on port `8880` and proxies to the loopback
	Gateway.
- Keep OpenClaw's normal token and browser-device approval enabled for remote
	Control UI access.

After the wizard, verify the resulting Gateway configuration includes the
following TLS setting:

```json5
{
	gateway: {
		tls: {
			enabled: false,
		},
	},
}
```

Open the Control UI only through Caddy at
`https://<CLAWVM_HTTPS_HOST>:8880/`. Do not expose the Gateway port directly,
and do not enable OpenClaw trusted-proxy mode: the supplied Caddyfile removes
forwarded headers and presents Caddy as a direct loopback client.