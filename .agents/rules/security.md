# Security

Prefix: SEC.

- **SEC1:** `.env.example` and `.env.test.example` hold empty values only. Examples in docs and the skill use the placeholders `sk-...`, `your-secret` and `123456:ABC`.
- **SEC2:** The API and MCP tokens are independent, and an empty token means no auth on that surface. Docs that show a server always show the token.
- **SEC3:** The init script seeds API-key auth only when `auth.json` is absent, unreadable or already `apikey`. It feeds the key to `codex login --with-api-key` on stdin, never in argv, and sets `auth.json` and `config.toml` to mode `600`.
- **SEC4:** The container is the sandbox: Codex runs with approvals and its own sandbox bypassed, and `aicode` has passwordless sudo. Do not describe the container as a security boundary for the host; the wrapper mounts the Docker socket.
- **SEC5:** The adapter logs prompts, schemas, system prompts and tokens only as lengths or booleans, and passes any other value that may hold user content through `_truncate`.
- **SEC6:** `.gitleaks.toml` allowlists only ignored local state (`.testing`, caches, the virtual environment). Do not widen it to cover tracked files.
