# Documentation Index

| Document | Purpose |
| --- | --- |
| `README.md` | Full ClawVM architecture, Docker and sndbx operation, updates, backup, and diagnostics. |
| `GETTING_STARTED.md` | Short first-run Docker Compose and OpenClaw installation path. |
| `commands.md` | Common operator commands. |
| [data/openclaw_update.md](data/openclaw_update.md) | One-command update inside either VM or from its host, user switching, backup scope, verification, and failure recovery; accompanies the distributed `data/openclaw_update.sh`. |
| `SAMBA_SETUP.md` | Host Samba and POSIX ACL configuration for the workspace only. |
| `TEST.md` | Build, runtime, portability, Samba, and sndbx verification protocol. |
| [proposal_vmupdate1.md](proposal_vmupdate1.md) | Proposed standard OpenClaw deployment and update architecture: verified problems, Kata/systemd test results and limitations, alternatives, phased migration, acceptance criteria, and open decisions; not an implemented operating procedure. |
| `sndbx.overlay.json5` | sndbx sandbox overlay; the host merges it under the root configuration. |
| [data/.openclaw/workspace/AGENTS.md](data/.openclaw/workspace/AGENTS.md) | Local OpenClaw agent description, unique to each instance; ignored by Git, not distributed, and potentially absent in a fresh checkout. |
| [data/.openclaw/workspace/SYSTEM_DESCRIPTION.md](data/.openclaw/workspace/SYSTEM_DESCRIPTION.md) | Versioned, distributed reference for VM behavior, resources, external interactions, safety, complete installed-program inventory and invocation examples; identical across forks using the same software baseline and not editable by runtime agents. |