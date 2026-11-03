terraform {
  required_version = ">= 1.16.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.12"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
  }

  # State lives in the storage account made by infra/bootstrap. The account details are in
  # backend.hcl (git-ignored): terraform init -backend-config=backend.hcl
  backend "azurerm" {}
}
