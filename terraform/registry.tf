# ---------------------------------------------------------------------------
# Phase 1 — Infrastructure
#
# These resources must exist BEFORE the Docker image can be pushed.
# Apply them first with:
#
#   make tf-registry
#
# Then build and push the image, then run `make tf-deploy`.
# ---------------------------------------------------------------------------

# Enable required GCP APIs
resource "google_project_service" "run" {
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "artifact_registry" {
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "iam" {
  service            = "iam.googleapis.com"
  disable_on_destroy = false
}

# Artifact Registry Docker repository
resource "google_artifact_registry_repository" "images" {
  location      = var.region
  repository_id = "${var.service_name}-images"
  description   = "Docker images for the ${var.service_name} Cloud Run service"
  format        = "DOCKER"

  depends_on = [google_project_service.artifact_registry]
}

# Service account used by Cloud Run at runtime
resource "google_service_account" "cloud_run" {
  account_id   = "${var.service_name}-sa"
  display_name = "${var.service_name} Cloud Run SA"
  description  = "Service account used by the ${var.service_name} Cloud Run service"

  depends_on = [google_project_service.iam]
}
