---
title: "Troubleshooting"
description: "codexbox error messages from the installer, the wrapper, API mode, Codex auth and MCP, with the cause of each and how to fix it."
nav_order: 9
---

# Troubleshooting

Messages are quoted as the code prints them, so you can search for them.

## Installer

| Message | Cause and fix |
| --- | --- |
| `❌ Docker is not installed. Please install Docker first.` | No `docker` on `PATH`. Install Docker and run the installer again. |
| `❌ CODEXBOX_FULL must be 0 or 1` | `CODEXBOX_FULL` has another value. Use `0`, `1`, or leave it unset. |
| `❌ CODEXBOX_SRC_LOCAL must be true or false` | Only `true`, `false` or empty are accepted. |
| `❌ AICODEBOX_MANAGED_INSTALL must be 0 or 1` | Only `0` and `1` are accepted. |
| `❌ Local image ... was not found. Build it first with make build or make build-full.` | A local install (`make install-wrapper`, or `CODEXBOX_SRC_LOCAL=true`) found no image to use. Build it, or use `make install` or `make install-full`. |
| `❌ Failed to download wrapper.sh` | The wrapper download from GitHub failed. Check the network, or the ref in `CODEXBOX_INSTALL_REF`. |

## Wrapper

| Message | Cause and fix |
| --- | --- |
| `CODEXBOX_FULL must be 0 or 1` | Same rule as the installer, checked on every run. |
| `⏳ Container '...' is busy. Waiting for it to finish...` then `❌ Container is still busy after 3 attempts. Try again later.` | The directory's persistent container is still running, usually another TUI session. Finish that one or run `codexbox stop`. |
| `❌ unsupported AICODEBOX_LAUNCH_CONTEXT_VERSION` | A nested launch from a box with a newer wrapper. Install the same wrapper versions side by side. Never set this variable by hand. |
| A server mode does not start | Container settings need `CODEXBOX_ENV_` in front through the wrapper: `CODEXBOX_ENV_CODEXBOX_API_MODE=1`, not `CODEXBOX_API_MODE=1`. |
| An old image keeps running after `docker pull` | The persistent container keeps its image. Remove it with `docker rm` and run `codexbox` again. |

## Auth and models

| Symptom | Cause and fix |
| --- | --- |
| A 400 "not supported" error for a `*-codex` model | A ChatGPT subscription login rejects the API-only model names. Use a `gpt-5.6-*` model, or log in with an API key. See [Authentication](auth.md#models). |
| `[10-codex-auth-config] existing auth_mode=... (subscription) — not overwriting with API key` | A subscription login exists, so `OPENAI_API_KEY` is ignored. That is on purpose. Run `codexbox logout` first to switch to the key. |
| `[10-codex-auth-config] codex CLI missing; skipping API-key seed` or `jq missing` | The image is damaged or not a codexbox image. Pull it again. |
| The subscription login is gone after a restart | `~/.codex` was not mounted. The wrapper mounts it; a direct `docker run` needs `-v "$HOME/.codex:/home/aicode/.codex"`. |

## API mode

| Message | Cause and fix |
| --- | --- |
| `api: no models configured — set AICODEBOX_AVAILABLE_MODELS (comma-separated) ...` | API mode refuses to start without a model list. Set `CODEXBOX_AVAILABLE_MODELS`. |
| `AICODEBOX_API_MODE_PORT must be a number, got ...` | `CODEXBOX_API_MODE_PORT` is not a number. |
| HTTP 409 from `/run` | Another run is using the same workspace. Wait for it, cancel it with `DELETE /run/{run_id}`, or use another workspace. |
| A warning that `tools_allowlist` is ignored | Codex has no allowlist of built-in tools. Use `noTools`. See [Codex adapter](codex-adapter.md#the-command-line). |

## MCP

| Symptom | Cause and fix |
| --- | --- |
| HTTP 421 | The `Host` header is not allowed. Add the proxy's host name to `CODEXBOX_MCP_MODE_ALLOWED_HOSTS`. |
| HTTP 403 from a browser client | The `Origin` is not allowed. Add it, with its scheme, to `CODEXBOX_MCP_MODE_ALLOWED_ORIGINS`. |
| HTTP 401 with the API token | MCP has its own token, `CODEXBOX_MCP_MODE_TOKEN`, with no fallback to the API one. |

## Debug output

`DEBUG=true` (or `CODEXBOX_ENV_DEBUG=true` through the wrapper) prints the wrapper's decisions, such as the container name and each forwarded variable name, and passes `DEBUG=true` into the container.
