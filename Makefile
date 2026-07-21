IMAGE_NAME := psyb0t/codexbox
# Single-source version derivation: codexbox/pyproject.toml [project]
# version is THE source. awk reads it on the host (no Python dep
# needed just to read the version). __init__.py reads the same value
# at runtime via importlib.metadata. Override at build time for
# one-offs: `VERSION=0.10.1-rc1 make build`.
VERSION    ?= $(shell awk -F\" '/^version *= *"/ {print $$2; exit}' codexbox/pyproject.toml)
TAG        := v$(VERSION)
# Published base image pinned to its immutable multi-architecture manifest.
# Override only to test a deliberately selected local fork.
BASE_IMAGE ?= psyb0t/aicodebox:v0.14.0@sha256:543aec8bf85ebc8a0689c4746d4c9e2ede65599decb50827593db0b3c65bd2a5
CODEX_VERSION ?= 0.144.6

.PHONY: all build build-full build-all pull-base test test-full-image test-image-select clean help version

all: build ## Build the codexbox image on top of the published base

version: ## Print the version that would be tagged
	@echo $(TAG)

pull-base: ## Pull the published aicodebox base image (SKIP_BASE_PULL=1 to use a locally-built base)
	@if [ "$${SKIP_BASE_PULL:-0}" = "1" ]; then \
		echo "[make] SKIP_BASE_PULL=1 — using local $(BASE_IMAGE)"; \
		docker image inspect $(BASE_IMAGE) >/dev/null 2>&1 \
			|| { echo "❌ SKIP_BASE_PULL=1 but $(BASE_IMAGE) not found locally" >&2; exit 1; }; \
	else \
		docker pull $(BASE_IMAGE); \
	fi

build: pull-base ## Build + tag the image (both :v<VERSION> and :latest)
	docker build \
		--build-arg BASE_IMAGE=$(BASE_IMAGE) \
		--build-arg CODEX_VERSION=$(CODEX_VERSION) \
		-t $(IMAGE_NAME):$(TAG) \
		-t $(IMAGE_NAME):latest .

build-full: build ## Build the toolchain-loaded variant on the matching minimal image
	docker build \
		-f Dockerfile.full \
		--build-arg BASE_IMAGE=$(IMAGE_NAME):$(TAG) \
		-t $(IMAGE_NAME):$(TAG)-full \
		-t $(IMAGE_NAME):latest-full \
		.

build-all: build build-full ## Build both minimal and full variants

test: ## Run the full e2e test suite (needs .env.test)
	bash test.sh

test-image-select: ## Verify installer/wrapper minimal/full selection without Docker
	bash tests/test_image_select.sh

test-full-image: build-full ## Build full and verify Codex plus every advertised tool
	IMAGE=$(IMAGE_NAME):latest-full bash tests/test_full_image.sh

clean: ## Remove built images (keeps the published base)
	docker rmi $(IMAGE_NAME):$(TAG) 2>/dev/null || true
	docker rmi $(IMAGE_NAME):latest 2>/dev/null || true
	docker rmi $(IMAGE_NAME):$(TAG)-full 2>/dev/null || true
	docker rmi $(IMAGE_NAME):latest-full 2>/dev/null || true

help: ## Display this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
