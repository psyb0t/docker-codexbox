# Docs and releases

Prefix: DOC.

- **DOC1:** `docs/` is the documentation site, published by GitHub Pages from `main` at https://psyb0t.github.io/docker-codexbox/ with Jekyll and just-the-docs (`docs/_config.yml`, theme overrides in `docs/_sass/`). `README.md` is the front door: a summary, the quick start and a Documentation section with full-URL links.
- **DOC2:** Mode pages set `parent: "Modes"`.
- **DOC3:** README links into the docs use full site URLs, because the README is mirrored to Docker Hub.
- **DOC4:** Wrap any code block containing `{{` or `{%` in `{% raw %}` comments, or Jekyll renders it as Liquid.
- **DOC5:** `make docs` builds the site with GitHub's Pages image into `.testing/docs-site`. Build it after any docs change.
- **DOC6:** Features owned by the aicodebox base may link to https://psyb0t.github.io/docker-aicodebox/, but these docs still list every `CODEXBOX_` name, default and Codex-specific difference.
- **DOC8:** Versions come from `codexbox/pyproject.toml`. `make version V=X.Y.Z` syncs `uv.lock`, the Codex plugin manifest and `CODEXBOX_RELEASE_REF` in `install.sh` without committing or tagging. `CHANGELOG.md` entries are headed `## vX.Y.Z, YYYY-MM-DD`. A `v*` tag on a green `main` commit promotes that commit's images; nothing is rebuilt.
