"""Exercise actual SQLite snapshotting and encrypted restic backup/restore."""

import os
import shutil
import sqlite3
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/backup-cluster.sh"


@unittest.skipUnless(
    shutil.which("restic") and shutil.which("sqlite3") and shutil.which("flock"),
    "restore drill requires restic, sqlite3, and flock",
)
class BackupTests(unittest.TestCase):
    def test_consistent_snapshot_token_and_restore(self):
        with tempfile.TemporaryDirectory() as folder:
            base = Path(folder)
            server = base / "server"
            (server / "db").mkdir(parents=True)
            (server / "cred").mkdir()
            with sqlite3.connect(server / "db/state.db") as db:
                db.execute("CREATE TABLE records(value TEXT)")
                db.execute("INSERT INTO records VALUES ('cluster-state')")
            (server / "token").write_text("FAKE-CLUSTER-TOKEN")
            (server / "cred/encryption-config.json").write_text('{"fake":"encryption-key"}')
            node_password = base / "node-password"
            node_password.write_text("FAKE-NODE-PASSWORD")
            config = base / "k3s-config.yaml"
            config.write_text("secrets-encryption: true")
            password = base / "restic-password"
            password.write_text("a-test-only-password-with-at-least-32-characters")
            mock_k3s = base / "k3s"
            mock_k3s.write_text("#!/bin/sh\nprintf 'k3s version fixture\\n'\n")
            mock_k3s.chmod(0o700)
            env = {
                **os.environ,
                "RESTIC_REPOSITORY": str(base / "repository"),
                "RESTIC_PASSWORD_FILE": str(password),
                "RESTIC_CACHE_DIR": str(base / "cache"),
                "K3S_SERVER_DIR": str(server),
                "K3S_CONFIG_FILE": str(config),
                "K3S_NODE_PASSWORD_FILE": str(node_password),
                "K3S_BINARY": str(mock_k3s),
                "BACKUP_LOCK_FILE": str(base / "lock"),
                "BACKUP_STAGE_PARENT": str(base),
            }
            subprocess.run(["restic", "init"], env=env, check=True, capture_output=True)
            subprocess.run(["bash", str(SCRIPT)], env=env, check=True, capture_output=True)
            self.assertFalse(list(base.glob("personal-cluster-backup.*")))
            restored = base / "restore"
            subprocess.run(
                ["restic", "restore", "latest", "--target", str(restored)],
                env=env,
                check=True,
                capture_output=True,
            )
            self.assertEqual((restored / "server/token").read_text(), "FAKE-CLUSTER-TOKEN")
            self.assertEqual(
                (restored / "server/cred/encryption-config.json").read_text(),
                '{"fake":"encryption-key"}',
            )
            self.assertEqual((restored / "config/node-password").read_text(), "FAKE-NODE-PASSWORD")
            with sqlite3.connect(restored / "server/db/state.db") as db:
                self.assertEqual(
                    db.execute("SELECT value FROM records").fetchone(), ("cluster-state",)
                )
            # An unusable backup destination must fail, leaving no plaintext stage behind.
            env["RESTIC_REPOSITORY"] = str(base / "nonexistent-repository")
            failed = subprocess.run(["bash", str(SCRIPT)], env=env, capture_output=True)
            self.assertNotEqual(failed.returncode, 0)
            self.assertFalse(list(base.glob("personal-cluster-backup.*")))
