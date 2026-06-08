terraform {
  required_version = ">= 1.3.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.80.0, < 7.0.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 4.80.0, < 7.0.0"
    }
  }
}

provider "google" {
  alias  = "project_creation"
  region = var.region
}

provider "google-beta" {
  alias  = "project_creation"
  region = var.region
}

provider "google" {
  project = module.project.project_id
  region  = var.region
}
