"""Unit tests for CodexAdapter.

Plan: `.plan-and-delegate/2026-07-21-080508_codexbox.md` (frozen CodexAdapter
public surface).

Runs in-process against the aicodebox AgentAdapter base contract. No docker,
no real codex binary. Covers:
  - build_argv: base flags, resume subcommand insertion, no_continue,
    model/thinking/json_schema translation, stdin sentinel placement.
  - parse_output: JSONL thread/turn/item events -> text + session + usage,
    tolerating interleaved non-JSON log lines.
  - parse_events: decoded dict list passthrough.
  - parse_stream_event: session / delta / stop / error line handling.
  - auth_paths: CODEX_HOME-relative auth.json path.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest
from aicodebox.adapters.base import RunRequest

from codexbox.adapter import (
    BYPASS_FLAG,
    CODEX_REASONING_LEVELS,
    CodexAdapter,
)


@pytest.fixture
def adapter() -> CodexAdapter:
    return CodexAdapter()


# ── build_argv — base shape ──────────────────────────────────────────────────


def test_build_argv_base_shape(adapter: CodexAdapter) -> None:
    argv = adapter.build_argv(RunRequest(prompt="hi"))

    assert argv[0] == "codex"
    assert argv[1] == "exec"
    assert "--json" in argv
    assert BYPASS_FLAG in argv
    assert "--skip-git-repo-check" in argv


def test_build_argv_stdin_sentinel_last(adapter: CodexAdapter) -> None:
    argv = adapter.build_argv(RunRequest(prompt="hi"))
    assert argv[-1] == "-"


def test_build_argv_prompt_not_in_argv(adapter: CodexAdapter) -> None:
    argv = adapter.build_argv(RunRequest(prompt="this exact prompt text"))
    assert "this exact prompt text" not in argv


# ── build_argv — model ───────────────────────────────────────────────────────


def test_build_argv_model_flag(adapter: CodexAdapter) -> None:
    argv = adapter.build_argv(RunRequest(prompt="hi", model="gpt-5.2-codex"))
    idx = argv.index("--model")
    assert argv[idx + 1] == "gpt-5.2-codex"


# ── build_argv — thinking ────────────────────────────────────────────────────


def test_build_argv_thinking_flag(adapter: CodexAdapter) -> None:
    argv = adapter.build_argv(RunRequest(prompt="hi", thinking="high"))
    idx = argv.index("-c")
    assert argv[idx + 1] == "model_reasoning_effort=high"


def test_validate_unknown_thinking_raises(adapter: CodexAdapter) -> None:
    with pytest.raises(ValueError):
        adapter.validate(RunRequest(prompt="hi", thinking="ludicrous"))


def test_validate_all_known_thinking_levels_ok(adapter: CodexAdapter) -> None:
    for level in CODEX_REASONING_LEVELS:
        adapter.validate(RunRequest(prompt="hi", thinking=level))


# ── build_argv — resume ──────────────────────────────────────────────────────


def test_build_argv_resume_inserted_after_exec(adapter: CodexAdapter) -> None:
    argv = adapter.build_argv(RunRequest(prompt="hi", resume="sess-123"))
    exec_idx = argv.index("exec")
    assert argv[exec_idx + 1] == "resume"
    assert argv[exec_idx + 2] == "sess-123"


def test_build_argv_resume_no_ephemeral(adapter: CodexAdapter) -> None:
    argv = adapter.build_argv(RunRequest(prompt="hi", resume="sess-123"))
    assert "--ephemeral" not in argv


def test_build_argv_default_continues_via_resume_last(adapter: CodexAdapter) -> None:
    argv = adapter.build_argv(RunRequest(prompt="hi"))
    exec_idx = argv.index("exec")
    assert argv[exec_idx + 1] == "resume"
    assert argv[exec_idx + 2] == "--last"
    assert "--ephemeral" not in argv


# ── build_argv — no_continue ─────────────────────────────────────────────────


def test_build_argv_no_continue_adds_ephemeral(adapter: CodexAdapter) -> None:
    argv = adapter.build_argv(RunRequest(prompt="hi", no_continue=True))
    assert "--ephemeral" in argv
    assert "resume" not in argv


# ── build_argv — system / append prompt ──────────────────────────────────────


def test_build_argv_system_prompt_replaces(adapter: CodexAdapter) -> None:
    argv = adapter.build_argv(RunRequest(prompt="hi", system_prompt="be terse"))
    idx = argv.index("instructions=be terse")
    assert argv[idx - 1] == "-c"


def test_build_argv_append_system_prompt(adapter: CodexAdapter) -> None:
    argv = adapter.build_argv(
        RunRequest(prompt="hi", append_system_prompt="cite file:line"),
    )
    idx = argv.index("developer_instructions=cite file:line")
    assert argv[idx - 1] == "-c"


def test_build_argv_system_and_append_together(adapter: CodexAdapter) -> None:
    argv = adapter.build_argv(
        RunRequest(prompt="hi", system_prompt="A", append_system_prompt="B"),
    )
    assert "instructions=A" in argv
    assert "developer_instructions=B" in argv


def test_build_argv_multiline_system_prompt_is_one_arg(
    adapter: CodexAdapter,
) -> None:
    prompt = "line one\nline two"
    argv = adapter.build_argv(RunRequest(prompt="hi", system_prompt=prompt))
    assert f"instructions={prompt}" in argv


# ── build_argv — no_tools ────────────────────────────────────────────────────


def test_build_argv_no_tools_drops_tools_and_sandboxes(
    adapter: CodexAdapter,
) -> None:
    argv = adapter.build_argv(RunRequest(prompt="hi", no_tools=True))
    sb_idx = argv.index("--sandbox")
    assert argv[sb_idx + 1] == "read-only"
    assert "features.shell_tool=false" in argv
    assert "web_search=disabled" in argv
    assert BYPASS_FLAG not in argv


def test_build_argv_default_keeps_bypass_no_sandbox(adapter: CodexAdapter) -> None:
    argv = adapter.build_argv(RunRequest(prompt="hi"))
    assert BYPASS_FLAG in argv
    assert "--sandbox" not in argv


def test_validate_tools_allowlist_ignored_not_raised(
    adapter: CodexAdapter,
) -> None:
    adapter.validate(RunRequest(prompt="hi", tools_allowlist=["read", "search"]))
    argv = adapter.build_argv(RunRequest(prompt="hi", tools_allowlist=["read"]))
    assert not any("allowed" in a.lower() for a in argv)


# ── build_argv — json_schema ──────────────────────────────────────────────────


def test_build_argv_json_schema_writes_temp_file(
    adapter: CodexAdapter,
) -> None:
    schema = {"type": "object", "required": ["name"]}
    argv = adapter.build_argv(RunRequest(prompt="hi", json_schema=schema))

    idx = argv.index("--output-schema")
    schema_path = argv[idx + 1]
    assert Path(schema_path).is_file()
    with open(schema_path) as f:
        assert json.load(f) == schema


# ── parse_output ─────────────────────────────────────────────────────────────


def _jsonl_fixture() -> str:
    events = [
        {"type": "thread.started", "thread_id": "019f83b2-thread-abc"},
        {"type": "turn.started"},
        "ERROR unrelated interleaved log noise from codex --json",
        {
            "type": "item.completed",
            "item": {"id": "item_0", "type": "agent_message", "text": "here it is."},
        },
        {
            "type": "turn.completed",
            "usage": {
                "input_tokens": 10,
                "cached_input_tokens": 0,
                "cache_write_input_tokens": 0,
                "output_tokens": 5,
                "reasoning_output_tokens": 0,
            },
        },
    ]
    return "\n".join(
        e if isinstance(e, str) else json.dumps(e) for e in events
    )


def test_parse_output_assembles_text(adapter: CodexAdapter) -> None:
    result = adapter.parse_output(_jsonl_fixture(), RunRequest())
    assert result.text == "here it is."
    assert result.session_id == "019f83b2-thread-abc"
    assert result.usage is not None
    assert result.usage["input_tokens"] == 10
    assert result.usage["output_tokens"] == 5


def test_parse_output_skips_non_json_lines(adapter: CodexAdapter) -> None:
    stdout = "not-json-at-all\n" + _jsonl_fixture() + "\nalso-not-json"
    result = adapter.parse_output(stdout, RunRequest())
    assert result.text == "here it is."
    assert result.session_id == "019f83b2-thread-abc"


def test_parse_output_turn_failed_sets_provider_error(
    adapter: CodexAdapter,
) -> None:
    events = [
        {"type": "thread.started", "thread_id": "019f83b2-thread-def"},
        {"type": "turn.started"},
        {
            "type": "item.completed",
            "item": {"id": "item_0", "type": "error", "message": "boom"},
        },
        {"type": "error", "message": "boom"},
        {"type": "turn.failed", "error": {"message": "unexpected status 401 ..."}},
    ]
    stdout = "\n".join(json.dumps(e) for e in events)
    result = adapter.parse_output(stdout, RunRequest())
    assert result.provider_error == "unexpected status 401 ..."
    assert result.session_id == "019f83b2-thread-def"


def test_parse_output_empty_stdout(adapter: CodexAdapter) -> None:
    result = adapter.parse_output("", RunRequest())
    assert result.text == ""
    assert result.session_id == ""
    assert result.usage is None


# ── parse_events ─────────────────────────────────────────────────────────────


def test_parse_events_returns_decoded_dicts(adapter: CodexAdapter) -> None:
    events = adapter.parse_events(_jsonl_fixture(), RunRequest())
    types = [e.get("type") for e in events]
    assert types == ["thread.started", "turn.started", "item.completed", "turn.completed"]
    assert events[0]["thread_id"] == "019f83b2-thread-abc"


# ── parse_stream_event ───────────────────────────────────────────────────────


def test_parse_stream_event_session(adapter: CodexAdapter) -> None:
    line = json.dumps({"type": "thread.started", "thread_id": "019f83b2-abc"})
    evt = adapter.parse_stream_event(line, RunRequest())
    assert evt is not None
    assert evt.type == "session"
    assert evt.data == {"id": "019f83b2-abc"}


def test_parse_stream_event_delta(adapter: CodexAdapter) -> None:
    line = json.dumps(
        {
            "type": "item.completed",
            "item": {"id": "item_0", "type": "agent_message", "text": "hello"},
        },
    )
    evt = adapter.parse_stream_event(line, RunRequest())
    assert evt is not None
    assert evt.type == "delta"
    assert evt.text == "hello"


def test_parse_stream_event_stop(adapter: CodexAdapter) -> None:
    line = json.dumps(
        {
            "type": "turn.completed",
            "usage": {"input_tokens": 3, "output_tokens": 1},
        },
    )
    evt = adapter.parse_stream_event(line, RunRequest())
    assert evt is not None
    assert evt.type == "stop"


def test_parse_stream_event_turn_failed_is_error(adapter: CodexAdapter) -> None:
    line = json.dumps(
        {"type": "turn.failed", "error": {"message": "unexpected status 401 ..."}},
    )
    evt = adapter.parse_stream_event(line, RunRequest())
    assert evt is not None
    assert evt.type == "error"


def test_parse_stream_event_top_level_error_is_error(adapter: CodexAdapter) -> None:
    line = json.dumps({"type": "error", "message": "fatal stream error"})
    evt = adapter.parse_stream_event(line, RunRequest())
    assert evt is not None
    assert evt.type == "error"


def test_parse_stream_event_malformed_returns_none(adapter: CodexAdapter) -> None:
    assert adapter.parse_stream_event("not-json", RunRequest()) is None
    assert adapter.parse_stream_event("", RunRequest()) is None


# ── misc surface ─────────────────────────────────────────────────────────────


def test_interactive_and_passthrough(adapter: CodexAdapter) -> None:
    assert adapter.interactive_argv("/workspace") == ["codex"]
    assert adapter.passthrough_argv(["--version"]) == ["codex", "--version"]


def test_auth_paths_ends_with_auth_json(
    adapter: CodexAdapter,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("HOME", "/home/alt")
    monkeypatch.delenv("CODEX_HOME", raising=False)
    paths = adapter.auth_paths()
    assert len(paths) == 1
    assert paths[0].endswith("/auth.json")


def test_auth_paths_honors_codex_home(
    adapter: CodexAdapter,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("HOME", "/home/alt")
    monkeypatch.setenv("CODEX_HOME", "/home/alt/.codex")
    paths = adapter.auth_paths()
    assert paths == ["/home/alt/.codex/auth.json"]
