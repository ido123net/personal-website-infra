resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  repository       = "oci://quay.io/jetstack/charts"
  chart            = "cert-manager"
  version          = "v1.21.3"
  wait             = true
  atomic           = true
  timeout          = 600
  values = [yamlencode({
    crds = { enabled = true }
    resources = {
      requests = { cpu = "10m", memory = "64Mi" }
      limits   = { memory = "256Mi" }
    }
    webhook = {
      resources = {
        requests = { cpu = "10m", memory = "32Mi" }
        limits   = { memory = "128Mi" }
      }
    }
    cainjector = {
      resources = {
        requests = { cpu = "10m", memory = "64Mi" }
        limits   = { memory = "256Mi" }
      }
    }
  })]
}
# A second Helm release avoids Kubernetes CRD schema discovery during the first
# Terraform plan, before cert-manager's CRDs have been installed.
resource "helm_release" "platform" {
  depends_on       = [helm_release.cert_manager]
  name             = "personal-platform"
  namespace        = "platform-system"
  create_namespace = true
  chart            = "${path.module}/charts/platform"
  version          = yamldecode(file("${path.module}/charts/platform/Chart.yaml")).version
  wait             = true
  atomic           = true
  timeout          = 300
  values = [yamlencode({
    acmeEmail    = var.acme_email
    ingressClass = "traefik"
  })]
}
