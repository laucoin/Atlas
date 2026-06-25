resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_version
  namespace        = "argocd"
  create_namespace = true

  # TLS will be terminated by Traefik (Phase 5); run the argo-server in
  # insecure mode so the in-cluster Service serves plain HTTP.
  values = [
    yamlencode({
      configs = {
        params = {
          "server.insecure" = "true"
        },
        cm = {
          "url"           = "https://argo.atlas.laucoin.fr"
          "admin.enabled" = var.disable_local_admin ? "false" : "true"
          "oidc.config"   = <<-EOT
              name: Authentik
              issuer: https://authentik.atlas.laucoin.fr/application/o/argo-cd/
              clientID: $argocd-oidc:clientId
              clientSecret: $argocd-oidc:clientSecret
              requestedScopes: ["openid", "profile", "email", "groups"]
            EOT
        },
        # Without an RBAC policy, OIDC users authenticate but match no role,
        # so Argo shows them nothing. Members of the `argocd-admins` Authentik
        # group get full admin; everyone else falls back to read-only.
        rbac = {
          "scopes"         = "[groups]"
          "policy.default" = "role:readonly"
          "policy.csv"     = "g, argocd-admins, role:admin"
        }
      }
    })
  ]
}

resource "kubectl_manifest" "root_application" {
  depends_on = [helm_release.argocd]

  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name       = "root"
      namespace  = "argocd"
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.repo_url
        targetRevision = var.repo_revision
        path           = "apps/_root"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "argocd"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  })
}
