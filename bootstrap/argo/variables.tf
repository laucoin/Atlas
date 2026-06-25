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

variable "disable_local_admin" {
  type        = bool
  description = <<-EOT
    When true, disables Argo CD's built-in local `admin` account so the only
    way in is Authentik SSO. Leave false during initial bootstrap (Phase 4)
    while OIDC is not yet wired — otherwise you'd lock yourself out until
    Phase 6. Flip to true and re-apply once SSO is verified. Re-enabling it
    (set back to false, re-apply) is the break-glass recovery path.
  EOT
  default     = false
}
