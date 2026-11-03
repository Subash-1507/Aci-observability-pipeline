variable "location" {
  description = "Azure region for the state storage (see docs/decisions/0001-region-koreacentral.md)."
  type        = string
  default     = "koreacentral"
}

variable "budget_amount" {
  description = "Monthly budget for the whole subscription, in the billing currency (INR)."
  type        = number
  default     = 1000
}

variable "budget_start_date" {
  description = "First month the budget tracks. Azure requires the first day of a month, in UTC."
  type        = string
  default     = "2026-11-01T00:00:00Z"
}
