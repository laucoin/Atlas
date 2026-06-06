variable "kubeconfig_path" {
  type        = string
  description = "Path to the kubeconfig produced by bootstrap/talos."
  default     = "../../kubeconfig"
}

variable "repo_url" {
  type        = string
  description = "Git URL Argo CD pulls manifests from (HTTPS or SSH). Must be reachable from inside the cluster."
}

variable "repo_revision" {
  type        = string
  description = "Git revision (branch, tag, or commit SHA) Argo tracks."
  default     = "main"
}

variable "argocd_version" {
  type        = string
  description = "argo-cd Helm chart version."
  default     = "9.5.21"
}
