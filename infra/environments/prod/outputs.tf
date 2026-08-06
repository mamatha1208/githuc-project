output "resource_group_name" {
  value = module.app.resource_group_name
}

output "acr_login_server" {
  value = module.app.acr_login_server
}

output "acr_name" {
  value = module.app.acr_name
}

output "container_app_name" {
  value = module.app.container_app_name
}

output "container_app_fqdn" {
  value = module.app.container_app_fqdn
}

output "latest_revision_name" {
  value = module.app.latest_revision_name
}
