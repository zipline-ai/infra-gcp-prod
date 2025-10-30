terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.14.1"
    }
  }
  backend "gcs" {
    bucket = "zipline-ai-tofu-state"
    prefix = "prod"
  }
}
provider "google" {
  project = var.project
  region  = var.region
}