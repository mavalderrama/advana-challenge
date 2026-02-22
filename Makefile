.ONESHELL:
ENV_PREFIX=$(shell python -c "if __import__('pathlib').Path('.venv/bin/pip').exists(): print('.venv/bin/')")

.PHONY: help
help:             	## Show the help.
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@fgrep "##" Makefile | fgrep -v fgrep

.PHONY: venv
venv:			## Create a virtual environment
	@echo "Creating virtualenv ..."
	@rm -rf .venv
	@python3 -m venv .venv
	@./.venv/bin/pip install -U pip
	@echo
	@echo "Run 'source .venv/bin/activate' to enable the environment"

.PHONY: install
install:		## Install dependencies
	pip install -r requirements-dev.txt
	pip install -r requirements-test.txt
	pip install -r requirements.txt

STRESS_URL = http://127.0.0.1:8000 
.PHONY: stress-test
stress-test:
	# change stress url to your deployed app 
	mkdir reports || true
	locust -f tests/stress/api_stress.py --print-stats --html reports/stress-test.html --run-time 60s --headless --users 100 --spawn-rate 1 -H $(STRESS_URL)

.PHONY: model-test
model-test:			## Run tests and coverage
	mkdir reports || true
	pytest --cov-config=.coveragerc --cov-report term --cov-report html:reports/html --cov-report xml:reports/coverage.xml --junitxml=reports/junit.xml --cov=challenge tests/model

.PHONY: api-test
api-test:			## Run tests and coverage
	mkdir reports || true
	pytest -vvvv --cov-config=.coveragerc --cov-report term --cov-report html:reports/html --cov-report xml:reports/coverage.xml --junitxml=reports/junit.xml --cov=challenge tests/api

.PHONY: build
build:			## Build locally the python artifact
	python setup.py bdist_wheel

# ---------------------------------------------------------------------------
# GCP deployment — run these targets in order on first deploy:
#   1. make tf-registry   (create Artifact Registry)
#   2. make docker-push   (build and push the image)
#   3. make tf-deploy     (create Cloud Run service)
#
# For subsequent releases (image already exists):
#   make docker-push && make tf-deploy
# ---------------------------------------------------------------------------

TF_DIR = terraform

.PHONY: tf-init
tf-init:		## Initialise Terraform (run once)
	cd $(TF_DIR) && terraform init

.PHONY: tf-registry
tf-registry:		## Phase 1 — create Artifact Registry (must run before docker-push)
	cd $(TF_DIR) && terraform apply \
		-target=google_project_service.run \
		-target=google_project_service.artifact_registry \
		-target=google_project_service.iam \
		-target=google_artifact_registry_repository.images \
		-target=google_service_account.cloud_run

.PHONY: docker-push
docker-push:		## Build and push the Docker image to Artifact Registry
	$(eval REGISTRY := $(shell cd $(TF_DIR) && terraform output -raw artifact_registry_url))
	$(eval IMAGE    := $(shell cd $(TF_DIR) && terraform output -raw docker_image_url))
	gcloud auth configure-docker $(shell cd $(TF_DIR) && terraform output -raw artifact_registry_url | cut -d/ -f1) --quiet
	docker build --platform linux/amd64 -t $(IMAGE) .
	docker push $(IMAGE)

.PHONY: tf-deploy
tf-deploy:		## Phase 2 — deploy Cloud Run service (run after docker-push)
	cd $(TF_DIR) && terraform apply

.PHONY: bootstrap
bootstrap:		## Full first-time deploy: registry → image → Cloud Run
	$(MAKE) tf-registry
	$(MAKE) docker-push
	$(MAKE) tf-deploy
