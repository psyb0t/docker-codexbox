# Docs and releases

Prefix: DOC.

- **DOC1:** `docs/` is the documentation site, published by GitHub Pages from `main` at https://psyb0t.github.io/docker-codexbox/ with Docusaurus (`website/`, sidebar order in `website/sidebars.mjs`). `README.md` is the front door: a summary, the quick start and a Documentation section with full-URL links.
- **DOC2:** Page order and nesting live in `website/sidebars.mjs`. Mode pages belong to the Modes category.
- **DOC3:** README links into the docs use full site URLs, because the README is mirrored to Docker Hub.
- **DOC4:** `website/static/llms.txt` lists every page with its title and description. A new or renamed page changes it in the same change.
- **DOC5:** `make docs` builds the site into `website/build` and fails on a broken link or anchor. Build it after any docs change.
- **DOC6:** Features owned by the aicodebox base may link to https://psyb0t.github.io/docker-aicodebox/, but these docs still list every `CODEXBOX_` name, default and Codex-specific difference.
- **DOC8:** Versions come from `codexbox/pyproject.toml`. `make version V=X.Y.Z` syncs `uv.lock`, the Codex plugin manifest and `CODEXBOX_RELEASE_REF` in `install.sh` without committing or tagging. `CHANGELOG.md` entries are headed `## vX.Y.Z, YYYY-MM-DD`. A `v*` tag on a green `main` commit promotes that commit's images; nothing is rebuilt.
