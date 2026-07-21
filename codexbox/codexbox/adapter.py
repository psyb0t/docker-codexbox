"""CodexAdapter — wires the aicodebox AgentAdapter contract to the OpenAI Codex CLI.

codex CLI surface used here (see .plan-and-delegate/2026-07-21-080508_codexbox.md
for the full ground-truth map):
  exec [OPTIONS] [PROMPT]                   non-interactive; PROMPT omitted/"-" reads stdin
  --json                                    JSONL ThreadEvent stream on stdout
  --dangerously-bypass-approvals-and-sandbox  headless bypass (alias --yolo)
  --skip-git-repo-check                     required so /workspace need not be a git repo
  -m, --model <id>                          model override (server-driven, no fixed list)
  -c model_reasoning_effort=<level>         reasoning effort (no --thinking flag)
  --output-schema <file>                    native JSON-schema enforcement
  --ephemeral                               don't persist session rollout files
  exec resume <id> / exec resume --last     resume is a subcommand, not a flag
"""

from __future__ import annotations

import json
import logging
import os
import tempfile
from typing import Any, ClassVar

from aicodebox.adapters.base import (
    AgentAdapter,
    RunRequest,
    RunResult,
    StreamEvent,
)

log = logging.getLogger(__name__)

BYPASS_FLAG = "--dangerously-bypass-approvals-and-sandbox"
SANDBOX_READ_ONLY = "read-only"
VALID_REASONING_EFFORTS = {"none", "minimal", "low", "medium", "high", "xhigh", "max"}
CODEX_REASONING_LEVELS = ["none", "minimal", "low", "medium", "high", "xhigh", "max"]

# `-c key=value` config overrides codex accepts. The value is parsed as TOML,
# falling back to the raw string on a parse failure, so free-form prompt text
# passed as a single argv element lands verbatim.
CONFIG_REASONING_EFFORT = "model_reasoning_effort"
# `instructions` REPLACES the model's built-in system prompt (the pi/claude
# --system-prompt equivalent); `developer_instructions` APPENDS a developer-role
# message alongside it (the --append-system-prompt equivalent).
CONFIG_INSTRUCTIONS = "instructions"
CONFIG_DEVELOPER_INSTRUCTIONS = "developer_instructions"
# no_tools levers: drop the shell/exec tool and the hosted web_search tool from
# the spec the model sees. codex has no master "disable every tool" switch —
# update_plan is unconditional and apply_patch stays while a local environment
# exists — so no_tools ALSO forces the read-only sandbox to neuter any residual
# tool's effect. Closest thing codex has to pi/claude --no-tools.
CONFIG_SHELL_TOOL_OFF = "features.shell_tool=false"
CONFIG_WEB_SEARCH_OFF = "web_search=disabled"


def _truncate(value: Any, limit: int = 80) -> str:
    """Render a value as a short string for log fields. Never logs full
    prompts / schemas / tokens — capped so a malicious caller can't blow
    up log volume by sending huge inputs, and so prompts (which may carry
    user-private content) don't land in logs verbatim. ``...`` suffix
    signals truncation occurred.
    """
    if value is None:
        return ""
    s = str(value)
    return s if len(s) <= limit else s[:limit] + "..."


class CodexAdapter(AgentAdapter):
    name: ClassVar[str] = "codex"
    binary: ClassVar[str] = "codex"
    available_models: ClassVar[list[str]] = []
    available_thinking_levels: ClassVar[list[str]] = CODEX_REASONING_LEVELS

    def validate(self, req: RunRequest) -> None:
        log.debug(
            "validate(req): output_format=%s thinking=%s no_tools=%s "
            "tools_allowlist=%s json_schema=%s resume=%s",
            req.output_format,
            req.thinking,
            req.no_tools,
            bool(req.tools_allowlist),
            req.json_schema is not None,
            bool(req.resume),
        )
        super().validate(req)

        # no_tools IS honored (see build_argv). tools_allowlist is not: codex
        # exec has no name-based built-in tool allowlist — the built-in tools
        # are per-feature flags, and the only real allowlist is MCP
        # enabled_tools per server. Warn + ignore rather than reject so the
        # server modes that pass it unconditionally still run.
        if req.tools_allowlist:
            log.warning(
                "validate(req): codex exec has no name-based built-in tool "
                "allowlist — tools_allowlist=%s ignored (use no_tools to drop "
                "shell+web_search, or MCP enabled_tools per server)",
                req.tools_allowlist,
            )

        if req.thinking and req.thinking not in VALID_REASONING_EFFORTS:
            log.warning(
                "validate(req): rejecting unknown reasoning effort %r",
                req.thinking,
            )
            raise ValueError(
                f"thinking={req.thinking!r} invalid; "
                f"choose one of {sorted(VALID_REASONING_EFFORTS)}"
            )

    def build_argv(self, req: RunRequest) -> list[str]:
        argv: list[str] = [self.binary, "exec"]

        # Session: default to continuing the workspace's most recent session
        # (pi's --continue / claude's --continue). codex `resume --last` starts
        # a FRESH session — not an error — when nothing is recorded yet, so it's
        # safe on a clean workspace. resume=<id> targets a specific session;
        # no_continue runs ephemerally with nothing persisted.
        session_choice: str
        if req.resume:
            argv += ["resume", req.resume]
            session_choice = "resume"
        elif req.no_continue:
            session_choice = "ephemeral"
        else:
            argv += ["resume", "--last"]
            session_choice = "continue"

        argv += ["--json", "--skip-git-repo-check"]

        # Sandbox/approvals. Normal runs get full access — the container is the
        # sandbox. no_tools runs drop to read-only so any tool the spec still
        # carries (apply_patch/update_plan can't be config-removed) can't mutate
        # anything.
        if req.no_tools:
            argv += ["--sandbox", SANDBOX_READ_ONLY]
        else:
            argv += [BYPASS_FLAG]

        if session_choice == "ephemeral":
            argv += ["--ephemeral"]

        if req.model:
            argv += ["--model", req.model]

        if req.thinking:
            argv += ["-c", f"{CONFIG_REASONING_EFFORT}={req.thinking}"]

        # System prompt. `instructions` REPLACES the built-in prompt (pi/claude
        # --system-prompt); `developer_instructions` APPENDS a developer-role
        # message (--append-system-prompt). Each is a single argv element, so
        # arbitrary multi-line prompt text survives verbatim.
        if req.system_prompt:
            argv += ["-c", f"{CONFIG_INSTRUCTIONS}={req.system_prompt}"]

        if req.append_system_prompt:
            argv += [
                "-c",
                f"{CONFIG_DEVELOPER_INSTRUCTIONS}={req.append_system_prompt}",
            ]

        # no_tools: drop the shell/exec + hosted web_search tools from the spec
        # the model sees (paired with the read-only sandbox above).
        if req.no_tools:
            argv += ["-c", CONFIG_SHELL_TOOL_OFF, "-c", CONFIG_WEB_SEARCH_OFF]

        has_schema = bool(req.json_schema)
        if req.json_schema:
            # Codex has native --output-schema enforcement (unlike pi/claude),
            # but it only accepts a FILE path, not inline JSON — write the
            # schema to a temp file. Leaking this temp file in an ephemeral
            # container is acceptable (documented in the project plan).
            fd, schema_path = tempfile.mkstemp(
                suffix=".json", prefix="codex-schema-",
            )
            os.write(fd, json.dumps(req.json_schema).encode("utf-8"))
            os.close(fd)
            argv += ["--output-schema", schema_path]

        if req.extra_args:
            argv += list(req.extra_args)

        # Prompt is piped to stdin by aicodebox.shared.runner — codex exec
        # reads from stdin when PROMPT is omitted or literally "-". The
        # stdin sentinel MUST be the last positional argument.
        argv += ["-"]

        log.debug(
            "build_argv: model=%s session=%s no_tools=%s system_prompt=%s "
            "append=%s has_schema=%s argc=%d",
            req.model or "(default)",
            session_choice,
            req.no_tools,
            bool(req.system_prompt),
            bool(req.append_system_prompt),
            has_schema,
            len(argv),
        )
        return argv

    def translate_auth(self, env: dict[str, str]) -> dict[str, str]:
        # codex reads OPENAI_API_KEY / OPENAI_BASE_URL / auth.json natively —
        # no aliasing needed.
        del env
        return {}

    def parse_output(self, stdout: str, req: RunRequest) -> RunResult:
        """Extract the canonical assistant text + session id + usage from
        codex's ``--json`` ThreadEvent stream.

        codex interleaves plain-text ``ERROR ...`` log lines onto stdout
        alongside the JSONL events — non-JSON lines are EXPECTED and must be
        skipped (counted + warned), never treated as fatal.
        """
        del req
        line_count = 0
        decoded_count = 0
        decode_errors = 0
        session_id = ""
        text_parts: list[str] = []
        usage: dict[str, Any] | None = None
        last_provider_error: str | None = None

        for line in stdout.splitlines():
            line = line.strip()
            if not line:
                continue
            line_count += 1
            try:
                evt = json.loads(line)
            except json.JSONDecodeError as exc:
                decode_errors += 1
                log.warning(
                    "parse_output: dropping non-JSON stdout line (err=%s, sample=%r)",
                    exc.msg,
                    _truncate(line, 80),
                )
                continue
            if not isinstance(evt, dict):
                decode_errors += 1
                continue
            decoded_count += 1

            etype = evt.get("type")

            if etype == "thread.started":
                tid = evt.get("thread_id")
                if isinstance(tid, str) and not session_id:
                    session_id = tid
                continue

            if etype == "item.completed":
                item = evt.get("item") or {}
                if isinstance(item, dict) and item.get("type") == "agent_message":
                    text = item.get("text")
                    if isinstance(text, str) and text:
                        text_parts.append(text)
                continue

            if etype == "turn.completed":
                u = evt.get("usage")
                if isinstance(u, dict):
                    usage = dict(u)
                continue

            if etype == "turn.failed":
                err = evt.get("error") or {}
                msg = err.get("message") if isinstance(err, dict) else None
                if isinstance(msg, str) and msg:
                    last_provider_error = msg
                    log.warning(
                        "parse_output: turn.failed (err=%s)",
                        _truncate(msg, 200),
                    )
                continue

            if etype == "error":
                msg = evt.get("message")
                if isinstance(msg, str) and msg:
                    last_provider_error = msg
                    log.warning(
                        "parse_output: top-level error event (err=%s)",
                        _truncate(msg, 200),
                    )
                continue

        text = "\n".join(text_parts).strip()
        if isinstance(usage, dict):
            if "input" in usage:
                usage.setdefault("input_tokens", usage["input"])
            if "output" in usage:
                usage.setdefault("output_tokens", usage["output"])

        log.info(
            "parse_output: text_len=%d session_id=%s lines=%d decoded=%d "
            "decode_errors=%d usage_keys=%s provider_error=%s",
            len(text),
            session_id or "(none)",
            line_count,
            decoded_count,
            decode_errors,
            sorted(usage.keys()) if usage else [],
            bool(last_provider_error),
        )

        return RunResult(
            text=text,
            raw_stdout=stdout,
            raw_stderr="",
            exit_code=0,
            session_id=session_id,
            usage=usage,
            provider_error=last_provider_error,
        )

    def parse_events(
        self, stdout: str, req: RunRequest,
    ) -> list[dict[str, Any]]:
        """JSON-decode every line of codex's ``--json`` ThreadEvent stream.

        Returned verbatim to ``/run`` callers as the ``events`` field when
        ``output_format=json-verbose``. Non-JSON lines (interleaved plain-text
        log lines) and non-object events are warned + dropped — events is
        best-effort; the raw bytes are reachable via ``includeRaw: true``.
        """
        del req
        events: list[dict[str, Any]] = []
        decode_errors = 0
        non_dict = 0
        for line in stdout.splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                evt = json.loads(line)
            except json.JSONDecodeError as exc:
                decode_errors += 1
                log.warning(
                    "parse_events: dropping non-JSON stdout line (err=%s, sample=%r)",
                    exc.msg,
                    _truncate(line, 80),
                )
                continue
            if isinstance(evt, dict):
                events.append(evt)
            else:
                non_dict += 1
                log.warning(
                    "parse_events: dropping non-object event (type=%s)",
                    type(evt).__name__,
                )

        log.debug(
            "parse_events: events=%d decode_errors=%d non_dict=%d",
            len(events),
            decode_errors,
            non_dict,
        )
        return events

    def parse_stream_event(
        self, line: str, req: RunRequest,
    ) -> StreamEvent | None:
        """Decode one line of codex's ``--json`` ThreadEvent stream into a
        canonical ``StreamEvent``.

        Only ``agent_message`` item.completed events become text deltas —
        ``reasoning`` / tool items / ``item.started`` / ``item.updated`` are
        silent so they don't contaminate the OAI ``content`` stream. Non-JSON
        lines (codex interleaves plain-text ``ERROR ...`` log lines) are
        dropped, not surfaced as stream errors.
        """
        del req
        if not line:
            return None
        try:
            evt = json.loads(line)
        except json.JSONDecodeError as exc:
            log.warning(
                "parse_stream_event: dropping non-JSON stdout line (err=%s, sample=%r)",
                exc.msg,
                _truncate(line, 80),
            )
            return None
        if not isinstance(evt, dict):
            return None

        etype = evt.get("type")

        if etype == "thread.started":
            tid = evt.get("thread_id")
            if isinstance(tid, str) and tid:
                return StreamEvent(type="session", data={"id": tid})
            return None

        if etype == "item.completed":
            item = evt.get("item") or {}
            if isinstance(item, dict) and item.get("type") == "agent_message":
                text = item.get("text")
                if isinstance(text, str) and text:
                    return StreamEvent(type="delta", text=text)
            return None

        if etype == "turn.completed":
            u = evt.get("usage")
            usage = dict(u) if isinstance(u, dict) else None
            if isinstance(usage, dict):
                if "input" in usage:
                    usage.setdefault("input_tokens", usage["input"])
                if "output" in usage:
                    usage.setdefault("output_tokens", usage["output"])
            return StreamEvent(type="stop", data={"usage": usage, "reason": "stop"})

        if etype == "turn.failed":
            err = evt.get("error") or {}
            msg = err.get("message") if isinstance(err, dict) else None
            if isinstance(msg, str) and msg:
                return StreamEvent(type="error", text=msg)
            return None

        if etype == "error":
            msg = evt.get("message")
            if isinstance(msg, str) and msg:
                return StreamEvent(type="error", text=msg)
            return None

        return None

    def interactive_argv(self, workspace: str) -> list[str]:
        del workspace
        return [self.binary]

    def passthrough_argv(self, args: list[str]) -> list[str]:
        return [self.binary, *args]

    def auth_paths(self) -> list[str]:
        # Persists BOTH apikey and ChatGPT-subscription OAuth tokens across
        # container recreates — auth.json is CODEX_HOME's single credential
        # file for both auth modes.
        home = os.environ.get("HOME", "/home/aicode")
        cfg = os.environ.get("CODEX_HOME", f"{home}/.codex")
        return [f"{cfg}/auth.json"]
