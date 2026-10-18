# Commands

Run commands from the ClawVM checkout unless stated otherwise.

## Docker Compose

```bash
docker compose build
docker compose up -d
docker compose ps
docker compose logs -f clawvm
docker compose exec clawvm bash
docker compose restart clawvm
docker compose stop clawvm
docker compose down
```

## OpenClaw

Run these inside `docker compose exec clawvm bash`:

```bash
openclaw --help
openclaw gateway --help
curl -fsSL https://openclaw.ai/install-cli.sh | bash
```

Use OpenClaw's official documented update flow to update OpenClaw. The installed
files remain below `/home/clawvm`, which is the host `data/` directory.

For a shell in an existing container created before the stable launcher was
added:

```bash
export PATH="$HOME/.openclaw/bin:$PATH"
openclaw --help
```

## LAN HTTPS Control UI

Set the selected deployment's `CLAWVM_HTTPS_BIND_HOST=0.0.0.0` and
`CLAWVM_HTTPS_HOST=<host LAN IP>`, recreate it, then open:

```text
https://<host LAN IP>:8880/
```

Install the Caddy root certificate once per trusted client:

```bash
scp -P 2222 clawvm@<host LAN IP>:.local/share/caddy/pki/authorities/local/root.crt ./clawvm-caddy-root.crt
```

## Browser automation

```bash
playwright --version
playwright screenshot --device="Desktop Chrome" https://example.com /tmp/example.png
```

Chromium is preinstalled at the pinned Playwright version. `PLAYWRIGHT_SHM_SIZE`
defaults to `1gb` in Docker Compose; `CLAWVM_SHM_SIZE` defaults to `1g` in sndbx.
For a Node script, import Playwright from
`/usr/local/lib/node_modules/playwright`.

## Documents and email

Inside the VM:

```bash
pdftotext -layout input.pdf output.txt
pdfinfo input.pdf
pdftoppm -r 150 -png input.pdf page
tesseract page-1.png stdout -l eng+rus+tha
qpdf --check input.pdf
pandoc input.docx -t markdown -o output.md
rsvg-convert input.svg -o output.png
document-python -c 'import fitz, pdfplumber, pypdf, docx, openpyxl, bs4, PIL'
document-python /opt/document-tools/test-document-tools.py
msmtp --version
mbsync --version
```

`document-python` uses the image-managed persistent venv at
`~/.local/share/document-tools/venv`. It initializes offline from bundled wheels
and does not alter system Python. Use a separate venv for user-added packages.
For large conversions, set `TMPDIR` to a writable directory under home rather
than the default 64 MiB `/tmp`.

Mail clients are installed but unconfigured: no messages are sent and no
mailboxes are accessed until an account is explicitly configured. SMTP sending
and IMAP synchronization require provider credentials and TLS; some providers
also require an OAuth2 token helper.

## Base image update

Update `Dockerfile` or its base-image arguments, then rebuild and recreate:

```bash
docker compose build --pull
docker compose up -d --force-recreate
```

Do not run `apt upgrade` in the service.

## Backup and restore

```bash
docker compose stop clawvm
rsync -aAX --numeric-ids data/ /backup/clawvm-data/
rsync -aAX --numeric-ids /backup/clawvm-data/ data/
docker compose up -d
```

## Image baseline checks

```bash
docker compose exec clawvm bash -lc '
  id
  node --version
  python3 --version
  yq --version
  fd --version
  command -v psql mysql redis-cli
'
```

## sndbx

```bash
docker build -t clawvm:latest .
```

Merge `config.sndbx.json5` into the root configuration, set
`CLAWVM_HOST_ROOT`, then start the `clawvm` sandbox with the normal sndbx
operator command or UI.

With public keys configured in the sandbox's `ssh_keys` list, connect through
the default loopback publication:

```bash
ssh -p 2222 clawvm@127.0.0.1
```