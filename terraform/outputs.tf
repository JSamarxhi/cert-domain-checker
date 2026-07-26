# Values printed after `terraform apply`, and readable later with
# `terraform output`. Useful for anything you would otherwise hunt for
# in the portal.

output "app_url" {
  description = "Public URL of the running service."
  value       = "https://${azurerm_container_app.main.ingress[0].fqdn}"
}

output "health_url" {
  description = "Health endpoint, for a quick post-deploy check."
  value       = "https://${azurerm_container_app.main.ingress[0].fqdn}/health"
}

output "docs_url" {
  description = "Interactive API documentation."
  value       = "https://${azurerm_container_app.main.ingress[0].fqdn}/docs"
}

output "resource_group_name" {
  description = "Resource group holding every resource in this configuration."
  value       = azurerm_resource_group.main.name
}
