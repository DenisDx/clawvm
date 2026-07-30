# ClawVM

ClawVM is a small, portable virtual-machine template for one manually installed
OpenClaw instance. It runs the same image with Docker Compose or sndbx. OpenClaw
is not bundled into the image: install and update it with its official tools in
the VM.

The host `data/` directory is mounted as `/home/clawvm`. It is the complete
home directory of the fixed unprivileged `clawvm` user (`UID:GID 1000:1000`),
including OpenClaw configuration, credentials, plugins, local packages, and
workspace. Copying `data/` to another ClawVM checkout moves the instance.

## Safety model

The container root filesystem is read-only. `/tmp` and `/run` are ephemeral
tmpfs mounts. Do not install system packages in a running VM: update the
`Dockerfile`, rebuild the image, and recreate the service instead.

The shared host workspace is `data/.openclaw/workspace`. It is the only path
that Samba may publish. Never publish `data/` or `/home/clawvm` as a whole,
because both contain OpenClaw credentials and configuration. See
`SAMBA_SETUP.md` before enabling file sharing.

## Browser automation

The image includes pinned Playwright `1.62.0`, its Chromium browser, the
official Chromium Linux dependencies, Xvfb, fonts, and a `1 GiB` shared-memory
allocation. Browser binaries stay in the image at `/ms-playwright`; runtime
profiles, downloads, Fontconfig cache, and screenshots remain below the mounted
`/home/clawvm` directory.

Verify the installation from a ClawVM console:

```bash
playwright --version
playwright screenshot --device="Desktop Chrome" https://example.com /tmp/example.png
```

For Node scripts, import the globally installed package from
`/usr/local/lib/node_modules/playwright`. Playwright's normal container launch
uses `chromiumSandbox: false`; this works with Docker's default seccomp policy.
When browser automation visits untrusted sites and Chromium sandboxing is
required, configure the official Playwright seccomp profile in the deployment
and explicitly enable `chromiumSandbox: true`. Do not add `SYS_ADMIN` as a
general runtime capability.

## Docker Compose

```bash
cp .env.example .env
docker compose build
docker compose up -d
docker compose exec clawvm bash
```

The initial service is intentionally idle and console-accessible. In the shell,
install OpenClaw with its official current local-prefix installer. It uses the
already configured `HOME=/home/clawvm`:

```bash
curl -fsSL https://openclaw.ai/install-cli.sh | bash
openclaw --help
```

ClawVM resolves the installer-managed versioned CLI directory through its
stable `/usr/local/bin/openclaw` launcher. For an installation made with an
older ClawVM image, add the installer-managed CLI directory to the current
shell before using it:

```bash
export PATH="$HOME/.openclaw/bin:$PATH"
openclaw --help
```

The supplied startup script applies this path automatically after it is copied
to `~/config/start.sh`.

Create the persistent launch command after completing the OpenClaw setup:

```bash
cp ~/config/start.sh.example ~/config/start.sh
chmod 0750 ~/config/start.sh
exit
docker compose restart clawvm
```

The sample launch command keeps `openclaw gateway` on loopback port `18789` and
starts Caddy on HTTPS port `8880`. Caddy proxies the Control UI, HTTP endpoints,
and WebSocket through one origin, so no CORS configuration is needed.
`PLAYWRIGHT_SHM_SIZE` controls the Docker Compose Chromium shared-memory size
and defaults to `1gb`.

### LAN HTTPS Control UI

For an HTTPS URL reachable from the LAN, set the host machine's LAN IP in the
Compose `.env`, then recreate the service:

```text
CLAWVM_HTTPS_BIND_HOST=0.0.0.0
CLAWVM_HTTPS_HOST=192.168.1.111
CLAWVM_HTTPS_PORT=8880
CLAWVM_HTTPS_HOST_PORT=8880
```

Open `https://192.168.1.111:8880/` from a LAN client. Caddy uses its internal
certificate authority because a public CA cannot issue a certificate for a
private IP. Install Caddy's root certificate once on each trusted client before
opening the UI:

```bash
scp -P 2222 clawvm@192.168.1.111:.local/share/caddy/pki/authorities/local/root.crt ./clawvm-caddy-root.crt
```

Import `clawvm-caddy-root.crt` into that client's trusted root certificate
store, then connect. Treat the certificate as a trust anchor: distribute it
only through SSH or another authenticated channel, never through an untrusted
web download. OpenClaw still requires its normal gateway token and one-time
browser device approval for remote access.

Run `openclaw setup` in the VM before the first gateway start. Otherwise the
Gateway exits as unconfigured and Caddy returns an upstream error. In sndbx,
remove and recreate the sandbox after changing HTTPS port variables because
Docker cannot change published ports on an existing container.

## sndbx

Build the local image first:

```bash
docker build -t clawvm:latest .
```

Merge `config.sndbx.json5` into the root sndbx configuration and set
`CLAWVM_HOST_ROOT` to this checkout's absolute path. The template requires the
root sndbx feature `read_only_rootfs` and its `tmpfs` list. Start the `clawvm`
sandbox, then use an sndbx console to run the same OpenClaw installation steps
as in Docker Compose.
`CLAWVM_SHM_SIZE` controls Chromium shared memory in sndbx and defaults to
`1g`.

For LAN HTTPS in sndbx, set these root `.env` variables and recreate the
sandbox after rebuilding the image:

```text
CLAWVM_HTTPS_BIND_HOST=0.0.0.0
CLAWVM_HTTPS_HOST=192.168.1.111
CLAWVM_HTTPS_PORT=8880
CLAWVM_HTTPS_HOST_PORT=8880
```

Use the same `https://192.168.1.111:8880/` URL and Caddy root-certificate
installation procedure as Docker Compose.

### SSH access in sndbx

The sndbx lifecycle hook starts key-only SSH for `clawvm`. Add public keys to
the sandbox's `ssh_keys` list, then restart or recreate the sandbox:

```json5
ssh_keys: [
	"ssh-ed25519 AAAA... operator@example",
],
```

By default SSH is published only on `127.0.0.1:2222`. Connect from the host
with `ssh -p 2222 clawvm@127.0.0.1`. Set `CLAWVM_SSH_BIND_HOST` or
`CLAWVM_SSH_HOST_PORT` in the root sndbx `.env` only when a different exposure
is intentional. SSH provisioning is sndbx-only; Docker Compose does not run
the lifecycle hook. The hook never installs, updates, configures, or starts
OpenClaw.

## Updates and backup

To update the base operating system, Node.js, Python, or preinstalled tools,
update the Dockerfile and rebuild the image. To update OpenClaw, use OpenClaw's
official update/install flow inside the VM as `clawvm`. Do not use `apt upgrade`
inside a running instance.

Stop the service before a consistent backup, then copy `data/` while preserving
owners, groups, ACLs, extended attributes, and dotfiles. On Linux, for example:

```bash
docker compose stop clawvm
rsync -aAX --numeric-ids data/ /backup/clawvm-data/
```

Restore the directory to `data/` in a fresh checkout, preserve its metadata,
and start the same or a compatible ClawVM image.

## Diagnostics

```bash
docker compose ps
docker compose logs -f clawvm
docker compose exec clawvm bash
docker compose down
```

`commands.md` lists common operations. `GETTING_STARTED.md` is the shortest
first-run path.