import os
import subprocess
import sys
import unittest
from pathlib import Path

import yaml


class BootstrapTests(unittest.TestCase):
    def test_firewall_preflight_rejects_locking_out_current_ssh_client(self):
        play = yaml.safe_load(
            (Path(__file__).resolve().parents[1] / "ansible/bootstrap.yml").read_text()
        )[0]
        task = next(
            task for task in play["pre_tasks"] if task["name"].startswith("Ensure the current SSH")
        )
        command = task["ansible.builtin.command"]["argv"][2]
        for peer, expected in [("198.51.100.10", 0), ("203.0.113.1", 1)]:
            result = subprocess.run(
                [sys.executable, "-c", command, "198.51.100.10/32"],
                env={**os.environ, "SSH_CONNECTION": f"{peer} 50000 192.0.2.10 22"},
                capture_output=True,
                check=False,
            )
            self.assertEqual(result.returncode, expected)

    def test_generated_system_configs_preserve_directive_boundaries(self):
        play = yaml.safe_load(
            (Path(__file__).resolve().parents[1] / "ansible/bootstrap.yml").read_text()
        )[0]
        files = {
            copy["dest"]: copy["content"]
            for task in play["tasks"]
            if "content" in (copy := task.get("ansible.builtin.copy", {}))
        }
        self.assertEqual(
            files["/etc/ssh/sshd_config.d/00-personal-platform.conf"].splitlines(),
            ["PasswordAuthentication no", "KbdInteractiveAuthentication no"],
        )
        self.assertEqual(
            files["/etc/modules-load.d/k3s.conf"].splitlines(), ["overlay", "br_netfilter"]
        )
        sysctls = dict(
            line.split("=", 1) for line in files["/etc/sysctl.d/90-k3s.conf"].splitlines()
        )
        self.assertEqual(sysctls["net.ipv4.ip_forward"], "1")
        # These values are required by the enabled protect-kernel-defaults flag.
        self.assertEqual(sysctls["vm.panic_on_oom"], "0")
        self.assertEqual(sysctls["vm.overcommit_memory"], "1")
        self.assertEqual(sysctls["kernel.panic"], "10")
        self.assertEqual(sysctls["kernel.panic_on_oops"], "1")
        for destination, content in files.items():
            with self.subTest(destination=destination):
                self.assertTrue(content.endswith("\n"))
