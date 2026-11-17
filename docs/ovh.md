# Provision the OVHcloud VPS

The `terraform/cloud/ovh` root creates one VPS-1 2027 (2 vCores, 4 GB RAM,
40 GB local disk, public IPv4) with Ubuntu 24.04. Billing is `P1M` with
`default` pricing: monthly, without a 6/12-month commitment. The existing
`terraform/` root still owns shared cluster components, with independent state.
No VPS has been ordered yet.

## Account and credentials

1. Create an [OVHcloud account](https://www.ovhcloud.com/en/) and add a
   **default payment method** in the control panel. Terraform places and pays
   the VPS order; you do not need to create the VPS manually.
2. This account uses `manager.ca.ovhcloud.com`: create application credentials
   at the **[Canadian API token page](https://ca.api.ovh.com/createToken/)**
   and keep `ovh_endpoint = "ovh-ca"` in `local.tfvars`.
   The European token page does not authenticate this account. The server can
   still be in Europe: keep `datacenter = "GRA"` for Gravelines, France.
   An account's API endpoint is independent of the server location.
3. Grant the following permissions for provisioning. Use a short expiration
   suitable for the provisioning session. These order permissions can spend
   money across the account, so keep the token local.

   | Method | Path |
   |---|---|
   | GET | `/me` |
   | GET | `/me/payment/method` |
   | POST | `/order/cart` |
   | GET, POST | `/order/cart/*` |
   | GET | `/me/order/*` |
   | POST | `/me/order/*/pay` |
   | GET, PUT | `/vps/*` |

   The stack does not request termination-email access. It blocks destruction
   with `prevent_destroy`; deliberate termination requires editing that guard
   and separate termination permissions. After creation, an ordinary management
   token can be restricted to `GET /me` and `GET, PUT /vps/SERVICE_NAME/*`,
   plus `GET, PUT /vps/SERVICE_NAME` and the cart/catalog routes if replanning.
4. From the repository root:

   ```sh
   cp .env.example .env
   chmod 600 .env
   # Edit .env locally with the three generated credentials.
   cp terraform/cloud/ovh/example.tfvars terraform/cloud/ovh/local.tfvars
   # Edit endpoint and datacenter in local.tfvars.
   ```

Never paste credentials into chat or put them in Terraform variables. The
provider reads the environment; application runtime secrets remain outside
Terraform. Keep Terraform state private too: it contains order/account details.
The cloud, cluster and application state files must all be kept separately.

### Authentication error: “This credential does not exist”

This error occurs while authenticating the provider, before the VPS order.
It does not mean that the requested European datacenter is unavailable.

- Confirm `ovh_endpoint = "ovh-ca"` in `terraform/cloud/ovh/local.tfvars`.
- Generate a fresh credential set at the Canadian **createToken** page above,
  with the permissions listed here, and finish any authorization/validation
  prompt. Creating an application alone (`createApp`) is not sufficient:
  access to your account also requires an authorized consumer key.
- Replace **all three** `.env` values with the application key, application
  secret and consumer key from that same creation. Do not mix old/new values,
  EU/Canadian credentials, or account login details with API keys.
- If you previously exported these variables in your shell, unset them before
  running with `.env`; existing shell variables take precedence over dotenv:

  ```sh
  unset OVH_APPLICATION_KEY OVH_APPLICATION_SECRET OVH_CONSUMER_KEY
  ```

Then rerun the documented plan command. If an old credential is listed in
your account's API access settings, revoke it after the replacement works.

## Region, price and plan

The example uses `GRA` (Gravelines, France), subject to current stock. `SBG`,
`DE` and `WAW` are other catalog codes; availability and checkout prices must
be confirmed for your account. The current Canadian account's authenticated
plan and GET checkout accept `GRA`; actual delivery/stock is not guaranteed
until provisioning succeeds. The authorized apply on 2026-11-16 was rejected
at checkout because GRA was out of stock. OVH's stock API then reported the
selected plan unavailable across European locations. No VPS was created.
Do not silently switch to Singapore if a European location is unavailable.

From the repository root, with Terraform on PATH:

```sh
terraform -chdir=terraform/cloud/ovh init
uv run --env-file .env terraform -chdir=terraform/cloud/ovh plan -var-file=local.tfvars -out=vps.tfplan
```

Planning creates a temporary shopping cart and reads the account/catalog; it
does not check out or pay. Review the single `ovh_vps.personal` creation,
Ubuntu version, datacenter, and the monthly `default` pricing on every option.
The plan reads all prices and explicitly selects `P1M/default`, rather than
trusting `selected_price`, which may select an annual commitment.

The catalog requires Linux, local storage and a standard one-day automatic
backup option. These are included in the configuration. The standard backup
has a catalog list price with an OVH promotion that currently makes it free;
`catalog_prices` shows list prices **before promotions and taxes**, not a final
checkout quote. Verify the matching configuration in the OVH configurator for
your account before applying. The authenticated GRA quote checked on
2026-11-16 is USD 5.35/month after the USD 0.50 backup promotion, with USD 0.00
tax returned for this account. Recheck when applying: prices, promotions and
tax depend on the account and time of ordering.
No additional backup bucket, premium backup, load balancer or managed
Kubernetes subscription is ordered. Restic backups remain disabled.

Once the plan and account quote agree, this command **places and pays the order**:

```sh
uv run --env-file .env terraform -chdir=terraform/cloud/ovh apply vps.tfplan
terraform -chdir=terraform/cloud/ovh output server_ipv4
terraform -chdir=terraform/cloud/ovh output service_name
```

If delivery fails after payment, inspect the order/service in the control
panel before retrying. Never delete the state to retry an order. The provider
records the service before a later configuration step, but payment/delivery
failures still need reconciliation to avoid duplicate orders.

If checkout instead fails with `out of stock in region GRA`, payment has not
been reached. A successful plan or GET checkout does not reserve capacity.
Check the public `GET /vps/order/rule/datacenter` endpoint using the account's
`ovhSubsidiary` and `planCode=vps-2027-model1`; for Ubuntu, check Linux stock,
not only the general status. Keep the server in Europe and the approved budget.
When stock returns, rerun plan before apply; do not reuse the failed plan.

## Initial SSH and handoff to Ansible

OVH sends initial Ubuntu login instructions through its delivery flow. Check
the SSH host fingerprint through the OVH console before accepting it locally.
For this provider, setting `public_ssh_key` also requires an image UUID and
rebuilds the VPS. This stack avoids a rebuild and never stores an initial
password in Terraform. Install your public key once using the delivered Ubuntu
login (normally `ubuntu`; confirm in the delivery instructions):

```sh
# Replace YOUR_IP and use your own public key filename.
cat ~/.ssh/id_ed25519.pub | ssh ubuntu@YOUR_IP 'umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys'
ssh ubuntu@YOUR_IP
```

If your workstation has no SSH key yet, create one with `ssh-keygen -t ed25519`.
Only the `.pub` file is copied. Confirm key-based login works, then prepare
the ignored inventory and bootstrap variables:

```sh
terraform -chdir=terraform/cloud/ovh output -raw ansible_inventory > ansible/inventory.yml
cp ansible/vars.example.yml ansible/local-vars.yml
# Set platform_ssh_public_key and your current public IP /32 in admin_cidrs.
# Leave backups_enabled: false.
uv run ansible-playbook ansible/bootstrap.yml -e @ansible/local-vars.yml
```

Use the actual delivered user in inventory if different from `ubuntu`.
The existing playbook refuses a host with swap enabled; if the delivered image
has swap, inspect and disable it (including its persistent configuration)
before bootstrap. Do not weaken the preflight.

Ansible installs the `platform` key-only administrator, disables password SSH,
restricts SSH to your admin CIDRs with UFW, opens HTTP/HTTPS and installs K3s.
There is no OVH Public Cloud project or security group: this is the separately
priced VPS product, protected by the host firewall. Keep the OVH console
available during bootstrap.

Continue at [README step 2](../README.md#2-fetch-a-private-kubeconfig-and-open-a-tunnel).
Put the `server_ipv4` output into `terraform/local.tfvars` for the shared
cluster stack. DNS remains a manual record plan for `idofrenkel.com` and
`higayon.idofrenkel.com`; no registrar change is required here.

Sources: pinned [OVH VPS resource](https://github.com/ovh/terraform-provider-ovh/blob/v2.25.0/docs/resources/vps.md),
[ordering permissions](https://github.com/ovh/terraform-provider-ovh/blob/v2.25.0/docs/guides/order_consumer_key_access_rules.md),
[pricing modes](https://github.com/ovh/terraform-provider-ovh/blob/v2.25.0/docs/guides/order_plan.md),
and [public EU catalog](https://eu.api.ovh.com/1.0/order/catalog/public/vps?ovhSubsidiary=IE).
