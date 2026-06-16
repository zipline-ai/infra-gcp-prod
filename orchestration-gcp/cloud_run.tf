# Google Artifact Registry - Remote Repository for Docker Hub
resource "google_project_service" "artifact_registry" {
  project = var.project_id
  service = "artifactregistry.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy         = false
}

resource "time_sleep" "artifact_registry_service_agent" {
  create_duration = "60s"

  depends_on = [google_project_service.artifact_registry]
}

resource "google_project_iam_member" "artifact_registry_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:service-${var.project_number}@gcp-sa-artifactregistry.iam.gserviceaccount.com"

  depends_on = [time_sleep.artifact_registry_service_agent]
}

resource "google_artifact_registry_repository" "docker_hub_remote_repository" {
  format        = "DOCKER"
  repository_id = "${var.name_prefix}-zipline-docker-hub-proxy"
  location      = var.region
  description   = "Remote repository for Docker images from Docker Hub"
  mode          = "REMOTE_REPOSITORY"
  remote_repository_config {
    description = "Proxy repository for ziplineai images on Docker Hub"
    docker_repository {
      public_repository = "DOCKER_HUB"
    }

    upstream_credentials {
      username_password_credentials {
        username                = "ziplineai"
        password_secret_version = google_secret_manager_secret_version.docker_token_version.name
      }
    }
  }
  depends_on = [
    google_project_service.artifact_registry,
    google_project_iam_member.artifact_registry_secret_accessor,
    google_secret_manager_secret_version.docker_token_version
  ]
}

locals {
  use_zipline_custom_domain = var.zipline_custom_domain != ""

  default_hub_url     = "https://${var.name_prefix}-zipline-orchestration-${var.project_number}.${var.region}.run.app"
  default_ui_url      = "https://${var.name_prefix}-zipline-ui-${var.project_number}.${var.region}.run.app"
  default_eval_url    = "https://${var.name_prefix}-zipline-chronon-eval-${var.project_number}.${var.region}.run.app"
  default_fetcher_url = "https://${var.name_prefix}-zipline-chronon-fetcher-${var.project_number}.${var.region}.run.app"

  hub_url     = local.use_zipline_custom_domain ? "https://${var.zipline_custom_domain}/services/hub" : var.hub_domain != "" ? "https://${var.hub_domain}" : local.default_hub_url
  ui_url      = local.use_zipline_custom_domain ? "https://${var.zipline_custom_domain}" : var.zipline_ui_domain != "" ? "https://${var.zipline_ui_domain}" : local.default_ui_url
  eval_url    = local.use_zipline_custom_domain ? "https://${var.zipline_custom_domain}/services/eval" : var.zipline_eval_domain != "" ? "https://${var.zipline_eval_domain}" : local.default_eval_url
  fetcher_url = local.use_zipline_custom_domain ? "https://${var.zipline_custom_domain}/services/fetcher" : local.default_fetcher_url

  hub_custom_domain_enabled  = local.use_zipline_custom_domain || var.hub_domain != ""
  ui_custom_domain_enabled   = local.use_zipline_custom_domain || var.zipline_ui_domain != ""
  eval_custom_domain_enabled = local.use_zipline_custom_domain || var.zipline_eval_domain != ""
}

resource "google_secret_manager_secret" "docker_token" {
  secret_id = "${var.name_prefix}-zipline-docker-token"
  replication {
    auto {}
  }

  depends_on = [google_project_service.secrets]
}

resource "google_secret_manager_secret_version" "docker_token_version" {
  secret      = google_secret_manager_secret.docker_token.id
  secret_data = var.docker_hub_token
}

# Enable required APIs
resource "google_project_service" "cloudrun_api" {
  project = var.project_id
  service = "run.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy         = false
}

resource "google_project_service" "iap_api" {
  project = var.project_id
  service = "iap.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy         = false
}

##############################################################
# Service Accounts and IAM Roles

# Service Account for Orchestration
resource "google_service_account" "orchestration_service_account" {
  account_id   = "${var.name_prefix}-zipline-orch-sa"
  display_name = "Zipline Cloud Run Service Account"
  project      = var.project_id
}

resource "google_project_iam_member" "orchestration_service_account_dataproc" {
  project = var.project_id
  member  = "serviceAccount:${google_service_account.orchestration_service_account.email}"
  role    = "roles/dataproc.editor"
}

resource "google_project_iam_member" "orchestration_service_account_storage" {
  project = var.project_id
  member  = "serviceAccount:${google_service_account.orchestration_service_account.email}"
  role    = "roles/storage.objectAdmin"
}

resource "google_project_iam_member" "orchestration_service_account_cloudsql" {
  project = var.project_id
  member  = "serviceAccount:${google_service_account.orchestration_service_account.email}"
  role    = "roles/cloudsql.client"
}

resource "google_project_iam_member" "orchestration_service_account_bigtable" {
  project = var.project_id
  member  = "serviceAccount:${google_service_account.orchestration_service_account.email}"
  role    = "roles/bigtable.user"
}

resource "google_project_iam_member" "orchestration_service_account_secretmanager" {
  project = var.project_id
  member  = "serviceAccount:${google_service_account.orchestration_service_account.email}"
  role    = "roles/secretmanager.secretAccessor"
}

resource "google_project_iam_member" "orchestration_logging" {
  project = var.project_id
  role    = "roles/logging.viewer"
  member  = "serviceAccount:${google_service_account.orchestration_service_account.email}"
}


resource "google_project_iam_member" "orchestration_logging_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.orchestration_service_account.email}"
}

resource "google_project_iam_member" "orchestration_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.orchestration_service_account.email}"
}

# Grant Dataproc access to the Orchestration service account
resource "google_service_account_iam_member" "orchestration_impersonation_dataproc" {
  service_account_id = var.dataproc_service_account
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.orchestration_service_account.email}"
}

resource "google_compute_ssl_policy" "ingress_ssl_policy" {
  name    = "${var.name_prefix}-zipline-ingress-ssl-policy"
  project = var.project_id

  # Modern profile with strong security
  profile         = "MODERN"
  min_tls_version = "TLS_1_2"
}

##############################################################
# Service Account for Eval (Metadata-only access)

resource "google_service_account" "eval_service_account" {
  account_id   = "${var.name_prefix}-zipline-eval-sa"
  display_name = "Chronon Eval Metadata Reader"
  description  = "Service account for Chronon eval with metadata-only access (no data access)"
  project      = var.project_id
}

# Grant BigQuery metadata viewer role (read table schemas, partitions)
resource "google_project_iam_member" "eval_metadata_viewer" {
  project = var.project_id
  role    = "roles/bigquery.metadataViewer"
  member  = "serviceAccount:${google_service_account.eval_service_account.email}"
}

# Grant BigQuery data viewer role
# Required since we are querying with limit 0 to transform BigQuery schemas until added to tableUtils
resource "google_project_iam_member" "eval_data_viewer" {
  project = var.project_id
  role    = "roles/bigquery.dataViewer"
  member  = "serviceAccount:${google_service_account.eval_service_account.email}"
}

# Grant BigQuery job user role (run metadata queries)
resource "google_project_iam_member" "eval_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.eval_service_account.email}"
}

# Grant Cloud SQL client access for eval database connection
resource "google_project_iam_member" "eval_cloudsql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.eval_service_account.email}"
}

# Grant logging permissions
resource "google_project_iam_member" "eval_logging_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.eval_service_account.email}"
}

# Grant monitoring permissions
resource "google_project_iam_member" "eval_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.eval_service_account.email}"
}

# Grant secret manager access for database credentials
resource "google_project_iam_member" "eval_secretmanager" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.eval_service_account.email}"
}

# Grant Cloud Storage viewer access for reading buckets
resource "google_project_iam_member" "eval_storage_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.eval_service_account.email}"
}

# Grant service account token creator to specified users/groups for impersonation
resource "google_service_account_iam_member" "eval_impersonation" {
  for_each = toset(var.eval_impersonation_users)

  service_account_id = google_service_account.eval_service_account.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = each.value
}

################################################################
# Cloud Run v2 service for Orchestration Hub

resource "google_cloud_run_v2_service" "orchestration" {
  name     = "${var.name_prefix}-zipline-orchestration"
  location = var.region

  custom_audiences = [
    local.hub_url
  ]
  ingress              = local.hub_custom_domain_enabled ? "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER" : "INGRESS_TRAFFIC_ALL"
  invoker_iam_disabled = var.zipline_auth_enabled

  template {

    vpc_access {
      network_interfaces {
        network    = var.vpc_name
        subnetwork = var.subnet_name
      }
      egress = "PRIVATE_RANGES_ONLY"
    }
    # Main orchestration container
    containers {
      name  = "orchestration-hub"
      image = "${google_artifact_registry_repository.docker_hub_remote_repository.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_hub_remote_repository.repository_id}/ziplineai/hub-gcp:${var.zipline_version}"
      env {
        name  = "DB_URL"
        value = "jdbc:postgresql://${google_sql_database_instance.orchestration_instance.private_ip_address}:5432/${google_sql_database.orchestration_database.name}"
      }
      env {
        name  = "DB_USERNAME"
        value = google_sql_user.orchestration_user.name
      }
      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_password.secret_id
            version = "latest"
          }
        }
      }
      env {
        name  = "GCP_REGION"
        value = var.region
      }
      env {
        name  = "GCP_PROJECT_ID"
        value = var.project_id
      }
      env {
        name  = "GCP_BIGTABLE_INSTANCE_ID"
        value = var.bigtable_instance_name
      }
      env {
        name  = "CUSTOMER_ID"
        value = var.name_prefix
      }
      env {
        name  = "USE_TEMPORAL"
        value = false
      }
      env {
        name  = "VERTICLE_CLASS"
        value = "ai.chronon.hub.GCPOrchestrationVerticle,ai.chronon.hub.GCPWorkflowExecutionVerticle"
      }
      env {
        name  = "BIGTABLE_INITIAL_RPC_TIMEOUT_DURATION"
        value = "PT0.5S"
      }
      env {
        name  = "BIGTABLE_MAX_RPC_TIMEOUT_DURATION"
        value = "PT0.5S"
      }
      env {
        name  = "ORCHESTRATION_PORT"
        value = 3903
      }
      env {
        name  = "TABLE_PARTITIONS_DATASET"
        value = var.table_partitions_dataset
      }
      env {
        name  = "DATA_QUALITY_METRICS_DATASET"
        value = var.data_quality_metrics_dataset
      }
      env {
        name  = "USE_HTTPS"
        value = "true"
      }
      env {
        name  = "CHRONON_METRICS_READER"
        value = "http"
      }
      env {
        name  = "EXPORTER_OTLP_ENDPOINT"
        value = "http://localhost:4318"
      }
      env {
        name  = "HUB_FRONTEND_URL"
        value = local.ui_url
      }
      # Zipline Authentication
      env {
        name  = "AUTH_ENABLED"
        value = var.zipline_auth_enabled
      }
      dynamic "env" {
        for_each = var.zipline_auth_enabled ? [1] : []
        content {
          name  = "AUTH_JWKS_URL"
          value = "${local.ui_url}/api/auth/jwks"
        }
      }

      ports {
        container_port = 3903
      }
      resources {
        limits = {
          cpu    = "6000m"
          memory = "16Gi"
        }
      }
    }
    # OpenTelemetry sidecar container
    containers {
      image = "otel/opentelemetry-collector-contrib:0.91.0"
      name  = "otel-collector"

      args = ["--config=env:OTEL_CONFIG_YAML"]

      env {
        name = "OTEL_CONFIG_YAML"
        value = yamlencode({
          receivers = {
            otlp = {
              protocols = {
                grpc = {
                  endpoint = "0.0.0.0:4317"
                }
                http = {
                  endpoint = "0.0.0.0:4318"
                }
              }
            }
          }
          processors = {
            resourcedetection = {
              detectors = ["env", "gcp"]
              timeout   = "5s"
              override  = false
            }
            resource = {
              attributes = [
                {
                  key    = "location"
                  value  = var.region
                  action = "upsert"
                },
                {
                  key    = "namespace"
                  value  = var.name_prefix
                  action = "upsert"
                },
                {
                  key    = "cluster"
                  value  = "zipline-${var.name_prefix}"
                  action = "upsert"
                }
              ]
            }
          }
          exporters = {
            googlemanagedprometheus = {
              project = var.project_id
            }
          }
          service = {
            pipelines = {
              metrics = {
                receivers  = ["otlp"]
                processors = ["resourcedetection", "resource"]
                exporters  = ["googlemanagedprometheus"]
              }
            }
          }
        })
      }

      resources {
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
      }
    }

    scaling {
      min_instance_count = 1
      max_instance_count = 1
    }
    service_account = google_service_account.orchestration_service_account.email
  }

  depends_on = [
    google_artifact_registry_repository.docker_hub_remote_repository,
    google_service_account.orchestration_service_account,
    google_project_iam_member.orchestration_service_account_cloudsql,
    google_project_iam_member.orchestration_monitoring,
    google_sql_database.orchestration_database,
  ]

  lifecycle {
    ignore_changes = [
      template[0].containers[0].resources[0].cpu_idle,
      template[0].labels,
      client,
      client_version,
      scaling,
    ]
  }
}

resource "google_cloud_run_v2_service_iam_member" "orchestration_personnel_access" {
  name     = google_cloud_run_v2_service.orchestration.name
  location = google_cloud_run_v2_service.orchestration.location
  role     = "roles/run.invoker"
  member   = "group:${var.personnel_email}"
}

resource "google_cloud_run_v2_service_iam_member" "orchestration_users_access" {
  count    = var.users_email != "" ? 1 : 0
  name     = google_cloud_run_v2_service.orchestration.name
  location = google_cloud_run_v2_service.orchestration.location
  role     = "roles/run.invoker"
  member   = "group:${var.users_email}"
}

resource "google_cloud_run_v2_service_iam_member" "orchestration_ui_hub_access" {
  name     = google_cloud_run_v2_service.orchestration.name
  location = google_cloud_run_v2_service.orchestration.location
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.orchestration_service_account.email}"
}

###############################################################
# Cloud Run v2 service for Orchestration UI

resource "google_cloud_run_v2_service" "zipline_ui" {
  name     = "${var.name_prefix}-zipline-ui"
  project  = var.project_id
  location = var.region

  ingress              = local.ui_custom_domain_enabled ? "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER" : "INGRESS_TRAFFIC_ALL"
  invoker_iam_disabled = var.zipline_auth_enabled
  custom_audiences = [
    local.ui_url
  ]
  template {
    vpc_access {
      network_interfaces {
        network    = var.vpc_name
        subnetwork = var.subnet_name
      }
      egress = "ALL_TRAFFIC"
    }
    service_account = google_service_account.orchestration_service_account.email
    labels = {
      container_name = "web-ui"
    }
    containers {
      name  = "web-ui"
      image = "${google_artifact_registry_repository.docker_hub_remote_repository.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_hub_remote_repository.repository_id}/ziplineai/web-ui:${var.zipline_version}"

      env {
        name  = "API_BASE_URL"
        value = google_cloud_run_v2_service.orchestration.uri
      }
      env {
        name  = "DATABASE_URL"
        value = "postgres://${google_sql_user.orchestration_user.name}@${google_sql_database_instance.orchestration_instance.private_ip_address}:5432/${google_sql_database.orchestration_database.name}"
      }
      env {
        name = "PGPASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_password.secret_id
            version = "latest"
          }
        }
      }
      env {
        name  = "GOOGLE_CLOUD_PROJECT"
        value = var.project_id
      }
      env {
        name  = "PUBLIC_ORCH_SERVER_NAME"
        value = google_cloud_run_v2_service.orchestration.name
      }
      dynamic "env" {
        for_each = var.deploy_fetcher ? [1] : []
        content {
          name  = "FETCHER_BASE_URL"
          value = local.use_zipline_custom_domain ? local.fetcher_url : google_cloud_run_v2_service.chronon_fetcher[0].uri
        }
      }
      env {
        name  = "PROMETHEUS_NAMESPACE"
        value = var.name_prefix
      }
      env {
        name  = "READ_ONLY"
        value = var.read_only_ui
      }
      env {
        name  = "ORCH_SERVICE_NAME"
        value = google_cloud_run_v2_service.orchestration.name
      }
      env {
        name  = "UI_SERVICE_NAME"
        value = "${var.name_prefix}-zipline-ui"
      }
      env {
        name  = "EVAL_SERVICE_NAME"
        value = google_cloud_run_v2_service.chronon_eval.name
      }
      dynamic "env" {
        for_each = var.deploy_fetcher ? [1] : []
        content {
          name  = "FETCHER_SERVICE_NAME"
          value = google_cloud_run_v2_service.chronon_fetcher[0].name
        }
      }
      # Zipline Authentication
      env {
        name  = "AUTH_ENABLED"
        value = var.zipline_auth_enabled
      }
      dynamic "env" {
        for_each = var.zipline_auth_enabled ? [1] : []
        content {
          name  = "AUTH_URL"
          value = local.ui_url
        }
      }
      dynamic "env" {
        for_each = var.zipline_auth_enabled ? [1] : []
        content {
          name  = "AUTH_ALLOWED_HOSTS"
          value = local.ui_custom_domain_enabled ? "${local.ui_url},${local.use_zipline_custom_domain ? var.zipline_custom_domain : var.zipline_ui_domain},${local.use_zipline_custom_domain ? google_compute_global_address.zipline_custom_domain_address[0].address : google_compute_global_address.zipline_ui_address[0].address}" : "${local.default_ui_url},${trimprefix(local.default_ui_url, "https://")}"
        }
      }
      dynamic "env" {
        for_each = var.zipline_auth_enabled ? [1] : []
        content {
          name = "AUTH_SECRET"
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.zipline_auth[0].secret_id
              version = "latest"
            }
          }
        }
      }

      dynamic "env" {
        for_each = var.zipline_auth_enabled ? [1] : []
        content {
          name  = "GOOGLE_OAUTH_CLIENT_ID"
          value = var.google_oauth_client_id
        }
      }
      dynamic "env" {
        for_each = var.zipline_auth_enabled && var.google_oauth_client_secret != "" ? [1] : []
        content {
          name = "GOOGLE_OAUTH_CLIENT_SECRET"
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.google_oauth_client_secret[0].secret_id
              version = "latest"
            }
          }
        }
      }

      dynamic "env" {
        for_each = var.zipline_auth_enabled ? [1] : []
        content {
          name  = "GITHUB_OAUTH_CLIENT_ID"
          value = var.github_oauth_client_id
        }
      }
      dynamic "env" {
        for_each = var.zipline_auth_enabled && var.github_oauth_client_secret != "" ? [1] : []
        content {
          name = "GITHUB_OAUTH_CLIENT_SECRET"
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.github_oauth_client_secret[0].secret_id
              version = "latest"
            }
          }
        }
      }

      dynamic "env" {
        for_each = var.zipline_auth_enabled ? [1] : []
        content {
          name  = "MICROSOFT_ENTRA_TENANT_ID"
          value = var.microsoft_entra_tenant_id
        }
      }
      dynamic "env" {
        for_each = var.zipline_auth_enabled ? [1] : []
        content {
          name  = "MICROSOFT_ENTRA_OAUTH_CLIENT_ID"
          value = var.microsoft_entra_oauth_client_id
        }
      }
      dynamic "env" {
        for_each = var.zipline_auth_enabled && var.microsoft_entra_oauth_client_secret != "" ? [1] : []
        content {
          name = "MICROSOFT_ENTRA_OAUTH_CLIENT_SECRET"
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.microsoft_entra_oauth_client_secret[0].secret_id
              version = "latest"
            }
          }
        }
      }

      dynamic "env" {
        for_each = var.zipline_auth_enabled ? [1] : []
        content {
          name  = "SSO_PROVIDER_ID"
          value = var.sso_provider_id
        }
      }
      dynamic "env" {
        for_each = var.zipline_auth_enabled ? [1] : []
        content {
          name  = "SSO_DOMAIN"
          value = var.sso_domain
        }
      }
      dynamic "env" {
        for_each = var.zipline_auth_enabled ? [1] : []
        content {
          name  = "SSO_ISSUER"
          value = var.sso_issuer
        }
      }
      dynamic "env" {
        for_each = var.zipline_auth_enabled ? [1] : []
        content {
          name  = "SSO_CLIENT_ID"
          value = var.sso_client_id
        }
      }
      dynamic "env" {
        for_each = var.zipline_auth_enabled && var.sso_client_secret != "" ? [1] : []
        content {
          name = "SSO_CLIENT_SECRET"
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.sso_client_secret[0].secret_id
              version = "latest"
            }
          }
        }
      }
      dynamic "env" {
        for_each = var.zipline_auth_enabled ? [1] : []
        content {
          name  = "IDP_ROLE_MAPPING"
          value = var.idp_role_mapping
        }
      }
      dynamic "env" {
        for_each = var.zipline_auth_enabled ? [1] : []
        content {
          name  = "IDP_GROUP_CLAIM"
          value = var.idp_group_claim
        }
      }


      resources {
        limits = {
          cpu    = "1000m"
          memory = "1Gi"
        }
      }
      ports {
        container_port = 3000
      }
    }
  }

  depends_on = [
    google_artifact_registry_repository.docker_hub_remote_repository,
    google_service_account.orchestration_service_account,
    google_project_iam_member.orchestration_service_account_secretmanager,
    google_cloud_run_v2_service.orchestration
  ]

  lifecycle {
    ignore_changes = [
      template[0].containers[0].resources[0].cpu_idle,
      client,
      client_version,
      scaling,
    ]
  }
}

resource "google_cloud_run_v2_service_iam_member" "ui_personnel_access" {
  name     = google_cloud_run_v2_service.zipline_ui.name
  location = google_cloud_run_v2_service.zipline_ui.location
  role     = "roles/run.invoker"
  member   = "group:${var.personnel_email}"
}

resource "google_cloud_run_v2_service_iam_member" "ui_users_access" {
  count    = var.users_email != "" ? 1 : 0
  name     = google_cloud_run_v2_service.zipline_ui.name
  location = google_cloud_run_v2_service.zipline_ui.location
  role     = "roles/run.invoker"
  member   = "group:${var.users_email}"
}

resource "google_cloud_run_v2_service_iam_member" "ui_iap_access" {
  count    = !(var.zipline_auth_enabled || var.disable_iap) && local.ui_custom_domain_enabled ? 1 : 0
  name     = google_cloud_run_v2_service.zipline_ui.name
  location = google_cloud_run_v2_service.zipline_ui.location
  role     = "roles/run.invoker"
  member   = "serviceAccount:service-${var.project_number}@gcp-sa-iap.iam.gserviceaccount.com"
}

resource "google_iap_web_backend_service_iam_member" "ui_iap_users_access" {
  count               = !(var.zipline_auth_enabled || var.disable_iap) && var.users_email != "" && local.ui_custom_domain_enabled ? 1 : 0
  project             = var.project_id
  web_backend_service = local.use_zipline_custom_domain ? google_compute_backend_service.zipline_custom_domain_ui_backend_service[0].name : google_compute_backend_service.zipline_ui_backend_service[0].name
  role                = "roles/iap.httpsResourceAccessor"
  member              = "group:${var.users_email}"

  depends_on = [
    google_cloud_run_v2_service.zipline_ui,
    google_cloud_run_v2_service_iam_member.ui_users_access
  ]
}

resource "google_iap_web_backend_service_iam_member" "ui_iap_personnel_access" {
  count               = !(var.zipline_auth_enabled || var.disable_iap) && local.ui_custom_domain_enabled ? 1 : 0
  project             = var.project_id
  web_backend_service = local.use_zipline_custom_domain ? google_compute_backend_service.zipline_custom_domain_ui_backend_service[0].name : google_compute_backend_service.zipline_ui_backend_service[0].name
  role                = "roles/iap.httpsResourceAccessor"
  member              = "group:${var.personnel_email}"
}

resource "google_iap_web_backend_service_iam_member" "ui_iap_all_access" {
  count               = var.allow_public_access && var.disable_iap && local.ui_custom_domain_enabled ? 1 : 0
  project             = var.project_id
  web_backend_service = local.use_zipline_custom_domain ? google_compute_backend_service.zipline_custom_domain_ui_backend_service[0].name : google_compute_backend_service.zipline_ui_backend_service[0].name
  role                = "roles/iap.httpsResourceAccessor"
  member              = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "ui_all_access" {
  count    = var.allow_public_access && !var.zipline_auth_enabled ? 1 : 0
  name     = google_cloud_run_v2_service.zipline_ui.name
  location = google_cloud_run_v2_service.zipline_ui.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

## Auth Secrets

resource "google_secret_manager_secret" "zipline_auth" {
  count     = var.zipline_auth_enabled ? 1 : 0
  secret_id = "${var.name_prefix}-zipline-auth"
  replication {
    auto {}
  }

  depends_on = [google_project_service.secrets]
}

resource "google_secret_manager_secret_version" "zipline_auth" {
  count       = var.zipline_auth_enabled ? 1 : 0
  secret      = google_secret_manager_secret.zipline_auth[0].id
  secret_data = random_password.zipline_auth_secret[0].result
  depends_on = [
    google_project_service.secrets
  ]
}

resource "random_password" "zipline_auth_secret" {
  count   = var.zipline_auth_enabled ? 1 : 0
  length  = 32
  special = true
}

resource "google_secret_manager_secret" "google_oauth_client_secret" {
  count     = var.zipline_auth_enabled && var.google_oauth_client_secret != "" ? 1 : 0
  secret_id = "${var.name_prefix}-zipline-google-oauth"
  replication {
    auto {}
  }

  depends_on = [google_project_service.secrets]
}

resource "google_secret_manager_secret_version" "google_oauth_client_secret" {
  count       = var.zipline_auth_enabled && var.google_oauth_client_secret != "" ? 1 : 0
  secret      = google_secret_manager_secret.google_oauth_client_secret[0].id
  secret_data = var.google_oauth_client_secret
  depends_on = [
    google_project_service.secrets
  ]
}


resource "google_secret_manager_secret" "github_oauth_client_secret" {
  count     = var.zipline_auth_enabled && var.github_oauth_client_secret != "" ? 1 : 0
  secret_id = "${var.name_prefix}-zipline-github-oauth"
  replication {
    auto {}
  }

  depends_on = [google_project_service.secrets]
}

resource "google_secret_manager_secret_version" "github_oauth_client_secret" {
  count       = var.zipline_auth_enabled && var.github_oauth_client_secret != "" ? 1 : 0
  secret      = google_secret_manager_secret.github_oauth_client_secret[0].id
  secret_data = var.github_oauth_client_secret
  depends_on = [
    google_project_service.secrets
  ]
}

resource "google_secret_manager_secret" "microsoft_entra_oauth_client_secret" {
  count     = var.zipline_auth_enabled && var.microsoft_entra_oauth_client_secret != "" ? 1 : 0
  secret_id = "${var.name_prefix}-zipline-microsoft-entra-oauth"
  replication {
    auto {}
  }

  depends_on = [google_project_service.secrets]
}

resource "google_secret_manager_secret_version" "microsoft_entra_oauth_client_secret" {
  count       = var.zipline_auth_enabled && var.microsoft_entra_oauth_client_secret != "" ? 1 : 0
  secret      = google_secret_manager_secret.microsoft_entra_oauth_client_secret[0].id
  secret_data = var.microsoft_entra_oauth_client_secret
  depends_on = [
    google_project_service.secrets
  ]
}

resource "google_secret_manager_secret" "sso_client_secret" {
  count     = var.zipline_auth_enabled && var.sso_client_secret != "" ? 1 : 0
  secret_id = "${var.name_prefix}-zipline-sso-client"
  replication {
    auto {}
  }

  depends_on = [google_project_service.secrets]
}

resource "google_secret_manager_secret_version" "sso_client_secret" {
  count       = var.zipline_auth_enabled && var.sso_client_secret != "" ? 1 : 0
  secret      = google_secret_manager_secret.sso_client_secret[0].id
  secret_data = var.sso_client_secret
  depends_on = [
    google_project_service.secrets
  ]
}

################################################################
# Cloud Run v2 service for Chronon Eval

resource "google_cloud_run_v2_service" "chronon_eval" {
  name     = "${var.name_prefix}-zipline-chronon-eval"
  location = var.region
  project  = var.project_id

  ingress              = local.eval_custom_domain_enabled ? "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER" : "INGRESS_TRAFFIC_ALL"
  invoker_iam_disabled = var.zipline_auth_enabled || local.eval_custom_domain_enabled
  template {
    vpc_access {
      network_interfaces {
        network    = var.vpc_name
        subnetwork = var.subnet_name
      }
      egress = "ALL_TRAFFIC"
    }

    service_account = google_service_account.eval_service_account.email
    labels = {
      container_name = "eval"
    }
    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_hub_remote_repository.repository_id}/ziplineai/eval-gcp:${var.zipline_version}"
      name  = "chronon-eval"

      ports {
        name           = "http1"
        container_port = 3904
      }

      env {
        name  = "DB_URL"
        value = "jdbc:postgresql://${google_sql_database_instance.orchestration_instance.private_ip_address}:5432/${google_sql_database.orchestration_database.name}"
      }
      env {
        name  = "DB_USERNAME"
        value = google_sql_user.orchestration_user.name
      }
      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_password.secret_id
            version = "latest"
          }
        }
      }
      env {
        name  = "GCP_REGION"
        value = var.region
      }
      env {
        name  = "GCP_PROJECT_ID"
        value = var.project_id
      }
      env {
        name  = "GCP_BIGTABLE_INSTANCE_ID"
        value = var.bigtable_instance_name
      }
      env {
        name  = "EVAL_SERVICE_ACCOUNT_EMAIL"
        value = google_service_account.eval_service_account.email
      }
      # Zipline Authentication
      env {
        name  = "AUTH_ENABLED"
        value = var.zipline_auth_enabled
      }
      dynamic "env" {
        for_each = var.zipline_auth_enabled ? [1] : []
        content {
          name  = "AUTH_JWKS_URL"
          value = "${local.ui_url}/api/auth/jwks"
        }
      }

      resources {
        limits = {
          cpu    = "4"
          memory = "8Gi"
        }
      }

      startup_probe {
        http_get {
          path = "/ping"
          port = 3904
        }
        initial_delay_seconds = 30
        period_seconds        = 10
        timeout_seconds       = 5
        failure_threshold     = 10
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 3
    }
  }
  traffic {
    percent = 100
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }

  depends_on = [
    google_cloud_run_v2_service.orchestration,
    google_service_account.eval_service_account,
    google_sql_database.orchestration_database,
    google_project_iam_member.eval_secretmanager,
    google_artifact_registry_repository.docker_hub_remote_repository
  ]
}

# IAM policy to allow orchestration service account to invoke eval service

resource "google_cloud_run_v2_service_iam_member" "eval_all_access" {
  count = var.allow_public_access ? 1 : 0

  name     = google_cloud_run_v2_service.chronon_eval.name
  location = google_cloud_run_v2_service.chronon_eval.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "eval_orchestration_access" {
  name     = google_cloud_run_v2_service.chronon_eval.name
  location = google_cloud_run_v2_service.chronon_eval.location
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.orchestration_service_account.email}"
}

################################################################
# Cloud Run v2 service for Chronon Fetcher

resource "google_cloud_run_v2_service" "chronon_fetcher" {
  count    = var.deploy_fetcher ? 1 : 0
  name     = "${var.name_prefix}-zipline-chronon-fetcher"
  location = var.region
  project  = var.project_id

  ingress              = local.use_zipline_custom_domain ? "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER" : "INGRESS_TRAFFIC_ALL"
  invoker_iam_disabled = var.zipline_auth_enabled || local.use_zipline_custom_domain
  template {

    vpc_access {
      network_interfaces {
        network    = var.vpc_name
        subnetwork = var.subnet_name
      }
      egress = "ALL_TRAFFIC"
    }

    service_account = google_service_account.orchestration_service_account.email

    labels = {
      container_name = "fetcher"
    }
    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_hub_remote_repository.repository_id}/ziplineai/chronon-fetcher:${var.zipline_version}"
      name  = "chronon-fetcher"

      ports {
        name           = "http1"
        container_port = 9000
      }

      env {
        name  = "GCP_PROJECT_ID"
        value = var.project_id
      }
      env {
        name  = "GOOGLE_CLOUD_PROJECT"
        value = var.project_id
      }
      env {
        name  = "GCP_BIGTABLE_INSTANCE_ID"
        value = var.bigtable_instance_name
      }
      env {
        name  = "CHRONON_METRICS_READER"
        value = "http"
      }
      env {
        name  = "EXPORTER_OTLP_ENDPOINT"
        value = "http://localhost:4318"
      }
      env {
        name  = "FETCHER_OOC_TOPIC_INFO"
        value = "pubsub://${google_pubsub_topic.logging_ooc[0].name}"
      }
      env {
        name  = "GCP_LOCATION"
        value = var.region
      }

      resources {
        limits = {
          cpu    = "2"
          memory = "4Gi"
        }
      }

      startup_probe {
        http_get {
          path = "/ping"
          port = 9000
        }
        initial_delay_seconds = 20
        period_seconds        = 10
        timeout_seconds       = 5
        failure_threshold     = 10
      }
    }

    # OTEL Collector sidecar for metrics export
    containers {
      image = "otel/opentelemetry-collector-contrib:0.91.0"
      name  = "collector"

      args = ["--config=env:OTEL_CONFIG_YAML"]

      env {
        name = "OTEL_CONFIG_YAML"
        value = yamlencode({
          receivers = {
            otlp = {
              protocols = {
                grpc = {
                  endpoint = "0.0.0.0:4317"
                }
                http = {
                  endpoint = "0.0.0.0:4318"
                }
              }
            }
          }
          processors = {
            resourcedetection = {
              detectors = ["env", "gcp"]
              timeout   = "5s"
              override  = false
            }
            resource = {
              attributes = [
                {
                  key    = "location"
                  value  = var.region
                  action = "upsert"
                },
                {
                  key    = "namespace"
                  value  = var.name_prefix
                  action = "upsert"
                },
                {
                  key    = "cluster"
                  value  = "zipline-${var.name_prefix}"
                  action = "upsert"
                }
              ]
            }
          }
          exporters = {
            googlemanagedprometheus = {
              project = var.project_id
            }
          }
          service = {
            pipelines = {
              metrics = {
                receivers  = ["otlp"]
                processors = ["resourcedetection", "resource"]
                exporters  = ["googlemanagedprometheus"]
              }
            }
          }
        })
      }

      resources {
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
      }

    }

    scaling {
      min_instance_count = 1
      max_instance_count = 5
    }
  }
  traffic {
    percent = 100
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }

  depends_on = [
    google_service_account.orchestration_service_account,
  ]
}

# IAM policy to allow orchestration service account to invoke chronon services
resource "google_cloud_run_v2_service_iam_member" "chronon_fetcher_access" {
  count    = var.deploy_fetcher ? 1 : 0
  location = google_cloud_run_v2_service.chronon_fetcher[0].location
  project  = google_cloud_run_v2_service.chronon_fetcher[0].project
  name     = google_cloud_run_v2_service.chronon_fetcher[0].name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.orchestration_service_account.email}"
}

# IAM policy to allow members of the personnel group to invoke chronon services
resource "google_cloud_run_v2_service_iam_member" "chronon_fetcher_personnel_access" {
  count    = var.deploy_fetcher ? 1 : 0
  location = google_cloud_run_v2_service.chronon_fetcher[0].location
  project  = google_cloud_run_v2_service.chronon_fetcher[0].project
  name     = google_cloud_run_v2_service.chronon_fetcher[0].name
  role     = "roles/run.invoker"
  member   = "group:${var.personnel_email}"
}

resource "google_cloud_run_v2_service_iam_member" "chronon_fetcher_additional_access" {
  for_each = var.deploy_fetcher ? var.fetcher_access_members : []
  location = google_cloud_run_v2_service.chronon_fetcher[0].location
  project  = google_cloud_run_v2_service.chronon_fetcher[0].project
  name     = google_cloud_run_v2_service.chronon_fetcher[0].name
  role     = "roles/run.invoker"
  member   = each.value
}

################################################################
# Load Balancer Backend Services for Cloud Run services

resource "google_compute_security_policy" "restrict_ingress_policy" {
  count = length(var.allowed_ip_ranges) > 0 ? 1 : 0

  name    = "restrict-ingress-policy"
  project = var.project_id

  rule {
    action   = "deny(403)"
    priority = "2147483647"

    match {
      versioned_expr = "SRC_IPS_V1"

      config {
        src_ip_ranges = ["*"]
      }
    }

    description = "Default rule, higher priority overrides it"
  }

  dynamic "rule" {
    for_each = var.allowed_ip_ranges
    content {
      action   = "allow"
      priority = "1000"

      match {
        versioned_expr = "SRC_IPS_V1"

        config {
          src_ip_ranges = [rule.value]
        }
      }

      description = "Allow traffic from trusted IP range ${rule.value}"
    }
  }

}

resource "google_compute_region_network_endpoint_group" "orchestration_neg" {
  count                 = !local.use_zipline_custom_domain && var.hub_domain != "" ? 1 : 0
  name                  = "${var.name_prefix}-zipline-orch-neg"
  project               = var.project_id
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = google_cloud_run_v2_service.orchestration.name
  }
}

resource "google_compute_backend_service" "orchestration_backend_service" {
  count                 = !local.use_zipline_custom_domain && var.hub_domain != "" ? 1 : 0
  name                  = "${var.name_prefix}-zipline-orch-backend-service"
  project               = var.project_id
  protocol              = var.use_https ? "HTTPS" : "HTTP"
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.orchestration_neg[0].id
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }

  security_policy = length(var.allowed_ip_ranges) > 0 ? google_compute_security_policy.restrict_ingress_policy[0].id : null

  depends_on = [
    google_cloud_run_v2_service.orchestration,
  ]
}

resource "google_compute_url_map" "orchestration_url_map" {
  count   = !local.use_zipline_custom_domain && var.hub_domain != "" ? 1 : 0
  name    = "${var.name_prefix}-zipline-orch-url-map"
  project = var.project_id

  default_service = google_compute_backend_service.orchestration_backend_service[0].id
}

resource "google_compute_managed_ssl_certificate" "orchestration_ssl_cert" {
  count   = !local.use_zipline_custom_domain && var.hub_domain != "" && var.use_https ? 1 : 0
  name    = "${var.name_prefix}-zipline-orch-ssl-cert"
  project = var.project_id

  managed {
    domains = [var.hub_domain]
  }
}

resource "google_compute_target_https_proxy" "orchestration_https_proxy" {
  count   = !local.use_zipline_custom_domain && var.hub_domain != "" && var.use_https ? 1 : 0
  name    = "${var.name_prefix}-zipline-orch-https-proxy"
  project = var.project_id

  url_map          = google_compute_url_map.orchestration_url_map[0].id
  ssl_certificates = [google_compute_managed_ssl_certificate.orchestration_ssl_cert[0].id]
  ssl_policy       = google_compute_ssl_policy.ingress_ssl_policy.id
}

resource "google_compute_target_http_proxy" "orchestration_http_proxy" {
  count   = !local.use_zipline_custom_domain && var.hub_domain != "" && !var.use_https ? 1 : 0
  name    = "${var.name_prefix}-zipline-orch-http-proxy"
  project = var.project_id

  url_map = google_compute_url_map.orchestration_url_map[0].id
}

resource "google_compute_global_address" "orchestration_address" {
  count   = !local.use_zipline_custom_domain && var.hub_domain != "" ? 1 : 0
  name    = "${var.name_prefix}-zipline-orch-lb-ip"
  project = var.project_id
}

resource "google_compute_global_forwarding_rule" "orchestration_forwarding_rule" {
  count       = !local.use_zipline_custom_domain && var.hub_domain != "" ? 1 : 0
  name        = "${var.name_prefix}-zipline-orch-forwarding-rule"
  project     = var.project_id
  ip_address  = google_compute_global_address.orchestration_address[0].address
  ip_protocol = "TCP"
  port_range  = var.use_https ? "443" : "80"

  load_balancing_scheme = "EXTERNAL_MANAGED"
  target                = var.use_https ? google_compute_target_https_proxy.orchestration_https_proxy[0].id : google_compute_target_http_proxy.orchestration_http_proxy[0].id
}


resource "google_compute_region_network_endpoint_group" "zipline_ui_neg" {
  count                 = !local.use_zipline_custom_domain && var.zipline_ui_domain != "" ? 1 : 0
  name                  = "${var.name_prefix}-zipline-ui-neg"
  project               = var.project_id
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = google_cloud_run_v2_service.zipline_ui.name
  }
}

resource "google_compute_backend_service" "zipline_ui_backend_service" {
  count                 = !local.use_zipline_custom_domain && var.zipline_ui_domain != "" ? 1 : 0
  name                  = "${var.name_prefix}-zipline-ui-backend-service"
  project               = var.project_id
  protocol              = "HTTPS"
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.zipline_ui_neg[0].id
  }

  iap {
    enabled = !(var.zipline_auth_enabled || var.disable_iap)
  }

  security_policy = length(var.allowed_ip_ranges) > 0 ? google_compute_security_policy.restrict_ingress_policy[0].id : null

  log_config {
    enable      = true
    sample_rate = 1.0
  }

  depends_on = [
    google_cloud_run_v2_service.zipline_ui,
  ]
}

resource "google_compute_url_map" "zipline_ui_url_map" {
  count   = !local.use_zipline_custom_domain && var.zipline_ui_domain != "" ? 1 : 0
  name    = "${var.name_prefix}-zipline-ui-url-map"
  project = var.project_id

  default_service = google_compute_backend_service.zipline_ui_backend_service[0].id
}

resource "google_compute_managed_ssl_certificate" "zipline_ui_ssl_cert" {
  count   = !local.use_zipline_custom_domain && var.zipline_ui_domain != "" ? 1 : 0
  name    = "${var.name_prefix}-zipline-ui-ssl-cert"
  project = var.project_id

  managed {
    domains = [var.zipline_ui_domain]
  }
}

resource "google_compute_target_https_proxy" "zipline_ui_https_proxy" {
  count   = !local.use_zipline_custom_domain && var.zipline_ui_domain != "" ? 1 : 0
  name    = "${var.name_prefix}-zipline-ui-https-proxy"
  project = var.project_id

  url_map          = google_compute_url_map.zipline_ui_url_map[0].id
  ssl_certificates = [google_compute_managed_ssl_certificate.zipline_ui_ssl_cert[0].id]
  ssl_policy       = google_compute_ssl_policy.ingress_ssl_policy.id
}

resource "google_compute_global_address" "zipline_ui_address" {
  count   = !local.use_zipline_custom_domain && var.zipline_ui_domain != "" ? 1 : 0
  name    = "${var.name_prefix}-zipline-ui-lb-ip"
  project = var.project_id
}

resource "google_compute_global_forwarding_rule" "zipline_ui_forwarding_rule" {
  count       = !local.use_zipline_custom_domain && var.zipline_ui_domain != "" ? 1 : 0
  name        = "${var.name_prefix}-zipline-ui-forwarding-rule"
  project     = var.project_id
  ip_address  = google_compute_global_address.zipline_ui_address[0].address
  ip_protocol = "TCP"
  port_range  = "443"

  load_balancing_scheme = "EXTERNAL_MANAGED"
  target                = google_compute_target_https_proxy.zipline_ui_https_proxy[0].id
}

resource "google_compute_region_network_endpoint_group" "zipline_eval_neg" {
  count                 = !local.use_zipline_custom_domain && var.zipline_eval_domain != "" ? 1 : 0
  name                  = "${var.name_prefix}-zipline-eval-neg"
  project               = var.project_id
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = google_cloud_run_v2_service.chronon_eval.name
  }
}

resource "google_compute_backend_service" "zipline_eval_backend_service" {
  count                 = !local.use_zipline_custom_domain && var.zipline_eval_domain != "" ? 1 : 0
  name                  = "${var.name_prefix}-zipline-eval-backend-service"
  project               = var.project_id
  protocol              = "HTTPS"
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.zipline_eval_neg[0].id
  }

  iap {
    enabled = false
  }

  security_policy = length(var.allowed_ip_ranges) > 0 ? google_compute_security_policy.restrict_ingress_policy[0].id : null

  log_config {
    enable      = true
    sample_rate = 1.0
  }

  depends_on = [
    google_cloud_run_v2_service.chronon_eval,
  ]
}

resource "google_compute_url_map" "zipline_eval_url_map" {
  count   = !local.use_zipline_custom_domain && var.zipline_eval_domain != "" ? 1 : 0
  name    = "${var.name_prefix}-zipline-eval-url-map"
  project = var.project_id

  default_service = google_compute_backend_service.zipline_eval_backend_service[0].id
}

resource "google_compute_managed_ssl_certificate" "zipline_eval_ssl_cert" {
  count   = !local.use_zipline_custom_domain && var.zipline_eval_domain != "" ? 1 : 0
  name    = "${var.name_prefix}-zipline-eval-ssl-cert"
  project = var.project_id

  managed {
    domains = [var.zipline_eval_domain]
  }
}

resource "google_compute_target_https_proxy" "zipline_eval_https_proxy" {
  count   = !local.use_zipline_custom_domain && var.zipline_eval_domain != "" ? 1 : 0
  name    = "${var.name_prefix}-zipline-eval-https-proxy"
  project = var.project_id

  url_map          = google_compute_url_map.zipline_eval_url_map[0].id
  ssl_certificates = [google_compute_managed_ssl_certificate.zipline_eval_ssl_cert[0].id]
  ssl_policy       = google_compute_ssl_policy.ingress_ssl_policy.id
}

resource "google_compute_global_address" "zipline_eval_address" {
  count   = !local.use_zipline_custom_domain && var.zipline_eval_domain != "" ? 1 : 0
  name    = "${var.name_prefix}-zipline-eval-lb-ip"
  project = var.project_id
}

resource "google_compute_global_forwarding_rule" "zipline_eval_forwarding_rule" {
  count       = !local.use_zipline_custom_domain && var.zipline_eval_domain != "" ? 1 : 0
  name        = "${var.name_prefix}-zipline-eval-forwarding-rule"
  project     = var.project_id
  ip_address  = google_compute_global_address.zipline_eval_address[0].address
  ip_protocol = "TCP"
  port_range  = "443"

  load_balancing_scheme = "EXTERNAL_MANAGED"
  target                = google_compute_target_https_proxy.zipline_eval_https_proxy[0].id
}

resource "google_compute_region_network_endpoint_group" "zipline_custom_domain_ui_neg" {
  count                 = local.use_zipline_custom_domain ? 1 : 0
  name                  = "${var.name_prefix}-zipline-custom-ui-neg"
  project               = var.project_id
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = google_cloud_run_v2_service.zipline_ui.name
  }
}

resource "google_compute_region_network_endpoint_group" "zipline_custom_domain_hub_neg" {
  count                 = local.use_zipline_custom_domain ? 1 : 0
  name                  = "${var.name_prefix}-zipline-custom-hub-neg"
  project               = var.project_id
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = google_cloud_run_v2_service.orchestration.name
  }
}

resource "google_compute_region_network_endpoint_group" "zipline_custom_domain_eval_neg" {
  count                 = local.use_zipline_custom_domain ? 1 : 0
  name                  = "${var.name_prefix}-zipline-custom-eval-neg"
  project               = var.project_id
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = google_cloud_run_v2_service.chronon_eval.name
  }
}

resource "google_compute_region_network_endpoint_group" "zipline_custom_domain_fetcher_neg" {
  count                 = local.use_zipline_custom_domain && var.deploy_fetcher ? 1 : 0
  name                  = "${var.name_prefix}-zipline-custom-fetcher-neg"
  project               = var.project_id
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = google_cloud_run_v2_service.chronon_fetcher[0].name
  }
}

resource "google_compute_backend_service" "zipline_custom_domain_ui_backend_service" {
  count                 = local.use_zipline_custom_domain ? 1 : 0
  name                  = "${var.name_prefix}-zipline-custom-ui-backend"
  project               = var.project_id
  protocol              = "HTTPS"
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.zipline_custom_domain_ui_neg[0].id
  }

  iap {
    enabled = !(var.zipline_auth_enabled || var.disable_iap)
  }

  security_policy = length(var.allowed_ip_ranges) > 0 ? google_compute_security_policy.restrict_ingress_policy[0].id : null

  log_config {
    enable      = true
    sample_rate = 1.0
  }

  depends_on = [
    google_cloud_run_v2_service.zipline_ui,
  ]
}

resource "google_compute_backend_service" "zipline_custom_domain_hub_backend_service" {
  count                 = local.use_zipline_custom_domain ? 1 : 0
  name                  = "${var.name_prefix}-zipline-custom-hub-backend"
  project               = var.project_id
  protocol              = "HTTPS"
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.zipline_custom_domain_hub_neg[0].id
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }

  security_policy = length(var.allowed_ip_ranges) > 0 ? google_compute_security_policy.restrict_ingress_policy[0].id : null

  depends_on = [
    google_cloud_run_v2_service.orchestration,
  ]
}

resource "google_compute_backend_service" "zipline_custom_domain_eval_backend_service" {
  count                 = local.use_zipline_custom_domain ? 1 : 0
  name                  = "${var.name_prefix}-zipline-custom-eval-backend"
  project               = var.project_id
  protocol              = "HTTPS"
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.zipline_custom_domain_eval_neg[0].id
  }

  iap {
    enabled = false
  }

  security_policy = length(var.allowed_ip_ranges) > 0 ? google_compute_security_policy.restrict_ingress_policy[0].id : null

  log_config {
    enable      = true
    sample_rate = 1.0
  }

  depends_on = [
    google_cloud_run_v2_service.chronon_eval,
  ]
}

resource "google_compute_backend_service" "zipline_custom_domain_fetcher_backend_service" {
  count                 = local.use_zipline_custom_domain && var.deploy_fetcher ? 1 : 0
  name                  = "${var.name_prefix}-zipline-custom-fetcher-backend"
  project               = var.project_id
  protocol              = "HTTPS"
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.zipline_custom_domain_fetcher_neg[0].id
  }

  iap {
    enabled = false
  }

  security_policy = length(var.allowed_ip_ranges) > 0 ? google_compute_security_policy.restrict_ingress_policy[0].id : null

  log_config {
    enable      = true
    sample_rate = 1.0
  }

  depends_on = [
    google_cloud_run_v2_service.chronon_fetcher,
  ]
}

resource "google_compute_url_map" "zipline_custom_domain_url_map" {
  count   = local.use_zipline_custom_domain ? 1 : 0
  name    = "${var.name_prefix}-zipline-custom-url-map"
  project = var.project_id

  default_service = google_compute_backend_service.zipline_custom_domain_ui_backend_service[0].id

  host_rule {
    hosts        = [var.zipline_custom_domain]
    path_matcher = "zipline-custom-domain"
  }

  path_matcher {
    name            = "zipline-custom-domain"
    default_service = google_compute_backend_service.zipline_custom_domain_ui_backend_service[0].id

    path_rule {
      paths   = ["/services/hub", "/services/hub/*"]
      service = google_compute_backend_service.zipline_custom_domain_hub_backend_service[0].id

      route_action {
        url_rewrite {
          path_prefix_rewrite = "/"
        }
      }
    }

    path_rule {
      paths   = ["/services/eval", "/services/eval/*"]
      service = google_compute_backend_service.zipline_custom_domain_eval_backend_service[0].id

      route_action {
        url_rewrite {
          path_prefix_rewrite = "/"
        }
      }
    }

    dynamic "path_rule" {
      for_each = var.deploy_fetcher ? [1] : []

      content {
        paths   = ["/services/fetcher", "/services/fetcher/*"]
        service = google_compute_backend_service.zipline_custom_domain_fetcher_backend_service[0].id

        route_action {
          url_rewrite {
            path_prefix_rewrite = "/"
          }
        }
      }
    }
  }
}

resource "google_compute_managed_ssl_certificate" "zipline_custom_domain_ssl_cert" {
  count   = local.use_zipline_custom_domain ? 1 : 0
  name    = "${var.name_prefix}-zipline-custom-ssl-cert"
  project = var.project_id

  managed {
    domains = [var.zipline_custom_domain]
  }
}

resource "google_compute_target_https_proxy" "zipline_custom_domain_https_proxy" {
  count   = local.use_zipline_custom_domain ? 1 : 0
  name    = "${var.name_prefix}-zipline-custom-https-proxy"
  project = var.project_id

  url_map          = google_compute_url_map.zipline_custom_domain_url_map[0].id
  ssl_certificates = [google_compute_managed_ssl_certificate.zipline_custom_domain_ssl_cert[0].id]
  ssl_policy       = google_compute_ssl_policy.ingress_ssl_policy.id
}

resource "google_compute_global_address" "zipline_custom_domain_address" {
  count   = local.use_zipline_custom_domain ? 1 : 0
  name    = "${var.name_prefix}-zipline-custom-lb-ip"
  project = var.project_id
}

resource "google_compute_global_forwarding_rule" "zipline_custom_domain_forwarding_rule" {
  count       = local.use_zipline_custom_domain ? 1 : 0
  name        = "${var.name_prefix}-zipline-custom-forwarding-rule"
  project     = var.project_id
  ip_address  = google_compute_global_address.zipline_custom_domain_address[0].address
  ip_protocol = "TCP"
  port_range  = "443"

  load_balancing_scheme = "EXTERNAL_MANAGED"
  target                = google_compute_target_https_proxy.zipline_custom_domain_https_proxy[0].id
}


###############################################################

output "docker_hub_remote_repository_id" {
  value = google_artifact_registry_repository.docker_hub_remote_repository.repository_id
}

output "orchestration_service_name" {
  value = google_cloud_run_v2_service.orchestration.name
}

output "orchestration_service_account_id" {
  value = google_service_account.orchestration_service_account.id
}

output "eval_service_url" {
  value       = local.eval_url
  description = "URL of the Chronon Eval service"
}

output "hub_address" {
  value = local.hub_url
}

output "ui_address" {
  value = local.ui_url
}

output "Google_OAuth_Redirect_URI_Instructions" {
  value       = var.zipline_auth_enabled && var.google_oauth_client_id != "" ? "In Google Cloud Console, open APIs & Services > Credentials > your OAuth 2.0 Client ID, then add this Authorized redirect URI: ${local.ui_url}/api/auth/callback/google" : null
  description = "Instructions for registering the Google OAuth redirect URI when Google auth is enabled."
}

output "GitHub_OAuth_Redirect_URI_Instructions" {
  value       = var.zipline_auth_enabled && var.github_oauth_client_id != "" ? "In GitHub, open Settings > Developer settings > OAuth Apps > your OAuth App, then set this Authorization callback URL: ${local.ui_url}/api/auth/callback/github" : null
  description = "Instructions for registering the GitHub OAuth callback URL when GitHub auth is enabled."
}

output "Microsoft_Entra_OAuth_Redirect_URI_Instructions" {
  value       = var.zipline_auth_enabled && var.microsoft_entra_oauth_client_id != "" ? "In Azure Portal, open Microsoft Entra ID > App registrations > your app registration > Authentication, then add this Web redirect URI: ${local.ui_url}/api/auth/callback/microsoft-entra-id" : null
  description = "Instructions for registering the Microsoft Entra OAuth redirect URI when Microsoft Entra auth is enabled."
}

output "fetcher_address" {
  value = var.deploy_fetcher ? local.fetcher_url : ""
}

output "UI_DNS_Instructions" {
  value = local.use_zipline_custom_domain ? "Create an A record pointing ${var.zipline_custom_domain} to ${google_compute_global_address.zipline_custom_domain_address[0].address}. UI will be available at ${local.ui_url}; hub at ${local.hub_url}; eval at ${local.eval_url}${var.deploy_fetcher ? "; fetcher at ${local.fetcher_url}" : ""}. For more details, see https://cloud.google.com/load-balancing/docs/https/setting-up-https-serverless#update_dns" : var.zipline_ui_domain != "" ? "Create an A record pointing ${var.zipline_ui_domain} to ${google_compute_global_address.zipline_ui_address[0].address}. For more details, see https://cloud.google.com/load-balancing/docs/https/setting-up-https-serverless#update_dns" : null
}

output "Hub_DNS_Instructions" {
  value = local.use_zipline_custom_domain ? "Create an A record pointing ${var.zipline_custom_domain} to ${google_compute_global_address.zipline_custom_domain_address[0].address}. Hub will be available at ${local.hub_url}. For more details, see https://cloud.google.com/load-balancing/docs/https/setting-up-https-serverless#update_dns" : var.hub_domain != "" ? "Create an A record pointing ${var.hub_domain} to ${google_compute_global_address.orchestration_address[0].address}. For more details, see https://cloud.google.com/load-balancing/docs/https/setting-up-https-serverless#update_dns" : null
}

output "Eval_DNS_Instructions" {
  value = local.use_zipline_custom_domain ? "Create an A record pointing ${var.zipline_custom_domain} to ${google_compute_global_address.zipline_custom_domain_address[0].address}. Eval will be available at ${local.eval_url}. For more details, see https://cloud.google.com/load-balancing/docs/https/setting-up-https-serverless#update_dns" : var.zipline_eval_domain != "" ? "Create an A record pointing ${var.zipline_eval_domain} to ${google_compute_global_address.zipline_eval_address[0].address}. For more details, see https://cloud.google.com/load-balancing/docs/https/setting-up-https-serverless#update_dns" : null
}

output "eval_service_account_email" {
  value       = google_service_account.eval_service_account.email
  description = "Email of the Chronon Eval metadata service account"
}

output "eval_service_account_id" {
  value       = google_service_account.eval_service_account.id
  description = "ID of the Chronon Eval metadata service account"
}
