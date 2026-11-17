variable "ovh_endpoint" {
  type        = string
  description = "API endpoint matching your account; this does not choose the server location."
  default     = "ovh-ca"
  validation {
    condition     = contains(["ovh-eu", "ovh-ca", "ovh-us"], var.ovh_endpoint)
    error_message = "Choose ovh-eu, ovh-ca or ovh-us for your OVHcloud account."
  }
}

variable "datacenter" {
  type        = string
  description = "OVH VPS datacenter code from your account's catalog; confirm current stock before applying."
  validation {
    condition     = can(regex("^[A-Z][A-Z0-9-]{1,31}$", var.datacenter))
    error_message = "Use a catalog datacenter code such as GRA, SBG, DE or WAW."
  }
}

variable "display_name" {
  type    = string
  default = "personal-platform"
}
