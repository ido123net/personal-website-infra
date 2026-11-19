variable "kubeconfig_path" {
  type        = string
  description = "Private local kubeconfig; use the SSH tunnel documented in README."
  default     = "~/.kube/personal-website-infra.yaml"
}
variable "kube_context" {
  type    = string
  default = "personal-platform"
}
variable "domain" {
  type        = string
  description = "An already registered domain; this repo does not buy domains."
  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,63}$", var.domain))
    error_message = "Use a lowercase domain name without scheme, path, wildcard or trailing dot."
  }
}
variable "server_ipv4" {
  type        = string
  description = "Public IPv4 of your existing VPS, for the DNS record plan."
  validation {
    condition     = can(cidrnetmask("${var.server_ipv4}/32"))
    error_message = "Use an IPv4 address, not a hostname or CIDR."
  }
}
variable "subdomains" {
  type        = set(string)
  description = "DNS labels to route to this server; application Ingress resources remain in app repos."
  default     = ["higayon"]
  validation {
    condition     = alltrue([for name in var.subdomains : can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", name))])
    error_message = "Each subdomain must be a single DNS label, 1-63 characters, without a wildcard."
  }
}
variable "acme_email" {
  type        = string
  description = "Email for Let's Encrypt account notices; ACME private keys are generated inside Kubernetes."
  validation {
    condition     = can(regex("^[^ @]+@[^ @]+\\.[^ @]+$", var.acme_email))
    error_message = "Use a valid ACME account email address."
  }
}

variable "monitoring_enabled" {
  type    = bool
  default = false
}

variable "monitoring_owner_email" {
  type    = string
  default = ""
}

variable "grafana_ingress_enabled" {
  description = "Publish after verifying Google sign-in and denial for a second account."
  type        = bool
  default     = false
}
