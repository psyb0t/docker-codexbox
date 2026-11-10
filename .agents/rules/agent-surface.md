# Agent surface

Prefix: AGT. The skill, plugin manifests and MCP bridge under `.agents/` describe codexbox to other agents. They are published to ClawHub and plugin marketplaces, so they are public text.

- **AGT1:** A behavior, mode, setting or route change updates `.agents/skills/codexbox/SKILL.md` and `references/setup.md` in the same change. Take facts from the code and `docs/`, not from another agent file.
- **AGT2:** The MCP tool list (`run_prompt`, `list_files`, `read_file`, `write_file`, `delete_file`) appears in the skill, `.agents/plugins/codexbox/README.md`, the `description` in `openclaw.plugin.json` and `docs/modes/mcp.md`. Update them together.
- **AGT3:** `version` in `.agents/.codex-plugin/plugin.json` moves with the release through `make version`. The Claude manifest has no version. The bridge `package.json` and `openclaw.plugin.json` stay at `0.0.0`; CI sets their version from the tag.
- **AGT4:** The pipeline's `publish-to-clawhub` job lists the exact directories in `skill_names` and `plugin_names`. A new skill or plugin directory is added there.
- **AGT5:** The bridge `bin/cli.js` writes nothing to stdout, which is the MCP channel, and never prints the token. It appends `CODEXBOX_MCP_PATH` (default `/mcp/`) to `CODEXBOX_URL`; a standalone MCP server needs `CODEXBOX_MCP_PATH=/`. `tests/test_mcp_bridge.sh` covers the URL.
- **AGT6:** The skill keeps one `Security & safety` section covering unauthenticated surfaces, file deletion and the piped installer. Agent text follows the same prose rules as the docs.
