variable "location" {
  description = "Azure region for the application (see docs/decisions/0001-region-koreacentral.md)."
  type        = string
  default     = "koreacentral"
}

variable "api_image_tag" {
  description = "Tag of the order-api image in the registry. Also reported as service.version on every signal."
  type        = string
}

# The two vendor keys come from the git-ignored .env through TF_VAR_ environment variables, never from a file.
variable "new_relic_license_key" {
  description = "New Relic ingest license key."
  type        = string
  sensitive   = true
}

variable "datadog_api_key" {
  description = "Datadog API key."
  type        = string
  sensitive   = true
}

variable "datadog_site" {
  description = "Datadog site of the account."
  type        = string
  default     = "us5.datadoghq.com"
}

variable "loadgen_interval_seconds" {
  description = "Seconds between two orders from the load generator."
  type        = number
  default     = 2
}

variable "loadgen_fault_percent" {
  description = "Share of orders that simulate a payment-gateway timeout: 0 normally, raised for the incident drill."
  type        = number
  default     = 20 # Chapter 7 drill: a deliberate bad release. Revert this commit to recover.

  validation {
    condition     = var.loadgen_fault_percent >= 0 && var.loadgen_fault_percent <= 100
    error_message = "loadgen_fault_percent must be between 0 and 100."
  }
}
