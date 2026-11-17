output "catalog_prices" {
  description = "Monthly catalog prices before taxes/promotions; not a final checkout total. Review the account's checkout quote."
  value = {
    server = flatten([for price in local.monthly_prices : price.price])
    required_options = {
      for code, prices in local.option_monthly_prices : code => flatten([for price in prices : price.price])
    }
  }
}

output "service_name" {
  value = ovh_vps.personal.service_name
}

output "server_ipv4" {
  description = "Use for shared-cluster local.tfvars and the DNS record plan."
  value       = local.server_ipv4
}

output "ansible_inventory" {
  description = "Save in ignored ansible/inventory.yml after confirming the SSH fingerprint and installing your key."
  value = yamlencode({
    all = { children = { platform = { hosts = { personal = {
      ansible_host = local.server_ipv4
      ansible_user = "ubuntu"
    } } } } }
  })
}
