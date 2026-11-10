---
title: "Authentication"
description: "Log Codex in with an OpenAI API key or a ChatGPT subscription, keep the login across containers, and pick models and reasoning effort."
nav_order: 4
---

# Authentication

Codex supports two ways to log in. Pick one. Both store their credentials in `$CODEX_HOME/auth.json`, which is `/home/aicode/.codex/auth.json` in the image.

This page is about how Codex reaches OpenAI. The bearer tokens that protect the HTTP API and MCP endpoints are separate and live on the [API mode](modes/api.md) and [MCP mode](modes/mcp.md) pages.

## API key

Set `OPENAI_API_KEY`. Set `OPENAI_BASE_URL` as well to use an OpenAI-compatible endpoint instead of the OpenAI API.

```bash
docker run --rm \
  -e OPENAI_API_KEY=sk-... \
  -v "$PWD/.codex:/home/aicode/.codex" \
  psyb0t/codexbox:latest \
  exec "say HELLO"
```

Codex does not use a bare `OPENAI_API_KEY` for `codex exec`; it needs a login that writes `auth.json`. So the image's [init script](https://github.com/psyb0t/docker-codexbox/blob/main/codexbox/init.d/10-codex-auth-config.sh) runs `codex login --with-api-key` with the key on stdin the first time each container starts, then sets `auth.json` to mode `600`. It only does this when `auth.json` is absent, unreadable, or already in `apikey` mode, so it never replaces a subscription login. It is safe to leave the key set.

## ChatGPT subscription

With no API key, Codex bills your ChatGPT Plus, Pro or Team plan. Log in once with the device flow, with `~/.codex` mounted so the login outlives the container:

```bash
codexbox login --device-auth
```

or without the wrapper:

```bash
docker run -it \
  -v "$HOME/.codex:/home/aicode/.codex" \
  psyb0t/codexbox:latest \
  login --device-auth
```

Codex prints a URL and a short code. Open the URL in any browser, enter the code and approve. Codex writes OAuth tokens to `auth.json`. Every later run with the same `~/.codex` mounted uses that login:

```bash
docker run --rm \
  -v "$HOME/.codex:/home/aicode/.codex" \
  psyb0t/codexbox:latest \
  exec "say HELLO"
```

Without the mount, the login lives in the container's filesystem and is gone when the container is removed. The wrapper always mounts `~/.codex` (or `CODEXBOX_DATA_DIR`).

When a subscription login exists, a set `OPENAI_API_KEY` does not overwrite it. The init script logs `existing auth_mode=... (subscription)` and leaves `auth.json` alone. `codexbox login status` shows the active mode, and `codexbox logout` clears it.

## Models

Codex has no fixed default model name. The available models come from the server and depend on how you logged in:

- **ChatGPT subscription:** the GPT-5.6 family: `gpt-5.6-luna` (fastest and cheapest), `gpt-5.6-terra` (balanced) and `gpt-5.6-sol` (the flagship and the account default). A subscription account rejects the `*-codex` and `*-codex-mini` names with a 400 "not supported" error.
- **API key:** the API catalog, such as `gpt-5.1-codex`, `gpt-5-codex` and `gpt-5.1-codex-mini`.

Pass a model with `-m` or `--model` on the command line, or as the `model` field of `/run`, `/openai/v1/chat/completions`, a Telegram `/model` choice or a cron job. API mode requires `CODEXBOX_AVAILABLE_MODELS`, the list it serves at `/openai/v1/models`; see [Configuration](configuration.md#workspace-and-runtime).

## Reasoning effort

Reasoning effort maps to Codex's `model_reasoning_effort` setting, passed as `-c model_reasoning_effort=<level>`. The levels are `none`, `minimal`, `low`, `medium`, `high`, `xhigh` and `max`. The adapter rejects any other value. It is the `thinking` field on the API and in cron jobs, and the `/effort` command in Telegram.
