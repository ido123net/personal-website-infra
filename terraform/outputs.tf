output "dns_records" {
  description = "Create these A records with your chosen DNS provider. This output does not modify live DNS."
  value = concat(
    [{ name = var.domain, type = "A", value = var.server_ipv4, ttl = 300 }],
    [for label in sort(tolist(var.subdomains)) : {
      name = "${label}.${var.domain}", type = "A", value = var.server_ipv4, ttl = 300
    }]
  )
}
output "application_defaults" {
  value = {
    kube_context      = var.kube_context
    ingress_class     = "traefik"
    staging_issuer    = "letsencrypt-staging"
    production_issuer = "letsencrypt-production"
    higayon_hostname  = "higayon.${var.domain}"
  }
}
