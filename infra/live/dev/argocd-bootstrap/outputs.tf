output "argocd_namespace" {
  description = "Argo CD namespace."
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "root_application_name" {
  description = "Root Argo CD Application name."
  value       = "root-dev"
}

output "port_forward_command" {
  description = "Command to access Argo CD UI locally."
  value       = "kubectl -n argocd port-forward svc/argocd-server 8080:80"
}

output "initial_admin_password_command" {
  description = "Command to read the initial Argo CD admin password."
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}
