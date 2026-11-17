# Every OVH call is mocked: these tests cannot place orders or charge an account.
mock_provider "ovh" {
  mock_data "ovh_me" {
    defaults = { ovh_subsidiary = "IE" }
  }
  mock_resource "ovh_vps" {
    defaults = { service_name = "vps-fixture.vps.ovh.net" }
  }
  mock_data "ovh_vps" {
    defaults = { ips = ["2001:db8::10", "192.0.2.10"] }
  }
  mock_data "ovh_order_cart_product_plan" {
    defaults = {
      prices = [
        {
          capacities   = ["renew"]
          duration     = "P1Y"
          pricing_mode = "upfront12"
          price        = [{ currency_code = "EUR", text = "€45.72", value = 45.72 }]
        },
        {
          capacities   = ["renew"]
          duration     = "P1M"
          pricing_mode = "default"
          price        = [{ currency_code = "EUR", text = "€4.49", value = 4.49 }]
        },
      ]
    }
  }
  mock_data "ovh_order_cart_product_options_plan" {
    defaults = {
      prices = [{
        capacities   = ["renew"]
        duration     = "P1M"
        pricing_mode = "default"
        price        = [{ currency_code = "EUR", text = "€0.00", value = 0 }]
      }]
    }
  }
}

variables {
  datacenter = "GRA"
}

run "monthly_order_contract" {
  command = plan
  assert {
    condition = (
      ovh_vps.personal.plan[0].duration == "P1M" &&
      ovh_vps.personal.plan[0].pricing_mode == "default" &&
      ovh_vps.personal.plan[0].plan_code == "vps-2027-model1" &&
      output.catalog_prices.server[0].value == 4.49
    )
    error_message = "Order and reported price must select monthly default billing even when annual prices come first."
  }
  assert {
    condition = (
      length(ovh_vps.personal.plan_option) == 3 &&
      alltrue([for option in ovh_vps.personal.plan_option : option.duration == "P1M" && option.pricing_mode == "default" && option.quantity == 1]) &&
      contains([for option in ovh_vps.personal.plan_option : option.plan_code], "option-auto-backup-2027-1-model1")
    )
    error_message = "Only the three required options should be ordered, with the standard backup and no commitment."
  }
  assert {
    condition = (
      contains(ovh_vps.personal.plan[0].configuration, { label = "vps_os", value = "Ubuntu 24.04" }) &&
      contains(ovh_vps.personal.plan[0].configuration, { label = "vps_datacenter", value = "GRA" }) &&
      ovh_vps.personal.image_id == null && ovh_vps.personal.public_ssh_key == null
    )
    error_message = "Install the bootstrap-compatible OS in the chosen datacenter without triggering a rebuild."
  }
}

run "missing_monthly_price_blocks_order" {
  command = plan
  override_data {
    target = data.ovh_order_cart_product_plan.server
    values = { prices = [] }
  }
  expect_failures = [ovh_vps.personal]
}

run "invalid_datacenter_rejected" {
  command = plan
  variables { datacenter = "France" }
  expect_failures = [var.datacenter]
}

run "invalid_endpoint_rejected" {
  command = plan
  variables { ovh_endpoint = "example.com" }
  expect_failures = [var.ovh_endpoint]
}
