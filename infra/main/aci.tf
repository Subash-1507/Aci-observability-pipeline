# The container group: the same three containers as compose.yaml plus a load generator, sharing localhost like a pod.
# No public IP: nothing is reachable from the internet. Every image comes from the private registry.

locals {
  registry  = azurerm_container_registry.acr.login_server
  api_image = "${local.registry}/order-api:${var.api_image_tag}"
  # Third-party images by digest, the same digests as compose.yaml: a tag can be moved to another image, a digest cannot.
  redis_image     = "${local.registry}/redis@sha256:21090af93f8324db2f0f0f4f38a7c60369d47d917e000c3423d89d2ae2883537"
  collector_image = "${local.registry}/otel/opentelemetry-collector-contrib@sha256:340c9ca6a36617084c6661bdc4f0fe92b7cda5a805d61673ec8db375fddc522b"
}

resource "azurerm_container_group" "app" {
  # checkov:skip=CKV_AZURE_98:The group has no IP address at all (ip_address_type None), so nothing can connect in; a VNet would only add a delegated subnet and NAT for outbound traffic
  # checkov:skip=CKV_AZURE_235:The plain environment variables are non-secret OpenTelemetry settings; the two vendor keys are secure_environment_variables
  name                = "ci-aciobs-app"
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location
  os_type             = "Linux"
  ip_address_type     = "None" # no inbound traffic at all: the load generator calls the API over localhost
  restart_policy      = "Always"
  tags                = local.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.acr_pull.id]
  }

  # Images are pulled with the identity's AcrPull role: no registry password exists anywhere.
  image_registry_credential {
    server                    = local.registry
    user_assigned_identity_id = azurerm_user_assigned_identity.acr_pull.id
  }

  container {
    name   = "order-api"
    image  = local.api_image
    cpu    = 0.5
    memory = 0.5

    environment_variables = {
      REDIS_HOST                                        = "localhost"
      OTEL_SERVICE_NAME                                 = "order-api"
      OTEL_RESOURCE_ATTRIBUTES                          = "deployment.environment.name=azure,service.version=${var.api_image_tag},cloud.provider=azure,cloud.platform=azure_container_instances,cloud.region=${var.location}"
      OTEL_EXPORTER_OTLP_ENDPOINT                       = "http://localhost:4318"
      OTEL_EXPORTER_OTLP_PROTOCOL                       = "http/protobuf"
      OTEL_TRACES_EXPORTER                              = "otlp"
      OTEL_METRICS_EXPORTER                             = "otlp"
      OTEL_LOGS_EXPORTER                                = "otlp"
      OTEL_PYTHON_LOGGING_AUTO_INSTRUMENTATION_ENABLED  = "true"
      OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE = "delta"
      OTEL_METRIC_EXPORT_INTERVAL                       = "60000" # once a minute in the cloud (every 10 s locally)
      OTEL_PYTHON_FASTAPI_EXCLUDED_URLS                 = "health"
      OTEL_SEMCONV_STABILITY_OPT_IN                     = "http"
    }

    # ACI ignores the image's Docker HEALTHCHECK, so the same check runs here, inside the container: restart the API if
    # /health stops answering. An exec probe, not http_get: ACI's HTTP probe counted this API's 200 responses as failures.
    # No commas in the command: ACI splits exec arguments at commas. timeout_seconds limits how long the check may take.
    liveness_probe {
      exec                  = ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health')"]
      initial_delay_seconds = 30 # Python and OpenTelemetry need more than 10 s to start on 0.5 vCPU
      period_seconds        = 30
      failure_threshold     = 3
      timeout_seconds       = 5
    }
  }

  container {
    name   = "redis"
    image  = local.redis_image
    cpu    = 0.2
    memory = 0.3
    # A cache only, nothing written to disk, as in compose.yaml. ACI cannot set the container's user, so the image's
    # entrypoint drops from root to the redis user. The shell passes the empty --save value, which ACI commands cannot hold.
    commands = ["sh", "-c", "exec docker-entrypoint.sh redis-server --save '' --appendonly no"]
  }

  container {
    name   = "otel-collector"
    image  = local.collector_image
    cpu    = 0.3
    memory = 0.5
    # ACI replaces the image's whole start command (Compose replaces only its arguments), so the program is named too.
    commands = ["/otelcol-contrib", "--config=/etc/otelcol-contrib/config.yaml"]

    environment_variables = {
      DD_SITE = var.datadog_site
    }

    # Hidden in the portal and the Azure API; kept only in Terraform state, inside the locked-down state storage.
    secure_environment_variables = {
      NEW_RELIC_LICENSE_KEY = var.new_relic_license_key
      DD_API_KEY            = var.datadog_api_key
    }

    # The same config file Docker Compose uses, mounted read-only. A secret volume mounts a file without a storage account.
    volume {
      name       = "collector-config"
      mount_path = "/etc/otelcol-contrib"
      read_only  = true
      secret = {
        "config.yaml" = base64encode(file("${path.module}/../../otel/collector.yaml"))
      }
    }

    liveness_probe {
      http_get {
        path   = "/"
        port   = 13133
        scheme = "http"
      }
      initial_delay_seconds = 10
      period_seconds        = 30
      failure_threshold     = 3
    }
  }

  container {
    name     = "loadgen"
    image    = local.api_image # the API image with a different start command: no extra image to trust
    cpu      = 0.1
    memory   = 0.2
    commands = ["python", "-m", "src.loadgen"]

    environment_variables = {
      LOADGEN_TARGET           = "http://localhost:8000"
      LOADGEN_INTERVAL_SECONDS = tostring(var.loadgen_interval_seconds)
      LOADGEN_FAULT_PERCENT    = tostring(var.loadgen_fault_percent)
    }
  }

  depends_on = [azurerm_role_assignment.acr_pull] # the identity must be allowed to pull before the first pull
}
