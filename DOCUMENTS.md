# Documentation Index

| Document | Purpose |
| --- | --- |
| `README.md` | Full ClawVM architecture, Docker and sndbx operation, updates, backup, and diagnostics. |
| `GETTING_STARTED.md` | Short first-run Docker Compose and OpenClaw installation path. |
| `commands.md` | Common operator commands. |
| `SAMBA_SETUP.md` | Host Samba and POSIX ACL configuration for the workspace only. |
| `TEST.md` | Build, runtime, portability, Samba, and sndbx verification protocol. |
| `config.sndbx.json5` | Mergeable sndbx sandbox template. |
| [data/.openclaw/workspace/AGENTS.md](data/.openclaw/workspace/AGENTS.md) | Per-instance agent entrypoint; intended to hold machine-specific rules and the shared-reference link. Manual application of the documented split is pending; read-only for repository agents. |
| [data/.openclaw/workspace/SYSTEM_DESCRIPTION.md](data/.openclaw/workspace/SYSTEM_DESCRIPTION.md) | Shared VM behavior, safety, complete installed-program inventory and invocation examples; identical across forks using the same software baseline and not editable by runtime agents. |
| [data/.openclaw/workspace/AGENTS_.md](data/.openclaw/workspace/AGENTS_.md) | Exact old and replacement text for shortening the protected agent guide and linking the shared reference; pending manual application, not an automatically loaded replacement. |