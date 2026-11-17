mock_provider "helm" {}
variables {
  domain      = "example.com"
  server_ipv4 = "192.0.2.10"
  acme_email  = "ido@example.com"
  subdomains  = ["higayon", "demo"]
}
run "dns_and_application_contract" {
  command = plan
  assert {
    condition     = length(output.dns_records) == 3 && output.dns_records[0].name == "example.com"
    error_message = "DNS outputs must contain the root and each requested subdomain."
  }
  assert {
    condition     = alltrue([for record in output.dns_records : record.type == "A" && record.value == "192.0.2.10"])
    error_message = "DNS records must target the configured server."
  }
  assert {
    condition     = output.application_defaults.higayon_hostname == "higayon.example.com" && output.application_defaults.ingress_class == "traefik"
    error_message = "Application integration defaults must agree with K3s ingress."
  }
}
run "invalid_domain_rejected" {
  command = plan
  variables { domain = "https://example.com/" }
  expect_failures = [var.domain]
}
run "invalid_address_rejected" {
  command = plan
  variables { server_ipv4 = "300.1.1.1" }
  expect_failures = [var.server_ipv4]
}
run "wildcard_subdomain_rejected" {
  command = plan
  variables { subdomains = ["*"] }
  expect_failures = [var.subdomains]
}
run "invalid_acme_email_rejected" {
  command = plan
  variables { acme_email = "not-an-email" }
  expect_failures = [var.acme_email]
}
