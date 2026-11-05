#!/usr/bin/env python3
"""Compose offline R package provenance and preserve component attribution."""
import argparse
import json
import re
from pathlib import Path

NUMERIC_VERSION = re.compile(r"[0-9]+(?:[.-][0-9]+)+")
CONTRIBUTORS = (
    'person("Statistics Netherlands", role = c("ctb", "cph"), comment = "Tau-Argus core, HiTaS and rounder")',
    'person("M.D.", "Montes de Oca", role = c("ctb", "cph"), comment = "CSP library")',
    'person("J.J.", "Salazar", role = c("ctb", "cph"), comment = "CSP and CRP libraries")',
    'person("HiGHS", role = c("ctb", "cph"), comment = "Bundled HiGHS solver")',
)


def fields(text):
    result = {}
    key = None
    for line in text.splitlines():
        if line and not line[0].isspace() and ":" in line:
            key, value = line.split(":", 1)
            if key in result:
                raise ValueError("Duplicate DESCRIPTION field: " + key)
            result[key] = value.strip()
        elif line.strip() and key:
            result[key] += "\n" + line.strip()
    return result


def set_field(text, name, value):
    lines = text.splitlines()
    start = next((i for i, line in enumerate(lines) if line.startswith(name + ":")), len(lines))
    end = start + 1
    while end < len(lines) and lines[end] and lines[end][0].isspace():
        end += 1
    replacement = []
    if value is not None:
        values = value.splitlines()
        replacement = [name + ": " + values[0]] + ["    " + line for line in values[1:]]
    return "\n".join(lines[:start] + replacement + lines[end:]) + "\n"


def update(root, native):
    if not NUMERIC_VERSION.fullmatch(native):
        raise ValueError("Native version must be a numeric R version")
    description = root / "DESCRIPTION"
    text = description.read_text(encoding="utf-8")
    original = fields(text)
    version = original["Version"]
    lockfile = root / "upstream.json"
    if lockfile.exists():
        lock = json.loads(lockfile.read_text(encoding="utf-8"))
        if lock.get("repository") != "InseeFrLab/rtauargus":
            raise ValueError("Unexpected upstream repository")
        if not NUMERIC_VERSION.fullmatch(lock.get("version", "")):
            raise ValueError("Invalid upstream version")
        if not re.fullmatch(r"[0-9a-f]{40}", lock.get("revision", "")):
            raise ValueError("Invalid upstream revision")
        if not re.fullmatch(r"[0-9a-f]{64}", lock.get("description_sha256", "")):
            raise ValueError("Invalid upstream DESCRIPTION hash")
        version = lock["version"] + "-" + native
        text = set_field(text, "Config/rtauargus/upstream-version", lock["version"])
        text = set_field(text, "Config/rtauargus/upstream-revision", lock["revision"])
    elif original["Package"] == "tauargusengine":
        version = native
    authors = original["Authors@R"]
    added = [entry for entry in CONTRIBUTORS if entry not in authors]
    if added:
        # CRAN expects person() or a flat c(person(...), person(...)) call.
        # Retain the original people when appending component attribution.
        authors = authors.strip()
        if authors.startswith("c(") and authors.endswith(")"):
            authors = authors[:-1].rstrip() + ",\n" + ",\n".join(added) + "\n)"
        else:
            authors = "c(\n" + authors + ",\n" + ",\n".join(added) + "\n)"
    for name, value in {
        "Version": version,
        "Authors@R": authors,
        "Config/tauargus/native-version": native,
        "Config/tauargus/linkage": "static",
        "StagedInstall": None,
    }.items():
        text = set_field(text, name, value)
    cmake = root / "tools/highs/CMakeLists.txt"
    if cmake.exists():
        build = cmake.read_text(encoding="utf-8")
        if "CITATION.cff" in build:
            if not (cmake.parent / "highs.cff").is_file():
                raise ValueError("Missing renamed HiGHS citation metadata")
            build = ("# R packaging change, 2026-11-04: citation metadata is named highs.cff.\n"
                     + build.replace("CITATION.cff", "highs.cff"))
            cmake.write_text(build, encoding="utf-8")
    description.write_text(text, encoding="utf-8")
    return version


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", type=Path)
    parser.add_argument("native_version")
    args = parser.parse_args()
    print(update(args.package, args.native_version))
