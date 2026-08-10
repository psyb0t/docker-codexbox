# codexbox — OpenAI Codex CLI on the aicodebox base.
#
# Build (base lives in the sibling repo ../docker-aicodebox):
#   docker build -t aicodebox-base:local ../docker-aicodebox/
#   docker build --build-arg BASE_IMAGE=aicodebox-base:local -t codexbox:local .
#
# NOTE on hardening: the base sets `aicode` (UID 1000) as its runtime user via
# `setpriv` inside `aicodebox-entrypoint`. This Dockerfile switches to root
# only for the install steps below; runtime drops back to aicode automatically.
ARG BASE_IMAGE=psyb0t/aicodebox:v0.14.0
FROM ${BASE_IMAGE}

# MCP Registry ownership label — identifies this image as the OCI package for
# the io.github.psyb0t/codexbox server listing.
LABEL io.modelcontextprotocol.server.name="io.github.psyb0t/codexbox"

USER root

# codex CLI — pinned npm global install, into a prefix `aicode` owns.
#
# `codex update` (and the TUI's "Update available!" prompt) shells out to
# `npm install -g @openai/codex`, which renames paths in BOTH the global lib
# dir and the global bin dir. npm's default prefix is /usr, so that means
# /usr/lib/node_modules AND /usr/bin — and the runtime user must never own
# /usr/bin. Installing under ~/.local instead lets the self-update succeed as
# aicode with no system dir changing hands.
#
# ~/.local specifically, because the base entrypoint hardcodes
# `PATH=/home/aicode/.local/bin:/usr/local/bin:/usr/bin:/bin` and forwards only
# an allowlist of env vars to the agent — a prefix anywhere else needs a PATH
# entry that gets dropped before codex ever runs. Nothing bind-mounts over it
# either (the wrapper mounts .ssh, .codex, and the workspace).
#
# The .npmrc is what makes the UPDATE resolve the same prefix: NPM_CONFIG_PREFIX
# is not on the entrypoint's forward list, and codex refuses to update when
# `npm root -g` disagrees with its own package root. Per-user npmrc is read
# regardless of environment, so it survives the privilege drop.
#
# Tradeoff: a user-writable executable dir on PATH, so the agent can rewrite the
# codex binary it later runs. Accepted — aicode already has passwordless sudo
# here, so it grants no new privilege, and the container is disposable.
#
# An update lives only as long as the container — most subcommands run in
# `docker run --rm` throwaways — so CODEX_VERSION is still what every fresh
# container starts from. Bump it to make an upgrade stick.
#
# The /usr/local/bin symlink is for the init.d scripts: the base entrypoint runs
# those under `sudo -E -u aicode -H`, and sudo's secure_path does NOT include
# ~/.local/bin, so `command -v codex` there would come up empty and silently
# skip the API-key seeding. The link is root-owned and points by path, so an
# update that replaces the target keeps resolving.
ARG CODEX_VERSION=0.144.6
ENV PATH="/home/aicode/.local/bin:${PATH}"
RUN npm install -g --prefix /home/aicode/.local --no-audit --no-fund \
        @openai/codex@${CODEX_VERSION} \
    && printf 'prefix=/home/aicode/.local\n' > /home/aicode/.npmrc \
    && chown -R aicode:aicode /home/aicode/.local /home/aicode/.npmrc \
    && ln -s /home/aicode/.local/bin/codex /usr/local/bin/codex

# codexbox python package (the CodexAdapter). aicodebox is already in the base
# image so we install with --no-deps to avoid redundant resolution.
COPY codexbox /opt/codexbox
RUN uv pip install --system --break-system-packages --no-deps /opt/codexbox

# First-run init scripts — base runs each once, marks completion at
# ~/.aicodebox/.init-done, then skips on subsequent boots.
COPY codexbox/init.d/ /aicodebox-init.d/
RUN chmod +x /aicodebox-init.d/*.sh

# Adapter selection — the modes resolve this at runtime.
#
# CODEX_HOME points codex at the bind-mounted ~/.codex dir so auth.json
# (API key OR ChatGPT subscription OAuth tokens) + config.toml + session
# state live ON the mount and PERSIST across container recreates —
# otherwise a `codex login` done inside one container is lost the moment
# the container is recreated. Bind-mount ~/.codex from the host to keep a
# subscription login alive. codex ERRORS at startup if CODEX_HOME is set
# but the directory doesn't already exist, so it's pre-created + chowned
# below.
ENV AICODEBOX_ADAPTER=codexbox.adapter:CodexAdapter \
    AICODEBOX_AGENT_BINARY=codexbox-agent \
    CODEXBOX_IMAGE_VARIANT=minimal \
    CODEX_HOME=/home/aicode/.codex

RUN mkdir -p /home/aicode/.codex && chown -R aicode:aicode /home/aicode/.codex

# codexbox agent launcher (see codexbox-agent.sh header for the full rationale).
COPY codexbox-agent.sh /usr/local/bin/codexbox-agent
RUN chmod +x /usr/local/bin/codexbox-agent

# codexbox-branded entrypoint: aliases CODEXBOX_* env vars to their
# AICODEBOX_* equivalents, then exec's the base entrypoint.
COPY codexbox-entrypoint.sh /usr/local/bin/codexbox-entrypoint
RUN chmod +x /usr/local/bin/codexbox-entrypoint

ENTRYPOINT ["/usr/local/bin/codexbox-entrypoint"]
