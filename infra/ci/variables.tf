variable "github_repository" {
  description = "The only GitHub repository allowed to sign in, exactly as GitHub names it: OIDC subjects are case-sensitive."
  type        = string
  default     = "Subash-1507/aci-observability-pipeline"
}

variable "state_storage_account_name" {
  description = "Name of the Terraform state storage account, read from infra/main/backend.hcl so it stays out of the repo."
  type        = string
}
