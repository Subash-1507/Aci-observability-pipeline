variable "new_relic_account_id" {
  description = "New Relic account ID, from the git-ignored .env so it stays out of the repo and out of plan output."
  type        = number
  sensitive   = true
}

variable "alert_email" {
  description = "Address that receives alert notifications, from the git-ignored .env."
  type        = string
  sensitive   = true
}

locals {
  slo_target_percent = 99
  slo_window_days    = 7
  latency_limit_ms   = 800
  alert_minutes      = 5

  # New Relic: the API's server spans in Azure, one per order. Health checks produce no spans (excluded in the app).
  nr_requests = "service.name = 'order-api' AND deployment.environment.name = 'azure' AND span.kind = 'server'"

  # Datadog: the request count Datadog builds from those spans. An SLO needs a count metric, and this one carries the status class.
  dd_hits  = "trace.http.server.request.hits.by_http_status"
  dd_scope = "env:azure,service:order-api"

  # Datadog: the API's own duration histogram, which gives percentiles without extra setup.
  dd_duration = "http.server.request.duration{env:azure,service.name:order-api}"
}
