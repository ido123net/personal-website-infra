#!/usr/bin/env bash
# This backs up control-plane state, not application databases or persistent volumes.
set -euo pipefail
umask 077
: "${RESTIC_REPOSITORY:?Set RESTIC_REPOSITORY in the protected backup environment}"
: "${RESTIC_PASSWORD_FILE:?Set RESTIC_PASSWORD_FILE in the protected backup environment}"
# Path overrides allow a restore drill against disposable local fixture data.
lock_file=${BACKUP_LOCK_FILE:-/run/lock/personal-cluster-backup.lock}
exec 9>"$lock_file"
flock -n 9 || exit 0
stage=$(mktemp -d "${BACKUP_STAGE_PARENT:-/var/tmp}/personal-cluster-backup.XXXXXX")
trap 'rm -rf -- "$stage"' EXIT
server=${K3S_SERVER_DIR:-/var/lib/rancher/k3s/server}
test -f "$server/db/state.db"
test -s "$server/token"
mkdir -p "$stage/server/db" "$stage/config"
# SQLite's backup API yields a consistent snapshot while K3s is running.
sqlite3 "$server/db/state.db" ".backup '$stage/server/db/state.db'"
cp "$server/token" "$stage/server/token"
# The restored node name must retain its node-password identity too.
cp "${K3S_NODE_PASSWORD_FILE:-/etc/rancher/node/password}" "$stage/config/node-password"
# Encryption configuration may be needed with secrets-encryption enabled.
if test -f "$server/cred/encryption-config.json"; then
  mkdir -p "$stage/server/cred"
  cp "$server/cred/encryption-config.json" "$stage/server/cred/encryption-config.json"
fi
cp "${K3S_CONFIG_FILE:-/etc/rancher/k3s/config.yaml}" "$stage/config/k3s-config.yaml"
"${K3S_BINARY:-/usr/local/bin/k3s}" --version > "$stage/config/k3s-version.txt"
# A constant relative path allows restic retention to group snapshots correctly.
cd "$stage"
restic backup --tag personal-control-plane --host personal-platform server config
# Retention is deliberately non-destructive by default. Review docs/operations.md
# before opting into a separate `restic forget --prune` maintenance command.
