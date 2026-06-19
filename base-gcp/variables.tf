variable "region" {}

variable "zone" {}


variable "customer_name" {}

variable "artifact_prefix" {}

variable "docker_hub_token" {
  description = "Docker Hub token for pulling Zipline images."
}

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

# A single custom domain for all services (optional). Either set zipline_custom_domain or the set (zipline_ui_domain, hub_domain, and zipline_eval_domain)
variable "zipline_custom_domain" {
  type        = string
  description = "Custom domain for the entire zipline stack. Either set this or the individual domains for each service."
  default     = ""
}


variable "hub_domain" {
  description = "Optional custom domain for hub. If not set, a default domain will be used."
  default     = ""
}

variable "zipline_ui_domain" {
  description = "Optional custom domain for the Zipline UI. If not set, a default domain will be used."
  default     = ""
}

variable "zipline_eval_domain" {
  description = "Set to provide a URL for the Zipline eval service."
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

variable "allow_public_access" {
  description = "Whether to create allUsers IAM grants for public Cloud Run/IAP access. Leave false for organizations that restrict public IAM members."
  type        = bool
  default     = false
}

variable "create_bigquery_reservation" {
  description = "Whether to create a BigQuery reservation for Zipline."
  type        = bool
  default     = true
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

variable "setup_dataproc_cluster" {
  description = "Whether to setup a static dataproc cluster."
  type        = bool
  default     = false
}

variable "create_dataproc_sa" {
  description = "Whether to create or import the dataproc service account"
  type        = bool
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
