#!/usr/bin/env python3
"""Test the updater against a fake Gateway in disposable, network-isolated containers."""

import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest
import uuid


ROOT = Path(__file__).resolve().parents[1]
MOCK_CLI = r"""
import fs from 'node:fs';
import http from 'node:http';
import {spawn, spawnSync} from 'node:child_process';
const home = process.env.HOME;
const manifest = new URL('./package.json', import.meta.url);
const version = JSON.parse(fs.readFileSync(manifest)).version;
const args = process.argv.slice(2);
const mode = fs.readFileSync(home + '/test-mode', 'utf8').trim();
if (args[0] === '--version') {
    console.log('OpenClaw ' + version);
} else if (args[0] === 'update') {
    if (args.includes('--dry-run')) {
        if (mode === 'preview-failure') process.exit(3);
        console.log(JSON.stringify({
            dryRun: true, targetVersion: '2026.10.5', downgradeRisk: false,
            root: home + '/.openclaw/tools/node-v24.19.0/lib/node_modules/openclaw',
            run: {reason: 'dry-run'}
        }));
    } else {
        if (process.getuid() === 0) throw Error('Updater must not run as root');
        if (!process.env.TMPDIR.startsWith(home + '/.local/state/')) throw Error('RAM scratch');
        if (process.env.NPM_CONFIG_PREFIX !== home + '/.openclaw/tools/node-v24.19.0') throw Error('Wrong prefix');
        fs.writeFileSync(home + '/update-called', 'yes');
        if (mode === 'update-failure') {
            console.log(JSON.stringify({status: 'error'}));
            process.exit(1);
        }
        fs.writeFileSync(manifest, JSON.stringify({version: '2026.10.5'}));
        fs.chmodSync(home + '/.openclaw', 0o700);
        console.log(JSON.stringify({status: 'ok'}));
    }
} else if (args[0] === 'gateway' && ['call', 'health'].includes(args[1])) {
    http.get('http://127.0.0.1:18789', response => {
        response.pipe(process.stdout);
    }).on('error', () => process.exit(1));
} else if (args[0] === 'gateway') {
    process.title = 'openclaw-gateway';
    spawn('sleep', ['360'], {stdio: 'ignore'});
    http.createServer((request, response) => {
        response.end(JSON.stringify({runtimeVersion: version}));
    }).listen(18789, '127.0.0.1');
    setInterval(() => {
        if (fs.existsSync(home + '/ancestry-request')) {
            fs.unlinkSync(home + '/ancestry-request');
            const result = spawnSync('bash', [home + '/openclaw_update.sh', '--check'], {encoding: 'utf8'});
            fs.writeFileSync(home + '/ancestry-result', JSON.stringify({code: result.status, error: result.stderr}));
        }
    }, 100);
} else {
    throw Error('Unexpected invocation: ' + args.join(' '));
}
"""


def command(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    """Run a bounded command with arguments; return captured text or raise."""
    return subprocess.run(args, text=True, capture_output=True, timeout=120, check=check)


class OpenClawUpdateTest(unittest.TestCase):
    """Exercise real user switching, process supervision, backup, and failure handling."""

    def setUp(self) -> None:
        """Create a synthetic persistent home and a disposable container per test."""
        self.temporary = tempfile.TemporaryDirectory(prefix=".openclaw-update-test-", dir=Path.home())
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name)
        self.container = "clawvm-update-test-" + uuid.uuid4().hex[:12]
        prefix = self.home / ".openclaw/tools/node-v24.19.0"
        for directory in ("bin", "lib/node_modules/openclaw", "lib/node_modules/npm/bin"):
            (prefix / directory).mkdir(parents=True, exist_ok=True)
        (self.home / ".openclaw/tools/node").symlink_to("node-v24.19.0")
        (self.home / ".openclaw/openclaw.json").write_text("{}")
        (prefix / "lib/node_modules/openclaw/openclaw.mjs").write_text(MOCK_CLI)
        (prefix / "lib/node_modules/openclaw/package.json").write_text('{"version":"2026.10.4"}')
        (prefix / "bin/node").write_text("#!/bin/sh\nexec /usr/local/bin/node \"$@\"\n")
        (prefix / "bin/node").chmod(0o755)
        for tool in ("npm", "npx"):
            target = prefix / f"lib/node_modules/npm/bin/{tool}-cli.js"
            target.write_text("#!/usr/bin/env node\nconsole.log(process.env.NPM_CONFIG_PREFIX);\n")
            target.chmod(0o755)
            (prefix / f"bin/{tool}").symlink_to(f"../lib/node_modules/npm/bin/{tool}-cli.js")
        launcher = self.home / ".openclaw/bin/openclaw"
        launcher.parent.mkdir()
        launcher.write_text('#!/bin/sh\nexec /usr/local/bin/node "$HOME/.openclaw/tools/node/lib/node_modules/openclaw/openclaw.mjs" "$@"\n')
        launcher.chmod(0o755)
        (self.home / "config").mkdir()
        (self.home / "config/Caddyfile").write_text("")
        shutil.copy2(ROOT / "data/openclaw_update.sh", self.home)
        shutil.copy2(ROOT / "data/config/start.sh.example", self.home / "config/start.sh")
        fake_proxy = self.home / ".openclaw/bin/caddy"
        fake_proxy.write_text("#!/bin/sh\nexec sleep infinity\n")
        fake_proxy.chmod(0o755)
        (self.home / "test-mode").write_text("success")
        (self.home / ".local/state").mkdir(parents=True)
        image = os.environ.get("CLAWVM_TEST_IMAGE", "clawvm:latest")
        # Match the image's existing clawvm UID without changing the shared image.
        command("docker", "run", "--rm", "--network", "none", "--user", "root",
                "--entrypoint", "sh", "-v", f"{self.home}:/fixture", image,
                "-c", "chown -R clawvm:clawvm /fixture")
        self.addCleanup(self.remove_container)
        mounts = []
        if self._testMethodName == "test_ram_scratch_refused":
            mounts = ["--tmpfs", "/home/clawvm/.local/state:rw,uid=1000,gid=1000,size=16m"]
        command("docker", "run", "-d", "--name", self.container, "--network", "none",
                "--runtime", os.environ.get("CLAWVM_TEST_RUNTIME", "runc"),
                "--read-only", "--user", "clawvm", "--tmpfs", "/tmp:rw,size=16m",
                "--tmpfs", "/run:rw,size=16m", "-v", f"{self.home}:/home/clawvm",
                *mounts, "--entrypoint", "bash", image, "/home/clawvm/config/start.sh")
        for _ in range(40):
            result = self.execute("bash", "-c", "ss -H -ltn 'sport = :18789'")
            if result.stdout.strip():
                break
            time.sleep(0.1)
        else:
            self.fail("Fixture Gateway did not start: " + command("docker", "logs", self.container).stdout)

    def remove_container(self) -> None:
        """Remove only this test's named container; report Docker failures."""
        command("docker", "rm", "-f", self.container)

    def execute(self, *args: str, user: str = "clawvm") -> subprocess.CompletedProcess[str]:
        """Run a command as the chosen fixture user and return its result."""
        return command("docker", "exec", "--user", user, self.container, *args, check=False)

    def update(self, *args: str, user: str = "root") -> subprocess.CompletedProcess[str]:
        """Invoke the real distributed updater in the fixture and return output."""
        return self.execute("bash", "/home/clawvm/openclaw_update.sh", *args, user=user)

    def test_root_update_and_backup(self) -> None:
        """Update as root, verify live activation and the pre-update archive."""
        state = str(self.home / ".openclaw")
        command("setfacl", "-m", "u:nobody:r-x", state)
        original_acl = command("getfacl", "-cp", state).stdout
        result = self.update()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("SUCCESS: installed and live Gateway version 2026.10.5", result.stdout)
        archives = list((self.home / ".local/state/openclaw-maintenance").glob("run.*/state.tar"))
        self.assertEqual(len(archives), 1)
        old = command("tar", "-xOf", str(archives[0]),
                      ".openclaw/tools/node-v24.19.0/lib/node_modules/openclaw/package.json")
        self.assertEqual(json.loads(old.stdout)["version"], "2026.10.4")
        self.assertEqual(command("getfacl", "-cp", state).stdout, original_acl)

    def test_clawvm_check_does_not_stop_or_update(self) -> None:
        """Preview as clawvm without package mutation or Gateway shutdown."""
        before = self.execute("ps", "-eo", "pid,comm").stdout
        result = self.update("--check", user="clawvm")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse((self.home / "update-called").exists())
        self.assertEqual([line for line in before.splitlines() if "openclaw-gatewa" in line],
                         [line for line in self.execute("ps", "-eo", "pid,comm").stdout.splitlines()
                          if "openclaw-gatewa" in line])

    def test_preview_failure_preserves_gateway(self) -> None:
        """Reject a failed preview without stopping the existing Gateway."""
        (self.home / "test-mode").write_text("preview-failure")
        result = self.update()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Preview failed", result.stderr)
        self.assertFalse((self.home / "update-called").exists())
        self.assertTrue(self.execute("bash", "-c", "ss -H -ltn 'sport = :18789'").stdout.strip())

    def test_update_failure_keeps_supervisor_paused(self) -> None:
        """Leave failed activation stopped and preserve its backup for recovery."""
        (self.home / "test-mode").write_text("update-failure")
        result = self.update()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Gateway remains stopped", result.stderr)
        self.assertFalse(self.execute("bash", "-c", "ss -H -ltn 'sport = :18789'").stdout.strip())
        self.assertTrue(list((self.home / ".local/state/openclaw-maintenance").glob("run.*/state.tar")))

    def test_unrelated_user_refused(self) -> None:
        """Reject a user other than root/clawvm before touching state."""
        self.home.chmod(0o755)
        result = self.update(user="nobody")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Run inside the VM as root or clawvm", result.stderr)

    def test_gateway_owned_invocation_refused(self) -> None:
        """Reject a tool shell descended from the Gateway being maintained."""
        (self.home / "ancestry-request").touch()
        for _ in range(80):
            if (self.home / "ancestry-result").exists():
                break
            time.sleep(0.1)
        result = json.loads((self.home / "ancestry-result").read_text())
        self.assertNotEqual(result["code"], 0)
        self.assertIn("Gateway-owned tool", result["error"])

    def test_ram_scratch_refused(self) -> None:
        """Reject a genuinely RAM-backed maintenance directory before installation."""
        result = self.update()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Disk-backed scratch is required", result.stderr)
        self.assertFalse((self.home / "update-called").exists())

    def test_concurrent_update_refused(self) -> None:
        """Reject an existing advisory lock without stopping the Gateway."""
        maintenance = self.home / ".local/state/openclaw-maintenance"
        maintenance.mkdir()
        with (maintenance / "update.lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            result = self.update()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Another updater is running", result.stderr)
        self.assertFalse((self.home / "update-called").exists())

    def test_backup_failure_resumes_gateway(self) -> None:
        """Resume the original supervisor when backup fails before installation."""
        (self.home / ".openclaw/openclaw.json").unlink()
        result = self.update()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Backup is missing", result.stderr)
        self.assertFalse((self.home / "update-called").exists())
        for _ in range(100):
            if self.execute("bash", "-c", "ss -H -ltn 'sport = :18789'").stdout.strip():
                break
            time.sleep(0.2)
        else:
            self.fail("Supervisor did not restore the Gateway after a backup failure.")


if __name__ == "__main__":
    unittest.main(verbosity=2)
