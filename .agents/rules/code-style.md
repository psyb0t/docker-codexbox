# Code style

Prefix: STY. `make lint` enforces the mechanical part of this file; the rest is review.

- **STY1:** Python targets 3.12 (`target-version = "py312"`, `requires-python = ">=3.12"`) and passes `ruff check`, `ruff format --check` and `pyright` with the settings in `codexbox/pyproject.toml`. Do not add `# noqa`, per-file ignores or pyright overrides to get a change through; fix the code.
- **STY2:** Every Python module starts with `from __future__ import annotations` (except `__init__.py`) and annotates every function. Use `X | None`, not `Optional[X]`.
- **STY3:** Log through `log = logging.getLogger(__name__)` with `%s` arguments, never f-strings, and pass any value that may hold user content through `_truncate` (`adapter.py`). Prompts, schemas, system prompts and tokens are logged as booleans or lengths, never verbatim.
- **STY4:** Codex flag names and config keys are module constants in `adapter.py` (`BYPASS_FLAG`, `CONFIG_INSTRUCTIONS`, `CONFIG_SHELL_TOOL_OFF`, ...). Add a constant rather than a new string literal in `build_argv`.
- **STY5:** Shell scripts pass `shellcheck -x -P SCRIPTDIR` with no new `disable` directives, and are formatted with `shfmt -i 4 -ci`: four-space indent, indented `case` arms.
- **STY6:** Linear scripts (`install.sh`, `codexbox-agent.sh`, `codexbox-entrypoint.sh`, the init script, the standalone tests) use `set -euo pipefail`. `wrapper.sh` deliberately omits it because it relies on expected non-zero probes; its header says so. Keep that header true.
- **STY7:** User-facing errors go to stderr. Debug output is gated: `dbg()` behind `DEBUG=true` in `wrapper.sh` and `codexbox-agent.sh`.
- **STY8:** Comments say why, not what. No local scratch paths (`.plan-and-delegate/`, `.testing/`, `.agent_notes/` and the like) in code comments or docstrings.
