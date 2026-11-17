import os
import tempfile
import unittest
from pathlib import Path

from scripts.fetch_kubeconfig import prepare_config, write_private

RAW = """apiVersion: v1
kind: Config
clusters:
- name: default
  cluster:
    server: https://127.0.0.1:6443
    certificate-authority-data: FAKE-CA
users:
- name: default
  user:
    client-certificate-data: FAKE-CERT
    client-key-data: FAKE-KEY
contexts:
- name: default
  context:
    cluster: default
    user: default
current-context: default
"""


class KubeconfigTests(unittest.TestCase):
    def test_rewrites_only_endpoint_and_context_preserving_credentials(self):
        result = prepare_config(RAW, 6445)
        self.assertEqual(
            result["clusters"][0]["cluster"],
            {"server": "https://127.0.0.1:6445", "certificate-authority-data": "FAKE-CA"},
        )
        self.assertEqual(result["users"][0]["user"]["client-key-data"], "FAKE-KEY")
        self.assertEqual(result["contexts"][0]["context"]["cluster"], result["clusters"][0]["name"])
        self.assertEqual(result["current-context"], "personal-platform")
        for port in [0, 443, 65536]:
            with self.assertRaises(ValueError):
                prepare_config(RAW, port)

    def test_private_file_cannot_replace_existing_file_or_symlink(self):
        with tempfile.TemporaryDirectory() as folder:
            target = Path(folder) / "config"
            write_private(target, "FAKE-KEY")
            self.assertEqual(os.stat(target).st_mode & 0o777, 0o600)
            with self.assertRaises(FileExistsError):
                write_private(target, "changed")
            link = Path(folder) / "link"
            link.symlink_to(Path(folder) / "missing")
            with self.assertRaises(FileExistsError):
                write_private(link, "changed")
            self.assertEqual(target.read_text(), "FAKE-KEY")
