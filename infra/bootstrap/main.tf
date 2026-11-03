# Bootstrap: what must exist before the main configuration can run.
# 1. A spending alert for the whole subscription, created before anything that costs money.
# 2. The storage that holds Terraform's state for infra/main.
# This folder keeps its own state on disk (git-ignored): it cannot store its state in storage it is creating.

provider "azurerm" {
  features {}
  storage_use_azuread = true # sign in to storage with Entra ID: the account below has no usable keys
}

data "azurerm_subscription" "current" {}
data "azurerm_client_config" "current" {}

locals {
  tags = {
    project    = "aci-observability-pipeline"
    managed_by = "terraform"
    component  = "bootstrap"
  }
}

# Budget alerts go to the subscription's Owners, so no email address is written in this public code.
resource "azurerm_consumption_budget_subscription" "project" {
  name            = "budget-aci-observability"
  subscription_id = data.azurerm_subscription.current.id
  amount          = var.budget_amount
  time_grain      = "Monthly"

  time_period {
    start_date = var.budget_start_date
  }

  notification {
    threshold      = 50
    operator       = "GreaterThanOrEqualTo"
    threshold_type = "Actual"
    contact_roles  = ["Owner"]
  }

  notification {
    threshold      = 80
    operator       = "GreaterThanOrEqualTo"
    threshold_type = "Actual"
    contact_roles  = ["Owner"]
  }

  notification {
    threshold      = 100
    operator       = "GreaterThanOrEqualTo"
    threshold_type = "Actual"
    contact_roles  = ["Owner"]
  }

  # Warns before the money is spent: Azure projects the month's total from the spending so far.
  notification {
    threshold      = 100
    operator       = "GreaterThanOrEqualTo"
    threshold_type = "Forecasted"
    contact_roles  = ["Owner"]
  }
}

resource "azurerm_resource_group" "tfstate" {
  name     = "rg-aciobs-tfstate"
  location = var.location
  tags     = local.tags
}

# Storage account names are global across Azure: a random suffix keeps the name unique and out of the code.
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_storage_account" "tfstate" {
  # checkov:skip=CKV_AZURE_59:Reached from Codespaces and GitHub-hosted runners, which have no fixed IPs; every request needs Entra ID (keys are disabled) and anonymous access is off
  # checkov:skip=CKV2_AZURE_33:A private endpoint needs a virtual network that the Codespace and the runners are not in (same reason as CKV_AZURE_59)
  # checkov:skip=CKV_AZURE_33:No queues are used: the account holds only the Terraform state blobs
  # checkov:skip=CKV2_AZURE_1:Microsoft-managed keys plus infrastructure (double) encryption; a customer-managed key would add a Key Vault and key rotation for one small file
  name                     = "staciobstf${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.tfstate.name
  location                 = azurerm_resource_group.tfstate.location
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "GRS" # state is also copied to the paired region; versioning and soft delete guard against bad writes

  shared_access_key_enabled         = false # no account keys and no key-signed SAS: every request signs in with Entra ID
  default_to_oauth_authentication   = true
  allow_nested_items_to_be_public   = false # no anonymous blob access
  cross_tenant_replication_enabled  = false
  local_user_enabled                = false # no SFTP local users
  infrastructure_encryption_enabled = true  # a second layer of encryption at rest, at no cost
  https_traffic_only_enabled        = true
  min_tls_version                   = "TLS1_2"

  blob_properties {
    versioning_enabled = true # every state write keeps the previous version, so a bad apply can be rolled back

    delete_retention_policy {
      days = 7
    }

    container_delete_retention_policy {
      days = 7
    }
  }

  tags = local.tags
}

resource "azurerm_storage_container" "tfstate" {
  # checkov:skip=CKV2_AZURE_21:Read logging needs a Log Analytics workspace (paid ingestion) for one state file; access is Entra-only and limited to one role assignment
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate.id # created through Azure Resource Manager, not with a key
  container_access_type = "private"
}

# Terraform reads and writes state as the signed-in user, so that user needs data access to this one container.
resource "azurerm_role_assignment" "state_writer" {
  scope                = azurerm_storage_container.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}
