.ONESHELL:
ENV_PREFIX=$(shell python -c "if __import__('pathlib').Path('.venv/bin/pip').exists(): print('.venv/bin/')")
GIT_SHA := $(shell git rev-parse --short HEAD)

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
# GCP deployment — first deploy:
#   make bootstrap          (registry → image → Cloud Run)
#
# Subsequent releases (image change):
#   make deploy             (docker-push + tf-deploy with current git SHA)
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
docker-push:		## Build and push the Docker image (tag: current git SHA)
	$(eval REGISTRY := $(shell cd $(TF_DIR) && terraform output -raw artifact_registry_url))
	$(eval SVC_NAME := $(shell cd $(TF_DIR) && terraform output -raw service_name))
	gcloud auth configure-docker $$(echo $(REGISTRY) | cut -d/ -f1) --quiet
	docker build --platform linux/amd64 -t $(REGISTRY)/$(SVC_NAME):$(GIT_SHA) .
	docker push $(REGISTRY)/$(SVC_NAME):$(GIT_SHA)

.PHONY: tf-deploy
tf-deploy:		## Deploy Cloud Run service with current git SHA image
	cd $(TF_DIR) && terraform apply -var="image_tag=$(GIT_SHA)"

.PHONY: deploy
deploy:			## Build, push, and deploy using current git SHA ($(GIT_SHA))
	$(MAKE) docker-push
	$(MAKE) tf-deploy

.PHONY: bootstrap
bootstrap:		## Full first-time deploy: registry → image → Cloud Run
	$(MAKE) tf-registry
	$(MAKE) docker-push
	$(MAKE) tf-deploy
