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

## Browser automation

```bash
playwright --version
playwright screenshot --device="Desktop Chrome" https://example.com /tmp/example.png
```

Chromium is preinstalled at the pinned Playwright version. `PLAYWRIGHT_SHM_SIZE`
defaults to `1gb` in Docker Compose; `CLAWVM_SHM_SIZE` defaults to `1g` in sndbx.
For a Node script, import Playwright from
`/usr/local/lib/node_modules/playwright`.

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