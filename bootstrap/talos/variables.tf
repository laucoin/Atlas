variable "cluster_name" {
  type        = string
  description = "Name of the Talos cluster."
  default     = "atlas"
}

variable "node_ip" {
  type        = string
  description = "LAN IP of the single Atlas node (also the Kubernetes API host)."
}

variable "node_hostname" {
  type        = string
  description = "Hostname applied to the node."
  default     = "atlas"
}

variable "install_disk" {
  type        = string
  description = "Block device Talos installs onto (e.g. /dev/nvme0n1, /dev/sda)."
}

variable "talos_version" {
  type        = string
  description = "Talos image version (vX.Y.Z). Must be >=1.13 — the config uses the HostnameConfig document (patches/hostname.yaml.tftpl)."
  default     = "v1.13.4"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version (X.Y.Z, no leading v)."
  default     = "1.31.2"
}

variable "network" {
  type = object({
    interface   = string
    cidr        = string
    gateway     = string
    nameservers = list(string)
  })
  description = "Static network configuration for the node."
}

variable "worker_nodes" {
  type = list(object({
    hostname     = string
    node_ip      = string
    install_disk = string
    interface    = string
    cidr         = string
    gateway      = string
    nameservers  = optional(list(string))
  }))
  description = <<-EOT
    Optional extra worker nodes to join to the cluster. Leave empty ([]) for
    the default single-node setup. Each entry reuses the cluster's existing
    machine secrets, so adding a worker never re-keys the cluster. nameservers
    defaults to the control-plane node's if omitted.
  EOT
  default     = []
}
