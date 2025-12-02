variable "project_id" {}

variable "project_number" {}

variable "name_prefix" {}

variable "personnel_email" {}

variable "users_email" {}

variable "alerting_email" {}

variable "zipline_version" {}

variable "region" {}

variable "hub_domain" {
  description = "Set to provide a URL for the Zipline hub."
  default     = ""
}

variable "zipline_ui_domain" {
  description = "Set to provide a URL for the Zipline frontend."
  default     = ""
}

variable "zipline_eval_domain" {
  description = "Set to provide a URL for the Zipline eval service."
  default     = ""
}

variable "vpc_id" {}

variable "vpc_name" {}

variable "subnet_name" {}

variable "bigtable_instance_name" {}

variable "table_partitions_dataset" {}

variable "data_quality_metrics_dataset" {}

variable "dataproc_service_account" {}

variable "use_https" {
  description = "Whether to use HTTPS for the Hub domain."
  type        = bool
  default     = true
}

variable "allowed_ip_ranges" {
  description = "List of CIDR blocks to allow access to the Zipline UI and Hub."
  type        = list(string)
  default     = []
}

variable "disable_iap" {
  description = "Whether to disable Identity-Aware Proxy (IAP) for the Zipline UI."
  type        = bool
  default     = false
}

variable "eval_impersonation_users" {
  description = "List of users/groups who can impersonate the eval service account (e.g., user:alice@example.com, group:data-team@example.com)"
  type        = list(string)
  default     = [""]
}