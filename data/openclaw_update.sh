#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

# Print an actionable error and exit; input: message; output: stderr.
fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

case "${1:-}" in
    --help|-h)
        printf 'Usage: bash /home/clawvm/openclaw_update.sh [--check]\n'
        printf 'Run from an independent root or clawvm terminal, never a Gateway tool.\n'
        exit 0 ;;
    --check|'') ;;
    *) fail "Unknown argument: $1 (use --help)." ;;
esac
(( $# <= 1 )) || fail 'Too many arguments (use --help).'
check_only="${1:-}"

app_home="$(getent passwd clawvm | cut -d: -f6)"
[[ "$app_home" == /home/clawvm ]] || fail 'Expected the clawvm account with home /home/clawvm.'
if (( EUID == 0 )); then
    script="$(readlink -f -- "${BASH_SOURCE[0]}")"
    [[ "$script" == "$app_home/openclaw_update.sh" ]] ||
        fail 'Run the distributed script at /home/clawvm/openclaw_update.sh inside the VM.'
    cd "$app_home"
    exec runuser -u clawvm -- bash "$script" "$@"
fi
[[ "$(id -un)" == clawvm && "$HOME" == "$app_home" ]] ||
    fail 'Run inside the VM as root or clawvm, with the correct HOME.'
cd "$HOME"
source /usr/local/lib/clawvm/load-env.sh
export PATH="$HOME/.openclaw/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
for command in python3 flock findmnt tar timeout ss getfacl pgrep; do
    command -v "$command" >/dev/null || fail "Required image tool is missing: $command."
done
[[ -x /usr/local/bin/node ]] || fail 'The image Node runtime is missing.'

# Inspect only this deployment's process tree; input: none; output: PID identities.
inspect_processes() {
    python3 - <<'PY'
import os
from pathlib import Path

def process(pid):
    """Read a process identity from its PID; return stat fields and argv."""
    path = Path("/proc") / str(pid)
    try:
        stat = (path / "stat").read_text().rsplit(") ", 1)[1].split()
        argv = (path / "cmdline").read_bytes().split(b"\0")
        uid = path.stat().st_uid
    except FileNotFoundError:
        return None
    return stat, argv, uid

gateways = []
for path in Path("/proc").iterdir():
    if path.name.isdigit():
        try:
            comm = (path / "comm").read_text().strip()
        except FileNotFoundError:
            continue
        if comm == "openclaw-gatewa":
            gateways.append(int(path.name))
if len(gateways) != 1:
    raise SystemExit("Expected exactly one running Gateway; start/repair this VM first.")
gateway = gateways[0]
g = process(gateway)
if not g or g[2] != os.getuid() or g[0][0] == "Z":
    raise SystemExit("Gateway is not a live process owned by clawvm.")
supervisor = int(g[0][1])
s = process(supervisor)
init = process(1)
expected = [b"bash", b"/home/clawvm/config/start.sh", b""]
if (supervisor == 1 or not s or not init or int(s[0][1]) != 1
        or s[2] != os.getuid() or s[1] != expected or init[1] != expected
        or s[0][0] in ("T", "t", "Z")):
    raise SystemExit("Unsupported or paused supervisor; expected the running config/start.sh loop.")
ancestor = os.getpid()
while ancestor > 1:
    if ancestor == gateway:
        raise SystemExit("Do not run this updater from a Gateway-owned tool; use SSH or docker exec.")
    entry = process(ancestor)
    if not entry:
        raise SystemExit("Could not verify the maintenance shell ancestry.")
    ancestor = int(entry[0][1])
print(gateway, g[0][19], supervisor, s[0][19])
PY
}

identities="$(inspect_processes)" || fail 'No processes were stopped.'
read -r gateway_pid gateway_birth supervisor_pid supervisor_birth <<< "$identities"
# Preserve the live Gateway's profile instead of guessing from the maintenance shell.
unset OPENCLAW_STATE_DIR OPENCLAW_CONFIG_PATH OPENCLAW_PROFILE OPENCLAW_GATEWAY_PORT
while IFS= read -r -d '' entry; do
    case "$entry" in
        OPENCLAW_STATE_DIR=*|OPENCLAW_CONFIG_PATH=*|OPENCLAW_PROFILE=*|OPENCLAW_GATEWAY_PORT=*)
            export "$entry" ;;
    esac
done < "/proc/$gateway_pid/environ"
[[ -z "${OPENCLAW_PROFILE:-}" ]] || fail 'Named profiles require a separately reviewed deployment.'
state="${OPENCLAW_STATE_DIR:-$HOME/.openclaw}"
config="${OPENCLAW_CONFIG_PATH:-$state/openclaw.json}"
[[ "$(readlink -f -- "$state")" == "$HOME/.openclaw" &&
   "$(readlink -f -- "$config")" == "$HOME/.openclaw/openclaw.json" ]] ||
    fail 'This updater supports the existing ~/.openclaw state and default config only.'
[[ ! -L "$state" && -d "$state" ]] || fail 'State must be a real persistent home directory.'
port="${OPENCLAW_GATEWAY_PORT:-18789}"
[[ "$port" =~ ^[0-9]+$ ]] && (( port > 0 && port < 65536 )) || fail 'Invalid Gateway port.'
runtime="$(readlink -f "$HOME/.openclaw/tools/node/bin/node")"
prefix="$(dirname "$(dirname "$runtime")")"
[[ "$prefix" == "$HOME"/.openclaw/tools/node-v* && "$(dirname "$prefix")" == "$HOME/.openclaw/tools" ]] ||
    fail 'Cannot identify the existing installer-owned npm prefix.'
cli="$prefix/lib/node_modules/openclaw/openclaw.mjs"
[[ -x "$runtime" && -f "$cli" && -O "$cli" ]] || fail 'Existing OpenClaw installation is incomplete or foreign-owned.'
export NPM_CONFIG_PREFIX="$prefix" npm_config_prefix="$prefix"
for tool in npm npx; do
    target="$prefix/lib/node_modules/npm/bin/$tool-cli.js"
    [[ "$(readlink -f "$prefix/bin/$tool")" == "$target" && -O "$target" ]] ||
        fail "Unexpected $tool launcher or ownership; no permissions changed."
    if [[ ! -x "$target" ]]; then
        printf 'Restoring owner execute permission on %s only.\n' "$target"
        chmod u+x -- "$target"
    fi
done
[[ "$(/usr/local/bin/node "$prefix/lib/node_modules/npm/bin/npm-cli.js" prefix -g)" == "$prefix" ]] ||
    fail 'npm did not select the persistent installation.'

maintenance="$HOME/.local/state/openclaw-maintenance"
mkdir -p "$maintenance"
[[ ! -L "$maintenance" && -O "$maintenance" ]] || fail 'Maintenance directory must be owned by clawvm and not a symlink.'
exec 9>"$maintenance/update.lock"
flock -n 9 || fail 'Another updater is running; wait for it to finish.'
run="$(mktemp -d "$maintenance/run.XXXXXXXX")"
chmod 0700 "$run"
mkdir "$run/tmp"
export TMPDIR="$run/tmp" TMP="$run/tmp" TEMP="$run/tmp"
case "$(findmnt -T "$TMPDIR" -n -o FSTYPE)" in
    ''|tmpfs|ramfs) fail "Disk-backed scratch is required; refused $run." ;;
esac
printf 'Maintenance records and backup: %s\n' "$run"
printf '%s %s\n' "$supervisor_pid" "$supervisor_birth" > "$run/supervisor"
getfacl -p "$state" > "$run/state-directory.acl"
state_mode="$(stat -c '%a' "$state")"
printf '%s\n' "$state_mode" > "$run/state-directory.mode"
paused=0
safe_to_resume=1

# Match PID start time, avoiding reused PIDs; inputs: PID, start time; output: status.
same_process() {
    local text tail
    local -a fields
    if ! text="$(cat "/proc/$1/stat" 2>/dev/null)"; then
        [[ ! -d "/proc/$1" ]] && return 1
        fail "Cannot read the identity of process $1."
    fi
    tail="${text##*) }"
    read -r -a fields <<< "$tail"
    [[ "${fields[19]}" == "$2" && "${fields[0]}" != Z ]]
}

# Verify that every OpenClaw SQLite store opens read-write after Gateway shutdown.
check_state_databases() {
    timeout --foreground 300 python3 - "$state" <<'PY'
import pathlib
import sqlite3
import sys

state = pathlib.Path(sys.argv[1])
databases = []
for pattern in ("*.sqlite", "state/*.sqlite", "agents/*/agent/*.sqlite"):
    databases.extend(state.glob(pattern))
failures = []
checked = 0
for database in sorted(set(databases)):
    if not database.is_file() or database.is_symlink():
        continue
    if database.name.endswith(("-lock.sqlite", "-writer.sqlite", "-quarantine.sqlite")):
        continue
    checked += 1
    try:
        connection = sqlite3.connect(f"file:{database}?mode=rw", uri=True, timeout=30)
        try:
            result = connection.execute("PRAGMA schema_version").fetchone()
        finally:
            connection.close()
    except Exception as error:
        failures.append(f"{database}: {error}")
        continue
    if result is None:
        failures.append(f"{database}: schema read returned no result")
for failure in failures:
    print(failure, file=sys.stderr)
if failures:
    raise SystemExit(1)
print(f"Checked {checked} OpenClaw SQLite store(s).")
PY
}

# Resume only the original verified supervisor; input: saved identity; output: status.
resume_supervisor() {
    same_process "$supervisor_pid" "$supervisor_birth" || {
        printf 'Original supervisor no longer exists; use the deployment operator.\n' >&2
        return 1
    }
    kill -CONT "$supervisor_pid"
    paused=0
}

# Preserve recovery evidence and resume only before mutation or after verified activation.
finish() {
    local status=$?
    trap - EXIT
    if (( paused && safe_to_resume )); then
        if ! resume_supervisor; then status=1; fi
    fi
    if (( status != 0 )); then
        printf 'Update failed. Records: %s\n' "$run" >&2
        if (( paused )); then
            printf 'Gateway remains stopped; supervisor %s remains paused. Do not restart the VM blindly.\n' "$supervisor_pid" >&2
            printf 'See /home/clawvm/openclaw_update.md, Recovery. No automatic database rollback was attempted.\n' >&2
        fi
    fi
    exit "$status"
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP

# Execute the selected package with fixed runtime/prefix; input: CLI arguments; output: CLI output.
openclaw_cli() {
    /usr/local/bin/node "$cli" "$@"
}

openclaw_cli --version
printf 'Checking the upstream update plan (no shutdown yet).\n'
timeout --foreground --signal=TERM --kill-after=60 600 \
    /usr/local/bin/node "$cli" update --dry-run --no-restart --json \
    > "$run/preview.json" 2> "$run/preview.log" ||
    fail "Preview failed; inspect $run/preview.log and preview.json."
target_version="$(python3 - "$run/preview.json" "${cli%/*}" <<'PY'
import json
import re
import sys
with open(sys.argv[1]) as file:
    plan = json.load(file)
if (not isinstance(plan, dict) or plan.get("dryRun") is not True
        or plan.get("root") != sys.argv[2] or plan.get("downgradeRisk") is not False
        or plan.get("run", {}).get("reason") != "dry-run"):
    raise SystemExit("Unexpected/refused preview or downgrade; inspect preview.json before updating.")
failures = plan.get("failures")
if failures:
    for failure in failures if isinstance(failures, list) else [failures]:
        if isinstance(failure, dict):
            reason = failure.get("reason", "unknown")
            message = failure.get("message", "")
        else:
            reason, message = "unknown", str(failure)
        print(f"Preview refusal [{reason}]: {message}", file=sys.stderr)
    raise SystemExit("Preview refused this update; resolve the listed checks before retrying.")
for note in plan.get("notes") or []:
    if isinstance(note, str) and "Would refuse update:" in note:
        print(f"Preview refusal: {note}", file=sys.stderr)
        raise SystemExit("Preview refused this update; resolve the listed checks before retrying.")
target = plan.get("targetVersion", "")
if not isinstance(target, str) or not re.fullmatch(r"\d+\.\d+\.\d+(?:-[a-zA-Z0-9.-]+)?", target):
    raise SystemExit("Preview has no supported exact package version.")
print(target)
PY
)" || fail 'The update plan was not accepted; Gateway was not stopped.'
printf 'Selected exact target: %s. Full plan: %s/preview.json\n' "$target_version" "$run"
if [[ "$check_only" == --check ]]; then
    printf 'CHECK PASSED. Gateway was not stopped; no package update was performed.\n'
    exit 0
fi
backup_bytes="$(du -sx -B1 "$state" | cut -f1)"
free_bytes="$(df -B1 --output=avail "$run" | tail -n 1 | tr -d ' ')"
(( free_bytes > backup_bytes * 2 + 6442450944 )) ||
    fail 'Insufficient disk space for the state backup and update (2x state size + 6 GiB required).'
[[ "$(inspect_processes)" == "$identities" ]] || fail 'Gateway changed during preflight; rerun.'
python3 - "$gateway_pid" > "$run/gateway-children.txt" <<'PY'
from pathlib import Path
import sys
processes = {}
for path in Path("/proc").iterdir():
    if path.name.isdigit():
        try:
            fields = (path / "stat").read_text().rsplit(") ", 1)[1].split()
        except FileNotFoundError:
            continue
        processes[int(path.name)] = (int(fields[1]), fields[19])
parents = {int(sys.argv[1])}
while True:
    children = {pid for pid, (parent, _) in processes.items() if parent in parents} - parents
    if not children:
        break
    for pid in children:
        print(pid, processes[pid][1])
    parents.update(children)
PY
printf 'Pausing supervisor %s and gracefully stopping Gateway %s.\n' "$supervisor_pid" "$gateway_pid"
paused=1
kill -STOP "$supervisor_pid"
same_process "$gateway_pid" "$gateway_birth" || fail 'Gateway changed before shutdown.'
kill -TERM "$gateway_pid"
deadline=$(( SECONDS + 360 ))
while same_process "$gateway_pid" "$gateway_birth"; do
    (( SECONDS < deadline )) || fail 'Gateway did not stop within 360 seconds; installation was not attempted.'
    sleep 1
done
while read -r child_pid child_birth; do
    if same_process "$child_pid" "$child_birth"; then
        printf 'Gracefully stopping remaining Gateway child %s.\n' "$child_pid"
        kill -TERM "$child_pid"
    fi
done < "$run/gateway-children.txt"
deadline=$(( SECONDS + 60 ))
while read -r child_pid child_birth; do
    while same_process "$child_pid" "$child_birth"; do
        (( SECONDS < deadline )) || fail "Gateway child $child_pid did not stop; installation was not attempted."
        sleep 1
    done
done < "$run/gateway-children.txt"
deadline=$(( SECONDS + 15 ))
while true; do
    listeners="$(ss -H -ltn "sport = :$port")" || fail 'Cannot inspect Gateway listeners.'
    [[ -z "$listeners" ]] && break
    (( SECONDS < deadline )) || fail 'Gateway port remains occupied; installation was not attempted.'
    sleep 1
done
printf 'Checking the OpenClaw SQLite stores after Gateway shutdown.\n'
check_state_databases || fail 'OpenClaw state has an unhealthy SQLite store; no backup or update was performed.'
printf 'Creating and validating a cold OpenClaw state/package backup.\n'
backup_paths=(.openclaw)
backup_excludes=()
findmnt --json -R "$HOME" > "$run/mounts.json"
python3 - "$run/mounts.json" "$HOME" > "$run/excluded-mounts.txt" <<'PY'
import json
import sys

def mounts(entries):
    """Yield mount targets from findmnt entries, including nested mounts."""
    for entry in entries:
        yield entry["target"]
        yield from mounts(entry.get("children", []))

with open(sys.argv[1]) as file:
    for target in mounts(json.load(file)["filesystems"]):
        if target.startswith(sys.argv[2] + "/.openclaw/"):
            print(target[len(sys.argv[2]) + 1:])
PY
while IFS= read -r mount; do
    backup_excludes+=("--exclude=$mount")
done < "$run/excluded-mounts.txt"
if [[ -d "$HOME/.config/openclaw" ]]; then backup_paths+=(.config/openclaw); fi
tar --acls --xattrs --one-file-system "${backup_excludes[@]}" \
    -cpf "$run/state.tar" -C "$HOME" "${backup_paths[@]}" \
    > "$run/backup.log" 2>&1 || fail "Backup failed; see $run/backup.log."
tar -tf "$run/state.tar" > "$run/backup-files.txt"
grep -Fx ".openclaw/openclaw.json" "$run/backup-files.txt" >/dev/null ||
    fail 'Backup is missing the OpenClaw configuration.'
grep -Fx "${cli#"$HOME/"}" "$run/backup-files.txt" >/dev/null ||
    fail 'Backup is missing the selected OpenClaw package.'
printf 'Updating the existing installation; detailed output is in update.log / update.json.\n'
safe_to_resume=0
if ! timeout --foreground --signal=TERM --kill-after=60 1800 \
    /usr/local/bin/node "$cli" update --tag "$target_version" --no-restart --timeout 300 --json \
    > "$run/update.json" 2> "$run/update.log"; then
    fail "Native updater failed or timed out; inspect $run/update.log and update.json."
fi
python3 - "$run/update.json" <<'PY'
import json
import sys
with open(sys.argv[1]) as file:
    result = json.load(file)
if result.get("status") != "ok":
    raise SystemExit("Native updater did not report status=ok; keep Gateway stopped for recovery.")
PY
openclaw_cli --version > "$run/installed-version.txt"
installed="$(/usr/local/bin/node -p 'require(process.argv[1]).version' "$prefix/lib/node_modules/openclaw/package.json")"
[[ -n "$installed" ]] || fail 'Updated package has no version.'
[[ "$installed" == "$target_version" ]] || fail 'Installed version does not match the previewed target.'
# chmod restores the existing ACL mask even when Kata cannot set POSIX ACLs.
[[ -d "$state" && ! -L "$state" && -O "$state" ]] || fail 'State directory identity changed during update.'
chmod "$state_mode" -- "$state"
safe_to_resume=1
resume_supervisor
printf 'Waiting up to 420 seconds for live Gateway health and version %s.\n' "$installed"
deadline=$(( SECONDS + 420 ))
healthy=0
while (( SECONDS < deadline )); do
    if timeout --foreground 25 /usr/local/bin/node "$cli" gateway call status --json \
        > "$run/gateway-status.json" 2> "$run/gateway-status.log" &&
       python3 - "$run/gateway-status.json" "$installed" <<'PY'
import json
import sys
with open(sys.argv[1]) as file:
    status = json.load(file)
sys.exit(0 if status.get("runtimeVersion") == sys.argv[2] else 1)
PY
    then
        if timeout --foreground 25 /usr/local/bin/node "$cli" gateway health \
            > "$run/gateway-health.txt" 2>&1; then
            healthy=1
            break
        fi
    fi
    sleep 5
done
if (( ! healthy )); then
    printf 'Live Gateway verification failed; pausing the supervisor and stopping the Gateway.\n' >&2
    if same_process "$supervisor_pid" "$supervisor_birth"; then
        kill -STOP "$supervisor_pid" 2>/dev/null || true
        paused=1
    fi
    safe_to_resume=0
    while read -r live_gateway_pid; do
        kill -TERM "${live_gateway_pid}" 2>/dev/null || true
    done < <(pgrep -x openclaw-gatewa 2>/dev/null || true)
    fail "Live Gateway verification failed; supervisor paused and Gateway stopped. Inspect $run/gateway-status.log and gateway-health.txt."
fi
printf 'SUCCESS: installed and live Gateway version %s; health check passed.\n' "$installed"
printf 'Backup and private logs retained in %s. Keep them until you verify your channels and workflows.\n' "$run"
