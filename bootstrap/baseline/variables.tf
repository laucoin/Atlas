variable "kubeconfig_path" {
  type        = string
  description = "Path to the kubeconfig produced by bootstrap/talos."
  default     = "../../kubeconfig"
}

variable "lb_ip" {
  type        = string
  description = "Single IP MetalLB advertises via L2 (typically the node's LAN IP)."
}

variable "acme_email" {
  type        = string
  description = "Email used for Let's Encrypt ACME registration."
}

variable "metallb_version" {
  type        = string
  description = "metallb Helm chart version."
  default     = "0.16.1"
}

variable "cert_manager_version" {
  type        = string
  description = "cert-manager Helm chart version."
  default     = "v1.20.2"
}

variable "local_path_provisioner_version" {
  type        = string
  description = "local-path-provisioner Helm chart version."
  default     = "0.0.37"
}
