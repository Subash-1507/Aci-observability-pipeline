terraform {
  required_version = ">= 1.16.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.12"
    }
  }

  # Same state storage as infra/main, in its own blob:
  # terraform init -backend-config=../main/backend.hcl -backend-config=key=ci.tfstate
  backend "azurerm" {}
}
