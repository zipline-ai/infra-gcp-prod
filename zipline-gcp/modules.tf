module "base_setup" {
  source = "../base-gcp"

  providers = {
    google = google
    time   = time
  }

  customer_name               = var.customer_name
  region                      = var.region
  docker_hub_token            = var.docker_hub_token
  personnel_email             = var.personnel_email
  users_email                 = var.users_email
  alerting_email              = var.alerting_email
  zone                        = var.bigtable_zone
  artifact_prefix             = var.artifact_prefix
  zipline_version             = var.zipline_version
  hub_domain                  = var.hub_domain
  zipline_ui_domain           = var.zipline_ui_domain
  zipline_eval_domain         = var.zipline_eval_domain
  vpc_network_name            = var.vpc_network_name
  vpc_network_id              = var.vpc_network_id
  vpc_subnet_name             = var.vpc_subnet_name
  allowed_ip_ranges           = var.allowed_ip_ranges
  disable_iap                 = var.disable_iap
  allow_public_access         = var.allow_public_access
  dataproc_init_actions       = var.dataproc_init_actions
  create_bigquery_reservation = var.create_bigquery_reservation
  eval_impersonation_users    = var.eval_impersonation_users
  read_only_ui                = var.read_only_ui
  setup_dataproc_cluster      = var.setup_dataproc_cluster
  deploy_fetcher              = var.deploy_fetcher
  fetcher_access_members      = var.fetcher_access_members
  create_dataproc_sa          = var.create_dataproc_sa

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
}

output "hub_address" {
  value = module.base_setup.hub_address
}

output "ui_address" {
  value = module.base_setup.ui_address
}

output "Google_OAuth_Redirect_URI_Instructions" {
  value       = module.base_setup.Google_OAuth_Redirect_URI_Instructions
  description = "Instructions for registering the Google OAuth redirect URI when Google auth is enabled."
}

output "GitHub_OAuth_Redirect_URI_Instructions" {
  value       = module.base_setup.GitHub_OAuth_Redirect_URI_Instructions
  description = "Instructions for registering the GitHub OAuth callback URL when GitHub auth is enabled."
}

output "Microsoft_Entra_OAuth_Redirect_URI_Instructions" {
  value       = module.base_setup.Microsoft_Entra_OAuth_Redirect_URI_Instructions
  description = "Instructions for registering the Microsoft Entra OAuth redirect URI when Microsoft Entra auth is enabled."
}

output "fetcher_address" {
  value = module.base_setup.fetcher_address
}

output "eval_service_url" {
  value       = module.base_setup.eval_service_url
  description = "URL of the Chronon Eval service"
}

output "UI_DNS_Instructions" {
  value = module.base_setup.UI_DNS_Instructions
}

output "Hub_DNS_Instructions" {
  value = module.base_setup.Hub_DNS_Instructions
}

output "Eval_DNS_Instructions" {
  value = module.base_setup.Eval_DNS_Instructions
}

output "eval_service_account_email" {
  value       = module.base_setup.eval_service_account_email
  description = "Email of the Chronon Eval metadata service account"
}
