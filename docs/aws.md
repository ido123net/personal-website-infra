# AWS account setup

AWS replaced OVH on 2026-11-17. IAM Identity Center and the `personal-infra`
AWS CLI profile are configured. The EC2 host and network were created with
Terraform and bootstrapped with K3s on 2026-11-17. The node is Ready. DNS and
application deployment are pending; external backup storage remains disabled.
The Terraform root lives in `terraform/cloud/aws`, and the shared K3s/Ansible
configuration is reusable.

## Proposed deployment and cost

For learning AWS, the deployment uses one EC2 Ubuntu 24.04 instance in Frankfurt (`eu-central-1`),
with a VPC, public subnet, internet gateway, route table, security group,
encrypted 40 GB gp3 root disk and an Elastic IP. K3s runs on the instance.
The security group will permit SSH only from the administrator's source IP,
and public HTTP/HTTPS. Application deployments remain in Higayon's repository.

The simplest compatible x86 starting point is `t3a.medium` (2 vCPUs, 4 GiB RAM).
Current on-demand rates checked against AWS's Frankfurt pricing list give:

| Component | Estimate for a full month |
|---|---:|
| t3a.medium at USD 0.0432/hour, 730 hours | USD 31.54 |
| 40 GB gp3 at USD 0.0952/GB-month | USD 3.81 |
| One public IPv4 at USD 0.005/hour, 730 hours | USD 3.65 |
| Total before tax, transfer, credits and optional services | **About USD 39** |

This estimate assumes CPU credit mode is configured to avoid unlimited-mode
surplus credit charges. Credits, taxes and transfer depend on the account and
usage. Review the full plan and estimate before infrastructure changes. AWS
capacity and account quotas were checked before the initial launch.

Lightsail's 2-vCPU/4-GB/80-GB Linux bundle with IPv4 is USD 24/month and is the
lower-cost alternative. EC2 was selected for learning VPC, networking and
storage configuration.

Sources: [EC2 on-demand pricing](https://aws.amazon.com/ec2/pricing/on-demand/),
[Frankfurt price list](https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AmazonEC2/current/eu-central-1/index.csv),
[IPv4 pricing](https://aws.amazon.com/vpc/pricing/), and
[Lightsail pricing](https://aws.amazon.com/lightsail/pricing/).

## 1. Enable IAM Identity Center

While signed in as root, open IAM Identity Center in Frankfurt. Enable an
**organization instance** (the option using AWS Organizations). An account
instance alone does not grant the account/role access used here.

Use the built-in Identity Center directory and create your own user. Complete
the user's activation/password setup and MFA in the access portal. Configure
the root user's MFA too if it is not already enabled.

Create a custom permission set named `PersonalInfra` and attach the AWS-managed
`AmazonEC2FullAccess` policy. Assign your Identity Center user to your AWS
account with that permission set. This grants broad EC2/network/storage access,
not account-wide administrator access. It is sufficient for the proposed
initial stack without instance IAM roles; additional services will require
reviewed permissions later.

Record the **AWS access portal/start URL** and the **Identity Center Region**
from the Identity Center dashboard. These are configuration, not passwords.

Official walkthrough: [Getting started with IAM Identity Center](https://docs.aws.amazon.com/singlesignon/latest/userguide/getting-started.html).

## 2. Add a spending notification

While signed in with billing access, use Billing and Cost Management → Budgets
to create a monthly cost budget of USD 50, with email alerts at 80% and 100%,
and a forecast alert if desired. This is an alert threshold, not a hard spending
cap or automatic shutdown. It is separate from the deployment spending approval.

See [AWS Budgets](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html).

## 3. Install AWS CLI v2 and authenticate

Install AWS CLI v2 with Homebrew if it is not already installed, then configure
a dedicated SSO profile:

```sh
brew install awscli
aws configure sso --profile personal-infra
aws sso login --profile personal-infra
aws sts get-caller-identity --profile personal-infra
```

For the configure wizard, use:

| Prompt | Value |
|---|---|
| SSO session name | `personal` |
| SSO start URL | The access portal URL from step 1 |
| SSO region | The region where Identity Center was enabled |
| Registration scopes | Default `sso:account:access` |
| Account | Your personal AWS account |
| Role | `PersonalInfra` |
| Default client region | `eu-central-1` |
| Default output | `json` |

The browser sign-in is for the Identity Center user, rather than the root
account. The `get-caller-identity` command should identify the SSO role.
Refresh expired sessions with `aws sso login --profile personal-infra`.

AWS CLI stores profile configuration and temporary login tokens under `~/.aws/`.
Do not put AWS secrets into this repository's OVH `.env` or chat, and do not
create root access keys. Terraform will use `AWS_PROFILE=personal-infra`.

See [CLI SSO configuration](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html)
and [AWS CLI installation](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).

## 4. Build and review the AWS infrastructure

See [`terraform/cloud/aws/README.md`](../terraform/cloud/aws/README.md). Create a
local `local.tfvars` there with your current public IPv4 `/32` and SSH public
key path, then initialize and review the plan:

```sh
terraform -chdir=terraform/cloud/aws init
terraform -chdir=terraform/cloud/aws validate
terraform -chdir=terraform/cloud/aws plan -var-file=local.tfvars -out=aws.tfplan
terraform -chdir=terraform/cloud/aws show aws.tfplan
```

The Terraform root provisions the server and network but does not apply them,
change DNS, install K3s, deploy the app, or configure backups. Review the
billable plan before applying. Cloudflare can continue hosting DNS for
`idofrenkel.com`; it need not move to Route 53. The local Docker app/database
remain available until the AWS deployment and data migration are verified.
