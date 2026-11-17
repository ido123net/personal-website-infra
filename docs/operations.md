# Operations and disaster recovery

## Routine maintenance

- Monitor `systemctl status k3s`, `kubectl get nodes,pods -A`, disk space, and `journalctl -u personal-cluster-backup.service`. Backup failures are visible in systemd; this small setup has no external alerting service.
- Install Ubuntu security updates regularly and schedule reboots. The single node will be unavailable during a reboot.
- Upgrade K3s deliberately: take a verified backup, change `k3s_version` in the ignored Ansible vars, read upstream compatibility notes, and rerun the playbook. Upgrade one supported minor release at a time. The binary checksum changes restart the server. Confirm pods and ingress recover.
- Upgrade cert-manager by changing its pinned chart version, checking compatibility with Kubernetes, then reviewing a Terraform plan. When changing the local issuer chart, bump its `Chart.yaml` version so Terraform schedules the Helm upgrade. Keep the CRDs when uninstalling cert-manager; do not delete app certificates casually.
- Do not share this Terraform state with an application repo. Local state is ignored; back it up in protected storage. A future remote backend should be chosen with the cloud provider. Helm account private keys never enter state, but cluster metadata still merits restricted access.

## Retention

Backups preserve all snapshots by default. Review a proposed retention policy before deleting any. To retain 7 daily, 4 weekly and 3 monthly snapshots for this cluster, use a transient unit with the protected environment:

```sh
sudo systemd-run --wait --pipe --property=EnvironmentFile=/etc/personal-infra/backup.env /usr/bin/restic snapshots --tag personal-control-plane
sudo systemd-run --wait --pipe --property=EnvironmentFile=/etc/personal-infra/backup.env /usr/bin/restic forget --tag personal-control-plane --group-by host,tags --keep-daily 7 --keep-weekly 4 --keep-monthly 3 --dry-run
# After reviewing the dry-run, repeat without --dry-run and add --prune.
```

Use a dedicated repository prefix; bucket lifecycle rules must not expire arbitrary restic objects. Restic manages its own content-addressed repository. Periodically run `restic check --read-data` through the same environment and perform a restore drill. Storage providers may charge for reads/requests.

## Restore a lost single-node cluster

1. Retrieve the restic password and storage credentials from your external secret store. Provision a fresh Ubuntu 24.04 host of the same architecture, with the same K3s version as the snapshot (check `config/k3s-version.txt`). Keep it out of live DNS initially.
2. Bootstrap the new host with Ansible, then stop K3s: `sudo systemctl stop k3s`. Do not run a fresh Kubernetes deployment over the restored state.
3. Install the protected backup environment/password and run restic `snapshots`, then `restore SNAPSHOT_ID --target /root/cluster-restore` using the systemd environment approach above. `SNAPSHOT_ID` must be an inspected snapshot tagged `personal-control-plane`. The restored tree contains `server/db/state.db`, `server/token`, optional `server/cred/encryption-config.json`, and `config/`.
4. With K3s stopped, move the **fresh host's** `/var/lib/rancher/k3s/server/db` aside. Create that directory mode 0700 and copy the restored `state.db` into it. Copy the restored `token` to `/var/lib/rancher/k3s/server/token` mode 0600. Restore `cred/encryption-config.json` if present, with its directory mode 0700 and file mode 0600. Restore `config/k3s-config.yaml` to `/etc/rancher/k3s/config.yaml` mode 0600. Restore `config/node-password` to `/etc/rancher/node/password` with root ownership and mode 0600 as well; otherwise the restored node-password Secret and the new host identity can disagree. Keep root ownership. Do not retain a stale SQLite WAL/SHM file beside the restored database.
5. Start K3s and inspect `journalctl -u k3s`, node readiness and all workloads. Restored application resources may immediately start; scale stateful apps down until their databases and volumes have been restored. A Kubernetes object in a backup is not its volume's contents.
6. Restore each application's data using its application-owned procedure. Restored local-path PVs reference the node name and paths; the bootstrap uses the stable name `personal-platform` to make replacement possible. Ensure actual data is restored at the expected path before restarting stateful workloads.
7. Fetch a fresh kubeconfig to a new protected filename, update the SSH tunnel, then confirm ingress locally with the application's Host header. Update live A records only after verifying the recovered app and its data. Repoint application Terraform to the recovered context, review a plan, and reconcile drift.

A backup is not a high-availability cluster. Recovery time depends on a new VPS and application data restores. Keep the original repository and passwords until the replacement is verified.
