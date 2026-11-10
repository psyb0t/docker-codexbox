# Docker images

Prefix: IMG. `Dockerfile` builds `psyb0t/codexbox:latest`, `Dockerfile.full` builds `:latest-full`.

- **IMG1:** The two Dockerfiles stay identical except for the `BASE_IMAGE` default and `CODEXBOX_IMAGE_VARIANT`. A change to one goes into both. Generic toolchains belong in aicodebox's full image, not here.
- **IMG2:** Both images follow the published `psyb0t/aicodebox:latest` and `:latest-full`. Do not pin the base by digest in the Dockerfiles; `BASE_IMAGE` and `FULL_BASE_IMAGE` in the `Makefile` are the override for a local fork.
- **IMG3:** Codex is installed with `npm install -g --prefix /home/aicode/.local @openai/codex@${CODEX_VERSION}`, with `prefix=/home/aicode/.local` in `/home/aicode/.npmrc` and a root-owned `/usr/local/bin/codex` symlink for the init scripts (sudo's `secure_path` lacks `~/.local/bin`). Keep all three; the `Dockerfile` comment explains why. `CODEX_VERSION` changes in the `Makefile` and both Dockerfiles together.
- **IMG4:** The Python package is installed with `uv pip install --system --break-system-packages --no-deps`, because its only dependency, `aicodebox`, is already in the base. Do not add runtime dependencies to `codexbox/pyproject.toml`.
- **IMG5:** `CODEX_HOME=/home/aicode/.codex` is created and owned by `aicode` in the image, because Codex fails at startup when `CODEX_HOME` points at a missing directory. The wrapper mounts the host data directory there.
- **IMG6:** `codexbox-entrypoint.sh` only copies `CODEXBOX_<X>` to `AICODEBOX_<X>` and execs the base entrypoint. A new shared setting needs a suffix in `_CODEXBOX_ALIASES` and a row in `docs/configuration.md`. `ADAPTER` and `AGENT_BINARY` are never aliased.
- **IMG7:** `codexbox-agent.sh` and `wrapper.sh` keep the same list of verbatim Codex subcommands. A subcommand missing from the wrapper list falls through to the persistent container and can block later commands for that workspace.
- **IMG8:** Init scripts in `codexbox/init.d/` run once per container as `aicode` through `sudo -E -u aicode -H`, so they must be safe to repeat and must not depend on `PATH` beyond the base's fixed one. The auth script never overwrites an `auth.json` whose `auth_mode` is not `apikey`.
- **IMG9:** `docs/`, `README.md`, the wrapper, the installer and local state stay out of the build context through `.dockerignore`. The `LABEL io.modelcontextprotocol.server.name` must match `name` in `server.json`.
