# Used by the image and container commands in the terminal; not written to any committed file.
output "acr_name" {
  description = "Name of the container registry."
  value       = azurerm_container_registry.acr.name
}

output "acr_login_server" {
  description = "Registry address used in image names."
  value       = azurerm_container_registry.acr.login_server
}

output "container_group_name" {
  description = "Name of the container group, for az container logs, stop and start."
  value       = azurerm_container_group.app.name
}
