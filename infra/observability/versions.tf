terraform {
  required_version = ">= 1.16.0"

  required_providers {
    newrelic = {
      source  = "newrelic/newrelic"
      version = "~> 3.101"
    }
    datadog = {
      source  = "DataDog/datadog"
      version = "~> 4.29"
    }
  }

  # Same state storage as infra/main, in its own blob:
  # terraform init -backend-config=../main/backend.hcl -backend-config=key=observability.tfstate
  backend "azurerm" {}
}

# Both providers read their keys from the environment (the git-ignored .env here), never from code.
provider "newrelic" {}

provider "datadog" {}
