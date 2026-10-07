# MCP Mode

`CODEXBOX_MCP_MODE=1`. Exposes the [MCP](https://modelcontextprotocol.io/) (Model Context Protocol) surface over streamable HTTP — `run_prompt`, `list_files`, `read_file`, `write_file`, `delete_file` as tools — so other agents can drive codex as a tool.

MCP is the one mode that is not a foreground mode. It coexists with whatever else the container is doing.

| Foreground | MCP placement |
|---|---|
| API mode (`CODEXBOX_API_MODE=1`) | mounted at `/mcp/` on the API port — no extra process |
| Telegram / Cron / passthrough | sidecar uvicorn on `CODEXBOX_MCP_MODE_PORT` (default `8081`), served at the port root `/` |

The slashless `/mcp` spelling reaches the same API-mounted handler without a redirect.

## Setup

Standalone alongside cron — scheduled jobs running on their own, and the same box reachable as a tool while they run:

```yaml
# docker-compose.yml
services:
  codexbox:
    image: psyb0t/codexbox:latest
    ports:
      - "8081:8081"
    environment:
      - CODEXBOX_CRON_MODE=1
      - CODEXBOX_CRON_MODE_FILE=/home/aicode/.aicodebox/cron.yaml
      - CODEXBOX_MCP_MODE=1
      - CODEXBOX_MCP_MODE_TOKEN=some-long-random-string
    volumes:
      - ~/.aicodebox:/home/aicode/.aicodebox
      - ~/workspaces:/workspace
```

Cron is the foreground process, so the container's lifetime follows the scheduler. MCP rides along in the background. Swap the cron flags for `CODEXBOX_TELEGRAM_MODE=1` and the same holds for the bot.

In API mode you publish no second port — MCP is already at `/mcp/` on the API port. See [api.md](api.md).

## Reverse proxies and public hosts

MCP keeps DNS rebinding protection enabled. Loopback hosts and origins work by default. If a reverse proxy, tunnel, or public DNS name forwards MCP, allow the exact values it sends. A browser MCP client also needs its exact Origin, including the scheme.

```dotenv
CODEXBOX_MCP_MODE_ALLOWED_HOSTS=localhost,localhost:*,127.0.0.1,127.0.0.1:*,[::1],[::1]:*,mcp.example.net
CODEXBOX_MCP_MODE_ALLOWED_ORIGINS=http://localhost:*,http://127.0.0.1:*,http://[::1]:*,https://mcp.example.net
```

An unexpected Host returns `421`, and an unexpected browser Origin returns `403`. Keep the port bound to loopback when a local proxy terminates TLS. Do not disable the protection or allow broad wildcards for an internet-facing endpoint.

## Tools

| Tool | What it does |
|---|---|
| `run_prompt` | Runs a prompt through codex and returns the response |
| `list_files` | Lists a directory under the workspace root |
| `read_file` | Reads a file |
| `write_file` | Writes a file |
| `delete_file` | Removes a file |

The file tools resolve their path under the workspace root and reject anything that climbs out of it. This does not sandbox `run_prompt` — codex runs with the container's own permissions.

## Auth

`CODEXBOX_MCP_MODE_TOKEN=<token>` — bearer in the `Authorization: Bearer …` header, or `?apiToken=…` for clients that can't set headers.

Two things that will bite you if you assume otherwise:

- **Empty means no auth at all.** Not "no access" — open. Anyone who can reach the port gets `run_prompt`, and `run_prompt` runs code. Leave it unset only when the port is bound to loopback or an internal network.
- **No fallback to `API_MODE_TOKEN`.** MCP has its own bearer; setting the API token does nothing for it.

## MCP mode environment variables

| Var | Default | What it does |
|-----|---------|---------------|
| `CODEXBOX_MCP_MODE` | `0` | Expose MCP — mounted at `/mcp/` in API mode, or as a sidecar elsewhere |
| `CODEXBOX_MCP_MODE_PORT` | `8081` | Port the sidecar MCP server binds to (ignored when mounted inside API) |
| `CODEXBOX_MCP_MODE_TOKEN` | empty | Bearer token for MCP. Empty = no auth. **No fallback to `API_MODE_TOKEN`** |
| `CODEXBOX_MCP_MODE_ALLOWED_HOSTS` | loopback hosts | Comma-separated MCP `Host` allowlist. Add each proxy host name |
| `CODEXBOX_MCP_MODE_ALLOWED_ORIGINS` | loopback HTTP origins | Comma-separated MCP browser Origin allowlist. Add each proxy origin |

> Every `CODEXBOX_*` variable is an alias for the `AICODEBOX_*` equivalent read by the base image. If both are set, `AICODEBOX_*` wins.

## Connecting a client

```bash
claude mcp add --transport http codexbox http://host:8081/ \
  --header "Authorization: Bearer some-long-random-string"
```

## Not to be confused with codex's own MCP support

This is the [aicodebox](https://github.com/psyb0t/docker-aicodebox) base's own MCP surface — file ops plus prompt running, over MCP. It is separate from codex's own MCP support: codex can act as an MCP *client* (`[mcp_servers.*]` in `config.toml`) and as an MCP *server* (`codex mcp-server`, stdio). Neither of those is wired up by codexbox.
