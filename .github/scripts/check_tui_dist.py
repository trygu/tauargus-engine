"""Check the TUI release boundary without loading the native engine."""

import argparse
import configparser
from email.parser import BytesParser
from pathlib import Path
import re
import tarfile
import tomllib
from zipfile import ZipFile


def check_metadata(data, version):
    metadata = BytesParser().parsebytes(data)
    if metadata["Name"] != "pytauargus-tui":
        raise ValueError("Distribution name must be pytauargus-tui")
    if metadata["Version"] != version:
        raise ValueError("Distribution version differs from pyproject.toml")
    dependencies = metadata.get_all("Requires-Dist", [])
    core = [item for item in dependencies
            if re.split(r"[\s\[<>=!~;(]", item, maxsplit=1)[0] == "pytauargus"]
    if len(core) != 1 or "@" in core[0]:
        raise ValueError("Engine dependency must resolve from the package index")


def check_distribution(directory, version, tag=""):
    directory = Path(directory)
    if tag and tag != f"py-v{version}":
        raise ValueError("Release tag must match the TUI project version")
    wheels = list(directory.glob("*.whl"))
    sources = list(directory.glob("*.tar.gz"))
    if len(wheels) != 1 or len(sources) != 1:
        raise ValueError("Expected exactly one TUI wheel and one source distribution")
    with ZipFile(wheels[0]) as archive:
        names = archive.namelist()
        info = [name for name in names if name.endswith(".dist-info/METADATA")]
        if len(info) != 1:
            raise ValueError("Expected one wheel metadata record")
        check_metadata(archive.read(info[0]), version)
        prefix = info[0].removesuffix("METADATA")
        wheel = BytesParser().parsebytes(archive.read(prefix + "WHEEL"))
        if (wheel["Root-Is-Purelib"] != "true"
                or wheel.get_all("Tag") != ["py3-none-any"]):
            raise ValueError("TUI wheel must remain portable pure Python")
        if any(name.endswith((".so", ".pyd", ".dll", ".dylib")) for name in names):
            raise ValueError("TUI wheel must not bundle native libraries")
        if any(name.startswith("pytauargus/") for name in names):
            raise ValueError("TUI wheel must not bundle core Python code")
        entry_file = prefix + "entry_points.txt"
        if entry_file not in names:
            raise ValueError("TUI console entry point is missing")
        entries = configparser.ConfigParser()
        entries.read_string(archive.read(entry_file).decode())
        if entries.get("console_scripts", "tauargus-tui", fallback="") != "pytauargus_tui.app:main":
            raise ValueError("TUI console entry point must be tauargus-tui")
    with tarfile.open(sources[0]) as archive:
        records = [member for member in archive.getmembers()
                   if member.name.endswith("/PKG-INFO")]
        if len(records) != 1 or not records[0].isfile():
            raise ValueError("Expected one source distribution metadata record")
        check_metadata(archive.extractfile(records[0]).read(), version)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--project", type=Path, default=Path("bindings/tui/pyproject.toml"))
    parser.add_argument("--tag", default="")
    args = parser.parse_args()
    project = tomllib.loads(args.project.read_text())["project"]
    check_distribution(args.directory, project["version"], args.tag)
    print(f"Verified portable {project['name']} {project['version']} distributions")
