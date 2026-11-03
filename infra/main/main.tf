# Main configuration: the application's resource group, its private image registry, and the identity
# the container group uses to pull images. The container group itself is added in aci.tf.

provider "azurerm" {
  features {}
}

locals {
  tags = {
    project    = "aci-observability-pipeline"
    managed_by = "terraform"
    component  = "app"
  }
}

resource "azurerm_resource_group" "app" {
  name     = "rg-aciobs-app"
  location = var.location
  tags     = local.tags
}

# Registry names are global across Azure: a random suffix keeps the name unique and out of the code.
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

# One trusted source for every image the container group runs: no pulls from Docker Hub at runtime.
resource "azurerm_container_registry" "acr" {
  # Basic tier on a student budget. Most of these controls exist only in the Premium tier, at about 10x the price.
  # checkov:skip=CKV_AZURE_139:Network rules and private endpoints need Premium; anonymous pull is off and pulls need the AcrPull identity
  # checkov:skip=CKV_AZURE_166:Quarantine needs Premium; the API image is scanned by Trivy in CI and before every push
  # checkov:skip=CKV_AZURE_237:Dedicated data endpoints need Premium
  # checkov:skip=CKV_AZURE_233:Zone redundancy needs Premium
  # checkov:skip=CKV_AZURE_167:Retention policies need Premium; Chapter 8 deletes the registry
  # checkov:skip=CKV_AZURE_165:Geo-replication needs Premium; one region by design (ADR 0001)
  # checkov:skip=CKV_AZURE_164:Content trust is retired in ACR and the provider removed trust_policy_enabled in v5; third-party images are pinned by digest
  # checkov:skip=CKV_AZURE_163:Registry scanning is a paid Defender plan; the API image is scanned by Trivy in CI and before every push
  name                 = "acraciobs${random_string.suffix.result}"
  resource_group_name  = azurerm_resource_group.app.name
  location             = azurerm_resource_group.app.location
  sku                  = "Basic" # cheapest tier; network rules and private endpoints need Premium
  admin_enabled        = false   # no shared admin password: pushes use your Entra sign-in, pulls use the identity below
  role_assignment_mode = "LegacyRegistryPermissions"
  tags                 = local.tags
}

# The container group's identity. It can pull images and do nothing else.
resource "azurerm_user_assigned_identity" "acr_pull" {
  name                = "id-aciobs-acrpull"
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location
  tags                = local.tags
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.acr_pull.principal_id
  principal_type       = "ServicePrincipal" # a brand-new identity may not be visible to Entra ID yet; this skips that lookup
}
