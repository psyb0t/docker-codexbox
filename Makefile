IMAGE_NAME := psyb0t/codexbox
PKG        := codexbox
# Single-source version derivation: codexbox/pyproject.toml [project]
# version is THE source. awk reads it on the host (no Python dep
# needed just to read the version). __init__.py reads the same value
# at runtime via importlib.metadata. Override at build time for
# one-offs: `VERSION=0.10.1-rc1 make build`.
VERSION    ?= $(shell awk -F\" '/^version *= *"/ {print $$2; exit}' codexbox/pyproject.toml)
TAG        := v$(VERSION)
# Shared first-party base images follow their published latest variants.
# Override only to test a deliberately selected local fork.
BASE_IMAGE ?= psyb0t/aicodebox:latest
FULL_BASE_IMAGE ?= psyb0t/aicodebox:latest-full
CODEX_VERSION ?= 0.162.1

# Lint and CI test tooling. Python checks run in the base image, which
# already carries the aicodebox package the adapter imports. Keep the Python
# tool pins equal to the dev group in codexbox/pyproject.toml.
CI_IMAGE         ?= $(BASE_IMAGE)
PY_TOOLS         := pytest==9.1.1 ruff==0.17.0 pyright==1.1.414
SHELLCHECK_IMAGE ?= koalaman/shellcheck:v0.11.0
SHFMT_IMAGE      ?= mvdan/shfmt:v3.14.1
SHELL_SOURCES    := wrapper.sh install.sh test.sh codexbox-entrypoint.sh codexbox-agent.sh \
	codexbox/init.d/10-codex-auth-config.sh tests/*.sh
DOCS_SITE        ?= .testing/docs-site
JEKYLL_IMAGE     := ghcr.io/actions/jekyll-build-pages:v1.0.13@sha256:6791ebfd912185ed59bfb5fb102664fa872496b79f87ff8b9cfba292a7345041

# Runs a bash script in CI_IMAGE as the calling user, with the repository
# mounted read-only and a throwaway venv that sees the system aicodebox.
PY_RUN = docker run --rm \
	--user "$$(id -u):$$(id -g)" \
	-e HOME=/tmp \
	-e UV_CACHE_DIR=/tmp/uv-cache \
	-e PYTHONDONTWRITEBYTECODE=1 \
	-v "$(CURDIR):/src:ro" \
	-w /src/codexbox \
	--entrypoint bash \
	$(CI_IMAGE) -euo pipefail -c
PY_SETUP = uv venv -q --system-site-packages /tmp/venv; \
	uv pip install -q --python /tmp/venv/bin/python $(PY_TOOLS); \
	. /tmp/venv/bin/activate;

.PHONY: all build build-full build-all install install-full install-wrapper pull-base pull-full-base test test-full-image test-image-select test-managed-nested clean help version pkg-lock lint lint-shell lint-python test-ci test-unit-ci docs

all: build ## Build the codexbox image on top of the published base

V ?=
export V
version: ## Print or synchronize version metadata without committing: make version V=X.Y.Z
	@set -eu; \
	if [ -z "$$V" ]; then printf '%s\n' "$(TAG)"; exit 0; fi; \
	printf '%s\n' "$$V" | LC_ALL=C grep -qE '^[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.]+)?$$' || { echo "V must be semver X.Y.Z" >&2; exit 1; }; \
	(cd $(PKG) && uv version --no-sync "$$V"); \
	tmp=$$(mktemp); trap 'rm -f "$$tmp"' EXIT; \
	jq --arg v "$$V" '.version=$$v' .agents/.codex-plugin/plugin.json >"$$tmp"; \
	mv "$$tmp" .agents/.codex-plugin/plugin.json; \
	tmp=$$(mktemp); \
	sed -E "s|^readonly CODEXBOX_RELEASE_REF=.*|readonly CODEXBOX_RELEASE_REF=\"v$$V\"|" install.sh >"$$tmp"; \
	chmod 755 "$$tmp"; \
	mv "$$tmp" install.sh

.PHONY: test-entrypoint-identity
test-entrypoint-identity: ## Verify Git identity aliases against the shared container entrypoint
	bash tests/test_entrypoint_identity.sh

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

pull-full-base: ## Pull the published full aicodebox image (SKIP_BASE_PULL=1 for a local image)
	@if [ "$${SKIP_BASE_PULL:-0}" = "1" ]; then \
		echo "[make] SKIP_BASE_PULL=1, using local $(FULL_BASE_IMAGE)"; \
		docker image inspect $(FULL_BASE_IMAGE) >/dev/null 2>&1 \
			|| { echo "full base image not found: $(FULL_BASE_IMAGE)" >&2; exit 1; }; \
	else \
		docker pull $(FULL_BASE_IMAGE); \
	fi

build: pull-base ## Build + tag the image (both :v<VERSION> and :latest)
	docker build \
		--build-arg BASE_IMAGE=$(BASE_IMAGE) \
		--build-arg CODEX_VERSION=$(CODEX_VERSION) \
		-t $(IMAGE_NAME):$(TAG) \
		-t $(IMAGE_NAME):latest .

build-full: pull-full-base ## Build the full variant on the full aicodebox base
	docker build \
		-f Dockerfile.full \
		--build-arg BASE_IMAGE=$(FULL_BASE_IMAGE) \
		--build-arg CODEX_VERSION=$(CODEX_VERSION) \
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

test-managed-nested: ## Verify managed install and nested wrapper propagation without Docker
	bash tests/test_managed_nested.sh

test-full-image: build-full ## Build full and verify Codex plus every advertised tool
	IMAGE=$(IMAGE_NAME):latest-full bash tests/test_full_image.sh

clean: ## Remove built images (keeps the published base)
	docker rmi $(IMAGE_NAME):$(TAG) 2>/dev/null || true
	docker rmi $(IMAGE_NAME):latest 2>/dev/null || true
	docker rmi $(IMAGE_NAME):$(TAG)-full 2>/dev/null || true
	docker rmi $(IMAGE_NAME):latest-full 2>/dev/null || true

help: ## Display this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.PHONY: test-unit
test-unit: ## Run adapter unit tests with locked dependencies
	cd codexbox && uv run --frozen python -m pytest tests/ -v

lint: lint-shell lint-python ## Run every linter in containers: shellcheck, shfmt, ruff, pyright

lint-shell: ## shellcheck and shfmt over the first-party shell scripts
	docker run --rm -v "$(CURDIR):/src:ro" -w /src $(SHELLCHECK_IMAGE) \
		-x -P SCRIPTDIR $(SHELL_SOURCES)
	docker run --rm -v "$(CURDIR):/src:ro" -w /src $(SHFMT_IMAGE) \
		-i 4 -ci -d $(SHELL_SOURCES)

lint-python: ## ruff check, ruff format --check and pyright over the adapter
	$(PY_RUN) '$(PY_SETUP) \
		ruff check --no-cache .; \
		ruff format --no-cache --check .; \
		pyright'

test-unit-ci: ## Run the adapter unit tests in the base image, no uv or sibling checkout needed
	$(PY_RUN) '$(PY_SETUP) python -m pytest -p no:cacheprovider tests'

test-ci: test-unit-ci test-image-select test-managed-nested test-entrypoint-identity ## Credential-free tests that CI runs

docs: ## Build the documentation site into .testing/docs-site
	@mkdir -p "$(DOCS_SITE)"
	docker run --rm \
		--user "$$(id -u):$$(id -g)" \
		-e HOME=/tmp \
		-e GITHUB_WORKSPACE=/work \
		-e GITHUB_REPOSITORY=psyb0t/docker-codexbox \
		-e INPUT_SOURCE=docs \
		-e INPUT_DESTINATION="$(DOCS_SITE)" \
		-e INPUT_VERBOSE=false \
		-v "$(CURDIR):/work" \
		$(JEKYLL_IMAGE)
