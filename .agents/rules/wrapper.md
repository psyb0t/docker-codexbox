# Wrapper and installer

Prefix: WRP. `wrapper.sh` is the host `codexbox` command; `install.sh` installs it.

- **WRP1:** The wrapper does host plumbing only: image choice, mounts, environment forwarding and container lifecycle. Codex flag logic lives in `codexbox-agent.sh` in the image. The wrapper forwards `"$@"` untouched.
- **WRP2:** Image resolution order: `CODEXBOX_IMAGE`, then `CODEXBOX_FULL` (`0` minimal, `1` full, empty for the installed choice, anything else exits 1), then `CODEXBOX_INSTALLED_IMAGE`. `install.sh` rewrites the `CODEXBOX_INSTALLED_IMAGE=` line with `sed`; keep it a single line starting at column 0. `tests/test_image_select.sh` covers this.
- **WRP3:** The workspace is mounted at its host path, not `/workspace`, so nested Docker calls from inside the box resolve on the host. Do not change that.
- **WRP4:** Secrets are forwarded with `-e NAME=value` and never echoed. `dbg` prints forwarded variable names only.
- **WRP5:** Nested launches use `AICODEBOX_LAUNCH_CONTEXT_VERSION=1` and the `AICODEBOX_HOST_*` variables; any other version exits 1. Sibling wrappers (`codexbox`, `claudebox`, `pibox`) are bind-mounted read-only from the same directory. A change here keeps the sibling repositories' wrappers in mind and is covered by `tests/test_managed_nested.sh`.
- **WRP6:** `install.sh` downloads the wrapper from `CODEXBOX_RELEASE_REF`, which `make version` rewrites. Never hand-edit that line. `CODEXBOX_INSTALL_REF` overrides it.
- **WRP7:** Every host setting and subcommand is documented in `docs/wrapper.md`, and installer settings in `docs/install.md`. Update them in the same change.
