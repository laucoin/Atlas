resource "helm_release" "local_path_provisioner" {
  name             = "local-path-provisioner"
  repository       = "https://charts.containeroo.ch"
  chart            = "local-path-provisioner"
  version          = var.local_path_provisioner_version
  namespace        = "local-path-storage"
  create_namespace = true
}

# local-path-provisioner spawns a short-lived helper pod that mounts a hostPath
# to create each volume. Talos' default "baseline" Pod Security standard rejects
# hostPath, so every PVC hangs Pending. The Helm release owns this namespace
# (create_namespace = true) and sets no PSA labels, so it inherits the baseline
# default. Patch it to "privileged" like metallb-system above.
resource "kubernetes_labels" "local_path_storage_psa" {
  depends_on = [helm_release.local_path_provisioner]

  api_version = "v1"
  kind        = "Namespace"
  metadata {
    name = "local-path-storage"
  }
  labels = {
    "pod-security.kubernetes.io/enforce" = "privileged"
    "pod-security.kubernetes.io/audit"   = "privileged"
    "pod-security.kubernetes.io/warn"    = "privileged"
  }
  force = true
}

resource "kubernetes_annotations" "local_path_default_sc" {
  depends_on = [helm_release.local_path_provisioner]

  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  metadata {
    name = "local-path"
  }
  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "true"
  }
  force = true
}

# MetalLB's speaker/frr-k8s pods run with hostNetwork, hostPorts and raw-socket
# capabilities, which Talos' default "baseline" Pod Security standard rejects.
# Own the namespace so we can pin it to "privileged" before the pods are admitted.
resource "kubernetes_namespace" "metallb_system" {
  metadata {
    name = "metallb-system"
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
    }
  }
}

resource "helm_release" "metallb" {
  name             = "metallb"
  repository       = "https://metallb.github.io/metallb"
  chart            = "metallb"
  version          = var.metallb_version
  namespace        = kubernetes_namespace.metallb_system.metadata[0].name
  create_namespace = false
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.cert_manager_version
  namespace        = "cert-manager"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  # cert-manager exposes Prometheus metrics (prometheus.enabled defaults true),
  # but the ServiceMonitor itself is NOT created here: baseline runs in Phase 3,
  # long before the Prometheus Operator CRDs arrive (Phase 8), so rendering a
  # ServiceMonitor now hard-fails ("no matches for kind ServiceMonitor"). The
  # ServiceMonitor is instead shipped as a GitOps manifest
  # (apps/observability/cert-manager-servicemonitor.yaml) which Argo applies
  # once the CRDs exist. kube-prometheus-stack's serviceMonitorSelector is
  # empty, so it gets picked up with no extra label.
  set {
    name  = "prometheus.servicemonitor.enabled"
    value = "false"
  }
}

resource "kubectl_manifest" "metallb_pool" {
  depends_on = [helm_release.metallb]

  yaml_body = yamlencode({
    apiVersion = "metallb.io/v1beta1"
    kind       = "IPAddressPool"
    metadata = {
      name      = "atlas-pool"
      namespace = "metallb-system"
    }
    spec = {
      addresses = ["${var.lb_ip}/32"]
    }
  })
}

resource "kubectl_manifest" "metallb_l2advertisement" {
  depends_on = [kubectl_manifest.metallb_pool]

  yaml_body = yamlencode({
    apiVersion = "metallb.io/v1beta1"
    kind       = "L2Advertisement"
    metadata = {
      name      = "atlas-l2"
      namespace = "metallb-system"
    }
    spec = {
      ipAddressPools = ["atlas-pool"]
    }
  })
}

resource "kubectl_manifest" "selfsigned_issuer" {
  depends_on = [helm_release.cert_manager]

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "selfsigned"
    }
    spec = {
      selfSigned = {}
    }
  })
}

# Solver wired to traefik (installed in Phase 5). Issuers are accepted now;
# challenges only succeed once the ingressClass exists.
resource "kubectl_manifest" "letsencrypt_staging" {
  depends_on = [helm_release.cert_manager]

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-staging"
    }
    spec = {
      acme = {
        email  = var.acme_email
        server = "https://acme-staging-v02.api.letsencrypt.org/directory"
        privateKeySecretRef = {
          name = "letsencrypt-staging-account-key"
        }
        solvers = [{
          http01 = {
            ingress = {
              ingressClassName = "traefik"
            }
          }
        }]
      }
    }
  })
}

resource "kubectl_manifest" "letsencrypt_prod" {
  depends_on = [helm_release.cert_manager]

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        email  = var.acme_email
        server = "https://acme-v02.api.letsencrypt.org/directory"
        privateKeySecretRef = {
          name = "letsencrypt-prod-account-key"
        }
        solvers = [{
          http01 = {
            ingress = {
              ingressClassName = "traefik"
            }
          }
        }]
      }
    }
  })
}
