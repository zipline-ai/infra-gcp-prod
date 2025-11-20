data "google_project" "zipline" {
}


resource "google_project_service" "bigtable_admin" {
  project = data.google_project.zipline.project_id
  service = "bigtableadmin.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy         = false
}

resource "google_project_service" "monitoring" {
  project = data.google_project.zipline.project_id
  service = "monitoring.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy         = false
}

# Add Service Networking API (required for private IP)
resource "google_project_service" "service_networking" {
  service = "servicenetworking.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy         = false
}

# Personnel Roles

resource "google_project_iam_member" "personnel_bigtable" {
  project = data.google_project.zipline.project_id
  role    = "roles/bigtable.user"
  member  = "group:${var.personnel_email}"
}

resource "google_project_iam_member" "personnel_logging" {
  project = data.google_project.zipline.project_id
  role    = "roles/logging.viewer"
  member  = "group:${var.personnel_email}"
}

resource "google_project_iam_member" "personnel_dataproc" {
  project = data.google_project.zipline.project_id
  role    = "roles/dataproc.editor"
  member  = "group:${var.personnel_email}"
}

resource "google_project_iam_member" "personnel_bigquery" {
  project = data.google_project.zipline.project_id
  role    = "roles/bigquery.user"
  member  = "group:${var.personnel_email}"
}

resource "google_project_iam_member" "personnel_bigquery_data" {
  project = data.google_project.zipline.project_id
  role    = "roles/bigquery.dataViewer"
  member  = "group:${var.personnel_email}"
}

resource "google_project_iam_member" "personnel_compute" {
  project = data.google_project.zipline.project_id
  role    = "roles/compute.viewer"
  member  = "group:${var.personnel_email}"
}

resource "google_project_iam_member" "personnel_storage_object" {
  project = data.google_project.zipline.project_id
  role    = "roles/storage.objectUser"
  member  = "group:${var.personnel_email}"
}

resource "google_project_iam_member" "personnel_monitoring" {
  project = data.google_project.zipline.project_id
  role    = "roles/monitoring.editor"
  member  = "group:${var.personnel_email}"
}

# Users Roles
resource "google_service_account_iam_member" "users_dataproc_sa" {
  count              = var.users_email != "" ? 1 : 0
  service_account_id = google_service_account.dataproc_sa.id
  role               = "roles/iam.serviceAccountUser"
  member             = "group:${var.users_email}"
}

resource "google_project_iam_member" "users_bigtable" {
  count   = var.users_email != "" ? 1 : 0
  project = data.google_project.zipline.project_id
  role    = "roles/bigtable.user"
  member  = "group:${var.users_email}"
}

resource "google_project_iam_member" "users_cloudsql" {
  count   = var.users_email != "" ? 1 : 0
  project = data.google_project.zipline.project_id
  role    = "roles/cloudsql.client"
  member  = "group:${var.users_email}"
}

resource "google_project_iam_member" "users_logging" {
  count   = var.users_email != "" ? 1 : 0
  project = data.google_project.zipline.project_id
  role    = "roles/logging.viewer"
  member  = "group:${var.users_email}"
}

resource "google_project_iam_member" "users_monitoring" {
  count   = var.users_email != "" ? 1 : 0
  project = data.google_project.zipline.project_id
  role    = "roles/monitoring.viewer"
  member  = "group:${var.users_email}"
}

resource "google_project_iam_member" "users_bigquery" {
  count   = var.users_email != "" ? 1 : 0
  project = data.google_project.zipline.project_id
  role    = "roles/bigquery.user"
  member  = "group:${var.users_email}"
}