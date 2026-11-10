---
title: "Agent integrations"
description: "Install the codexbox skill and plugins in Claude Code, Codex and OpenClaw, or bridge a stdio MCP client to a running codexbox server."
nav_order: 8
---

# Agent integrations

The [codexbox skill](https://github.com/psyb0t/docker-codexbox/tree/main/.agents/skills/codexbox) teaches an agent to run Codex through the wrapper and to use a codexbox server's HTTP, MCP, Telegram and cron surfaces. It works in any agent that reads `.agents/skills/`, such as [peen](https://github.com/psyb0t/peen), and installs natively in the clients below.

## Claude Code

```bash
claude plugin marketplace add psyb0t/agents
claude plugin install codexbox@psyb0t
```

Claude Code asks for the codexbox URL and, if the server sets them, the API and MCP bearer tokens. It stores the tokens in your OS keychain.

## Codex

```bash
codex plugin marketplace add psyb0t/agents
codex plugin add codexbox@psyb0t
```

Installed from the marketplace, the skill is `$codexbox:codexbox`. Codex also picks it up with no install in any repository that contains `.agents/skills/`, where it is plain `$codexbox`.

## OpenClaw

Every release publishes the skill to ClawHub:

```bash
openclaw skills install @psyb0t/codexbox
```

For MCP clients that only speak local stdio, the [`@psyb0t/codexbox`](https://github.com/psyb0t/docker-codexbox/tree/main/.agents/plugins/codexbox) plugin is a stdio-to-HTTP bridge built on `mcp-remote`:

```bash
openclaw plugins install clawhub:@psyb0t/codexbox
```

Then set the plugin's environment:

| Variable | Required | What it does |
| --- | --- | --- |
| `CODEXBOX_URL` | yes | Base URL of the server, such as `http://localhost:8080`. The bridge appends `CODEXBOX_MCP_PATH`. |
| `CODEXBOX_MCP_PATH` | no | Path of the MCP endpoint under `CODEXBOX_URL`. Default `/mcp/`. Set `/` for a separate MCP server. |
| `CODEXBOX_MCP_MODE_TOKEN` | no | Bearer token, when the server sets `CODEXBOX_MCP_MODE_TOKEN` |

The default `/mcp/` fits a server in [API mode](modes/api.md) with MCP on. A separate MCP server answers at its port root instead, so set `CODEXBOX_URL=http://localhost:8081` and `CODEXBOX_MCP_PATH=/` for it.

The plugin does not ship Codex or start a container. It connects to a codexbox server you run. A client that already supports remote streamable HTTP servers does not need it: point the client at `$CODEXBOX_URL/mcp/` with an `Authorization: Bearer <token>` header.

## What is in the repository

| Path | What it is |
| --- | --- |
| [`.agents/skills/codexbox/`](https://github.com/psyb0t/docker-codexbox/tree/main/.agents/skills/codexbox) | The skill and its setup reference |
| [`.agents/.claude-plugin/plugin.json`](https://github.com/psyb0t/docker-codexbox/blob/main/.agents/.claude-plugin/plugin.json) | Claude Code plugin manifest, with the URL and token prompts |
| [`.agents/.codex-plugin/plugin.json`](https://github.com/psyb0t/docker-codexbox/blob/main/.agents/.codex-plugin/plugin.json) | Codex plugin manifest |
| [`.agents/plugins/codexbox/`](https://github.com/psyb0t/docker-codexbox/tree/main/.agents/plugins/codexbox) | The OpenClaw MCP bridge |
| [`server.json`](https://github.com/psyb0t/docker-codexbox/blob/main/server.json) | The MCP Registry listing for the image |
