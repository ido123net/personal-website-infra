terraform {
  required_version = ">= 1.7, < 2.0"
  required_providers {
    ovh = {
      source  = "ovh/ovh"
      version = "= 2.25.0"
    }
  }
}

# Credentials come from OVH_* environment variables or ~/.ovh.conf.
provider "ovh" {
  endpoint = var.ovh_endpoint
}
