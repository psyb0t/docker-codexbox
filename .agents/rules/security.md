# Security

Prefix: SEC.

- **SEC1:** Never commit or print secrets. `.env`, `.env.*` and `*.env` are ignored, except `.env.example` and `.env.test.example`, which hold empty values only. Examples in docs and the skill use obvious placeholders (`sk-...`, `your-secret`, `123456:ABC`).
- **SEC2:** The API and MCP tokens are independent, and an empty token means no auth on that surface. Docs that show a server always show the token, and compose examples bind ports to `127.0.0.1`.
- **SEC3:** The init script seeds API-key auth only when `auth.json` is absent, unreadable or already `apikey`. It feeds the key to `codex login --with-api-key` on stdin, never in argv, and sets `auth.json` and `config.toml` to mode `600`.
- **SEC4:** The container is the sandbox: Codex runs with approvals and its own sandbox bypassed, and `aicode` has passwordless sudo. Do not describe the container as a security boundary for the host; the wrapper mounts the Docker socket.
- **SEC5:** Log no prompt, schema, system prompt or token text. The adapter logs lengths and booleans and truncates everything else with `_truncate`.
- **SEC6:** `.gitleaks.toml` allowlists only ignored local state (`.testing`, caches, the virtual environment). Do not widen it to cover tracked files.
