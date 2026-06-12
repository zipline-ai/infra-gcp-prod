# Required variables for Zipline GCP deployment
variable "customer_name" {
  description = "A unique name of the customer for whom the Zipline deployment is being created."
}
variable "project" {
  description = "The GCP project ID where the Zipline deployment will be created."
}
variable "region" {
  description = "The GCP region where the Zipline deployment will be created."
}
variable "bigtable_zone" {
  description = "The GCP zone where the Bigtable instance will be created."
}
variable "artifact_prefix" {
  description = "The prefix to use for storing Zipline artifacts in GCS. This should start with gs://"
}

variable "docker_hub_token" {
  description = "Docker Hub token for pulling Zipline Docker images. If you have not been provided one, please reach out to the Zipline team."
}

variable "zipline_version" {
  description = "The version of Zipline to deploy. This should correspond to a valid Docker image tag in the Zipline repository."
  default     = "latest"
}
variable "personnel_email" {
  description = "Group email for personnel who will administer the Zipline deployment."
}


# Optional variables for Zipline GCP deployment
variable "users_email" {
  description = "Group email for users who will access the Zipline deployment."
  default     = ""
}
variable "alerting_email" {
  description = "Email address to send alerts to."
  default     = ""
}
variable "hub_domain" {
  description = "Optional custom domain for hub. If not set, cloud run's domain will be used. This must be set if your organization requires internal only ingress."
  default     = ""
}

variable "zipline_ui_domain" {
  description = "Optional custom domain for the Zipline UI. This must be set to add authentication to the zipline ui."
  default     = ""
}

variable "zipline_eval_domain" {
  description = "Set to provide a URL for the Zipline eval service."
  default     = ""
}

variable "vpc_network_name" {
  description = "The name of the VPC network to deploy resources into. If not set, one will be created."
  default     = ""
}

variable "vpc_network_id" {
  description = "The full link of the VPC network to deploy resources into. This should start with 'projects/'. If not set, one will be created."
  default     = ""
}

variable "vpc_subnet_name" {
  description = "The name of the VPC subnet to deploy resources into. If not set, one will be created."
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

variable "dataproc_init_actions" {
  description = "List of initialization actions to run on Dataproc clusters."
  type        = list(string)
  default     = []
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
