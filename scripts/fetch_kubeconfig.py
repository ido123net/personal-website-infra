#!/usr/bin/env python3
"""Fetch the cluster admin config over SSH, without printing private keys."""

import argparse
import os
import re
import subprocess
from pathlib import Path

import yaml


def prepare_config(raw: str, port: int) -> dict:
    config = yaml.safe_load(raw)
    if not isinstance(config, dict) or len(config.get("clusters", [])) != 1:
        raise ValueError("Expected a single-cluster K3s kubeconfig")
    if not 1024 <= port <= 65535:
        raise ValueError("Use an unprivileged local port between 1024 and 65535")
    config["clusters"][0]["name"] = "personal-platform"
    config["clusters"][0]["cluster"]["server"] = f"https://127.0.0.1:{port}"
    if len(config.get("users", [])) != 1:
        raise ValueError("Expected one K3s user")
    config["users"][0]["name"] = "personal-platform-admin"
    config["contexts"] = [
        {
            "name": "personal-platform",
            "context": {"cluster": "personal-platform", "user": "personal-platform-admin"},
        }
    ]
    config["current-context"] = "personal-platform"
    return config


def write_private(destination: Path, content: str):
    destination.parent.mkdir(parents=True, exist_ok=True)
    # Do not follow a symlink or overwrite an existing config by accident.
    fd = os.open(destination, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w") as output:
        output.write(content)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("host", help="SSH target, for example platform@192.0.2.10")
    parser.add_argument("--port", type=int, default=6445)
    parser.add_argument("--output", type=Path, default=Path("~/.kube/personal-website-infra.yaml"))
    args = parser.parse_args()
    if not re.fullmatch(r"[a-z_][a-z0-9_-]*@[A-Za-z0-9.-]+", args.host):
        parser.error("Use user@host (no SSH options or shell syntax)")
    result = subprocess.run(
        [
            "ssh",
            "-o",
            "StrictHostKeyChecking=yes",
            args.host,
            "sudo -n /usr/local/bin/k3s kubectl config view --raw",
        ],
        capture_output=True,
        text=True,
        check=True,
    )
    config = prepare_config(result.stdout, args.port)
    destination = args.output.expanduser().absolute()
    write_private(destination, yaml.safe_dump(config, sort_keys=False))
    print(f"Private kubeconfig saved to {destination}")
    print(f"Start a tunnel: ssh -N -L 127.0.0.1:{args.port}:127.0.0.1:6443 {args.host}")


if __name__ == "__main__":
    main()
