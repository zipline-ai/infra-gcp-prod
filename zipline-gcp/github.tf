data "google_service_account" "github" {
  account_id = "github-actions"
}

resource "google_service_account_iam_member" "github_dev_cloudrun_access" {
  service_account_id = module.base_setup.orchestration_service_account_id
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${data.google_service_account.github.email}"
}

resource "google_cloud_run_service_iam_member" "github_dev_cloud_run_invoker" {
  service  = module.base_setup.orchestration_service_name
  location = var.region
  role     = "roles/run.invoker"
  member   = "serviceAccount:${data.google_service_account.github.email}"
}
