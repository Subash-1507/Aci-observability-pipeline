variable "github_subject_prefix" {
  description = "Start of the OIDC subject GitHub sends for this repository: owner and repository names plus their immutable numeric IDs, so a renamed or re-created repository cannot sign in. Check it with: gh api repos/Subash-1507/aci-observability-pipeline/actions/oidc/customization/sub"
  type        = string
  default     = "repo:Subash-1507@91477713/aci-observability-pipeline@1441545527"
}

variable "state_storage_account_name" {
  description = "Name of the Terraform state storage account, read from infra/main/backend.hcl so it stays out of the repo."
  type        = string
}
