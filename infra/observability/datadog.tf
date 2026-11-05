# The SLO: at least 99% of orders in any 7 days are answered without a server error.
resource "datadog_service_level_objective" "availability" {
  name        = "Order API availability"
  type        = "metric"
  description = "Share of orders answered without a server error (5xx)."

  query {
    numerator   = "sum:${local.dd_hits}{${local.dd_scope},!http.status_class:5xx}.as_count()"
    denominator = "sum:${local.dd_hits}{${local.dd_scope}}.as_count()"
  }

  thresholds {
    timeframe = "${local.slo_window_days}d"
    target    = local.slo_target_percent
  }

  tags = ["service:order-api", "env:azure"]
}

# The alert. No "no data" notification: the group is stopped when idle, and silence is not an incident.
resource "datadog_monitor" "p95_latency" {
  name    = "Order API: P95 latency above ${local.latency_limit_ms} ms"
  type    = "metric alert"
  query   = "percentile(last_${local.alert_minutes}m):p95:${local.dd_duration} > ${local.latency_limit_ms / 1000}"
  message = "P95 latency has been above ${local.latency_limit_ms} ms for ${local.alert_minutes} minutes. Open a slow trace and follow it to its log line. @${var.alert_email}"

  monitor_thresholds {
    critical = local.latency_limit_ms / 1000
  }

  notify_no_data      = false
  require_full_window = false
  include_tags        = false

  tags = ["service:order-api", "env:azure"]
}

resource "datadog_dashboard" "order_api" {
  title       = "Order API: traffic, errors, latency and SLO"
  description = "The same questions as the New Relic dashboard, from Datadog's own data."
  layout_type = "ordered"
  reflow_type = "auto"

  widget {
    service_level_objective_definition {
      title             = "Availability, last ${local.slo_window_days} days (target ${local.slo_target_percent}%)"
      view_type         = "detail"
      view_mode         = "overall"
      slo_id            = datadog_service_level_objective.availability.id
      time_windows      = ["${local.slo_window_days}d"]
      show_error_budget = true
    }
  }

  widget {
    timeseries_definition {
      title = "Requests, by status class"

      request {
        display_type = "bars"

        formula {
          formula_expression = "requests"
        }

        query {
          metric_query {
            data_source = "metrics"
            name        = "requests"
            query       = "sum:${local.dd_hits}{${local.dd_scope}} by {http.status_class}.as_count()"
          }
        }
      }
    }
  }

  widget {
    timeseries_definition {
      title = "Latency percentiles"

      request {
        display_type = "line"

        formula {
          formula_expression = "p50"
          alias              = "P50"
        }

        formula {
          formula_expression = "p95"
          alias              = "P95"
        }

        formula {
          formula_expression = "p99"
          alias              = "P99"
        }

        query {
          metric_query {
            data_source = "metrics"
            name        = "p50"
            query       = "p50:${local.dd_duration}"
          }
        }

        query {
          metric_query {
            data_source = "metrics"
            name        = "p95"
            query       = "p95:${local.dd_duration}"
          }
        }

        query {
          metric_query {
            data_source = "metrics"
            name        = "p99"
            query       = "p99:${local.dd_duration}"
          }
        }
      }

      marker {
        value        = "y = ${local.latency_limit_ms / 1000}"
        display_type = "error dashed"
        label        = "Alert line"
      }
    }
  }
}
