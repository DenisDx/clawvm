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

Create the persistent launch command after completing the OpenClaw setup:

```bash
cp ~/config/start.sh.example ~/config/start.sh
chmod 0750 ~/config/start.sh
exit
docker compose restart clawvm
```

The sample launch command runs `openclaw gateway` on
`OPENCLAW_GATEWAY_PORT` (default `18789`). Adjust it when OpenClaw's official
configuration requires a different documented startup command or port.

By default the published port binds to `127.0.0.1`. Change
`OPENCLAW_BIND_HOST` in `.env` only when intentional LAN access is required.
`PLAYWRIGHT_SHM_SIZE` controls the Docker Compose Chromium shared-memory size
and defaults to `1gb`.

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