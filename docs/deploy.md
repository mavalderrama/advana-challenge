# Deployment Guide — LATAM Flight Delay API on GCP Cloud Run

## Overview

The deployment is split into two phases to solve the bootstrapping problem:

```
Phase 1 (tf-registry)  →  Phase 2 (docker-push)  →  Phase 3 (tf-deploy)
Create Artifact Registry   Build & push image         Create Cloud Run service
```

All three phases are automated via Makefile targets. On a first deploy use `make bootstrap` to run them in order. On subsequent releases only phases 2 and 3 are needed.

---

## Prerequisites

| Tool | Min version | Install |
|---|---|---|
| [gcloud CLI](https://cloud.google.com/sdk/docs/install) | any recent | `brew install google-cloud-sdk` |
| [Terraform](https://developer.hashicorp.com/terraform/install) | >= 1.5 | `brew install terraform` |
| [Docker](https://docs.docker.com/get-docker/) | >= 24 | Docker Desktop |

---

## 1. GCP project setup

### 1.1 Create or select a project

```bash
# Create a new project (skip if you already have one)
gcloud projects create YOUR_PROJECT_ID --name="Flight Delay API"

# Set it as the active project
gcloud config set project YOUR_PROJECT_ID
```

### 1.2 Enable billing

Billing must be enabled on the project before any API can be activated.
Open: https://console.cloud.google.com/billing/linkedaccount?project=YOUR_PROJECT_ID

### 1.3 Authenticate

```bash
# Login with your Google account
gcloud auth login

# Create Application Default Credentials (used by Terraform)
gcloud auth application-default login
```

---

## 2. Configure Terraform variables

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit `terraform/terraform.tfvars` and set at minimum:

```hcl
project_id = "YOUR_PROJECT_ID"
region     = "us-central1"   # change if needed
```

Optional overrides (defaults are fine for a first deploy):

| Variable | Default | Description |
|---|---|---|
| `service_name` | `flight-delay-api` | Name of the Cloud Run service and registry |
| `image_tag` | `latest` | Docker image tag to deploy |
| `allow_unauthenticated` | `true` | Public access to the API |
| `min_instance_count` | `0` | Scale to zero when idle |
| `max_instance_count` | `10` | Maximum autoscale instances |
| `cpu_limit` | `1` | vCPUs per instance |
| `memory_limit` | `1Gi` | RAM per instance |

---

## 3. Initialise Terraform

Run once per machine / fresh clone:

```bash
make tf-init
```

---

## 4. First-time deploy (bootstrap)

Runs all three phases in the correct order:

```bash
make bootstrap
```

What it does internally:

```
make tf-registry   # Enables GCP APIs, creates Artifact Registry repo & service account
make docker-push   # Builds the image for linux/amd64 and pushes it to the registry
make tf-deploy     # Creates the Cloud Run service pointing at the pushed image
```

At the end Terraform prints the live URL:

```
Outputs:
service_url = "https://flight-delay-api-<hash>-uc.a.run.app"
```

Verify the service is healthy:

```bash
curl $(cd terraform && terraform output -raw service_url)/health
# → {"status":"OK"}
```

---

## 5. Subsequent releases

Re-build and push a new image, then redeploy:

```bash
make docker-push   # rebuilds and pushes (same tag by default)
make tf-deploy     # updates the Cloud Run revision to the new image
```

To deploy a specific tag (e.g. a git SHA):

```bash
cd terraform && terraform apply -var="image_tag=abc1234"
```

---

## 6. Tear down

Remove all GCP resources created by Terraform:

```bash
cd terraform && terraform destroy
```

> The Artifact Registry images are **not** deleted automatically. Remove them manually in the GCP Console or with `gcloud artifacts docker images delete` if needed.

---

## Terraform file reference

| File | Purpose |
|---|---|
| `terraform/registry.tf` | Phase 1 resources: GCP API enablement, Artifact Registry, service account |
| `terraform/service.tf` | Phase 2 resources: Cloud Run v2 service, public IAM binding |
| `terraform/providers.tf` | Google provider config and optional GCS remote state backend |
| `terraform/variables.tf` | All input variables with descriptions and defaults |
| `terraform/outputs.tf` | `service_url`, `artifact_registry_url`, `docker_image_url`, `service_account_email` |
| `terraform/terraform.tfvars.example` | Template — copy to `terraform.tfvars` |

---

## Makefile target reference

| Target | Description |
|---|---|
| `make tf-init` | Initialise Terraform (run once) |
| `make tf-registry` | Phase 1: create Artifact Registry and supporting infra |
| `make docker-push` | Build the image for `linux/amd64` and push to Artifact Registry |
| `make tf-deploy` | Phase 2: create / update the Cloud Run service |
| `make bootstrap` | Full first-time deploy (phases 1 → 2 → 3) |
| `make api-test` | Run API tests locally |
| `make model-test` | Run model tests locally |
| `make stress-test` | Run Locust load test (set `STRESS_URL` to the live service URL) |

---

## Troubleshooting

### `docker-push` fails with permission denied

```bash
gcloud auth configure-docker us-central1-docker.pkg.dev
```

If that still fails, ensure your account has the `roles/artifactregistry.writer` IAM role on the project.

### Cloud Run returns 403 on public endpoints

`allow_unauthenticated` may be `false` in your `terraform.tfvars`. Set it to `true` and re-run `make tf-deploy`, or invoke the service with an identity token:

```bash
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
     $(cd terraform && terraform output -raw service_url)/health
```

### Cloud Run fails to start (startup probe timeout)

The model artifact is loaded on startup. If the instance is under-resourced it may time out. Increase memory:

```hcl
# terraform/terraform.tfvars
memory_limit = "2Gi"
```

Then run `make tf-deploy`.

### `terraform apply` fails with API not enabled

Run `make tf-registry` first. It enables `run.googleapis.com`, `artifactregistry.googleapis.com`, and `iam.googleapis.com` before creating any resources that depend on them.
