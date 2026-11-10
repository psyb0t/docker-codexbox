# Code style

Prefix: STY. `make lint` enforces the mechanical part of this file; the rest is review.

- **STY1:** Python targets 3.12 (`target-version = "py312"`, `requires-python = ">=3.12"`) and passes `ruff check`, `ruff format --check` and `pyright` with the settings in `codexbox/pyproject.toml`.
- **STY2:** Every Python module except `__init__.py` starts with `from __future__ import annotations`.
- **STY4:** Codex flag names and config keys are module constants in `adapter.py` (`BYPASS_FLAG`, `CONFIG_INSTRUCTIONS`, `CONFIG_SHELL_TOOL_OFF`, ...). Add a constant rather than a new string literal in `build_argv`.
- **STY5:** Shell scripts pass `shellcheck -x -P SCRIPTDIR` and are formatted with `shfmt -i 4 -ci`.
- **STY6:** `wrapper.sh` deliberately omits `set -euo pipefail` because it relies on expected non-zero probes; its header says so. Keep that header true.
- **STY7:** Debug output is gated: `dbg()` behind `DEBUG=true` in `wrapper.sh` and `codexbox-agent.sh`.
