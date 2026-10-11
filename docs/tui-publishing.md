# Python packages and shared releases

**`pytauargus` and `pytauargus-tui` are separate PyPI packages with one
version and one release.** Every `py-v<version>` tag builds, tests and
publishes both packages through `.github/workflows/wheels.yml`. There are
no separate TUI tags or version decisions.

| Package | Contents | Command |
| --- | --- | --- |
| `pytauargus` | Native engine, Python API and headless CLI | `tauargus` |
| `pytauargus-tui` | Pure-Python terminal frontend and Textual dependency | `tauargus-tui` |

Installing the engine alone does not install Textual or the TUI. Installing
`pytauargus-tui` installs the exact matching engine version. A fix in either
package advances both versions, even when the other package is unchanged.
The first TUI distribution will be available with the next Python release.

```bash
pip install --upgrade pytauargus-tui
# Or install the command in its own environment:
uv tool install --upgrade pytauargus-tui
tauargus-tui path/to/batch.arb
```

## Checks and release flow

`tests.yml` appears as **Checks**: engine and TUI tests use the local engine,
plus a portable TUI distribution check. Pushes to `master`/`tui` and pull
requests targeting them run checks; side branches use PR checks instead of
running the same suite on both their push and PR events. Manual checks remain
available. A push to `tui` while it has a PR to `master` also tests that PR's
integration with its base branch.

`wheels.yml` appears as **Release** and runs on `py-v*` tags or manually:

1. Verify both project versions, lockfile versions, the TUI's exact engine
   dependency and (on release) the tag. Fail before native builds on drift.
2. Build engine wheels for all supported platforms/Python versions and one
   pure-Python TUI wheel plus source distribution.
3. Install the newly built engine and TUI wheels together on Linux x64/arm64,
   macOS arm64 and Windows x64, with Python 3.10 and 3.13; test the TUI and
   both commands. The engine is installed from the artifacts, not PyPI.
4. Publish the engine to PyPI, then its matching TUI.
5. Attach both packages to one GitHub release, then publish the engine's
   container image to GHCR.

Manual runs build and test only. Publishing requires a `py-v*` tag.
PyPI uploads are not atomic across projects: if the TUI upload fails after
an engine upload, rerun the failed jobs on the same immutable tag. Existing
files are skipped; the GitHub release and image wait for both PyPI uploads.
Do not move tags or replace published versions.

The existing `tool.uv.sources` entry still resolves the local sibling engine
for development. Use `scripts/sync-venv.sh` after native changes. Published
TUI distributions contain no local dependency URL or bundled native engine.
Testing the newly built pair includes the repeated-OPT and error-string
fixes; the old published engine 0.3.0 does not contain those fixes.

## One-time PyPI setup

Keep the engine's existing Trusted Publisher for `wheels.yml`. Configure a
[Trusted Publisher](https://docs.pypi.org/trusted-publishers/adding-a-publisher/)
or [pending publisher](https://docs.pypi.org/trusted-publishers/creating-a-project-through-oidc/)
for the TUI project:

| Setting | Value |
| --- | --- |
| PyPI project | `pytauargus-tui` |
| GitHub owner | `trygu` |
| Repository | `tauargus-engine` |
| Workflow filename | `wheels.yml` |
| GitHub environment | `pypi-tui` |

Create/configure `pypi-tui` in GitHub before the first release. The engine
publisher identity is unchanged; the TUI publisher now uses `wheels.yml`,
not the superseded `tui-release.yml`. Both projects are always published
on release tags; the former engine-only `PYPI_ENABLED` switch is removed.

## Release procedure

From a checkout containing both packages, using Python 3.11 or newer:

```bash
python .github/scripts/python_release.py --set-version X.Y.Z
uv lock --project bindings/python
uv lock --project bindings/tui
python .github/scripts/python_release.py
```

Run local engine and TUI tests as described in AGENTS.md and the TUI README.
Commit both manifests and lockfiles, push the branch, and confirm Checks is
green. A manual Release run can validate the cross-platform wheel pair
before tagging. Once the release commit is on `master`:

```bash
VERSION=$(python -c 'import pathlib, tomllib; print(tomllib.loads(pathlib.Path("bindings/python/pyproject.toml").read_text())["project"]["version"])')
git tag "py-v$VERSION"
git push origin "py-v$VERSION"
```

No release tag or upload is performed by the version-setting helper.
