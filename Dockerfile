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

USER root

# codex CLI — pinned npm global install.
ARG CODEX_VERSION=0.144.6
RUN npm install -g --no-audit --no-fund @openai/codex@${CODEX_VERSION}

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
