---
title: "MCP mode"
description: "codexbox MCP mode: run_prompt and workspace file tools over streamable HTTP, where it is served, its bearer token and reverse-proxy allowlists."
nav_order: 4
parent: "Modes"
---

# MCP mode

`CODEXBOX_MCP_MODE=1` serves [MCP](https://modelcontextprotocol.io/) (Model Context Protocol) over streamable HTTP, with `run_prompt`, `list_files`, `read_file`, `write_file` and `delete_file` as tools, so other agents can use Codex as a tool.

MCP is the one mode that is not a foreground mode. It runs next to whatever else the container does.

| Foreground | Where MCP is served |
| --- | --- |
| API mode (`CODEXBOX_API_MODE=1`) | `/mcp/` on the API port, with no extra process |
| Telegram, cron, or a plain shell | A separate uvicorn server on `CODEXBOX_MCP_MODE_PORT` (default `8081`), at the port root `/` |

In API mode, the spelling `/mcp` without the slash reaches the same handler without a redirect.

## Setup

Next to cron, scheduled jobs run on their own and the same box answers as a tool while they run:

```yaml
# docker-compose.yml
services:
  codexbox:
    image: psyb0t/codexbox:latest
    ports:
      - "127.0.0.1:8081:8081"
    environment:
      - CODEXBOX_CRON_MODE=1
      - CODEXBOX_CRON_MODE_FILE=/home/aicode/.aicodebox/cron.yaml
      - CODEXBOX_MCP_MODE=1
      - CODEXBOX_MCP_MODE_TOKEN=some-long-random-string
      - OPENAI_API_KEY=sk-...
    volumes:
      - ~/.aicodebox:/home/aicode/.aicodebox
      - ~/workspaces:/workspace
```

Cron is the foreground process, so the container lives as long as the scheduler, and MCP runs in the background. Swap the cron settings for `CODEXBOX_TELEGRAM_MODE=1` and the same holds for the bot.

In API mode, publish no second port. MCP is already at `/mcp/` on the API port. See [API mode](api.md).

Through the [wrapper](../wrapper.md), API and MCP together:

```bash
CODEXBOX_ENV_CODEXBOX_API_MODE=1 \
CODEXBOX_ENV_CODEXBOX_MCP_MODE=1 \
CODEXBOX_ENV_CODEXBOX_AVAILABLE_MODELS=your-model-id \
CODEXBOX_ENV_CODEXBOX_API_MODE_TOKEN=your-api-token \
CODEXBOX_ENV_CODEXBOX_MCP_MODE_TOKEN=your-mcp-token \
codexbox
```

## Tools

| Tool | What it does |
| --- | --- |
| `run_prompt` | Runs a prompt through Codex and returns the answer |
| `list_files` | Lists a directory under the workspace root |
| `read_file` | Reads a file |
| `write_file` | Writes a file |
| `delete_file` | Deletes a file, with no undo |

The file tools resolve their path under the workspace root and refuse anything that climbs out of it. That does not sandbox `run_prompt`. Codex runs with the container's own permissions.

## Auth

`CODEXBOX_MCP_MODE_TOKEN=<token>` is checked as a bearer in the `Authorization: Bearer ...` header, or as `?apiToken=...` for clients that cannot set headers.

- **Empty means no auth at all**, not no access. Anyone who can reach the port gets `run_prompt`, and `run_prompt` runs code. Leave it empty only when the port is bound to loopback or an internal network.
- **There is no fallback to the API token.** MCP has its own bearer; setting `CODEXBOX_API_MODE_TOKEN` does nothing for it.

## Reverse proxies and public hosts

MCP keeps DNS rebinding protection on. Loopback hosts and origins work by default. If a reverse proxy, tunnel or public DNS name forwards MCP, allow the exact values it sends. A browser MCP client also needs its exact Origin, including the scheme.

```dotenv
CODEXBOX_MCP_MODE_ALLOWED_HOSTS=localhost,localhost:*,127.0.0.1,127.0.0.1:*,[::1],[::1]:*,mcp.example.net
CODEXBOX_MCP_MODE_ALLOWED_ORIGINS=http://localhost:*,http://127.0.0.1:*,http://[::1]:*,https://mcp.example.net
```

An unexpected Host gets `421`, and an unexpected browser Origin gets `403`. Keep the port bound to loopback when a local proxy terminates TLS. Do not turn the protection off or allow broad wildcards for an endpoint on the internet.

## MCP mode settings

| Variable | Default | What it does |
| --- | --- | --- |
| `CODEXBOX_MCP_MODE` | `0` | Serve MCP, at `/mcp/` in API mode or as a separate server otherwise |
| `CODEXBOX_MCP_MODE_PORT` | `8081` | Port of the separate server. Ignored in API mode. |
| `CODEXBOX_MCP_MODE_TOKEN` | empty | Bearer token for MCP. Empty means no auth. No fallback to the API token. |
| `CODEXBOX_MCP_MODE_ALLOWED_HOSTS` | loopback hosts | Comma-separated `Host` allowlist. Add each proxy host name. |
| `CODEXBOX_MCP_MODE_ALLOWED_ORIGINS` | loopback HTTP origins | Comma-separated browser `Origin` allowlist. Add each proxy origin. |

Every `CODEXBOX_*` name is an alias for the `AICODEBOX_*` name the base reads. If both are set, `AICODEBOX_*` wins.

## Connecting a client

```bash
# separate server
claude mcp add --transport http codexbox http://host:8081/ \
  --header "Authorization: Bearer some-long-random-string"

# API mode
claude mcp add --transport http codexbox http://host:8080/mcp/ \
  --header "Authorization: Bearer some-long-random-string"
```

For clients that only speak stdio, the [`@psyb0t/codexbox` plugin](../agents.md#openclaw) bridges to the HTTP endpoint.

## Not Codex's own MCP support

This is the aicodebox base's MCP server: file operations and prompt runs, over MCP. It is separate from Codex's own MCP support, where Codex acts as an MCP client (`[mcp_servers.*]` in `config.toml`) or as a stdio MCP server (`codex mcp-server`). codexbox wires up neither.
