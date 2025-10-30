module "base_setup" {
  source = "../base-gcp"

  customer_name               = var.customer_name
  region                      = var.region
  personnel_email             = var.personnel_email
  users_email                 = var.users_email
  alerting_email              = var.alerting_email
  zone                        = var.bigtable_zone
  artifact_prefix             = var.artifact_prefix
  zipline_version             = var.zipline_version
  hub_domain                  = var.hub_domain
  zipline_ui_domain           = var.zipline_ui_domain
  vpc_network_name            = var.vpc_network_name
  vpc_network_id              = var.vpc_network_id
  vpc_subnet_name             = var.vpc_subnet_name
  allowed_ip_ranges           = var.allowed_ip_ranges
  disable_iap                 = var.disable_iap
  dataproc_init_actions       = var.dataproc_init_actions
  create_bigquery_reservation = var.create_bigquery_reservation
}

output "hub_address" {
  value = module.base_setup.hub_address
}

output "ui_address" {
  value = module.base_setup.ui_address
}

output "UI_DNS_Instructions" {
  value = module.base_setup.UI_DNS_Instructions
}

output "Hub_DNS_Instructions" {
  value = module.base_setup.Hub_DNS_Instructions
}