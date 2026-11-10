---
title: "Codex adapter"
description: "How codexbox maps run options to codex exec flags: system prompts, noTools, toolsAllowlist, schemas, reasoning effort and session continuation."
nav_order: 7
---

# Codex adapter

The server modes do not call Codex through the wrapper. They load [`codexbox/codexbox/adapter.py`](https://github.com/psyb0t/docker-codexbox/blob/main/codexbox/codexbox/adapter.py), which implements the aicodebox adapter contract for Codex: it turns a run request into a `codex exec` command line and turns Codex's `--json` event stream back into a result. This page is how the shared run options land on Codex.

## The command line

Every run is `codex exec` with `--json` and `--skip-git-repo-check`, so the workspace does not have to be a Git repository. The prompt goes to stdin, and `-` is always the last argument. Normal runs add `--dangerously-bypass-approvals-and-sandbox`, because the container is the sandbox.

| Run option | Codex flag |
| --- | --- |
| `model` | `--model <id>` |
| `thinking` | `-c model_reasoning_effort=<level>`. Levels: `none`, `minimal`, `low`, `medium`, `high`, `xhigh`, `max`. Anything else is rejected. |
| `systemPrompt` | `-c instructions=<text>`, which replaces Codex's built-in instructions |
| `appendSystemPrompt` | `-c developer_instructions=<text>`, which adds a developer-role message |
| `jsonSchema` | Written to a temporary file and passed as `--output-schema <file>` |
| `noTools` | `--sandbox read-only` instead of the bypass flag, plus `-c features.shell_tool=false` and `-c web_search=disabled` |
| `toolsAllowlist` | Nothing. Logged as a warning and ignored. |
| `resume` | `codex exec resume <id>` |
| `noContinue` | `--ephemeral` |
| extra arguments (`x-aicodebox-extra-args`) | Added as they are, before the final `-` |

Each `-c` value is one argument, so multi-line prompt text arrives unchanged.

`noTools` is the closest Codex gets to a no-tools run. It drops the shell and web search tools from what the model sees, and the read-only sandbox stops the tools Codex keeps regardless, `apply_patch` and `update_plan`, from changing anything.

`toolsAllowlist` has no Codex equivalent. Codex has no allowlist of built-in tools by name, only `enabled_tools` per MCP server. The adapter accepts the field so callers that send it to every aicodebox agent keep working.

## Session continuation

A run with neither `resume` nor `noContinue` continues the workspace's own Codex session:

- The first such run in a workspace starts a new top-level `exec` session. Its ID, from the `thread.started` event, is pinned to the workspace's resolved path.
- Later runs resume that exact ID. A newer subagent rollout in the same workspace cannot take over, because Codex refuses direct turns on subagent sessions.
- A workspace with no pin yet takes its newest top-level `exec` rollout under `$CODEX_HOME/sessions`, if there is one, so existing workspaces keep their history.
- `resume` runs that session and pins it once Codex confirms the thread.
- `noContinue` runs with `--ephemeral` and leaves the pin alone.

The pins are files under `$CODEX_HOME/sessions/.codexbox-roots/`, one per workspace, named by a SHA-256 of the workspace path. Mounting `~/.codex` keeps them, and `codexbox clear-session` deletes them with the sessions.

The interactive TUI is different. The wrapper runs `codex resume --last`, which Codex scopes to the current directory. See [The codexbox wrapper](wrapper.md#commands).

## Reading Codex's output

The adapter reads these events from the `--json` stream:

| Event | Used for |
| --- | --- |
| `thread.started` | The session ID, and the workspace pin |
| `item.completed` of type `agent_message` | The answer text. Several messages are joined with newlines. In a stream, each one is a text delta. |
| `turn.completed` | Token usage. `input` and `output` are copied to `input_tokens` and `output_tokens`. |
| `turn.failed`, `error` | The provider error |

Reasoning items, tool items, `item.started` and `item.updated` stay out of the answer text and the OpenAI-compatible stream. `"eventMode": "full"` on `/run` returns all of them.

Codex also prints plain-text log lines on stdout between the JSON events. The adapter skips them with a warning instead of failing the run.

## Auth files

The adapter declares `$CODEX_HOME/auth.json` as its credential file. It holds either login mode; see [Authentication](auth.md).
