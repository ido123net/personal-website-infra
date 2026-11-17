# personal-website-infra

Foundation for Ido's personal websites: one small Ubuntu server running K3s, with shared HTTP ingress, automatic TLS, a DNS record plan, and optional encrypted offsite control-plane backups. AWS is now the chosen cloud provider, including learning AWS infrastructure. Higayon and future applications keep their deployments in their own repositories.

`idofrenkel.com` is registered, with `higayon.idofrenkel.com` planned for Higayon. No cloud server has been provisioned. The OVH order failed because of stock and was abandoned in favor of AWS on 2026-11-17. Start with [AWS account and CLI setup](docs/aws.md). The recommended learning path is EC2 in Frankfurt; its Terraform root has not been implemented yet. The bootstrap requires Ubuntu 24.04, at least 2 vCPUs/4 GB RAM, public IPv4 and no swap. Offsite backups remain disabled, so no backup bucket is required now.

## Contents and ownership

| Here | In each application repo |
|---|---|
| Host bootstrap, K3s, Traefik, cert-manager, shared ACME issuers | Deployments, Services, Ingress, migrations, app secrets and databases |
| Root/subdomain DNS record plan | Requested application hostname and certificate reference |
| Kubernetes control-plane backup/restore | PostgreSQL dumps and persistent-volume backups |

The cloud Terraform root will create the AWS host/network; Ansible configures the host; Terraform in `terraform/` installs shared Helm releases in the cluster. These use separate Terraform roots/state files, also separate from Higayon's state. AWS will use a named CLI profile with temporary credentials. Terraform does not receive application secrets or buy a domain. `terraform/cloud/ovh` remains historical; do not apply it.

## Local tools and checks

Python 3.12 and `uv` are required. Install Terraform >=1.7, Helm >=3, kubectl and SSH separately. Linux hosts use systemd and apt. macOS is supported as the operator workstation.

```sh
uv sync --locked
uv run python -m unittest discover -s tests -v
uv run ansible-playbook -i ansible/inventory.example.yml ansible/bootstrap.yml --syntax-check
uv run yamllint ansible systemd examples .pre-commit-config.yaml
uv run ruff check .
uv run ruff format --check .
uv run ty check
bash -n scripts/backup-cluster.sh
terraform -chdir=terraform init -backend=false
terraform -chdir=terraform fmt -check -recursive
terraform -chdir=terraform validate
terraform -chdir=terraform test
terraform -chdir=terraform/cloud/ovh init -backend=false
terraform -chdir=terraform/cloud/ovh validate
terraform -chdir=terraform/cloud/ovh test
helm lint terraform/charts/platform --set acmeEmail=ido@example.com
uv run pre-commit install
```

For a reproducible Linux restore drill with all dependencies, run `docker build -f tests/Dockerfile -t personal-infra-restore-check .` followed by `docker run --rm personal-infra-restore-check`.

The restic restore drill runs when `restic` and `sqlite3` are on PATH; otherwise that test explicitly skips. Test fixtures contain no real cluster keys. See [verification](docs/verification.md) for actual checks and limitations.

## 1. Prepare and bootstrap the host

Follow [AWS account and CLI setup](docs/aws.md) first. AWS Terraform provisioning is the next implementation step; do not create a server manually. The platform also works on an existing dedicated Ubuntu host. Confirm its SSH host-key fingerprint against the provider console and keep the console available during bootstrap. Do not open Kubernetes API or overlay ports publicly.

```sh
# For AWS, wait for the provisioning inventory output.
# For an existing host instead:
# cp ansible/inventory.example.yml ansible/inventory.yml
cp ansible/vars.example.yml ansible/local-vars.yml
# Edit the ignored files: actual host/user, SSH public key and your admin CIDR.
uv run ansible-playbook ansible/bootstrap.yml -e @ansible/local-vars.yml
```

The playbook creates a key-only `platform` sudo user, configures UFW, downloads the pinned K3s binary and verifies its upstream SHA256, installs a systemd service, enables secret encryption, and waits for a ready node. Traefik, CoreDNS, ServiceLB and local-path storage come from K3s. The Kubernetes API remains accessible to internal pods and through an SSH tunnel; public access is denied by UFW. The playbook refuses to enable the firewall unless the current SSH client is inside an allowed administrator CIDR. Only run on a new dedicated host. Existing UFW allow rules are not deleted automatically; when removing an administrator CIDR, remove the obsolete rule with `sudo ufw status numbered` and `sudo ufw delete NUMBER` after confirming access from the replacement network.

The playbook is designed for repeat runs. `--check` is a preview, not a complete first-install test: commands/services that depend on packages or directories not yet installed may not be checkable. It does not provision PostgreSQL or deploy applications.

## 2. Fetch a private kubeconfig and open a tunnel

Verify `ssh platform@YOUR_IP` works before proceeding. The script refuses to overwrite an existing kubeconfig and never prints its keys. For intentional refresh, move the old config to a protected backup first.

```sh
uv run python scripts/fetch_kubeconfig.py platform@YOUR_IP
# Keep this in a separate terminal:
ssh -N -L 127.0.0.1:6445:127.0.0.1:6443 platform@YOUR_IP
# In your working terminal:
export KUBECONFIG="$HOME/.kube/personal-website-infra.yaml"
kubectl --context personal-platform get nodes
```

This is cluster-admin access; the kubeconfig is mode 0600 and stays outside Git. No Kubernetes dashboard or publicly accessible admin endpoint is installed.

## 3. Install shared HTTPS components

```sh
cp terraform/example.tfvars terraform/local.tfvars
# Edit domain, public IPv4 and ACME email. The domain must already be yours.
terraform -chdir=terraform init
terraform -chdir=terraform plan -var-file=local.tfvars -out=platform.tfplan
terraform -chdir=terraform apply platform.tfplan
terraform -chdir=terraform output -json dns_records
```

Terraform reads the private kubeconfig through `kubeconfig_path` and `kube_context`, installs pinned cert-manager, then creates `letsencrypt-staging` and `letsencrypt-production` ClusterIssuers. HTTP-01 uses Traefik. The local issuer chart is a separate release so a first plan does not need CRDs already installed. ACME account keys are generated inside Kubernetes, not passed to Terraform.

Add the output A records to your chosen DNS provider (DNS-only while checking HTTP-01). The output is a **plan**, not live DNS automation. Preserve unrelated MX/TXT records. Only create AAAA records once IPv6 reaches this server correctly. A wildcard DNS record or certificate is not needed initially; add explicit subdomains as applications arrive.

The domain registration is paid once per year. Each application's subdomain points to the same IPv4; Traefik routes by hostname. HTTPS certificates are requested by application-owned Ingress annotations or Certificate resources. Port 80 must remain reachable for HTTP-01 renewals.

## 4. Deploy Higayon from its own repo

After configuring PostgreSQL and the application runtime secret, use Higayon's existing deployment with:

```hcl
kubeconfig          = "~/.kube/personal-website-infra.yaml"
context             = "personal-platform"
hostname            = "higayon.idofrenkel.com"
ingress_class       = "traefik"
runtime_secret_name = "higayon-runtime"
tls_secret_name     = "higayon-tls"
```

Higayon currently expects an existing PostgreSQL connection; its application repo should own any dedicated in-cluster PostgreSQL deployment and its data backup. It is not created here. Create a Certificate named `higayon-tls` in namespace `higayon` with `issuerRef.name: letsencrypt-production`, `issuerRef.kind: ClusterIssuer`, and `dnsNames: [higayon.YOUR_DOMAIN]`, or add the cert-manager issuer annotation to the application Ingress. Test certificate issuance with the staging issuer first; staging certificates are intentionally untrusted. Configure the production Google OAuth client with `https://higayon.YOUR_DOMAIN/accounts/google/login/callback/`.

## 5. Enable offsite backups (optional)

Backups are **disabled until configured**. Create an external S3-compatible bucket and a scoped access key with read/write/list/delete permissions for the dedicated restic prefix. Keep its credentials and a separate random restic password in protected files outside this repo. See [backup.env example](examples/backup.env.example); use `RESTIC_PASSWORD_FILE=/etc/personal-infra/restic-password` for the remote host.

Set these fields in ignored `ansible/local-vars.yml`, then rerun the playbook:

```yaml
backups_enabled: true
backup_env_file: /absolute/protected/path/backup.env
backup_password_file: /absolute/protected/path/restic-password
```

Initialize the repository once on the VPS, then test the service:

```sh
sudo systemd-run --wait --pipe --property=EnvironmentFile=/etc/personal-infra/backup.env /usr/bin/restic init
sudo systemctl start personal-cluster-backup.service
sudo journalctl -u personal-cluster-backup.service --since today
sudo systemctl list-timers personal-cluster-backup.timer
```

The daily timer snapshots SQLite through its backup API and includes the K3s token, node-password identity, encryption configuration, server config and version, then uploads them with restic's encryption. It does **not** back up application PostgreSQL or local-path volumes. Keep the restic password outside both the server and backup bucket so a lost host can be recovered. Review [operations and restore](docs/operations.md) before relying on the backup.

## Limits and cost

This is a single-node personal cluster. A node failure or upgrade takes applications offline; local persistent volumes do not survive host loss without application backups. K3s itself has no license fee and the bundled ingress uses the node's ports, avoiding a separately billed cloud load balancer. Budget from the selected VPS, domain renewal, and actual backup storage; no provider price is encoded here. Heavy monitoring/GitLab workloads or high availability require more resources and a new capacity plan.

Versions and sources: K3s `v1.36.6+k3s1`, cert-manager `v1.21.3`, Helm Terraform provider `3.3.x` locked in `.terraform.lock.hcl`. Read the official [K3s configuration](https://docs.k3s.io/installation/configuration), [backup/restore](https://docs.k3s.io/datastore/backup-restore), [networking](https://docs.k3s.io/networking/networking-services), [cert-manager Helm installation](https://cert-manager.io/docs/installation/helm/), and [restic repositories](https://restic.readthedocs.io/en/stable/030_preparing_a_new_repo.html).
