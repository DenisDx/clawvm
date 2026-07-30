#!/usr/bin/env python3
"""ClawVM lifecycle hooks executed by sndbx after container startup."""

import json
import os
import subprocess
import sys
from pathlib import Path


HOME_DIRECTORY = Path("/home/clawvm")
AUTHORIZED_KEYS_PATH = HOME_DIRECTORY / ".ssh" / "authorized_keys"


def load_context() -> dict:
    """Load the JSON context supplied by sndbx; exits when it is invalid."""
    raw_context = os.getenv("SNDBX_CONTEXT_JSON", "")
    try:
        context = json.loads(raw_context)
    except json.JSONDecodeError as error:
        print(f"invalid SNDBX_CONTEXT_JSON: {error}", file=sys.stderr)
        raise SystemExit(2) from error
    if not isinstance(context, dict):
        print("SNDBX_CONTEXT_JSON must contain an object", file=sys.stderr)
        raise SystemExit(2)
    return context


def ssh_keys(context: dict) -> list[str]:
    """Return unique non-empty SSH public-key lines from hook context."""
    configured_keys = context.get("ssh_keys", [])
    if not isinstance(configured_keys, list):
        return []
    return list(dict.fromkeys(
        key.strip() for key in configured_keys if isinstance(key, str) and key.strip()
    ))


def write_authorized_keys(keys: list[str]) -> None:
    """Write SSH keys for clawvm with permissions accepted by sshd."""
    AUTHORIZED_KEYS_PATH.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    AUTHORIZED_KEYS_PATH.write_text("\n".join(keys) + "\n", encoding="utf-8")
    os.chmod(AUTHORIZED_KEYS_PATH.parent, 0o700)
    os.chmod(AUTHORIZED_KEYS_PATH, 0o600)
    subprocess.run(
        ["chown", "-R", "clawvm:clawvm", str(AUTHORIZED_KEYS_PATH.parent)],
        check=True,
    )


def ensure_sshd() -> None:
    """Validate and start the configured SSH daemon when it is not running."""
    runtime_directory = Path("/run/sshd")
    runtime_directory.mkdir(mode=0o755, parents=True, exist_ok=True)
    host_key_path = runtime_directory / "ssh_host_ed25519_key"
    config_path = runtime_directory / "sshd_config"
    if not host_key_path.exists():
        subprocess.run(
            ["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", str(host_key_path)],
            check=True,
        )
    base_config = Path("/etc/ssh/sshd_config").read_text(encoding="utf-8")
    config_without_host_keys = "\n".join(
        line for line in base_config.splitlines() if not line.strip().startswith("HostKey")
    )
    config_path.write_text(
        f"{config_without_host_keys}\nHostKey {host_key_path}\n",
        encoding="utf-8",
    )
    subprocess.run(["/usr/sbin/sshd", "-t", "-f", str(config_path)], check=True)
    running = subprocess.run(["pgrep", "-x", "sshd"], check=False).returncode == 0
    if not running:
        subprocess.run(["/usr/sbin/sshd", "-f", str(config_path)], check=True)


def on_system_start(context: dict) -> int:
    """Apply configured SSH keys and ensure key-only SSH access is available."""
    keys = ssh_keys(context)
    if keys:
        write_authorized_keys(keys)
        print(f"on_system_start: wrote {len(keys)} SSH key(s) for clawvm")
    else:
        print("on_system_start: no ssh_keys configured; preserving authorized_keys")
    ensure_sshd()
    return 0


def main() -> int:
    """Dispatch the requested sndbx lifecycle hook."""
    hook_name = os.getenv("SNDBX_HOOK", "on_system_start").strip() or "on_system_start"
    if hook_name == "on_system_start":
        return on_system_start(load_context())
    print(f"unknown hook: {hook_name!r}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())