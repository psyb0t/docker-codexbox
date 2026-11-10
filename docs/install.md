---
title: "Install"
description: "Install the codexbox wrapper with the one-line installer or from a checkout, pick the minimal or full image, and know what each image licenses."
nav_order: 2
---

# Install

Docker installed and running is the only prerequisite.

## One-line installer

[`install.sh`](https://github.com/psyb0t/docker-codexbox/blob/main/install.sh) pulls the selected image, creates `~/.codex` and `~/.ssh/codexbox`, generates an SSH key there if none exists, downloads the wrapper and installs it as `codexbox` in `/usr/local/bin` with `sudo`.

```bash
# minimal image, the default
curl -fsSL https://raw.githubusercontent.com/psyb0t/docker-codexbox/main/install.sh | bash

# full image, every development tool installed
export CODEXBOX_FULL=1 && curl -fsSL https://raw.githubusercontent.com/psyb0t/docker-codexbox/main/install.sh | bash

# custom command name
curl -fsSL https://raw.githubusercontent.com/psyb0t/docker-codexbox/main/install.sh | bash -s -- codex
```

`CODEXBOX_FULL` has to reach `bash`, not only `curl`, hence the `export ... &&` form. The installer writes the chosen image into the installed wrapper, so you do not need to export it again.

Piping a remote script into `bash` runs code you have not read. To read it first:

```bash
curl -fsSL -o install.sh https://raw.githubusercontent.com/psyb0t/docker-codexbox/main/install.sh
less install.sh
bash install.sh
```

After install, `codexbox --version` prints the Codex CLI version. The installer ends by printing the public key it generated, `~/.ssh/codexbox/id_ed25519.pub`. Add it to GitHub if you want Git over SSH inside the container.

### Installer settings

| Variable | Default | What it does |
| --- | --- | --- |
| `CODEXBOX_FULL` | `0` | `0` installs the minimal image, `1` the full image. Any other value fails. |
| `CODEXBOX_INSTALL_DIR` | `/usr/local/bin` | Directory the wrapper is installed into |
| `CODEXBOX_BIN_NAME` | `codexbox` | Command name. The first argument to the script wins over it. |
| `CODEXBOX_INSTALL_REF` | the release tag | Git ref the wrapper is downloaded from. Each release pins its own tag in `install.sh`. |
| `CODEXBOX_SRC_LOCAL` | `false` | `true` uses a local image instead of pulling, and fails if that image is missing |
| `AICODEBOX_MANAGED_INSTALL` | `0` | `1` never prompts to replace an existing SSH key. `CODEXBOX_MANAGED_INSTALL` is read when the shared name is unset. |

When the installer runs from a directory that holds `wrapper.sh`, it installs that local file instead of downloading one.

## From a local checkout

These targets build the image and install the checkout's own `wrapper.sh`, without pulling a published codexbox image:

```bash
make install       # build the minimal image, then install
make install-full  # build the full image, then install

# install the wrapper only, against an image that already exists locally
make install-wrapper
CODEXBOX_FULL=1 make install-wrapper
```

All three set `CODEXBOX_SRC_LOCAL=true`. `make install-wrapper` fails if the selected image is absent instead of falling back to `docker pull`. The builds pull the published aicodebox base first; [Development](development.md) has the details.

## Upgrading

```bash
docker pull psyb0t/codexbox:latest        # or :latest-full
```

Pulling a new image does not update the installed wrapper. Run the installer again for a new wrapper. The wrapper's persistent per-directory container keeps the image it was created with until you remove it with `docker rm`.

## Image variants

- `psyb0t/codexbox:latest` is the minimal image: Codex, Node.js, Python, `uv`, Docker, Git, `jq` and `curl`. It builds from [`Dockerfile`](https://github.com/psyb0t/docker-codexbox/blob/main/Dockerfile) on `psyb0t/aicodebox:v0.18.4`.
- `psyb0t/codexbox:latest-full` builds from [`Dockerfile.full`](https://github.com/psyb0t/docker-codexbox/blob/main/Dockerfile.full) on `psyb0t/aicodebox:v0.18.4-full` and adds the same Codex layer.

Release tags add `:vX.Y.Z` and `:vX.Y.Z-full`. Every push to `main` also publishes per-commit SHA tags.

The full image adds:

- Go 1.27.2 with gopls, Delve, golangci-lint, staticcheck, gofumpt and test and code-generation helpers
- Python 3.14.8 with pytest, Black, Flake8, mypy, Pyright, Poetry, Pipenv and common HTTP and parsing libraries
- JavaScript and TypeScript linting, formatting, process, framework, API-test, static-server, Lighthouse and Storybook CLIs
- GitHub CLI, Terraform, kubectl and Helm
- Build tools, CMake, ClangFormat, Valgrind, GDB, strace and ltrace
- PostgreSQL, MySQL, SQLite and Redis clients
- Vim, Nano, tmux, htop, archive tools, network diagnostics, ripgrep, fd, bat, eza, shellcheck and shfmt

aicodebox owns those toolchains, their pins and their supply-chain checks. codexbox adds only Codex and its startup layer. [`tests/test_full_image.sh`](https://github.com/psyb0t/docker-codexbox/blob/main/tests/test_full_image.sh) checks every tool in the list.

The wrapper picks the variant in this order: `CODEXBOX_IMAGE` if set, then a runtime `CODEXBOX_FULL=0` or `1`, then the image the installer wrote into the wrapper.

### Licensing

The minimal image adds Apache-2.0 Codex on top of the aicodebox base. The full image also bundles HashiCorp Terraform, which is BUSL-1.1: source-available with a non-compete clause, not OSI-approved open source. If that matters to you, use the minimal image or read the [BUSL-1.1 terms](https://github.com/hashicorp/terraform/blob/main/LICENSE) first. [THIRD_PARTY.md](https://github.com/psyb0t/docker-codexbox/blob/main/THIRD_PARTY.md) lists every bundled component and its license.
