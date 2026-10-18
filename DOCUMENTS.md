# Documentation Index

| Document | Purpose |
| --- | --- |
| `README.md` | Full ClawVM architecture, Docker and sndbx operation, updates, backup, and diagnostics. |
| `GETTING_STARTED.md` | Short first-run Docker Compose and OpenClaw installation path. |
| `commands.md` | Common operator commands. |
| `SAMBA_SETUP.md` | Host Samba and POSIX ACL configuration for the workspace only. |
| `TEST.md` | Build, runtime, portability, Samba, and sndbx verification protocol. |
| `config.sndbx.json5` | Mergeable sndbx sandbox template. |
| [data/.openclaw/workspace/AGENTS.md](data/.openclaw/workspace/AGENTS.md) | Local OpenClaw agent description, unique to each instance; ignored by Git, not distributed, and potentially absent in a fresh checkout. |
| [data/.openclaw/workspace/SYSTEM_DESCRIPTION.md](data/.openclaw/workspace/SYSTEM_DESCRIPTION.md) | Versioned, distributed reference for VM behavior, resources, external interactions, safety, complete installed-program inventory and invocation examples; identical across forks using the same software baseline and not editable by runtime agents. |