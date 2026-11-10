# Testing

Prefix: TST. How to run each suite is in `AGENTS.md` and `docs/development.md`.

- **TST1:** Adapter unit tests live in `codexbox/tests/test_adapter.py`. They run in process against the real `aicodebox` base classes, with no Docker and no Codex binary, and set `CODEX_HOME` to a `tmp_path` so session pins never touch a real home. Every adapter change gets a test here.
- **TST2:** `make test-ci` is what CI runs, and it must stay credential-free, deterministic and free of network access beyond pulling images and pinned packages. It runs `test-unit-ci`, `test-image-select`, `test-managed-nested` and `test-entrypoint-identity`. A new offline test joins it.
- **TST3:** Python tooling in CI runs inside `CI_IMAGE` (the aicodebox base) because the runner has neither `uv` nor the project's Python. Keep `PY_TOOLS` in the `Makefile` equal to the dev group in `codexbox/pyproject.toml`.
- **TST4:** Hermetic shell tests replace `docker`, `sudo` and `curl` with fakes on `PATH` and unset every inherited `AICODEBOX_HOST_*` variable first. Follow that pattern so a test never reaches a real daemon or the network.
- **TST5:** `make test` (`test.sh`) is the authenticated end-to-end suite. It reads `.env.test`, builds `codexbox:local` and calls OpenAI. It never runs in CI. Test functions register in `ALL_TESTS` and use the helpers in `tests/common.sh`.
- **TST6:** `make test-full-image` checks the advertised full-image tool list. A change to that list in the docs changes `tests/test_full_image.sh` too.
