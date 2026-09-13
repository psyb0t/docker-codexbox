# Third-party components

`docker-codexbox`'s own code (wrapper, entrypoint, agent launcher, adapter,
init scripts, plugin) is WTFPL — see [LICENSE](LICENSE). The Codexbox
OpenClaw plugin under `.agents/plugins/codexbox/` is MIT — see
[.agents/plugins/codexbox/LICENSE](.agents/plugins/codexbox/LICENSE).

The table below covers third-party software baked into the published Docker
images (not build-time-only dependencies, not things the user downloads
separately).

| Component | Kind | SPDX license | Source | Where it lives | Note |
|---|---|---|---|---|---|
| [@openai/codex](https://github.com/openai/codex) | image-package | Apache-2.0 | https://github.com/openai/codex | `npm install -g --prefix /home/aicode/.local @openai/codex` in `Dockerfile` (both image variants) | Full license text: [LICENSES/Apache-2.0.txt](LICENSES/Apache-2.0.txt) |
| [HashiCorp Terraform](https://github.com/hashicorp/terraform) | inherited image package | BUSL-1.1 | https://github.com/hashicorp/terraform | `aicodebox:v0.15.0-full` only | Source-available, non-compete license, not OSI-approved open source. Corresponding source at the upstream repo above. See the FLAG in the project docs. |
| [GitHub CLI (`gh`)](https://github.com/cli/cli) | inherited image package | MIT | https://github.com/cli/cli | `aicodebox:v0.15.0-full` only | |
| [kubectl](https://github.com/kubernetes/kubectl) | inherited image package | Apache-2.0 | https://github.com/kubernetes/kubectl | `aicodebox:v0.15.0-full` only | |
| [Helm](https://github.com/helm/helm) | inherited image package | Apache-2.0 | https://github.com/helm/helm | `aicodebox:v0.15.0-full` only | |
| [golangci-lint](https://github.com/golangci/golangci-lint) | inherited image package | BSD-3-Clause | https://github.com/golangci/golangci-lint | `aicodebox:v0.15.0-full` only | |

See also the sibling [docker-aicodebox](https://github.com/psyb0t/docker-aicodebox)
base image's own `THIRD_PARTY.md` (if present) for components inherited from
that layer.
