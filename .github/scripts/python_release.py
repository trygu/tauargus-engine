"""Keep pytauargus and pytauargus-tui on one release version (Python 3.11+)."""

import argparse
from pathlib import Path
import re
import tomllib


def projects(root):
    return [Path(root) / "bindings" / directory / "pyproject.toml"
            for directory in ("python", "tui")]


def check_release(root, tag=""):
    paths = projects(root)
    engine, tui = [tomllib.loads(path.read_text())["project"] for path in paths]
    version = engine["version"]
    if engine["name"] != "pytauargus" or tui["name"] != "pytauargus-tui":
        raise ValueError("Unexpected Python project names")
    if tui["version"] != version:
        raise ValueError("Engine and TUI versions must match")
    dependencies = [dep for dep in tui["dependencies"]
                    if re.split(r"[\s\[<>=!~;@]", dep, maxsplit=1)[0] == "pytauargus"]
    if dependencies != [f"pytauargus=={version}"]:
        raise ValueError("TUI dependency must require the matching engine version")
    if tag and tag != f"py-v{version}":
        raise ValueError("Release tag must match both projects: py-v<version>")
    for path, expected in zip(paths, ({"pytauargus": version},
                                     {"pytauargus": version, "pytauargus-tui": version})):
        locked = {pkg["name"]: pkg["version"] for pkg in
                  tomllib.loads(path.with_name("uv.lock").read_text())["package"]}
        if any(locked.get(name) != value for name, value in expected.items()):
            raise ValueError(f"Stale release version in {path.with_name('uv.lock')}")
    return version


def set_version(root, version):
    if not re.fullmatch(r"\d+\.\d+\.\d+(?:(?:a|b|rc)\d+|\.(?:post|dev)\d+)?", version):
        raise ValueError("Expected a Python release version, e.g. 0.3.1 or 0.4.0rc1")
    changes = []
    for path in projects(root):
        text = path.read_text()
        project = tomllib.loads(text)["project"]
        text, count = re.subn(r'(?m)^version = "[^"]+"$', f'version = "{version}"', text, count=1)
        if count != 1:
            raise ValueError(f"Cannot find project version in {path}")
        if project["name"] == "pytauargus-tui":
            deps = [dep for dep in project["dependencies"] if dep.startswith("pytauargus")]
            if len(deps) != 1:
                raise ValueError("Expected one TUI engine dependency")
            text = text.replace(f'"{deps[0]}"', f'"pytauargus=={version}"', 1)
        changes.append((path, text))
    for path, text in changes:
        path.write_text(text)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--tag", default="")
    parser.add_argument("--set-version")
    args = parser.parse_args()
    if args.set_version:
        set_version(args.root, args.set_version)
        print("Updated both projects. Run uv lock --project bindings/python and uv lock --project bindings/tui.")
    else:
        print(f"Verified shared Python release {check_release(args.root, args.tag)}")
