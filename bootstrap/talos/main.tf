locals {
  cluster_endpoint = "https://${var.node_ip}:6443"

  common_patch = templatefile("${path.module}/patches/common.yaml.tftpl", {
    interface   = var.network.interface
    cidr        = var.network.cidr
    gateway     = var.network.gateway
    nameservers = var.network.nameservers
  })

  # Talos >=1.13 always emits a `HostnameConfig {auto: stable}` document, which
  # collides with a static `machine.network.hostname` ("static hostname is
  # already set in v1alpha1 config"). Set the hostname here instead, disabling
  # the auto behaviour, so the two never conflict.
  hostname_patch = templatefile("${path.module}/patches/hostname.yaml.tftpl", {
    hostname = var.node_hostname
  })

  controlplane_patch = templatefile("${path.module}/patches/controlplane.yaml.tftpl", {
    install_disk = var.install_disk
  })
}

resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

data "talos_machine_configuration" "controlplane" {
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.cluster_endpoint
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  kubernetes_version = var.kubernetes_version
  talos_version      = var.talos_version

  config_patches = [
    local.common_patch,
    local.hostname_patch,
    local.controlplane_patch,
  ]
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [var.node_ip]
  nodes                = [var.node_ip]
}

resource "talos_machine_configuration_apply" "controlplane" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = var.node_ip
  endpoint                    = var.node_ip
}

# Optional worker nodes — reuse the cluster secrets and join via the existing
# control-plane endpoint (no re-bootstrap). See getting-started.md.
data "talos_machine_configuration" "worker" {
  for_each = { for w in var.worker_nodes : w.hostname => w }

  cluster_name       = var.cluster_name
  cluster_endpoint   = local.cluster_endpoint
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  kubernetes_version = var.kubernetes_version
  talos_version      = var.talos_version

  config_patches = [
    templatefile("${path.module}/patches/common.yaml.tftpl", {
      interface   = each.value.interface
      cidr        = each.value.cidr
      gateway     = each.value.gateway
      nameservers = coalesce(each.value.nameservers, var.network.nameservers)
    }),
    templatefile("${path.module}/patches/hostname.yaml.tftpl", {
      hostname = each.value.hostname
    }),
    templatefile("${path.module}/patches/worker.yaml.tftpl", {
      install_disk = each.value.install_disk
    }),
  ]
}

resource "talos_machine_configuration_apply" "worker" {
  for_each = { for w in var.worker_nodes : w.hostname => w }

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker[each.key].machine_configuration
  node                        = each.value.node_ip
  endpoint                    = each.value.node_ip
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [talos_machine_configuration_apply.controlplane]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.node_ip
  endpoint             = var.node_ip
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on = [talos_machine_bootstrap.this]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.node_ip
  endpoint             = var.node_ip
}

resource "local_sensitive_file" "kubeconfig" {
  content         = talos_cluster_kubeconfig.this.kubeconfig_raw
  filename        = "${path.module}/../../kubeconfig"
  file_permission = "0600"
}

resource "local_sensitive_file" "talosconfig" {
  content         = data.talos_client_configuration.this.talos_config
  filename        = "${path.module}/../../talosconfig"
  file_permission = "0600"
}
