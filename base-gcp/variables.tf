variable "region" {}

variable "zone" {}


variable "customer_name" {}

variable "artifact_prefix" {}

variable "personnel_email" {
  description = "A group email address for personnel who should administer the Zipline deployment."
  default     = ""
}

variable "users_email" {
  description = "A group email address for users who should have access to the Zipline deployment."
  default     = ""
}

variable "alerting_email" {
  description = "Email address to send alerts to."
  default     = ""
}

variable "dataproc_subnetwork" {
  default = ""
}

variable "dataproc_tags" {
  default = []
}

variable "dataproc_init_actions" {
  default = []
}

variable "hub_domain" {
  description = "Optional custom domain for hub. If not set, a default domain will be used."
  default     = ""
}

variable "zipline_ui_domain" {
  description = "Optional custom domain for the Zipline UI. If not set, a default domain will be used."
  default     = ""
}

variable "zipline_version" {
  description = "The version of Zipline to deploy. This should correspond to a valid Docker image tag in the Zipline repository."
  default     = "latest"
}

variable "vpc_network_name" {
  description = "The name of the VPC network to deploy resources into. If not set, one will be created."
  default     = ""
}

variable "vpc_network_id" {
  description = "The id of the VPC network to deploy resources into. If not set, one will be created."
  default     = ""
}

variable "vpc_subnet_name" {
  description = "The name of VPC subnet to deploy resources into. If not set, one will be created."
  default     = ""
}

variable "allowed_ip_ranges" {
  description = "List of CIDR IP ranges allowed to access the Zipline deployment."
  type        = list(string)
  default     = []
}

variable "disable_iap" {
  description = "Whether to disable Identity-Aware Proxy (IAP) for the Zipline UI."
  type        = bool
  default     = false
}

variable "create_bigquery_reservation" {
  description = "Whether to create a BigQuery reservation for Zipline."
  type        = bool
  default     = true
}