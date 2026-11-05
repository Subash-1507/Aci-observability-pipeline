data "newrelic_entity" "order_api" {
  name   = "order-api"
  domain = "EXT"
  type   = "SERVICE"
}

# The SLO: at least 99% of orders in any 7 days are answered without a server error.
resource "newrelic_service_level" "availability" {
  guid        = data.newrelic_entity.order_api.guid
  name        = "Order API availability"
  description = "Share of orders answered without a server error (5xx)."

  events {
    account_id = var.new_relic_account_id

    valid_events {
      from  = "Span"
      where = local.nr_requests
    }

    good_events {
      from  = "Span"
      where = "${local.nr_requests} AND http.response.status_code < 500"
    }
  }

  objective {
    target = local.slo_target_percent

    time_window {
      rolling {
        count = local.slo_window_days
        unit  = "DAY"
      }
    }
  }
}

resource "newrelic_alert_policy" "order_api" {
  name                = "Order API"
  incident_preference = "PER_CONDITION"
}

# The alert. It reads spans, not the duration metric: spans are exact and arrive within seconds, the metric once a minute.
resource "newrelic_nrql_alert_condition" "p95_latency" {
  account_id                   = var.new_relic_account_id
  policy_id                    = newrelic_alert_policy.order_api.id
  type                         = "static"
  name                         = "P95 latency above ${local.latency_limit_ms} ms"
  description                  = "P95 latency has been above ${local.latency_limit_ms} ms for ${local.alert_minutes} minutes. Open a slow trace and follow it to its log line."
  enabled                      = true
  violation_time_limit_seconds = 86400

  nrql {
    query = "SELECT percentile(duration.ms, 95) FROM Span WHERE ${local.nr_requests}"
  }

  critical {
    operator              = "above"
    threshold             = local.latency_limit_ms
    threshold_duration    = local.alert_minutes * 60
    threshold_occurrences = "ALL"
  }

  aggregation_window = 60
  aggregation_method = "event_flow"
  aggregation_delay  = 60

  # The group is stopped when idle: silence is not an incident, and any open incident closes once the signal stops.
  fill_option                    = "none"
  expiration_duration            = 600
  open_violation_on_expiration   = false
  close_violations_on_expiration = true
}

# The notification path: destination (who), channel (what the email says), workflow (which issues use it).
resource "newrelic_notification_destination" "email" {
  account_id = var.new_relic_account_id
  name       = "Order API alert email"
  type       = "EMAIL"

  property {
    key   = "email"
    value = var.alert_email
  }

  # New Relic adds its own properties here, such as link_sent_email, around its address verification email.
  # Terraform must leave them alone. To change the address, recreate this resource with terraform apply -replace.
  lifecycle {
    ignore_changes = [property]
  }
}

resource "newrelic_notification_channel" "email" {
  account_id     = var.new_relic_account_id
  name           = "Order API alert email"
  type           = "EMAIL"
  destination_id = newrelic_notification_destination.email.id
  product        = "IINT"

  property {
    key   = "subject"
    value = "{{ issueTitle }}"
  }
}

resource "newrelic_workflow" "order_api" {
  account_id            = var.new_relic_account_id
  name                  = "Order API alerts"
  muting_rules_handling = "NOTIFY_ALL_ISSUES"

  issues_filter {
    name = "Order API policy"
    type = "FILTER"

    predicate {
      attribute = "labels.policyIds"
      operator  = "EXACTLY_MATCHES"
      values    = [newrelic_alert_policy.order_api.id]
    }
  }

  destination {
    channel_id = newrelic_notification_channel.email.id
  }
}

resource "newrelic_one_dashboard" "order_api" {
  name        = "Order API: traffic, errors, latency and SLO"
  permissions = "public_read_only" # readable inside this New Relic account, not on the internet

  page {
    name = "Order API"

    widget_billboard {
      title  = "Availability, last ${local.slo_window_days} days (target ${local.slo_target_percent}%)"
      row    = 1
      column = 1
      width  = 4
      height = 3

      nrql_query {
        query = "SELECT clamp_max(sum(newrelic.sli.good) / sum(newrelic.sli.valid) * 100, 100) AS 'Availability %' FROM Metric WHERE entity.guid = '${newrelic_service_level.availability.sli_guid}' SINCE ${local.slo_window_days} days ago"
      }
    }

    widget_billboard {
      title  = "Error budget left, last ${local.slo_window_days} days"
      row    = 1
      column = 5
      width  = 4
      height = 3

      nrql_query {
        query = "SELECT (1 - (sum(newrelic.sli.valid) - sum(newrelic.sli.good)) / (sum(newrelic.sli.valid) * ${(100 - local.slo_target_percent) / 100})) * 100 AS 'Budget left %' FROM Metric WHERE entity.guid = '${newrelic_service_level.availability.sli_guid}' SINCE ${local.slo_window_days} days ago"
      }
    }

    widget_billboard {
      title  = "P95 latency, last ${local.alert_minutes} minutes (ms)"
      row    = 1
      column = 9
      width  = 4
      height = 3

      nrql_query {
        query = "SELECT percentile(duration.ms, 95) FROM Span WHERE ${local.nr_requests} SINCE ${local.alert_minutes} minutes ago"
      }
    }

    widget_line {
      title  = "Requests per minute, by status code"
      row    = 4
      column = 1
      width  = 6
      height = 3

      nrql_query {
        query = "SELECT rate(count(*), 1 minute) FROM Span WHERE ${local.nr_requests} FACET http.response.status_code TIMESERIES"
      }
    }

    widget_line {
      title  = "Latency percentiles (ms)"
      row    = 4
      column = 7
      width  = 6
      height = 3

      nrql_query {
        query = "SELECT percentile(duration.ms, 50, 95, 99) FROM Span WHERE ${local.nr_requests} TIMESERIES"
      }
    }
  }
}
