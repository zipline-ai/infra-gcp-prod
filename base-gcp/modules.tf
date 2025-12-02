module "orchestration" {
  source = "../orchestration-gcp"

  project_id      = data.google_project.zipline.project_id
  project_number  = data.google_project.zipline.number
  zipline_version = var.zipline_version

  name_prefix     = var.customer_name
  region          = var.region
  personnel_email = var.personnel_email
  users_email     = var.users_email
  alerting_email  = var.alerting_email

  zipline_ui_domain = var.zipline_ui_domain
  hub_domain        = var.hub_domain

  bigtable_instance_name       = google_bigtable_instance.zipline_bigtable_instance.name
  table_partitions_dataset     = google_bigtable_table.table_partitions.name
  data_quality_metrics_dataset = "DATA_QUALITY_METRICS"
  dataproc_service_account     = google_service_account.dataproc_sa.id

  vpc_id      = var.vpc_network_id != "" ? var.vpc_network_id : google_compute_network.zipline_vpc[0].id
  vpc_name    = var.vpc_network_name != "" ? var.vpc_network_name : google_compute_network.zipline_vpc[0].name
  subnet_name = var.vpc_subnet_name != "" ? var.vpc_subnet_name : google_compute_subnetwork.zipline_subnet[0].name

  allowed_ip_ranges = var.allowed_ip_ranges
  disable_iap       = var.disable_iap

  eval_impersonation_users = var.eval_impersonation_users

  depends_on = [
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

output "eval_service_account_email" {
  value       = module.orchestration.eval_service_account_email
  description = "Email of the Chronon Eval metadata service account"
}

output "eval_service_account_id" {
  value       = module.orchestration.eval_service_account_id
  description = "ID of the Chronon Eval metadata service account"
}