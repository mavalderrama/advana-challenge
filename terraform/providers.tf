terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # State is stored in GCS. Create the bucket manually, then run:
  #   terraform init -backend-config="bucket=YOUR_TF_STATE_BUCKET"
  # In CI/CD, pass the bucket via the TF_STATE_BUCKET secret.
  backend "gcs" {
    prefix = "flight-delay-api/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
