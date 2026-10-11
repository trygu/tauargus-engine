# TUI package and publishing

The interactive frontend ships as **`pytauargus-tui`**, independently of
**`pytauargus`**. Both projects live in this repository. Developing the TUI
does not require a new engine release unless it needs a new engine API.

| Project | Contents | Command | Release tag |
| --- | --- | --- | --- |
| `pytauargus` | Native engine, Python API and headless CLI | `tauargus` | `py-v<version>` |
| `pytauargus-tui` | Pure-Python terminal frontend | `tauargus-tui` | `tui-v<version>` |

The TUI has its own version in `bindings/tui/pyproject.toml`. Its dependency
range describes compatible published engine versions. Textual belongs to the
TUI package; installing the engine alone does not install the interface.

After the first TUI release is published:

```bash
pip install --upgrade pytauargus-tui
# Or install the command in its own environment:
uv tool install --upgrade pytauargus-tui
tauargus-tui path/to/batch.arb
```

## Development and release checks

The existing `tool.uv.sources` entry resolves the engine from the sibling
package for local development. Keep using the local-engine development flow
and `scripts/sync-venv.sh` after native changes.

Published TUI distributions retain an ordinary `pytauargus` dependency,
without a checkout path or bundled engine. `.github/workflows/tui-release.yml`
builds the source distribution and a `py3-none-any` wheel, checks package
metadata and the console entry point, and rejects native/core payloads or
local engine dependency URLs.

The workflow tests the installed wheel on Linux, macOS and Windows, with
Python 3.10 and 3.13, using the released engine resolved by its dependency
range. This is a consumer-install check, separate from local engine
development. If the TUI needs an unreleased engine API, release that engine
first and set the TUI's minimum dependency accordingly.

The first release also needs the in-tree native fixes for repeated OPT and
embedded legacy error strings. As of 2026-10-11, the published engine is
0.3.0: the current TUI's second-OPT preview regression aborts with that wheel.
Publish an engine containing those fixes, then raise the TUI's minimum engine
version to that release before tagging the TUI. Keep the consumer tests using
published wheels so local development fixes cannot hide a release blocker.

Branch pushes, pull requests and manual runs only build and test. Publishing runs
only on `tui-v*` tags, after all checks pass and the tag matches the TUI's
project version. The core `py-v*` wheel/container workflow stays unchanged.

## One-time PyPI setup

Configure a [Trusted Publisher](https://docs.pypi.org/trusted-publishers/adding-a-publisher/)
for the TUI project. If the project does not exist, use a
[pending publisher](https://docs.pypi.org/trusted-publishers/creating-a-project-through-oidc/).

| Setting | Value |
| --- | --- |
| PyPI project | `pytauargus-tui` |
| GitHub owner | `trygu` |
| Repository | `tauargus-engine` |
| Workflow filename | `tui-release.yml` |
| GitHub environment | `pypi-tui` |

Create/configure that environment in the repository before the first release.
The publish job uses OIDC through `pypa/gh-action-pypi-publish`; it does not
reuse the engine publisher or require a PyPI token in the repository.

## Release

1. Finish the TUI changes and update its own package version and lockfile.
2. Ensure the build and installed-wheel test matrix is green on the exact
   commit to release. A manual workflow run is available for this check.
3. Push a new tag matching the package version. From the repository root,
   using Python 3.11 or newer:

   ```bash
   TUI_VERSION=$(python -c 'import pathlib, tomllib; print(tomllib.loads(pathlib.Path("bindings/tui/pyproject.toml").read_text())["project"]["version"])')
   git tag "tui-v$TUI_VERSION"
   git push origin "tui-v$TUI_VERSION"
   ```

4. The workflow publishes to PyPI, then attaches the TUI wheel and source
   distribution to its own GitHub release. That release does not replace the
   engine's GitHub "latest release" link and does not publish a Docker image.

Published package versions and release tags are not reused.
