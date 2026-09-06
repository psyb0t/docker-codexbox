IMAGE_NAME := psyb0t/codexbox
PKG        := codexbox
# Single-source version derivation: codexbox/pyproject.toml [project]
# version is THE source. awk reads it on the host (no Python dep
# needed just to read the version). __init__.py reads the same value
# at runtime via importlib.metadata. Override at build time for
# one-offs: `VERSION=0.10.1-rc1 make build`.
VERSION    ?= $(shell awk -F\" '/^version *= *"/ {print $$2; exit}' codexbox/pyproject.toml)
TAG        := v$(VERSION)
# Published base image pinned to its immutable multi-architecture manifest.
# Override only to test a deliberately selected local fork.
BASE_IMAGE ?= psyb0t/aicodebox:v0.14.8@sha256:3f28a053b88d9989698444c0f3d372b5ec6865df1eacb3ae11333245876a0b51
CODEX_VERSION ?= 0.151.0

.PHONY: all build build-full build-all install install-full install-wrapper pull-base test test-full-image test-image-select clean help version pkg-lock

all: build ## Build the codexbox image on top of the published base

version: ## Print version, or set-everywhere+commit+tag: make version V=X.Y.Z
ifeq ($(strip $(V)),)
	@echo $(TAG)
else
	@echo "$(V)" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.]+)?$$' || { echo "V must be semver (X.Y.Z), got '$(V)'" >&2; exit 1; }
	@set -e; old="$(VERSION)"; \
	( cd $(PKG) && uv version "$(V)" >/dev/null ); \
	tmp=$$(mktemp); jq --arg v "$(V)" '.version=$$v' .agents/.codex-plugin/plugin.json >"$$tmp" && mv "$$tmp" .agents/.codex-plugin/plugin.json; \
	git add $(PKG)/pyproject.toml $(PKG)/uv.lock .agents/.codex-plugin/plugin.json; \
	git commit -q -m "v$(V)"; \
	git tag -a "v$(V)" -m "$(PKG) v$(V)"; \
	echo "[make version] v$$old -> v$(V): bumped pyproject+uv.lock+codex-manifest, committed, tagged"; \
	if git --no-pager grep -In -e "$$old" -- ':!CHANGELOG.md' ':!uv.lock' ':!*server.json' ':!*package.json' >/dev/null 2>&1; then \
		echo "⚠ v$$old still appears in tracked files make version does not manage — check for a missed version location:" >&2; \
		git --no-pager grep -In -e "$$old" -- ':!CHANGELOG.md' ':!uv.lock' ':!*server.json' ':!*package.json' >&2; \
	fi
endif

pkg-lock: ## Refresh the Python lockfile under the current dependency pins
	cd codexbox && uv lock

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

install: build ## Build the minimal image locally and install the wrapper without pulling it
	CODEXBOX_SRC_LOCAL=true bash ./install.sh

install-full: build-full ## Build the full image locally and install the wrapper without pulling it
	CODEXBOX_FULL=1 CODEXBOX_SRC_LOCAL=true bash ./install.sh

install-wrapper: ## Install the wrapper without building or pulling (CODEXBOX_FULL=1 selects full)
	CODEXBOX_SRC_LOCAL=true bash ./install.sh

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
