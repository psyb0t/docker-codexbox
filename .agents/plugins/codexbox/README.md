# @psyb0t/codexbox

An OpenClaw/MCP plugin that connects your agent to a self-hosted
[codexbox](https://github.com/psyb0t/docker-codexbox) instance (the OpenAI
Codex CLI running inside an aicodebox container) over the
[Model Context Protocol](https://modelcontextprotocol.io).

codexbox, when started with `CODEXBOX_MCP_MODE=1`, serves a Streamable-HTTP
MCP endpoint at `/mcp`. This package is a thin stdio↔HTTP bridge (via
[`mcp-remote`](https://www.npmjs.com/package/mcp-remote)) for MCP clients that
speak local stdio servers — it forwards everything to your running codexbox
instance and authenticates with your bearer token when the server requires one.

> codexbox is **self-hosted**. This plugin does not ship Codex or the
> container image — it connects to a codexbox server that **you** run. See
> the [codexbox repo](https://github.com/psyb0t/docker-codexbox) to stand one up.

## Tools

The codexbox MCP tools become available to your agent: `run_prompt` (invoke
Codex on the box and get its textual response), `list_files`, `read_file`,
`write_file`, `delete_file` (workspace file operations).

## Configuration

| Env var | Required | Description |
|---|---|---|
| `CODEXBOX_URL` | yes | Base URL of your running codexbox server, e.g. `http://localhost:8080`. The bridge appends `/mcp`. |
| `CODEXBOX_MCP_MODE_TOKEN` | no | Bearer token — only if the codexbox server was started with `CODEXBOX_MCP_MODE_TOKEN` set. |

## Install

Install it into your OpenClaw agent from ClawHub:

```bash
openclaw plugins install clawhub:@psyb0t/codexbox
```

Then set `CODEXBOX_URL` (and `CODEXBOX_MCP_MODE_TOKEN` if your server uses
auth) in the plugin's environment.

## Native remote MCP (no install)

If your MCP client already supports **remote** Streamable-HTTP servers, you
don't need this bridge — point the client straight at
`$CODEXBOX_URL/mcp` with an `Authorization: Bearer <token>` header.

## License

MIT. See [LICENSE](LICENSE).
