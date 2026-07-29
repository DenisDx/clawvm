# Test Protocol

Run these checks from the ClawVM checkout after changing the image or deployment
configuration.

## 1. Build and baseline commands

```bash
docker compose build
docker compose run --rm --no-deps --entrypoint bash clawvm -lc '
  id
  node --version
  npm --version
  corepack --version
  python3 --version
  pipx --version
  yq --version
  fd --version
  playwright --version
  command -v psql mysql redis-cli
'
```

Expected: the user is `clawvm` with UID/GID `1000:1000`; all commands succeed;
`yq --version` identifies the Go implementation.

## 2. Playwright Chromium

```bash
docker compose run --rm --no-deps --entrypoint bash clawvm -lc '
  node - <<"NODE"
const { chromium } = require("/usr/local/lib/node_modules/playwright");
(async () => {
  const browser = await chromium.launch({ headless: true, chromiumSandbox: false });
  const page = await browser.newPage();
  await page.setContent("<title>browser-ready</title>");
  if (await page.title() !== "browser-ready") process.exit(1);
  await browser.close();
})().catch(error => { console.error(error); process.exit(1); });
NODE
'
```

Expected: Chromium launches as UID/GID `1000:1000` with the image's
`PLAYWRIGHT_BROWSERS_PATH` and the configured `1 GiB` shared-memory mount.

## 3. Read-only root and portable home

```bash
docker compose run --rm --no-deps --entrypoint bash clawvm -lc '
  test ! -w /etc
  mkdir -p ~/.openclaw/workspace
  printf "ok\n" > ~/.openclaw/workspace/.clawvm-smoke
  cat ~/.openclaw/workspace/.clawvm-smoke
'
test "$(cat data/.openclaw/workspace/.clawvm-smoke)" = ok
rm data/.openclaw/workspace/.clawvm-smoke
```

Expected: the root filesystem is not writable, while the host `data/` directory
contains the workspace file.

## 4. Blank startup fallback

Before creating `data/config/start.sh`, run:

```bash
docker compose up -d
docker compose exec clawvm bash -lc 'ps -o args= -p 1'
docker compose down
```

Expected: the service remains console-accessible and PID 1 is the entrypoint
fallback running `sleep infinity`.

## 5. OpenClaw persistence

Install OpenClaw with the official local-prefix installer, create an OpenClaw
workspace file, and configure `data/config/start.sh`. Stop the service, copy
`data/` with `rsync -aAX --numeric-ids`, restore it to another checkout, then
start that checkout. The configuration, workspace, installed OpenClaw files, and
startup command must remain available.

## 6. Samba workspace

Follow `SAMBA_SETUP.md`. Verify that a Samba-authorized host user can edit a file
created by OpenClaw and that OpenClaw can edit a file created through the Samba
share. Confirm the Samba share cannot browse `data/.openclaw/openclaw.json` or
other OpenClaw credential paths.

## 7. sndbx

Build `clawvm:latest`, merge `config.sndbx.json5`, and start the `clawvm`
sandbox. Verify that `/home/clawvm` is the only persistent writable mount,
`/tmp` and `/run` are tmpfs, `/dev/shm` has the configured `CLAWVM_SHM_SIZE`,
and the root filesystem is read-only. Repeat the portable-home, Chromium, and
gateway port checks from the Docker mode.