# Google Artifact Registry - Remote Repository for Docker Hub
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
    google_secret_manager_secret_iam_member.artifact_registry_secret_access
  ]
}

resource "google_secret_manager_secret" "docker_token" {
  secret_id = "${var.name_prefix}-zipline-docker-token"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "docker_token_version" {
  secret      = google_secret_manager_secret.docker_token.id
  secret_data = var.docker_hub_token
}

resource "google_secret_manager_secret_iam_member" "artifact_registry_secret_access" {
  secret_id = google_secret_manager_secret.docker_token.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:service-${var.project_number}@gcp-sa-artifactregistry.iam.gserviceaccount.com"
}

# Enable required APIs
resource "google_project_service" "cloudrun_api" {
  service = "run.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy         = false
}

resource "google_project_service" "iap_api" {
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
    var.hub_domain != "" ? "https://${var.hub_domain}" : "https://${var.name_prefix}-zipline-orchestration-${var.project_number}.${var.region}.run.app"
  ]
  ingress = var.hub_domain != "" ? "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER" : "INGRESS_TRAFFIC_ALL"

  template {

    vpc_access {
      network_interfaces {
        network    = var.vpc_name
        subnetwork = var.subnet_name
      }
      egress = "ALL_TRAFFIC"
    }
    # Main orchestration container
    containers {
      name  = "orchestration-hub"
      image = "${google_artifact_registry_repository.docker_hub_remote_repository.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_hub_remote_repository.repository_id}/ziplineai/orchestration-hub:${var.zipline_version}"
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
        value = var.zipline_ui_domain != "" ? "https://${var.zipline_ui_domain}" : "https://${var.name_prefix}-zipline-ui-${var.project_number}.${var.region}.run.app"
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

  ingress              = var.zipline_ui_domain != "" ? "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER" : "INGRESS_TRAFFIC_ALL"
  invoker_iam_disabled = var.zipline_ui_domain != "" ? false : true
  custom_audiences = [
    var.zipline_ui_domain != "" ? "https://${var.zipline_ui_domain}" : "https://${var.name_prefix}-zipline-ui-${var.project_number}.${var.region}.run.app"
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
      template[0].labels,
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
  name     = google_cloud_run_v2_service.zipline_ui.name
  location = google_cloud_run_v2_service.zipline_ui.location
  role     = "roles/run.invoker"
  member   = "serviceAccount:service-${var.project_number}@gcp-sa-iap.iam.gserviceaccount.com"
}

resource "google_iap_web_backend_service_iam_member" "ui_iap_users_access" {
  count               = var.users_email != "" && var.zipline_ui_domain != "" ? 1 : 0
  project             = var.project_id
  web_backend_service = google_compute_backend_service.zipline_ui_backend_service[0].name
  role                = "roles/iap.httpsResourceAccessor"
  member              = "group:${var.users_email}"

  depends_on = [
    google_cloud_run_v2_service.zipline_ui,
    google_cloud_run_v2_service_iam_member.ui_users_access
  ]
}

resource "google_iap_web_backend_service_iam_member" "ui_iap_personnel_access" {
  count               = var.zipline_ui_domain != "" ? 1 : 0
  project             = var.project_id
  web_backend_service = google_compute_backend_service.zipline_ui_backend_service[0].name
  role                = "roles/iap.httpsResourceAccessor"
  member              = "group:${var.personnel_email}"
}

resource "google_iap_web_backend_service_iam_member" "ui_iap_all_access" {
  count               = var.disable_iap && var.zipline_ui_domain != "" ? 1 : 0
  project             = var.project_id
  web_backend_service = google_compute_backend_service.zipline_ui_backend_service[0].name
  role                = "roles/iap.httpsResourceAccessor"
  member              = "allUsers"
}

################################################################
# Cloud Run v2 service for Chronon Eval

resource "google_cloud_run_v2_service" "chronon_eval" {
  name                = "${var.name_prefix}-zipline-chronon-eval"
  location            = var.region
  project             = var.project_id
  deletion_protection = false

  ingress = var.zipline_eval_domain != "" ? "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER" : "INGRESS_TRAFFIC_ALL"

  template {
    vpc_access {
      network_interfaces {
        network    = var.vpc_name
        subnetwork = var.subnet_name
      }
      egress = "ALL_TRAFFIC"
    }

    service_account = google_service_account.eval_service_account.email

    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_hub_remote_repository.repository_id}/ziplineai/eval:${var.zipline_version}"
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

  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
    ]
  }

  depends_on = [
    google_cloud_run_v2_service.orchestration,
    google_service_account.eval_service_account,
    google_sql_database.orchestration_database,
    google_project_iam_member.eval_secretmanager
  ]
}

# IAM policy to allow orchestration service account to invoke eval service
resource "google_cloud_run_v2_service_iam_member" "eval_orchestration_access" {
  location = google_cloud_run_v2_service.chronon_eval.location
  project  = google_cloud_run_v2_service.chronon_eval.project
  name     = google_cloud_run_v2_service.chronon_eval.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.orchestration_service_account.email}"
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
  count                 = var.hub_domain != "" ? 1 : 0
  name                  = "${var.name_prefix}-zipline-orch-neg"
  project               = var.project_id
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = google_cloud_run_v2_service.orchestration.name
  }
}

resource "google_compute_backend_service" "orchestration_backend_service" {
  count                 = var.hub_domain != "" ? 1 : 0
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
  count   = var.hub_domain != "" ? 1 : 0
  name    = "${var.name_prefix}-zipline-orch-url-map"
  project = var.project_id

  default_service = google_compute_backend_service.orchestration_backend_service[0].id
}

resource "google_compute_managed_ssl_certificate" "orchestration_ssl_cert" {
  count   = var.hub_domain != "" && var.use_https ? 1 : 0
  name    = "${var.name_prefix}-zipline-orch-ssl-cert"
  project = var.project_id

  managed {
    domains = [var.hub_domain]
  }
}

resource "google_compute_target_https_proxy" "orchestration_https_proxy" {
  count   = var.hub_domain != "" && var.use_https ? 1 : 0
  name    = "${var.name_prefix}-zipline-orch-https-proxy"
  project = var.project_id

  url_map          = google_compute_url_map.orchestration_url_map[0].id
  ssl_certificates = [google_compute_managed_ssl_certificate.orchestration_ssl_cert[0].id]
  ssl_policy       = google_compute_ssl_policy.ingress_ssl_policy.id
}

resource "google_compute_target_http_proxy" "orchestration_http_proxy" {
  count   = var.hub_domain != "" && !var.use_https ? 1 : 0
  name    = "${var.name_prefix}-zipline-orch-http-proxy"
  project = var.project_id

  url_map = google_compute_url_map.orchestration_url_map[0].id
}

resource "google_compute_global_address" "orchestration_address" {
  count   = var.hub_domain != "" ? 1 : 0
  name    = "${var.name_prefix}-zipline-orch-lb-ip"
  project = var.project_id
}

resource "google_compute_global_forwarding_rule" "orchestration_forwarding_rule" {
  count       = var.hub_domain != "" ? 1 : 0
  name        = "${var.name_prefix}-zipline-orch-forwarding-rule"
  project     = var.project_id
  ip_address  = google_compute_global_address.orchestration_address[0].address
  ip_protocol = "TCP"
  port_range  = var.use_https ? "443" : "80"

  load_balancing_scheme = "EXTERNAL_MANAGED"
  target                = var.use_https ? google_compute_target_https_proxy.orchestration_https_proxy[0].id : google_compute_target_http_proxy.orchestration_http_proxy[0].id
}


resource "google_compute_region_network_endpoint_group" "zipline_ui_neg" {
  count                 = var.zipline_ui_domain != "" ? 1 : 0
  name                  = "${var.name_prefix}-zipline-ui-neg"
  project               = var.project_id
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = google_cloud_run_v2_service.zipline_ui.name
  }
}

resource "google_compute_backend_service" "zipline_ui_backend_service" {
  count                 = var.zipline_ui_domain != "" ? 1 : 0
  name                  = "${var.name_prefix}-zipline-ui-backend-service"
  project               = var.project_id
  protocol              = "HTTPS"
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.zipline_ui_neg[0].id
  }

  iap {
    enabled = true
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
  count   = var.zipline_ui_domain != "" ? 1 : 0
  name    = "${var.name_prefix}-zipline-ui-url-map"
  project = var.project_id

  default_service = google_compute_backend_service.zipline_ui_backend_service[0].id
}

resource "google_compute_managed_ssl_certificate" "zipline_ui_ssl_cert" {
  count   = var.zipline_ui_domain != "" ? 1 : 0
  name    = "${var.name_prefix}-zipline-ui-ssl-cert"
  project = var.project_id

  managed {
    domains = [var.zipline_ui_domain]
  }
}

resource "google_compute_target_https_proxy" "zipline_ui_https_proxy" {
  count   = var.zipline_ui_domain != "" ? 1 : 0
  name    = "${var.name_prefix}-zipline-ui-https-proxy"
  project = var.project_id

  url_map          = google_compute_url_map.zipline_ui_url_map[0].id
  ssl_certificates = [google_compute_managed_ssl_certificate.zipline_ui_ssl_cert[0].id]
  ssl_policy       = google_compute_ssl_policy.ingress_ssl_policy.id
}

resource "google_compute_global_address" "zipline_ui_address" {
  count   = var.zipline_ui_domain != "" ? 1 : 0
  name    = "${var.name_prefix}-zipline-ui-lb-ip"
  project = var.project_id
}

resource "google_compute_global_forwarding_rule" "zipline_ui_forwarding_rule" {
  count       = var.zipline_ui_domain != "" ? 1 : 0
  name        = "${var.name_prefix}-zipline-ui-forwarding-rule"
  project     = var.project_id
  ip_address  = google_compute_global_address.zipline_ui_address[0].address
  ip_protocol = "TCP"
  port_range  = "443"

  load_balancing_scheme = "EXTERNAL_MANAGED"
  target                = google_compute_target_https_proxy.zipline_ui_https_proxy[0].id
}

resource "google_compute_region_network_endpoint_group" "zipline_eval_neg" {
  count                 = var.zipline_eval_domain != "" ? 1 : 0
  name                  = "${var.name_prefix}-zipline-eval-neg"
  project               = var.project_id
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = google_cloud_run_v2_service.chronon_eval.name
  }
}

resource "google_compute_backend_service" "zipline_eval_backend_service" {
  count                 = var.zipline_eval_domain != "" ? 1 : 0
  name                  = "${var.name_prefix}-zipline-eval-backend-service"
  project               = var.project_id
  protocol              = "HTTPS"
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.zipline_eval_neg[0].id
  }

  iap {
    enabled = true
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
  count   = var.zipline_eval_domain != "" ? 1 : 0
  name    = "${var.name_prefix}-zipline-eval-url-map"
  project = var.project_id

  default_service = google_compute_backend_service.zipline_eval_backend_service[0].id
}

resource "google_compute_managed_ssl_certificate" "zipline_eval_ssl_cert" {
  count   = var.zipline_eval_domain != "" ? 1 : 0
  name    = "${var.name_prefix}-zipline-eval-ssl-cert"
  project = var.project_id

  managed {
    domains = [var.zipline_eval_domain]
  }
}

resource "google_compute_target_https_proxy" "zipline_eval_https_proxy" {
  count   = var.zipline_eval_domain != "" ? 1 : 0
  name    = "${var.name_prefix}-zipline-eval-https-proxy"
  project = var.project_id

  url_map          = google_compute_url_map.zipline_eval_url_map[0].id
  ssl_certificates = [google_compute_managed_ssl_certificate.zipline_eval_ssl_cert[0].id]
  ssl_policy       = google_compute_ssl_policy.ingress_ssl_policy.id
}

resource "google_compute_global_address" "zipline_eval_address" {
  count   = var.zipline_eval_domain != "" ? 1 : 0
  name    = "${var.name_prefix}-zipline-eval-lb-ip"
  project = var.project_id
}

resource "google_compute_global_forwarding_rule" "zipline_eval_forwarding_rule" {
  count       = var.zipline_eval_domain != "" ? 1 : 0
  name        = "${var.name_prefix}-zipline-eval-forwarding-rule"
  project     = var.project_id
  ip_address  = google_compute_global_address.zipline_eval_address[0].address
  ip_protocol = "TCP"
  port_range  = "443"

  load_balancing_scheme = "EXTERNAL_MANAGED"
  target                = google_compute_target_https_proxy.zipline_eval_https_proxy[0].id
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
  value       = google_cloud_run_v2_service.chronon_eval.uri
  description = "URL of the Chronon Eval service"
}

output "hub_address" {
  value = var.hub_domain != "" ? var.hub_domain : google_cloud_run_v2_service.orchestration.uri
}

output "ui_address" {
  value = var.zipline_ui_domain != "" ? var.zipline_ui_domain : google_cloud_run_v2_service.zipline_ui.uri
}

output "UI_DNS_Instructions" {
  value = var.zipline_ui_domain != "" ? "Create an A record pointing ${var.zipline_ui_domain} to ${google_compute_global_address.zipline_ui_address[0].address}. For more details, see https://cloud.google.com/load-balancing/docs/https/setting-up-https-serverless#update_dns" : null
}

output "Hub_DNS_Instructions" {
  value = var.hub_domain != "" ? "Create an A record pointing ${var.hub_domain} to ${google_compute_global_address.orchestration_address[0].address}. For more details, see https://cloud.google.com/load-balancing/docs/https/setting-up-https-serverless#update_dns" : null
}

output "Eval_DNS_Instructions" {
  value = var.zipline_eval_domain != "" ? "Create an A record pointing ${var.zipline_eval_domain} to ${google_compute_global_address.zipline_eval_address[0].address}. For more details, see https://cloud.google.com/load-balancing/docs/https/setting-up-https-serverless#update_dns" : null
}

output "eval_service_account_email" {
  value       = google_service_account.eval_service_account.email
  description = "Email of the Chronon Eval metadata service account"
}

output "eval_service_account_id" {
  value       = google_service_account.eval_service_account.id
  description = "ID of the Chronon Eval metadata service account"
}