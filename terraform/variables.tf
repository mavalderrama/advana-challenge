variable "project_id" {
  description = "GCP Project ID where all resources will be created."
  type        = string
}

variable "region" {
  description = "GCP region for all resources (Artifact Registry, Cloud Run)."
  type        = string
  default     = "us-central1"
}

variable "service_name" {
  description = "Name used for the Cloud Run service, Artifact Registry repository, and service account."
  type        = string
  default     = "flight-delay-api"
}

variable "image_tag" {
  description = "Docker image tag to deploy (e.g., 'latest', 'v1.0.0', or a git commit SHA)."
  type        = string
  default     = "latest"
}

variable "allow_unauthenticated" {
  description = "Allow public, unauthenticated access to the Cloud Run service. Set to false for private APIs."
  type        = bool
  default     = true
}

variable "min_instance_count" {
  description = "Minimum number of Cloud Run instances. Set to 0 to enable scale-to-zero."
  type        = number
  default     = 0
}

variable "max_instance_count" {
  description = "Maximum number of Cloud Run instances for autoscaling."
  type        = number
  default     = 25
}

variable "cpu_limit" {
  description = "CPU limit per Cloud Run instance (e.g., '1', '2')."
  type        = string
  default     = "8"
}

variable "memory_limit" {
  description = "Memory limit per Cloud Run instance (e.g., '512Mi', '1Gi', '2Gi')."
  type        = string
  default     = "8Gi"
}

variable "request_timeout_seconds" {
  description = "Maximum time in seconds for a Cloud Run request to complete before it is terminated."
  type        = number
  default     = 300
}

variable "deployer_service_account" {
  description = "Email of the service account used to deploy (e.g. GitHub Actions SA). Granted iam.serviceAccountUser on the Cloud Run SA so it can configure the service."
  type        = string
}
