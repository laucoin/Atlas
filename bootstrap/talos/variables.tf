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
  description = "Talos image version (vX.Y.Z)."
  default     = "v1.8.2"
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
