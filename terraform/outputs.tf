output "service_url" {
  description = "Public URL of the deployed Cloud Run service."
  value       = google_cloud_run_v2_service.api.uri
}

output "service_name" {
  description = "Name of the Cloud Run service."
  value       = google_cloud_run_v2_service.api.name
}

output "artifact_registry_url" {
  description = "Artifact Registry repository URL — use as the Docker registry hostname when pushing images."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.images.repository_id}"
}

output "docker_image_url" {
  description = "Full Docker image URL for the currently deployed tag."
  value       = local.image_url
}

output "service_account_email" {
  description = "Email of the service account attached to the Cloud Run service."
  value       = google_service_account.cloud_run.email
}
