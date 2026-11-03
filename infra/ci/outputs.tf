# Client IDs for the GitHub environment secrets. Printed in the terminal only, never committed.
output "deploy_client_id" {
  description = "AZURE_CLIENT_ID for the GitHub environment azure."
  value       = azurerm_user_assigned_identity.deploy.client_id
}

output "power_client_id" {
  description = "AZURE_CLIENT_ID for the GitHub environment azure-power."
  value       = azurerm_user_assigned_identity.power.client_id
}
