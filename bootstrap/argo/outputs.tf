output "argocd_namespace" {
  value       = "argocd"
  description = "Namespace where Argo CD is installed."
}

output "initial_admin_password_command" {
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
  description = "Shell command that prints the initial admin password."
}

output "port_forward_command" {
  value       = "kubectl -n argocd port-forward svc/argocd-server 8080:80"
  description = "Until Phase 5 wires Traefik, reach the UI via port-forward."
}
