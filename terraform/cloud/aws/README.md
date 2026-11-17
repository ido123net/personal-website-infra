# AWS EC2 host

This root provisions the first AWS host for the provider-independent K3s
platform: a dedicated VPC, one public subnet, internet gateway and route,
restricted security group, Ubuntu 24.04 EC2 instance, encrypted gp3 root volume,
SSH public key pair, and Elastic IPv4. It does not configure live DNS, install
K3s, deploy applications, or create backup storage.

The instance is `t3a.medium` by default, and T-series CPU credits are explicitly
set to `standard` to avoid unlimited-mode surplus credit charges. IMDSv2 is
required, with hop limit 2 for workloads in containers. SSH is limited to the
CIDRs in the local variable file; use your current public IPv4 as `/32`.

## Prepare

Install AWS CLI v2 and Terraform. Authenticate with the configured SSO profile:

```sh
aws sso login --profile personal-infra
aws sts get-caller-identity --profile personal-infra
```

Create an SSH key if you do not already have one. This creates a local private
key; keep it private and out of this repository:

```sh
ssh-keygen -t ed25519 -f ~/.ssh/personal-platform -C personal-platform
```

Copy `example.tfvars` to `local.tfvars`, change `admin_cidrs` to your current
public IPv4 `/32`, and set `ssh_public_key_path` to the `.pub` key plus
`ssh_private_key_path` to its matching private key. `*.tfvars` is ignored by
Git.

## Review before creating AWS resources

```sh
terraform -chdir=terraform/cloud/aws init
terraform -chdir=terraform/cloud/aws fmt -check
terraform -chdir=terraform/cloud/aws validate
terraform -chdir=terraform/cloud/aws plan -var-file=local.tfvars -out=aws.tfplan
terraform -chdir=terraform/cloud/aws show aws.tfplan
```

The plan creates billable resources. Review it and the current pricing before
applying. A full month is estimated at about USD 39 before taxes, data transfer,
and account-specific charges. A budget notification is not a spending cap.

## After an approved apply

Use the `server_ipv4` output for the DNS record plan in the shared Terraform
root. Save the `ansible_inventory` output as the ignored
`ansible/inventory.yml`, verify the SSH host fingerprint, and run the existing
Ansible bootstrap with `ansible/vars.example.yml` copied to the ignored
`ansible/local-vars.yml`. DNS changes and Ansible execution are separate
operations and are not performed by this Terraform root.

Terraform state contains infrastructure identifiers and the SSH public key.
Keep local state private; never commit state or a saved plan.
