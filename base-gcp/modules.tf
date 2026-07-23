module "orchestration" {
  source = "../orchestration-gcp"

  project_id       = data.google_project.zipline.project_id
  project_number   = data.google_project.zipline.number
  zipline_version  = var.zipline_version
  docker_hub_token = var.docker_hub_token

  name_prefix     = var.customer_name
  region          = var.region
  personnel_email = var.personnel_email
  users_email     = var.users_email
  alerting_email  = var.alerting_email

  zipline_custom_domain  = var.zipline_custom_domain
  zipline_ui_domain      = var.zipline_ui_domain
  hub_domain             = var.hub_domain
  zipline_eval_domain    = var.zipline_eval_domain
  zipline_fetcher_domain = var.zipline_fetcher_domain

  bigtable_instance_name       = google_bigtable_instance.zipline_bigtable_instance.name
  table_partitions_dataset     = google_bigtable_table.table_partitions.name
  data_quality_metrics_dataset = "DATA_QUALITY_METRICS"
  dataproc_service_account     = var.create_dataproc_sa ? google_service_account.dataproc_sa[0].id : data.google_service_account.dataproc_sa[0].id

  vpc_id      = var.vpc_network_id != "" ? var.vpc_network_id : google_compute_network.zipline_vpc[0].id
  vpc_name    = var.vpc_network_name != "" ? var.vpc_network_name : google_compute_network.zipline_vpc[0].name
  subnet_name = var.vpc_subnet_name != "" ? var.vpc_subnet_name : google_compute_subnetwork.zipline_subnet[0].name

  allowed_ip_ranges      = var.allowed_ip_ranges
  disable_iap            = var.disable_iap
  allow_public_access    = var.allow_public_access
  deploy_fetcher         = var.deploy_fetcher
  fetcher_access_members = var.fetcher_access_members
  fetcher_open_access    = var.fetcher_open_access

  read_only_ui = var.read_only_ui

  eval_impersonation_users = var.eval_impersonation_users

  zipline_auth_enabled                = var.zipline_auth_enabled
  google_oauth_client_id              = var.google_oauth_client_id
  google_oauth_client_secret          = var.google_oauth_client_secret
  github_oauth_client_id              = var.github_oauth_client_id
  github_oauth_client_secret          = var.github_oauth_client_secret
  microsoft_entra_tenant_id           = var.microsoft_entra_tenant_id
  microsoft_entra_oauth_client_id     = var.microsoft_entra_oauth_client_id
  microsoft_entra_oauth_client_secret = var.microsoft_entra_oauth_client_secret
  sso_provider_id                     = var.sso_provider_id
  sso_domain                          = var.sso_domain
  sso_issuer                          = var.sso_issuer
  sso_client_id                       = var.sso_client_id
  sso_client_secret                   = var.sso_client_secret
  idp_role_mapping                    = var.idp_role_mapping
  idp_group_claim                     = var.idp_group_claim

  depends_on = [
    google_project_service.bigquery,
    google_project_service.cloud_resource_manager,
    google_project_service.compute,
    google_project_service.iam,
    google_project_service.pubsub,
    google_project_service.service_usage,
    google_project_service.storage,
    google_service_networking_connection.private_vpc_connection
  ]

}

output "docker_hub_remote_repository_id" {
  value = module.orchestration.docker_hub_remote_repository_id
}

output "orchestration_service_name" {
  value = module.orchestration.orchestration_service_name
}

output "orchestration_service_account_id" {
  value = module.orchestration.orchestration_service_account_id
}

output "hub_address" {
  value = module.orchestration.hub_address
}

output "ui_address" {
  value = module.orchestration.ui_address
}

output "Google_OAuth_Redirect_URI_Instructions" {
  value       = module.orchestration.Google_OAuth_Redirect_URI_Instructions
  description = "Instructions for registering the Google OAuth redirect URI when Google auth is enabled."
}

output "GitHub_OAuth_Redirect_URI_Instructions" {
  value       = module.orchestration.GitHub_OAuth_Redirect_URI_Instructions
  description = "Instructions for registering the GitHub OAuth callback URL when GitHub auth is enabled."
}

output "Microsoft_Entra_OAuth_Redirect_URI_Instructions" {
  value       = module.orchestration.Microsoft_Entra_OAuth_Redirect_URI_Instructions
  description = "Instructions for registering the Microsoft Entra OAuth redirect URI when Microsoft Entra auth is enabled."
}

output "fetcher_address" {
  value = module.orchestration.fetcher_address
}

output "eval_service_url" {
  value       = module.orchestration.eval_service_url
  description = "URL of the Chronon Eval service"
}

output "UI_DNS_Instructions" {
  value = module.orchestration.UI_DNS_Instructions
}

output "Hub_DNS_Instructions" {
  value = module.orchestration.Hub_DNS_Instructions
}

output "Eval_DNS_Instructions" {
  value = module.orchestration.Eval_DNS_Instructions
}

output "Fetcher_DNS_Instructions" {
  value = module.orchestration.Fetcher_DNS_Instructions
}

output "eval_service_account_email" {
  value       = module.orchestration.eval_service_account_email
  description = "Email of the Chronon Eval metadata service account"
}

output "eval_service_account_id" {
  value       = module.orchestration.eval_service_account_id
  description = "ID of the Chronon Eval metadata service account"
}