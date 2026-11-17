data "ovh_me" "account" {}

# These data sources create a temporary shopping cart, not a paid order.
data "ovh_order_cart" "catalog" {
  ovh_subsidiary = data.ovh_me.account.ovh_subsidiary
}

locals {
  plan_code = "vps-2027-model1"
  # Required catalog families: Linux, local disk and standard one-day backup.
  # The standard backup is bundled by OVH; no restic bucket is provisioned.
  option_codes = toset([
    "option-linux",
    "option-storage-local-2027-model1",
    "option-auto-backup-2027-1-model1",
  ])
}

data "ovh_order_cart_product_plan" "server" {
  cart_id        = data.ovh_order_cart.catalog.id
  product        = "vps"
  plan_code      = local.plan_code
  price_capacity = "renew"
}

data "ovh_order_cart_product_options_plan" "included" {
  for_each          = local.option_codes
  cart_id           = data.ovh_order_cart.catalog.id
  product           = "vps"
  plan_code         = local.plan_code
  options_plan_code = each.value
  price_capacity    = "renew"
}

locals {
  # selected_price can select an annual commitment: explicitly select monthly.
  monthly_prices = [
    for price in data.ovh_order_cart_product_plan.server.prices : price
    if contains(price.capacities, "renew") && price.pricing_mode == "default" && price.duration == "P1M"
  ]
  option_monthly_prices = {
    for code, option in data.ovh_order_cart_product_options_plan.included : code => [
      for price in option.prices : price
      if contains(price.capacities, "renew") && price.pricing_mode == "default" && price.duration == "P1M"
    ]
  }
}

resource "ovh_vps" "personal" {
  display_name   = var.display_name
  ovh_subsidiary = data.ovh_me.account.ovh_subsidiary

  plan = [{
    plan_code    = local.plan_code
    duration     = "P1M"
    pricing_mode = "default"
    configuration = [
      { label = "vps_datacenter", value = var.datacenter },
      { label = "vps_os", value = "Ubuntu 24.04" },
    ]
  }]

  plan_option = [for code in sort(tolist(local.option_codes)) : {
    plan_code     = code
    quantity      = 1
    duration      = "P1M"
    pricing_mode  = "default"
    configuration = []
  }]

  # No image_id/public_ssh_key: OVH applies those through a destructive rebuild.
  # Install the administrator public key once using the initial Ubuntu login,
  # then Ansible configures key-only SSH, UFW and K3s (see docs/ovh.md).
  lifecycle {
    prevent_destroy = true
    precondition {
      condition     = length(local.monthly_prices) == 1 && alltrue([for prices in values(local.option_monthly_prices) : length(prices) == 1])
      error_message = "The selected offer and its required options must support monthly default pricing. Review the OVH catalog."
    }
  }
}

data "ovh_vps" "personal" {
  service_name = ovh_vps.personal.service_name
}

locals {
  server_ipv4 = one([for ip in data.ovh_vps.personal.ips : ip if can(cidrnetmask("${ip}/32"))])
}
