# DevSecOps lab: every command the pipeline runs, runnable on your laptop.
#
# The GitHub workflows call these same targets, so "it passed locally"
# means "it will pass in CI". Run `make` to see everything.
#
# All scanners run as pinned containers (versions in tools.env): the only
# things you install are docker, kind, kubectl, git and make.

include tools.env
export

SHELL      := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c
SHA        ?= $(shell git rev-parse --short=12 HEAD 2>/dev/null || echo local)
IMAGE      := $(REGISTRY)/$(IMAGE_NAME)
REPORTS    := reports
CTX        := kind-$(CLUSTER_NAME)
ENV        ?= dev
DOCKER_RUN := docker run --rm -v "$(CURDIR):/src" -w /src
TRIVY      := docker run --rm -v trivy-cache:/root/.cache/ -v "$(CURDIR):/src" -w /src \
              -v /var/run/docker.sock:/var/run/docker.sock $(TRIVY_IMAGE)
# Only fail on problems that have a fix available. Unfixed CVEs are tracked,
# not blocking: you cannot act on them, and blocking on them trains people
# to ignore the pipeline.
TRIVY_GATE := --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1

.DEFAULT_GOAL := help
.PHONY: help
help: ## Show this help
	@awk 'BEGIN{FS=":.*## "} /^## /{printf "\n\033[1m%s\033[0m\n", substr($$0,4)} /^[a-z0-9-]+:.*## /{printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

$(REPORTS):
	@mkdir -p $(REPORTS) && chmod 777 $(REPORTS)

## Platform (kind cluster + local registry)
.PHONY: doctor up down status oidc oidc-vars gatekeeper
doctor: ## Check this machine can run the lab (tools, versions, Docker, RAM, ports)
	@platform/doctor.sh
up: ## Create the registry and the kind cluster
	@platform/up.sh
down: ## Delete the cluster and the registry
	@platform/down.sh
status: ## What is running, and which version is deployed where
	@platform/status.sh
oidc: ## Trust GitHub Actions OIDC tokens from this repo (or REPO=owner/name) (Part 2)
	@platform/oidc.sh "$(or $(REPO),$(shell gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null))"
oidc-vars: ## Store the cluster address + CA as GitHub repo variables (needs gh)
	@repo=$$(cat .local/github-repo); \
	gh variable set KIND_API_SERVER --repo "$$repo" --body "https://127.0.0.1:6443"; \
	gh variable set KIND_AUDIENCE   --repo "$$repo" --body "kind-$(CLUSTER_NAME)"; \
	gh variable set KIND_CA_DATA    --repo "$$repo" --body "$$(base64 < .local/cluster-ca.crt | tr -d '\n')"
gatekeeper: ## Install OPA Gatekeeper + the admission policies (Part 2)
	@platform/gatekeeper.sh

## Self-hosted GitHub Actions runner (on this machine)
.PHONY: runner-install runner-start runner-stop runner-remove
runner-install: ## Download + register a runner for this repo (or REPO=owner/name)
	@platform/runner/runner.sh install "$(or $(REPO),$(shell gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null))"
runner-start: ## Start the runner in the background
	@platform/runner/runner.sh start
runner-stop: ## Stop the runner
	@platform/runner/runner.sh stop
runner-remove: ## Unregister and delete the runner
	@platform/runner/runner.sh remove

## Build and test
.PHONY: test build push deploy deploy-insecure
# The container runs as root on your mounted repo: write no caches into it, or
# root-owned .pytest_cache/__pycache__ break the next `git clean`/checkout.
test: ## Unit tests (pytest, in a container)
	$(DOCKER_RUN) -e PYTHONDONTWRITEBYTECODE=1 python:3.14-slim sh -c \
	  "pip install -q --root-user-action=ignore -r app/requirements-dev.txt && python -m pytest -q -p no:cacheprovider app/tests"
build: ## Build the image as $(IMAGE):$(SHA)
	docker build -t $(IMAGE):$(SHA) app
push: ## Push the image to the local registry and print its digest
	docker push -q $(IMAGE):$(SHA)
	@docker inspect --format '{{index .RepoDigests 0}}' $(IMAGE):$(SHA)
deploy-insecure: ## Part 1: build :dev and deploy the INSECURE manifests to dev
	docker build -t $(IMAGE):dev app
	docker push -q $(IMAGE):dev
	kubectl --context $(CTX) -n dev apply -f k8s/insecure/
	kubectl --context $(CTX) -n dev set image deploy/kubenotes app=$(IMAGE):dev
	kubectl --context $(CTX) -n dev rollout status deploy/kubenotes --timeout=120s
deploy: ## Part 3: deploy $(IMAGE):$(SHA) by DIGEST to ENV=dev|prod with YOUR kubeconfig
	@digest=$$(docker inspect --format '{{index .RepoDigests 0}}' $(IMAGE):$(SHA) 2>/dev/null | cut -d@ -f2) || true; \
	if [ -z "$$digest" ]; then \
	  echo "image $(IMAGE):$(SHA) not pushed yet -- building and pushing it first"; \
	  docker build -t $(IMAGE):$(SHA) app && docker push -q $(IMAGE):$(SHA) >/dev/null; \
	  digest=$$(docker inspect --format '{{index .RepoDigests 0}}' $(IMAGE):$(SHA) | cut -d@ -f2); \
	fi; \
	ci/render.sh $(ENV) "$$digest" $(SHA) | kubectl --context $(CTX) apply -f -; \
	kubectl --context $(CTX) -n $(ENV) rollout status deploy/kubenotes --timeout=120s

## Security scans (each one is a pipeline gate)
.PHONY: scan scan-secrets scan-sast scan-deps scan-iac policy-test scan-image sbom scan-workflows dast
scan: scan-secrets scan-sast scan-deps scan-iac ## Every scan that needs no image or cluster
scan-secrets: | $(REPORTS) ## Gitleaks: secrets anywhere in the git history
	$(DOCKER_RUN) $(GITLEAKS_IMAGE) git /src --redact --no-banner -c /src/.gitleaks.toml \
	  --report-format sarif --report-path $(REPORTS)/gitleaks.sarif
scan-sast: | $(REPORTS) ## Semgrep + Bandit: insecure code patterns
	$(DOCKER_RUN) $(SEMGREP_IMAGE) semgrep scan --metrics=off --error \
	  --config p/python --config p/flask --config p/security-audit \
	  --sarif-output=$(REPORTS)/semgrep.sarif --text app
	$(DOCKER_RUN) python:3.14-slim sh -c \
	  "pip install -q --root-user-action=ignore bandit==1.9.4 && bandit -q -r app -x app/tests -f txt"
scan-deps: | $(REPORTS) ## Trivy: known CVEs in Python dependencies (SCA)
	$(TRIVY) fs --scanners vuln $(TRIVY_GATE) --format table app
	@$(TRIVY) fs --scanners vuln --format sarif --output $(REPORTS)/trivy-deps.sarif app >/dev/null
scan-iac: policy-test | $(REPORTS) ## Hadolint + Trivy config + Conftest: Dockerfile and Kubernetes manifests
	$(DOCKER_RUN) $(HADOLINT_IMAGE) hadolint app/Dockerfile
	$(TRIVY) config --severity HIGH,CRITICAL --exit-code 1 --file-patterns 'dockerfile:Dockerfile' app/Dockerfile
	$(TRIVY) config --severity HIGH,CRITICAL --exit-code 1 k8s/base
	@echo "conftest: rendered dev + prod manifests against policies/"
	@for env in dev prod; do \
	  ci/render.sh $$env sha256:$$(printf '%064d' 0) $(SHA) > $(REPORTS)/rendered-$$env.yaml; done
	$(DOCKER_RUN) $(CONFTEST_IMAGE) test --policy policies $(REPORTS)/rendered-dev.yaml $(REPORTS)/rendered-prod.yaml
policy-test: ## Unit tests for the Rego policies
	$(DOCKER_RUN) $(CONFTEST_IMAGE) verify --policy policies
scan-image: | $(REPORTS) ## Trivy: CVEs in the built image (OS + Python packages)
	$(TRIVY) image $(TRIVY_GATE) --format table $(IMAGE):$(SHA)
	@$(TRIVY) image --format sarif --output $(REPORTS)/trivy-image.sarif $(IMAGE):$(SHA) >/dev/null
sbom: | $(REPORTS) ## CycloneDX SBOM of the built image
	$(TRIVY) image --format cyclonedx --output $(REPORTS)/sbom.cdx.json $(IMAGE):$(SHA)
	@echo "SBOM: $(REPORTS)/sbom.cdx.json ($$(grep -c '"bom-ref"' $(REPORTS)/sbom.cdx.json) components)"
scan-workflows: ## actionlint + zizmor: mistakes and security holes in .github/workflows
	$(DOCKER_RUN) $(ACTIONLINT_IMAGE) -color -config-file .github/actionlint.yaml $(wildcard .github/workflows/*.y*ml ci/workflows/*.y*ml)
	$(DOCKER_RUN) $(ZIZMOR_IMAGE) --offline --persona=pedantic --min-severity medium $(wildcard .github/workflows/*.y*ml ci/workflows/*.y*ml)
dast: | $(REPORTS) ## OWASP ZAP baseline scan against the app running in ENV=dev|prod
	@port=$$([ "$(ENV)" = prod ] && echo 30081 || echo 30080); \
	cp .zap/rules.tsv $(REPORTS)/zap-rules.tsv; \
	docker run --rm --network kind -v "$(CURDIR)/$(REPORTS):/zap/wrk:rw" $(ZAP_IMAGE) \
	  zap-baseline.py -t "http://$(CLUSTER_NAME)-control-plane:$$port" \
	  -c zap-rules.tsv -r zap-report.html -J zap-report.json -I

## Posture & compliance (benchmarks against standards, not just your own rules)
.PHONY: scan-config cis
KUBESCAPE := docker run --rm -v kubescape-cache:/home/nonroot/.kubescape \
             -v "$(CURDIR):/src" -w /src $(KUBESCAPE_IMAGE)
scan-config: | $(REPORTS) ## Kubescape: scan the hardened K8s manifests against the NSA + MITRE frameworks
	$(KUBESCAPE) scan framework nsa,mitre k8s/base \
	  --compliance-threshold 70 --format pretty-printer
	@$(KUBESCAPE) scan framework nsa,mitre k8s/base \
	  --format json --output $(REPORTS)/kubescape.json >/dev/null 2>&1 || true
	@echo "kubescape report: $(REPORTS)/kubescape.json  (try 'k8s/insecure' to watch it fail)"
cis: | $(REPORTS) ## CIS Kubernetes Benchmark against the running cluster (kube-bench)
	@sed 's#__KUBEBENCH_IMAGE__#$(KUBEBENCH_IMAGE)#' platform/cis/kube-bench-job.yaml.tpl \
	  | kubectl --context $(CTX) apply -f -
	@kubectl --context $(CTX) -n kube-system wait --for=condition=complete job/kube-bench --timeout=150s || true
	@kubectl --context $(CTX) -n kube-system logs job/kube-bench | tee $(REPORTS)/kube-bench.txt
	@kubectl --context $(CTX) -n kube-system delete job kube-bench --ignore-not-found >/dev/null

## Detect & respond (Part 4)
# The API server writes the audit log as root with mode 0600. On Linux and
# WSL that makes it unreadable to you, so open it up before reading it
# (every time: log rotation creates a fresh 0600 file).
AUDIT_READABLE = docker exec $(CLUSTER_NAME)-control-plane sh -c 'chmod a+r /var/log/kubernetes/*.log' >/dev/null 2>&1 || true
.PHONY: audit detect incident triage ai-doctor
audit: ## Show the last lines of the Kubernetes API audit log
	@$(AUDIT_READABLE)
	@tail -n 40 .local/audit/audit.log 2>/dev/null || echo "no audit log yet (make up, then do something)"
detect: ## Scan the audit log for attack signals -> detect/findings.json
	@$(AUDIT_READABLE)
	@detect/detect.py --json detect/findings.json || true   # exit code = finding count (for CI); not a make failure here
incident: detect ## AI incident report from the findings (needs a Claude credential)
	@ai/incident-doctor.py --findings detect/findings.json $(ALERT)
triage: ## AI prioritised fix list from the scan reports
	@ai/security-triage.py --reports $(REPORTS) $(ALERT)
ai-doctor: ## AI diagnosis of a failed build: make ai-doctor LOG=reports/build.log
	@ai/build-doctor.py --log "$(LOG)" $(ALERT)

.PHONY: clean
clean: ## Delete local reports
	rm -rf $(REPORTS) k8s/.render.*
