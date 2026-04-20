variable "project_id" {}

variable "project_number" {}

variable "name_prefix" {}

variable "docker_hub_token" {}

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
  default     = []
}

variable "read_only_ui" {
  description = "Enable to mark the UI as read only, i.e. no modifications from buttons on the UI"
  default     = false
}

# Zipline Authentication
variable "zipline_auth_enabled" {
  type        = bool
  description = "Enable Zipline authentication"
  default     = false
}

variable "google_oauth_client_id" {
  type        = string
  description = "Optional for use google oauth with zipline authentication"
  default     = ""
}

variable "google_oauth_client_secret" {
  type        = string
  description = "Optional for use google oauth with zipline authentication"
  default     = ""
  sensitive   = true
}

variable "github_oauth_client_id" {
  type        = string
  description = "Optional for use github oauth with zipline authentication"
  default     = ""
}

variable "github_oauth_client_secret" {
  type        = string
  description = "Optional for use github oauth with zipline authentication"
  default     = ""
  sensitive   = true
}

variable "microsoft_entra_tenant_id" {
  type        = string
  description = "Optional for use Microsoft Entra id with zipline authentication"
  default     = ""
}

variable "microsoft_entra_oauth_client_id" {
  type        = string
  description = "Optional for use Microsoft Entra id with zipline authentication"
  default     = ""
}


variable "microsoft_entra_oauth_client_secret" {
  type        = string
  description = "Optional for use microsoft Entra ID with zipline authentication"
  default     = ""
  sensitive   = true
}

variable "sso_provider_id" {
  type        = string
  description = "Optional for use SSO with zipline authentication"
  default     = ""
}

variable "sso_domain" {
  type        = string
  description = "Optional for use SSO with zipline authentication"
  default     = ""
}

variable "sso_issuer" {
  type        = string
  description = "Optional for use SSO with zipline authentication"
  default     = ""
}

variable "sso_client_id" {
  type        = string
  description = "Optional for use SSO with zipline authentication"
  default     = ""
}

variable "sso_client_secret" {
  type        = string
  description = "Optional for use SSO with zipline authentication"
  default     = ""
  sensitive   = true
}

variable "idp_role_mapping" {
  type        = string
  description = "Optional comma separated list of role mappings for zipline authentication"
  default     = ""
}

variable "idp_group_claim" {
  type        = string
  description = "Optional group claims configured for zipline authentication"
  default     = ""
}

variable "deploy_fetcher" {
  type        = bool
  description = "Whether to deploy the fetcher service or not"
  default     = false
}

variable "fetcher_access_members" {
  type        = set(string)
  description = "List of users/groups who can access the fetcher service (e.g., user:alice@example.com, group:data-team@example.com"
  default     = []
}