#!/usr/bin/env python3
"""Write and verify the engine bundle provenance manifest.

The engine CI builds the superbuild, installs it into a bundle
directory and uploads the result as an artifact. The manifest records
what the bundle contains (every file with size and SHA256) and how it
was built (engine commit, HiGHS version, platform, generator,
compiler, workflow run), so a downloaded bundle can be checked for
integrity without re-running the build.

Commands:
    write   <bundle> [--meta k=v ...]   walk the bundle, write MANIFEST.json
    verify  <bundle>                    recompute every hash, fail on a
                                        missing file, a mismatch or an
                                        empty file set

The manifest is machine-generated JSON (this script, stdlib only). It
never reads or writes secrets, and it does not hash itself: MANIFEST.json
is excluded from the file set.
"""

import argparse
import hashlib
import json
import os
import sys

MANIFEST_NAME = "MANIFEST.json"
FORMAT = "tauargus-engine-bundle/1"


def sha256(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def cmd_write(args: argparse.Namespace) -> int:
    files = {}
    for root, _dirs, names in os.walk(args.bundle):
        for name in sorted(names):
            path = os.path.join(root, name)
            rel = os.path.relpath(path, args.bundle).replace(os.sep, "/")
            if rel == MANIFEST_NAME:
                continue
            files[rel] = {"sha256": sha256(path), "size": os.path.getsize(path)}
    if not files:
        print(f"refusing to write a manifest: no files under {args.bundle}",
              file=sys.stderr)
        return 1
    metadata = {}
    for kv in args.meta:
        key, sep, value = kv.partition("=")
        if not sep or not key:
            print(f"bad --meta entry (expected key=value): {kv}", file=sys.stderr)
            return 1
        metadata[key] = value
    manifest = {
        "format": FORMAT,
        "generated_by": "scripts/engine_manifest.py",
        "metadata": metadata,
        "files": files,
    }
    out = os.path.join(args.bundle, MANIFEST_NAME)
    with open(out, "w") as f:
        json.dump(manifest, f, indent=2, sort_keys=True)
        f.write("\n")
    print(f"manifest written: {len(files)} files")
    return 0


def cmd_verify(args: argparse.Namespace) -> int:
    path = os.path.join(args.bundle, MANIFEST_NAME)
    try:
        with open(path) as f:
            manifest = json.load(f)
    except (OSError, json.JSONDecodeError) as exc:
        print(f"cannot read manifest {path}: {exc}", file=sys.stderr)
        return 1
    files = manifest.get("files")
    if not isinstance(files, dict) or not files:
        print("manifest lists no files; refusing to verify an empty set",
              file=sys.stderr)
        return 1
    problems = 0
    for rel in sorted(files):
        record = files[rel]
        file_path = os.path.join(args.bundle, rel)
        if not os.path.isfile(file_path):
            print(f"MISSING   {rel}", file=sys.stderr)
            problems += 1
            continue
        if record.get("size") != os.path.getsize(file_path):
            print(f"SIZE      {rel}", file=sys.stderr)
            problems += 1
        elif sha256(file_path) != record.get("sha256"):
            print(f"MISMATCH  {rel}", file=sys.stderr)
            problems += 1
    if problems:
        print(f"verification failed: {problems} problem(s)", file=sys.stderr)
        return 1
    print(f"verified {len(files)} files against {MANIFEST_NAME}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    for name, func, meta in (("write", cmd_write, True),
                             ("verify", cmd_verify, False)):
        p = sub.add_parser(name)
        p.add_argument("bundle")
        if meta:
            p.add_argument("--meta", action="append", default=[],
                           help="key=value provenance field (repeatable)")
        p.set_defaults(func=func)
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
