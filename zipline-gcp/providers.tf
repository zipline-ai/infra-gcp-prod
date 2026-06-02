terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.14.1"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.13.1"
    }
  }
}
provider "google" {
  project = var.project
  region  = var.region
}
