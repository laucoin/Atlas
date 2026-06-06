output "cluster_endpoint" {
  value       = local.cluster_endpoint
  description = "Kubernetes API endpoint URL."
}

output "kubeconfig_path" {
  value       = local_sensitive_file.kubeconfig.filename
  description = "Path on disk to the generated kubeconfig."
}

output "talosconfig_path" {
  value       = local_sensitive_file.talosconfig.filename
  description = "Path on disk to the generated talosconfig."
}
