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
Configure the sndbx stop grace to at least 360 seconds for an interactive VM
(the Obsidian assistant uses 360), and avoid stopping or updating during heavy
work. If already current, OpenClaw may refresh the same version rather than
upgrade.

No image rebuild, VM recreation, or normal host-side restart is needed.
The script does not make the Web UI update button work in this deployment;
use this script instead of the button or a bare `openclaw update`.

Optional preview without stopping the Gateway or installing packages:

```bash
bash /home/clawvm/openclaw_update.sh --check
```

## Why this VM does not use systemd

This VM has no usable systemd. The image starts OpenClaw through
`/home/clawvm/config/start.sh`, which declares itself as the external
supervisor (`OPENCLAW_SUPERVISOR_MODE=external`). OpenClaw therefore skips
native service management, its self-update path, and automatic inference-based
triage. Do not run `openclaw gateway start|stop|restart`, install a systemd
unit, or use the Web UI update button; those paths do not own this VM. The
external marker also disables a bare `openclaw update`; this script is the only
supported update path.

`start.sh` also has a bounded startup watchdog. If the Gateway process stays
alive without listening, it is terminated and retried with backoff instead of
waiting forever. Before starting OpenClaw it rolls back any hot SQLite journal
left by an unclean stop. The defaults are normally sufficient; they can be
tuned in `.env`:

| Variable | Default | Meaning |
| --- | --- | --- |
| `OPENCLAW_GATEWAY_STARTUP_TIMEOUT_SECONDS` | 600 | Time allowed to bind the Gateway port |
| `OPENCLAW_GATEWAY_DOWN_GRACE_SECONDS` | 120 | Time the port may stay down after being live |
| `OPENCLAW_GATEWAY_RETRY_MAX_SECONDS` | 300 | Maximum retry backoff |
| `OPENCLAW_GATEWAY_TERM_GRACE_SECONDS` | 20 | Grace before the watchdog forces a stuck process |

If the Gateway looks hung, first check whether it is still listening:
`ss -H -ltn 'sport = :18789'`. An alive process without a listener is a startup
failure, not an update in progress; the watchdog will restart it. `update.lock`
being present is normal: it is an advisory lock file and an empty stale file does
not block a later run. Do not delete it while an updater is running.

`openclaw gateway status` may print `no supported service manager detected` and
`Runtime: stopped` even while the Gateway is live. Those fields are diagnostic
only in this systemd-less VM. Trust `openclaw gateway health`, an actual listener
on `127.0.0.1:18789`, and the Web UI. Doctor may also warn that host process
visibility cannot be established from the container; that is expected under Kata
and is not an update failure.

The updater stops the Gateway gracefully. Set `stop_grace_seconds` in the VM's
sndbx overlay to at least 360 for an interactive workload (the Obsidian assistant
uses 360), matching OpenClaw's drain window. Do not lower it below the time your
workload needs.

## Stopping, restarting, and SSH

Use the sndbx Web UI or API stop/start/restart action for this VM; sndbx then
runs the image hook that configures SSH. Do **not** use `docker restart` on a
Kata VM: it can leave `docker exec` broken and may skip the sndbx start hook, so
sshd does not come back. If that already happened, run a full `docker stop`
followed by `docker start`, then invoke the normal sndbx start action (or its
start hook) so SSH is restored.

If a VM is force-stopped and leaves SQLite journals, the next `start.sh` recovers
the state stores before OpenClaw starts. Do not delete `-journal` or `-wal` files
by hand.

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

**SQLite preflight refusal:** after stopping the Gateway the updater opens the
OpenClaw state stores read-write. If one is unhealthy it refuses before backup
or installation, resumes the supervisor, and exits nonzero. Do not bypass this
check; repair or restore the store first.

**Failure during installation or live verification:** the Gateway stays stopped
and its restart loop stays paused to avoid starting an incomplete package or
entering a restart/triage loop. Keep the printed run directory. **Do not reboot/restart the VM, blindly rerun the updater, delete
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
