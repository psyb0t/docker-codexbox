---
title: "Development"
description: "Build, lint and test codexbox from a checkout with Make and Docker, what CI runs on each push, how releases are cut and how to build these docs."
nav_order: 10
---

# Development

Docker, Make and Bash are enough for everything except the authenticated end-to-end suite. `make help` lists every target.

## Layout

| Path | What it is |
| --- | --- |
| [`Dockerfile`](https://github.com/psyb0t/docker-codexbox/blob/main/Dockerfile), [`Dockerfile.full`](https://github.com/psyb0t/docker-codexbox/blob/main/Dockerfile.full) | The minimal and full images, on `psyb0t/aicodebox:v0.18.4` and `:latest-full` |
| [`codexbox/`](https://github.com/psyb0t/docker-codexbox/tree/main/codexbox) | The Python package with `CodexAdapter`, its unit tests, and `init.d/` |
| [`codexbox-entrypoint.sh`](https://github.com/psyb0t/docker-codexbox/blob/main/codexbox-entrypoint.sh) | Copies `CODEXBOX_*` settings to `AICODEBOX_*`, then runs the base entrypoint |
| [`codexbox-agent.sh`](https://github.com/psyb0t/docker-codexbox/blob/main/codexbox-agent.sh) | What the shell path runs: adds the bypass flag and session continuation around `codex` |
| [`wrapper.sh`](https://github.com/psyb0t/docker-codexbox/blob/main/wrapper.sh), [`install.sh`](https://github.com/psyb0t/docker-codexbox/blob/main/install.sh) | The host command and its installer |
| [`test.sh`](https://github.com/psyb0t/docker-codexbox/blob/main/test.sh), [`tests/`](https://github.com/psyb0t/docker-codexbox/tree/main/tests) | The end-to-end runner and the shell test scripts |
| [`.agents/`](https://github.com/psyb0t/docker-codexbox/tree/main/.agents) | The agent skill, plugin manifests and MCP bridge |
| `docs/` | This site |

## Building

```bash
make build        # psyb0t/codexbox:latest and :v<version>, on psyb0t/aicodebox:v0.18.4
make build-full   # psyb0t/codexbox:latest-full and :v<version>-full, on :latest-full
make build-all    # both
make clean        # remove the images these targets built
```

Both builds pull the published aicodebox base first. To build on a base you built yourself, tag it as the base name and skip the pull:

```bash
SKIP_BASE_PULL=1 make build
SKIP_BASE_PULL=1 BASE_IMAGE=aicodebox-base:local make build
```

`CODEX_VERSION` (default in the [Makefile](https://github.com/psyb0t/docker-codexbox/blob/main/Makefile) and both Dockerfiles) is the npm version of `@openai/codex` the images install. Change all three together.

## Linting

```bash
make lint          # all of the below
make lint-shell    # shellcheck and shfmt (-i 4 -ci) over the first-party shell scripts
make lint-python   # ruff check, ruff format --check and pyright over codexbox/
```

Every linter runs in a container. The shell linters use pinned `koalaman/shellcheck` and `mvdan/shfmt` images. The Python checks run in the aicodebox base image, which already has the `aicodebox` package the adapter imports, with ruff, pyright and pytest installed into a throwaway virtual environment at the versions pinned in `codexbox/pyproject.toml`. The checkout is mounted read-only.

## Tests

| Target | Needs | What it checks |
| --- | --- | --- |
| `make test-unit-ci` | Docker | The adapter unit tests in `codexbox/tests/`, in the base image |
| `make test-unit` | `uv` and `../docker-aicodebox` checked out next to this repository | The same unit tests, from the locked development environment |
| `make test-image-select` | Bash | The installer and wrapper pick, pull and bake the right image for `CODEXBOX_FULL` |
| `make test-managed-nested` | Bash, Make | Managed installs, the release-pinned wrapper download and the nested-launch context |
| `make test-entrypoint-identity` | Docker | `CODEXBOX_GIT_*` and `AICODEBOX_GIT_*` through the real base entrypoint |
| `make test-e2e-runner` | Bash | `test.sh` loads only end-to-end test files, and `.env.test.example` names only tests that exist |
| `make test-agent-defaults` | Bash | `CODEXBOX_MODEL` and `CODEXBOX_REASONING_EFFORT` reach Codex on the shell path, and the caller's flags still win |
| `make test-mcp-bridge` | Docker | The URL the OpenClaw MCP bridge connects to, for API mode and a separate MCP server |
| `make test-scratch-paths` | Git | No tracked file points at the local planning directory |
| `make test-ci` | Docker | Every target above except `test-unit`. This is what CI runs. |
| `make test-full-image` | Docker | Builds the full image and checks its variant marker, Codex, the Go and Python versions and every advertised tool |
| `make test` | Docker, `.env.test` | The end-to-end suite against a real OpenAI or Codex endpoint |

The image-select, managed-install, e2e runner and agent defaults tests replace `docker`, `sudo`, `curl` or `codex` with fakes, so they need neither a daemon nor the network.

For the end-to-end suite, copy the example and fill it in:

```bash
cp .env.test.example .env.test
$EDITOR .env.test   # OPENAI_API_KEY, or a CODEXBOX_DATA_DIR with a subscription login
make test
```

`test.sh` builds `codexbox:local` on the published base, runs the tests and removes the image. `KEEP_IMAGE=1` keeps it, `SKIP_BUILD=1` reuses it and `SKIP_BASE_PULL=1` skips the base pull. `./test.sh test_smoke_codex` runs one test. It sources only the `tests/test_*.sh` files that register tests in `ALL_TESTS`; the other scripts there are standalone and run through their own `make` targets. Set `CODEXBOX_MODEL` in `.env.test` to a small model, because an empty value means the account default.

## CI

[`.github/workflows/pipeline.yml`](https://github.com/psyb0t/docker-codexbox/blob/main/.github/workflows/pipeline.yml) runs on every push:

- **Any branch:** `make lint` and `make test-ci` on a GitHub runner. They need no credentials and no `.env.test`.
- **`main`:** after those pass, both variants are built for `linux/amd64` and `linux/arm64`, scanned with Grype (findings go to the Security tab without failing the run), and pushed as `:latest`, `:latest-full` and per-commit SHA tags. The version and license badges are refreshed.
- **A `v*` tag:** waits for the tagged commit's `main` run to succeed, promotes those exact images to `:vX.Y.Z` and `:vX.Y.Z-full` without rebuilding, creates the GitHub release from the tag's notes, refreshes the badges, then publishes the skill and the MCP bridge to ClawHub and `server.json` to the MCP Registry.

## Releasing

```bash
make version            # print the current tag, v<version>
make version V=0.7.7    # set it everywhere, without committing or tagging
```

`make version V=...` updates `codexbox/pyproject.toml` and `uv.lock`, the Codex plugin manifest and the wrapper ref in `install.sh`. Add a `CHANGELOG.md` entry, commit, then push an annotated `v*` tag after `main` is green.

## Documentation

`docs/` is this site, built by GitHub Pages from `main` with Jekyll and the just-the-docs theme.

```bash
make docs   # build into .testing/docs-site with GitHub's own Pages image
```

Every page needs front matter with a unique `title` and a `description` of 50 to 170 characters. Link between pages with the relative `.md` path. Link a file outside `docs/` with its full `https://github.com/psyb0t/docker-codexbox/blob/main/...` URL, because a relative `../` link breaks on the site.
