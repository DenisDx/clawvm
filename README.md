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

## Workspace agent instructions

[data/.openclaw/workspace/SYSTEM_DESCRIPTION.md](data/.openclaw/workspace/SYSTEM_DESCRIPTION.md)
is the shared agent-facing reference for VM behavior, storage, safety, installed
programs, and invocation examples. It includes the complete image-selected
package inventory, dependency-provided command-line tools, Python imports,
and known unusable wrappers. Keep it identical across forks of the same
read-only software baseline; agents inside the VM must not edit it.

[data/.openclaw/workspace/AGENTS.md](data/.openclaw/workspace/AGENTS.md)
is the per-instance agent entrypoint. The intended split keeps only machine
identity, local restrictions, and a link to the shared reference there.
Because this guide is read-only for repository agents, the exact proposed
replacement is recorded in
[data/.openclaw/workspace/AGENTS_.md](data/.openclaw/workspace/AGENTS_.md)
and **still requires manual application**. Until then, the original guide
retains its older common instructions; the companion is not automatically
loaded in its place. Preserve each fork's specific mount and permission rules.

Inside the VM, these files are at `/home/clawvm/.openclaw/workspace/`.
They are shared through the home bind mount, not baked into the image.
Documentation changes require no image rebuild. After manual application,
agents must load the shortened guide and its shared reference into their
instruction context.

## PDF, graphics, and document tools

The read-only image includes:

- Poppler (`pdftotext`, `pdftoppm`, `pdfinfo`, `pdfimages`), Ghostscript (`gs`),
  and `qpdf` for extraction, rendering, inspection, and rewriting PDFs.
- Tesseract OCR with English (`eng`), Russian (`rus`), and Thai (`tha`) data,
  plus Noto fonts for document rendering.
- Pandoc for document conversion, `rsvg-convert` for SVG rendering, and
  `vim-common` plus the separate Debian `xxd` package for hexadecimal inspection.
- `msmtp` for SMTP submission and `mbsync` (isync) for IMAP synchronization.
  No accounts, credentials, automatic polling, or mail services are configured.
  Keep account configuration in the persistent home with restrictive permissions;
  use TLS and your provider's supported authentication. OAuth2 providers may
  require a separate token helper. Do not put credentials into the image.

Pinned Python libraries include PyMuPDF (`pymupdf` / `fitz`), `pdfplumber`,
`pypdf`, Pillow, `python-docx`, `openpyxl`, Beautiful Soup, and `lxml`.
All dependencies are bundled as wheels under `/opt/document-tools` during the
build. Startup initializes the persistent environment at
`~/.local/share/document-tools/venv` offline, even when the home mount was empty
or already existed. It never uses `pip --user` or modifies system Python.

Use the dedicated launcher, which also initializes the environment if a
deployment overrides the normal entrypoint:

```bash
document-python -c 'import fitz, pdfplumber, pypdf; print("PDF libraries ready")'
document-python your_script.py
# Alternatively, activate the environment for an interactive session:
source ~/.local/share/document-tools/venv/bin/activate
```

The `venv` path is a symlink to an image-bundle-versioned environment. On a
bundle or Python-version change, initialization creates and checks a new
environment before switching the link; failure stops startup with an error.
Installation is serialized for concurrent callers. Existing versions are kept,
so rebuilds do not delete environments still used by running processes.
Treat this environment as image-managed: add permanent dependencies to
`docker/document-requirements.txt` and rebuild, or use a separate personal venv
for ad hoc packages.

Examples:

```bash
pdftotext -layout input.pdf output.txt
pdftoppm -r 150 -png input.pdf page
tesseract page-1.png stdout -l eng+rus+tha
qpdf --check input.pdf
pandoc input.docx -t markdown -o output.md
document-python /opt/document-tools/test-document-tools.py
```

Tesseract consumes raster images, not PDFs; rasterize scanned pages first.
Pandoc does not read arbitrary PDFs and does not reproduce complex Office
layouts exactly. This baseline does not include LibreOffice or OCRmyPDF.
Use a work directory below the persistent home for large documents: the
default `/tmp` is only 64 MiB. For tools with substantial temporary output,
create a home directory and set `TMPDIR` to it for that command.

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
chmod 0600 .env
docker compose build
docker compose up -d
docker compose exec clawvm bash
```

Replace `OPENCLAW_GATEWAY_TOKEN` in `.env` with a long random value before
starting. The private file is mounted read-only at `~/.env` and loaded for the
Gateway and interactive `clawvm` Bash sessions; it is ignored by Git.

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
It also listens on HTTP port `80` for clients that require plain HTTP/WebSocket;
the OpenClaw gateway token and device authorization still apply.
`PLAYWRIGHT_SHM_SIZE` controls the Docker Compose Chromium shared-memory size
and defaults to `1gb`.

In addition to the HTTPS endpoint, ClawVM publishes general-purpose ports
`8881` through `8885` with the same host and container port number. They use
the HTTPS bind host setting, so they remain loopback-only by default.

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

The same sandbox publication also reserves general-purpose ports `8881`
through `8885`, mapped identically on the host and in the VM.

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

If `data/` was copied without preserving its owners, permissions, or ACLs, run
the recovery script from the ClawVM checkout before starting the container:

```bash
sudo ./run_after_restore.sh
```

It restores the fixed ClawVM UID/GID (`1000:1000`), private data permissions,
the executable startup script, and the optional `clawvm-share` workspace ACL.
It does not modify file contents.

## Diagnostics

```bash
docker compose ps
docker compose logs -f clawvm
docker compose exec clawvm bash
docker compose down
```

`commands.md` lists common operations. `GETTING_STARTED.md` is the shortest
first-run path.