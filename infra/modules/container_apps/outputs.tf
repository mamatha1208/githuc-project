output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "acr_login_server" {
  value = azurerm_container_registry.this.login_server
}

output "acr_name" {
  value = azurerm_container_registry.this.name
}

output "container_app_name" {
  value = azurerm_container_app.this.name
}

output "container_app_fqdn" {
  description = "Public URL of the deployed app"
  value       = azurerm_container_app.this.latest_revision_fqdn
}

output "latest_revision_name" {
  description = "Name of the revision just deployed — save this if you need to roll back to it later"
  value       = azurerm_container_app.this.latest_revision_name
}
