# Docs and releases

Prefix: DOC.

- **DOC1:** `docs/` is the documentation site, published by GitHub Pages from `main` at https://psyb0t.github.io/docker-codexbox/ with Jekyll and just-the-docs (`docs/_config.yml`, theme overrides in `docs/_sass/`). `README.md` is the front door: a summary, the quick start and a Documentation section with full-URL links. Reference material goes in `docs/`, and each fact has one home.
- **DOC2:** Every page has front matter with a unique `title` and a `description` of 50 to 170 characters, and exactly one `#` heading. Mode pages set `parent: "Modes"`.
- **DOC3:** Link between pages with the relative `.md` path. Link a file outside `docs/` with its full `https://github.com/psyb0t/docker-codexbox/blob/main/...` (or `tree/main/...`) URL. README links into the docs use full site URLs, because the README is mirrored to Docker Hub.
- **DOC4:** Wrap any code block containing `{{` or `{%` in `{% raw %}` comments, or Jekyll renders it as Liquid.
- **DOC5:** `make docs` builds the site with GitHub's Pages image into `.testing/docs-site`. Build it after any docs change and check the links before committing.
- **DOC6:** Features owned by the aicodebox base may link to https://psyb0t.github.io/docker-aicodebox/, but these docs still list every `CODEXBOX_` name, default and Codex-specific difference.
- **DOC7:** Prose has no em dashes or en dashes, says "directory", never "folder", and avoids AI filler vocabulary. First person, when used, is singular.
- **DOC8:** Versions come from `codexbox/pyproject.toml`. `make version V=X.Y.Z` syncs `uv.lock`, the Codex plugin manifest and `CODEXBOX_RELEASE_REF` in `install.sh` without committing or tagging. Each release adds a `CHANGELOG.md` entry headed `## vX.Y.Z, YYYY-MM-DD`. A `v*` tag on a green `main` commit promotes that commit's images; nothing is rebuilt.
