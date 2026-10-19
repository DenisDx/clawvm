WARNIG! THE PROPOSAL IS CURRENTLY CANCELED

ARCHIVIED

# Proposal: standard OpenClaw operation and updates

**Date:** 2026-10-18  
**Scope:** ClawVM and its local `denis_obsidian_assistant` fork  
**Status:** architecture proposal; migration is not implemented

## 1. Executive summary

The objective is to make OpenClaw work through its supported installation,
service-management, and update mechanisms, without routine manual process
control or version-specific deployment workarounds.

The current deployment combines a writable, home-installed OpenClaw package
with an immutable container image and a custom shell supervisor. It is neither
a complete native Linux managed-service installation nor the official
image-managed OpenClaw container deployment. This mixed ownership caused the
update difficulties described below.

**Recommended direction:**

1. Investigate documented, supported cgroup delegation for systemd under the
   existing Kata runtime in an isolated test, with an explicit stopping point.
2. Retain Kata only if native service management, `docker exec`, and all three
   OpenClaw update entry points pass end-to-end tests without unacceptable
   privilege changes or a custom service-manager shim.
3. If this cannot be demonstrated, choose between:
   - a conventional Linux VM with systemd, preserving native in-app updates; or
   - the official container-image model, keeping host-owned image updates but
     explicitly accepting that in-place OpenClaw updates are not the deployment
     contract.

The existing test **did not pass** the Kata compatibility gate. It does not
prove that systemd is universally incompatible with Kata.

This proposal supersedes the earlier suggestion to create a bespoke updater
script as the permanent solution. The current manual maintenance instructions
remain the operational reference until a replacement is implemented and tested.

## 2. Requirements and boundaries

### Required outcome

- Routine updates should not require manually selecting Node paths, exporting
  npm prefixes, killing processes, or repairing file modes.
- For a native-installation solution, support:
  - `openclaw update` from an independent user terminal;
  - the existing OpenClaw Control UI update button;
  - the agent's native `gateway` tool with `action: "update.run"`.
- Preserve the Gateway, channels, agent state, documents, browser tools, SSH,
  HTTPS access, and each instance's configuration.
- Use disk-backed storage for large downloads, package staging, snapshots,
  backups, and conversion output.
- Keep update ownership explicit and failure reporting accurate.
- Preserve VM isolation. OpenClaw and its agents must run as the non-root
  `clawvm` account, even if the guest service manager runs as root.

### Scope and approval boundaries

- Shared implementation belongs in ClawVM. The Obsidian checkout is a local
  fork, not a separate published repository; never commit its private changes.
- Preserve ClawVM's UID/GID 1000 and Obsidian's UID/GID 1002 unless a separate
  migration is explicitly approved.
- Preserve the Obsidian and Agents_shared mounts, published ports, local
  scripts, and ClawVM's additional dashboard.
- Keep each instance's AGENTS.md local, unique, and untracked.
  SYSTEM_DESCRIPTION.md remains distributed system documentation.
- Changing sndbx's backend, active root configuration, host runtime settings,
  capabilities, or isolation policy requires explicit scope approval.
- No privileged mode, host Docker socket, host PID namespace, host systemd bus,
  or writable host cgroup mount may be introduced merely to make a test pass.

## 3. Current deployment and operational state

The following facts were observed on 2026-10-18; they are not guarantees about
subsequent operator changes.

| Area | Observed state |
| --- | --- |
| Platform | Docker workloads isolated through Kata; not conventional OS VMs booted directly into systemd |
| Gateway lifecycle | Bash is PID 1; a custom loop starts/restarts the Gateway; the same startup script runs Caddy |
| Service manager | No systemctl, loginctl, or D-Bus daemon in the production image; no XDG_RUNTIME_DIR |
| Cgroups | Guest-visible cgroup v2 mount is read-only |
| OS storage | Read-only root filesystem; writable persistent home bind mount |
| Temporary storage | Running Obsidian `/tmp` is a 512 MiB tmpfs; both project templates specify 64 MiB |
| OpenClaw package | Persistent home installation, separate from the image's Node/npm and dispatcher |
| Runtime selection | Multiple image/home Node and launcher paths; image dispatcher searches versioned directories |
| Current Obsidian version | CLI and live Gateway verified as 2026.10.4 after the successful supervised update |
| Current ClawVM state | Stopped; it was not activated by the update or feasibility test |
| Host lifecycle | sndbx uses `docker exec` for guest commands and image startup hooks |
| Stop deadline | sndbx requests Docker's 360-second shutdown allowance through a wrapper defaulting to a 30-second subprocess timeout |

Relevant implementation surfaces:

- [Dockerfile](Dockerfile)
- [Compose deployment](docker-compose.yml)
- [sndbx template](config.sndbx.json5)
- [Image entrypoint](docker/entrypoint.sh)
- [Startup example](data/config/start.sh.example)
- [OpenClaw image dispatcher](docker/openclaw)
- [Environment loader](docker/load-clawvm-env.sh)
- [Image lifecycle hook](app.py)
- [sndbx lifecycle implementation](../../src/sandbox.py)

The local active startup scripts are not interchangeable with the example:
ClawVM has an additional dashboard, while Obsidian has its own startup behavior.
They must be inventoried and migrated, not overwritten wholesale.

## 4. Problems: evidence, impact, and required correction

| ID | Verified finding | Impact | Required correction |
| --- | --- | --- | --- |
| P1 | Under the image Node runtime, npm selected `/usr/local`, while OpenClaw lived in home storage. | `global-install-foreign-destination`; the updater refused the image-owned launcher. | One recognized installation, stable user-owned prefix, and consistent CLI/service runtime selection. |
| P2 | Persistent npm/npx scripts lacked owner execute permission. | Owner execution failed despite a named ACL entry granting execute. | Correct initial package ownership/modes and prevent deployment tools from damaging them. The specific two-file repair is already complete. |
| P3 | All 10,032 inventoried package files matched baseline hashes but differed in executable status. | The updater classified content-identical files as local overrides and preserved thousands of files during the stalled activation. | Stop broad permission rewrites. Baseline-verified executable bits were repaired with approval; do not repeat this as routine update logic. |
| P4 | `/tmp` was a small RAM-backed mount, while update scratch estimates approached 3 GB. | Capacity risk for staging/snapshots. This was a warning, not proof that `/tmp` caused the activation stall. | Writable disk-backed scratch with space checks and cleanup. Removing the mount alone would expose read-only `/tmp`. |
| P5 | The custom Gateway supervisor is not a supported OpenClaw-managed service. | Doctor encountered `gateway-lifecycle` contention; native service shutdown/restart could not be assumed. | Use a supported native service manager, or explicitly assign updates to the container deployment owner. |
| P6 | The interrupted updater retained the old package under a recovery name, leaving the normal path absent. | The old Gateway could still serve HTTP while the CLI launcher was broken. | Respect upstream recovery ownership; verify package integrity and live version, not HTTP alone. |
| P7 | Doctor hardened private state permissions and masked host-user ACL access. | Host Git access to documentation below `.openclaw` was blocked. | Separate distribution source/shared documents from private runtime state; do not fight private-state hardening on every update. |
| P8 | The outer stop-command timeout is shorter than Docker's requested shutdown allowance. | A graceful shutdown can appear to fail before its permitted drain completes. | Align service, Docker, and sndbx deadlines and test termination end-to-end. |
| P9 | Actual container mounts differ from project templates. | Updating templates alone cannot fix an already-created VM. | Migrate active deployment configuration and recreate mounts when required. |

The process that originally introduced every permission change was not
established. Do not attribute all damage to a specific script without evidence.
Audit startup, restore, deployment, and host-sharing operations before changing
their policy.

**Successful temporary workaround:** the Obsidian update from 2026.9.5 to
2026.10.4 completed with a cold backup, explicit disk scratch and npm prefix,
verified package-mode repair, exclusive maintenance, and a deployment restart.
This established recovery of the current instance, not a permanent fix for
native web UI or agent updates.

## 5. Why systemd installation alone did not solve it

### 5.1 Responsibilities that must coexist

Kata's runtime/guest agent starts container processes and places them in cgroups.
Systemd also uses cgroups to manage service processes. A working nested setup
needs a correctly delegated hierarchy: systemd must manage its services without
breaking the runtime's ability to create additional container processes.

Installing the systemd binaries does not establish that delegation, create a
working user manager/D-Bus session, or prove update handoff compatibility.

### 5.2 Isolated test results

The test image added Debian systemd 252, systemd-sysv, dbus-user-session, and
libpam-systemd to the existing ClawVM image. No production data or channel
credentials were mounted. An isolated disk-backed directory was used for one
diagnostic run; no host control sockets or production mounts were exposed.

| Test | Result | What it establishes |
| --- | --- | --- |
| Simple process under Kata | Succeeded | Kata could start an ordinary workload. |
| Systemd as PID 1 with default capabilities | Exited with code 255 | Package installation alone was insufficient. The early exit did not provide enough diagnostics to establish its exact cause. |
| Add only CAP_SYS_ADMIN, without changing the read-only cgroup mount | Still exited | That capability alone did not make the setup usable. |
| Requested private cgroup namespace, CAP_SYS_ADMIN, and remounted the existing guest cgroup2 mount read-write | Systemd stayed running, including with a read-only root | A systemd process can boot in this experimental setup; this is not service/update acceptance. |
| `docker exec` after that boot | Kata returned EBUSY while attaching a process to its Docker scope | The resulting configuration broke a management operation required by sndbx. |
| Docker stop of that test container | Completed with exit code 0 | Termination worked; this does not compensate for broken exec. |

The significant error was:

```text
failed to add process into unit docker-<container-id>.scope
System.Error.EBUSY: Failed to attach processes to control group:
Device or resource busy
```

**Observed:** process placement failed after systemd booted in the modified
cgroup setup.  
**Working explanation:** the inner service manager and Kata process placement
did not coexist correctly in that hierarchy.  
**Not yet proven:** the exact cgroup topology/controller condition causing
EBUSY, whether a supported delegation configuration resolves it, or whether
another supported Kata version behaves differently.

CAP_SYS_ADMIN is a broad capability, even inside a guest. Its use in a disposable
probe is not approval to add it to production. A requested private cgroup
namespace alone is also not a complete isolation assessment.

No privileged-mode or host-cgroup-access workaround was tested. A standalone
systemd user manager without systemd as PID 1 was not tested. Its viability must
not be assumed, nor rejected solely from the PID-1 experiment.

**Conclusion:** the tested configuration failed the gate; systemd is not proven
impossible under every Kata configuration. All disposable probe containers,
their image, and scratch data were removed. Neither production VM was migrated.

**Rollback verification, 2026-10-18 13:50 UTC:** at the user's request, both
production deployments and image identities were checked against the
pre-experiment baseline. No production migration changes required reversal.
Obsidian still uses Bash PID 1, a read-only cgroup mount, no added capabilities,
and no systemd packages. ClawVM remains stopped. The earlier successful
OpenClaw 2026.10.4 update and document-tool installation are intentionally
retained; they are outside the scope of this rollback request.

## 6. Architecture options

| Option | Update owner | CLI / existing UI / agent in-place updates | Scope and trade-off |
| --- | --- | --- | --- |
| A. Retain Kata with supported systemd/cgroup delegation | OpenClaw native updater | Intended; unverified until all tests pass | Best continuity if supported. Requires runtime investigation, safe delegation, working sndbx exec, and possibly launcher changes. |
| B. Conventional Debian/Ubuntu VM with systemd | OpenClaw native updater | Intended through upstream service handoff; still requires tests | Clearest native Linux model. Requires a real VM backend and lifecycle/storage/network integration outside the two image repositories. |
| C. Official OpenClaw container-image deployment under Kata | Host/sndbx replaces the image | Not the in-place update contract | Supported container model with less lifecycle ambiguity. Existing UI/agent actions cannot be claimed to own image replacement. |
| D. Custom updater script or systemd emulation | Our custom integration | Only through separately implemented behavior | Recreates responsibility for locking, snapshots, failures, restart, and future upstream changes. Not recommended as the target. |

### Option A: retain Kata only after a bounded feasibility investigation

- Record exact Docker, Kata, guest-kernel, cgroup, and systemd versions.
- Determine the actual nested cgroup topology and ownership; the EBUSY message
  is evidence to investigate, not a substitute for that inspection.
- Find a documented delegation configuration supported by the runtime.
- Test systemd and the `clawvm` user manager, D-Bus, persistence after logout,
  and systemctl access from both SSH and native update requests.
- Verify root and non-root `docker exec`, sndbx hooks, resource limits, clean
  shutdown, and absence of host-resource exposure.
- If it needs fabricated service markers, broad host access, runtime patches,
  or an undocumented boot shim, stop rather than extending the workaround.

Pass this gate before migrating state or claiming web UI update support.

### Option B: conventional Linux VM

Use a VM that boots its own OS and systemd normally, not systemd nested inside
the current Kata-managed container process hierarchy.

The additional platform work includes VM creation, virtual disks, networking and
port publication, shared-directory access, SSH/command transport, lifecycle,
resource limits, backup/restore, and sndbx status reporting. Existing Docker
methods cannot simply be reused unchanged. Do not build another custom
hypervisor manager if an established supported management stack fits.

Select the backend and approve its scope before implementation. Preserve the
application user and external interfaces; reassess the current read-only-root
requirement explicitly rather than silently abandoning it.

### Option C: official container-image updates

Base the deployment on the official image/entrypoint behavior, adding the
required document tools through a reproducible derived image if needed.
Preserve upstream activation and Doctor behavior instead of replacing it with
the current shell loop.

The host pulls/builds the new image and recreates the workload with the same
state/configuration mounts. Caddy and other unrelated services should not become
an alternative Gateway supervisor. Backups and migration checks remain required.

This is a legitimate standard deployment, but it changes the requested user
experience. An agent could only request an authorized host deployment operation
through a separately supported integration; that is not the native in-place
`update.run` action. Merely setting external-supervisor mode does not enable
self-update; the installed OpenClaw implementation explicitly disables it.

## 7. Target design for a native installation (A or B)

### Installation and service ownership

1. One recognized OpenClaw npm installation in a stable user-owned prefix.
2. One selected supported Node runtime for the CLI, Gateway, and updater;
   future runtime changes use the official installer or normal OS maintenance.
3. Persistent npm/service environment configuration, not per-update exports.
4. Gateway service generated by `openclaw gateway install` and maintained
   through OpenClaw's supported lifecycle.
5. Real user manager and D-Bus availability at boot and after logout.
6. Independent services for Caddy, SSH, and the ClawVM dashboard.
7. Retire obsolete launchers only after replacement installation/service checks.

The installed 2026.10.4 package already exposes the agent action
`gateway` / `update.run` for an owner-authorized or operator-scheduled request,
with managed handoff and completion notification. Prefer this action over a
shell process that tries to stop its own Gateway. Tool availability, requester
authorization, and handoff must all be tested in the final deployment.

### Storage and permissions

- Replace `/tmp` with a writable disk-backed mount and an explicit cleanup
  policy. Use conventional shared temporary-directory permissions where
  applicable; keep per-user scratch and backups private.
- Keep appropriately sized `/run` and `/dev/shm` for their normal purposes.
- Check free bytes and inodes on actual mounted filesystems; container-layer
  disk limits do not necessarily limit a writable home bind mount.
- Preserve package executable modes. Limit ownership correction to necessary,
  explicitly identified migration paths, not the whole home at every boot.
- Keep private runtime state private; restrict host-sharing ACLs to intended
  shared folders. Use authorized backup access for private state.
- Store distributed documentation in an accessible distribution source and,
  if needed, provision its copy into private runtime workspaces. Do not require
  Git to weaken OpenClaw's private directory permissions.
- Test atomic rename, file locking, fsync, SQLite WAL recovery, and lifecycle
  behavior on virtiofs/shared storage. Guest-local database storage is an option
  if those tests fail, not an unproven mandatory migration.

## 8. Phased implementation and decision gates

| Phase | Deliverable | Exit criterion |
| --- | --- | --- |
| 0. Baseline | Version/configuration inventory, resource limits, local customization inventory, backup and restore procedure | No secrets in reports; verified restorable baseline |
| 1. Runtime decision | Bounded Option A investigation or explicitly selected B/C | Supported lifecycle proven, or alternative and broader scope approved |
| 2. Isolated prototype | Reproducible guest/image, installation, services, disk scratch, permission policy | Normal startup and management work without manual repairs |
| 3. Update qualification | Actual released-version upgrade tests for each applicable entry point | Acceptance matrix below passes |
| 4. Migration rehearsal | Restored copy of representative state with outbound integrations disabled | State, plugins, tools, and rollback checks pass without contacting production channels |
| 5. Publication | Shared ClawVM changes and synchronized local Obsidian fork | Fork UID/GID, ports, mounts, scripts, and unrelated changes preserved |
| 6. Production cutover | Approved maintenance window, fresh backup, stop old owner, migrate once, start new owner | Live version, channels, SSH, HTTPS, storage, and resource checks pass |
| 7. Closeout | Short operational documentation and retained rollback materials | Routine operation no longer requires the manual workaround |

Expected image/project changes include Dockerfile, entrypoint/startup
provisioning, lifecycle hook, Compose and sndbx templates, permission/restore
scripts, documentation distribution, README, SYSTEM_DESCRIPTION, DOCUMENTS,
and TEST. The exact set depends on the selected option.

Changes to [sndbx lifecycle code](../../src/sandbox.py), its active configuration,
or host runtime/backend settings are additional scope. Editing a template alone
does not change an existing container's mounts or startup model.

## 9. Acceptance tests

Use isolated installations with synthetic state and compatible released version
pairs. Do not downgrade production state to manufacture a test.

| Test | Required result |
| --- | --- |
| Native CLI update (A/B) | Package update, migrations, managed restart, and live version verification without manual process control |
| Existing Control UI button (A/B) | Actual activation, normal reconnection, accurate update history |
| Native agent update.run (A/B) | Authorized request survives Gateway shutdown; completion notification arrives |
| Image replacement (C) | Upstream activation/Doctor behavior, compatible state, healthy new Gateway; no claim that native in-place actions replace the image |
| Requester disconnect | Closing SSH/browser does not abandon an admitted update owned by the manager |
| Concurrent update | Explicit refusal or serialization; no competing installation or database mutation |
| Download/disk failure | Honest failure, bounded cleanup, and preservation of the working installation when safe |
| Migration/activation failure | Explicit supported recovery outcome; no blind code rollback over migrated state |
| Process lifecycle | sndbx command execution/hooks, SSH, stop/start, and restart remain functional |
| Reboot/recreation/rebuild | Updated installation and state persist; no resurrection of obsolete launchers |
| Existing functionality | PDF/OCR, document Python environment, browser, shared mounts, dashboard, HTTPS, and required channels still work |
| Isolation | OpenClaw remains non-root; resource limits work; no host control interfaces are exposed |

For native updates, verify the installed version and the live Gateway's
`runtimeVersion`, for example through `openclaw gateway call status --json`.
HTTP 200, npm exit zero, a dry run, or an already-current no-op is not proof of
successful replacement, migration, or restart.

No web UI/agent end-to-end upgrade has yet passed under the proposed service
model. These are acceptance requirements, not completed results.

## 10. Backup, migration, and rollback safeguards

- Preserve package/runtime identity, persistent state, configuration, service
  definitions, ownership/ACL metadata, and deployment settings.
- Verify an actual restore into isolated storage before production cutover.
- Do not run two Gateways against the same writable database, or copied live
  credentials against the same external channel.
- Keep old image/runtime and matching pre-migration state together. Restoring
  old code alone over a newer database schema is not a safe rollback.
- Retain recovery artifacts until the acceptance checks and observation period
  are complete. Define retention instead of deleting all old data immediately.
- Do not delete locks, suppress failed checks, silently reset permissions, or
  automatically accept downgraded versions/new plugin capabilities.
- Preserve Obsidian-specific changes locally; publish only shared ClawVM work.
- Keep the stopped ClawVM instance stopped unless activation is approved.

## 11. Open decisions and limits

| Decision | Current position |
| --- | --- |
| Can supported Kata delegation preserve systemd and docker exec together? | Not established; the tested configuration failed |
| Can a supported systemd user-manager-only arrangement work? | Untested; no custom bootstrap should be adopted without evidence and lifecycle qualification |
| Is native web UI/agent updating mandatory? | It is the preferred goal; choosing C requires explicit acceptance of a different update owner |
| Which conventional VM backend would be used for B? | Not selected; requires separate platform design and approval |
| Can read-only root be retained? | Preferred where compatible; reevaluate explicitly for the chosen service model |
| Does database state need guest-local disk? | Decide from filesystem tests, not from assumption |
| What host/runtime capability changes are acceptable? | None approved for production by the feasibility test |

Future OpenClaw releases can require new Node versions, native libraries,
browsers, or OS facilities. Native application updates do not eliminate platform
maintenance. The goal is supported ownership and repeatable qualification, not
a guarantee that all unknown future releases will work unattended.

## 12. References and documentation ownership

- [Current operator instructions](README.md)
- [Current agent-facing system reference](data/.openclaw/workspace/SYSTEM_DESCRIPTION.md)
- [Existing verification protocol](TEST.md)
- [Documentation index](DOCUMENTS.md)
- [OpenClaw Gateway lifecycle and systemd setup](https://docs.openclaw.ai/gateway)
- [Official installer behavior](https://docs.openclaw.ai/install/installer)
- [OpenClaw update interface](https://docs.openclaw.ai/cli/update)
- [Updating and recovery](https://docs.openclaw.ai/install/updating)
- [Official container-image upgrades](https://docs.openclaw.ai/install/docker#upgrading-container-images)

Upstream documentation can advance beyond the installed release. Record exact
versions during implementation and verify behavior against those releases.
This proposal describes planned architecture and unresolved decisions; it must
not be read as a claim that the current machines already implement it.
