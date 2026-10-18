# Updating OpenClaw

## One command inside the running VM

From an independent **root or clawvm terminal** (SSH or Docker exec), run:

```bash
bash /home/clawvm/openclaw_update.sh
```

Root is switched to `clawvm` automatically. Keep the terminal open until the
script finishes. Do not launch it from an OpenClaw agent/tool session: stopping
that Gateway can terminate its own updater; the script rejects that invocation.

The script checks the current installation and update plan, locks out parallel
runs, pauses the existing restart loop, stops the Gateway gracefully, backs up
OpenClaw state and packages, updates the exact previewed version, resumes the
same restart loop, and verifies **live Gateway version and health**.
The Gateway is unavailable during backup/update. Caddy, SSH, and the VM stay up.
Graceful shutdown alone can take about 5.5 minutes while active work drains.
If already current, OpenClaw may refresh the same version rather than upgrade.

No image rebuild, VM recreation, or normal host-side restart is needed.
The script does not make the Web UI update button work in this deployment;
use this script instead of the button or a bare `openclaw update`.

Optional preview without stopping the Gateway or installing packages:

```bash
bash /home/clawvm/openclaw_update.sh --check
```

## Alternatively: one command on the host

For the existing Obsidian assistant:

```bash
docker exec --user root sndbx-denis-obsidian-assistant bash /home/clawvm/openclaw_update.sh
```

For ClawVM, replace `sndbx-denis-obsidian-assistant` with `sndbx-clawvm`.
If it is stopped, first start that existing VM through sndbx. Do not create
another Compose deployment or start a second Gateway.

## Backup, results, and failures

The printed run directory is under
`/home/clawvm/.local/state/openclaw-maintenance/run.*`. It contains `state.tar`,
the preview, update results/logs, and live health/version checks. All large files
use verified disk-backed storage, **never `/tmp`**. Allow free space of at least
twice the OpenClaw state size plus 6 GiB; old runs are not automatically deleted.

The archive preserves permissions and ACLs exposed by the guest filesystem;
keep host-side backups for full host ACL metadata. External
workspace mounts (listed in `excluded-mounts.txt`), symlink targets, the host's
deployment configuration, and its separately mounted `.env` are **not backed
up**. Keep the normal host backup for those. Stop other tools from modifying
OpenClaw state during maintenance. Logs and archives can contain private data;
do not publish them.
After success, only the top-level `.openclaw` directory's original mode is
restored, including the existing host ACL mask changed by Doctor's chmod.
Credential files keep their private permissions; no recursive reset is done.

**Success** is an explicit `SUCCESS` line with the installed/live version and
a zero exit code. Afterwards check your Web UI, channels, and normal workflows.

**Failure before installation:** the existing restart loop is resumed
automatically if it was paused; the script exits nonzero.

**Failure during installation:** the Gateway stays stopped and its restart loop
stays paused to avoid starting an incomplete package. Keep the printed run
directory. **Do not reboot/restart the VM, blindly rerun the updater, delete
locks, or restore only the old package over migrated databases.**
Use an independent host `docker exec --user root -it CONTAINER bash` shell for
operator-assisted recovery. Inspect `update.json` and `update.log`; recover a
complete installation and compatible state using the installed release's
supported repair procedure or a consistent host backup. Only then restart the
existing VM through sndbx and verify live health/version. The archive is
recovery evidence, not a promise that every future migration is reversible.

This script supports the current `clawvm` account, installer-owned prefix,
default `~/.openclaw` state, and `~/config/start.sh` loop. It deliberately refuses
unknown layouts, named profiles, changed supervisors, and downgrade previews.
If a future release needs a newer Node or OS library, update the image separately;
the script never changes the read-only system or installs a second OpenClaw.
