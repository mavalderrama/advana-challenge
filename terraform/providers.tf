terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # Uncomment and configure to store state in GCS (recommended for teams).
  # Create the bucket manually before running `terraform init`.
  #
  # backend "gcs" {
  #   bucket = "YOUR_TF_STATE_BUCKET"
  #   prefix = "flight-delay-api/state"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
