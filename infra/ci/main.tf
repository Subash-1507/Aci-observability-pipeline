# Who may deploy: the two identities GitHub Actions signs in as (OIDC, no stored secret) and exactly what each may do.
# A person runs this folder, never the pipeline, so the pipeline cannot widen its own permissions.
# Both identities live in the state resource group, where neither has any rights.

provider "azurerm" {
  features {}
}

data "azurerm_resource_group" "state" {
  name = "rg-aciobs-tfstate"
}

data "azurerm_resource_group" "app" {
  name = "rg-aciobs-app"
}

data "azurerm_storage_account" "state" {
  name                = var.state_storage_account_name
  resource_group_name = data.azurerm_resource_group.state.name
}

locals {
  tags = {
    project    = "aci-observability-pipeline"
    managed_by = "terraform"
    component  = "ci"
  }
  github_issuer   = "https://token.actions.githubusercontent.com"
  github_audience = ["api://AzureADTokenExchange"]
  state_container = "${data.azurerm_storage_account.state.id}/blobServices/default/containers/tfstate"
}

# ---- Deploy identity: only jobs in the GitHub environment "azure", which waits for a reviewer's approval.
resource "azurerm_user_assigned_identity" "deploy" {
  name                = "id-aciobs-deploy"
  resource_group_name = data.azurerm_resource_group.state.name
  location            = data.azurerm_resource_group.state.location
  tags                = local.tags
}

resource "azurerm_federated_identity_credential" "deploy" {
  name                      = "github-environment-azure"
  user_assigned_identity_id = azurerm_user_assigned_identity.deploy.id
  issuer                    = local.github_issuer
  audience                  = local.github_audience
  subject                   = "repo:${var.github_repository}:environment:azure"
}

# Pushes images and replaces the container group: the app resource group only.
resource "azurerm_role_assignment" "deploy_app" {
  scope                = data.azurerm_resource_group.app.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.deploy.principal_id
  principal_type       = "ServicePrincipal"
}

# Reads and writes infra/main's Terraform state: the state container only.
resource "azurerm_role_assignment" "deploy_state" {
  scope                = local.state_container
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.deploy.principal_id
  principal_type       = "ServicePrincipal"
}

# ---- Power identity: the Start/Stop buttons in the GitHub environment "azure-power". No approval, so almost no rights.
resource "azurerm_user_assigned_identity" "power" {
  name                = "id-aciobs-power"
  resource_group_name = data.azurerm_resource_group.state.name
  location            = data.azurerm_resource_group.state.location
  tags                = local.tags
}

resource "azurerm_federated_identity_credential" "power" {
  name                      = "github-environment-azure-power"
  user_assigned_identity_id = azurerm_user_assigned_identity.power.id
  issuer                    = local.github_issuer
  audience                  = local.github_audience
  subject                   = "repo:${var.github_repository}:environment:azure-power"
}

# A custom role with three permissions: see, start and stop container groups. Nothing else.
resource "azurerm_role_definition" "aci_power" {
  name              = "ACI start-stop (aci-observability-pipeline)"
  scope             = data.azurerm_resource_group.app.id
  description       = "Read, start and stop container groups. Nothing else."
  assignable_scopes = [data.azurerm_resource_group.app.id]

  permissions {
    actions = [
      "Microsoft.ContainerInstance/containerGroups/read",
      "Microsoft.ContainerInstance/containerGroups/start/action",
      "Microsoft.ContainerInstance/containerGroups/stop/action",
    ]
  }
}

resource "azurerm_role_assignment" "power" {
  scope              = data.azurerm_resource_group.app.id
  role_definition_id = azurerm_role_definition.aci_power.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.power.principal_id
  principal_type     = "ServicePrincipal"
}
