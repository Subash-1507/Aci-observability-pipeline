# Written to infra/main/backend.hcl, which is git-ignored: the storage account name stays out of the repo.
output "backend_config" {
  description = "Backend settings for infra/main."
  value       = <<-EOT
    resource_group_name  = "${azurerm_resource_group.tfstate.name}"
    storage_account_name = "${azurerm_storage_account.tfstate.name}"
    container_name       = "${azurerm_storage_container.tfstate.name}"
    key                  = "main.tfstate"
    use_azuread_auth     = true
  EOT
}

output "budget_name" {
  description = "The subscription budget that warns at 50%, 80% and 100% of actual spend and 100% of forecast."
  value       = azurerm_consumption_budget_subscription.project.name
}
