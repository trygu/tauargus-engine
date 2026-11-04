#!/usr/bin/env python3
"""Adapt staged library sources to the R host. Original checkouts stay intact."""
# SPDX-License-Identifier: EUPL-1.2
import re
import shutil
import sys
from pathlib import Path

root, header = map(Path, sys.argv[1:])
functions = {
    name: "rta_host_" + name
    for name in (
        "printf", "vprintf", "fprintf", "vfprintf", "puts", "fputs",
        "putchar", "fputc", "fwrite", "fflush", "fclose", "freopen",
        "fileno", "exit", "abort",
    )
}
functions.update({
    "stdout": "rta_host_stdout()", "stderr": "rta_host_stderr()",
    "cout": "rta_host_cout()", "cerr": "rta_host_cerr()", "clog": "rta_host_clog()",
})
names = "|".join(functions)
qualified = re.compile(r"\bstd\s*::\s*(" + names + r")\b")
using = re.compile(r"\busing\s+std\s*::\s*(" + names + r")\s*;")
plain = re.compile(r"\b(" + names + r")\b")
# Preserve comments, ordinary string/character literals and C++ raw strings.
literal = re.compile(
    r'(//[^\n]*|/\*[\s\S]*?\*/|R"(?P<raw>[^ ()\\\t\r\n]{0,16})\('
    r'[\s\S]*?\)(?P=raw)"|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\')'
)
def adapt(code):
    code = qualified.sub(lambda m: functions[m[1]], using.sub("", code))
    def replace(match):
        # printf is an attribute grammar keyword in format(printf, ...).
        if match[1] == "printf" and re.search(r"\bformat\s*\(\s*$", code[:match.start()]):
            return match[0]
        return functions[match[1]]
    return plain.sub(replace, code)

marker = "/* R host adaptation, 2026-11-04: console and termination calls. */\n"
changed = 0
for path in list(root.rglob("*")):
    if path.suffix not in {".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp"}:
        continue
    if path.name == header.name:
        continue
    text = path.read_text(encoding="utf-8", errors="surrogateescape")
    if text.startswith(marker):
        continue
    pieces, start = [], 0
    for match in literal.finditer(text):
        code = text[start:match.start()]
        pieces.extend((adapt(code), match[0]))
        start = match.end()
    pieces.append(adapt(text[start:]))
    adapted = "".join(pieces)
    if adapted != text:
        path.write_text(marker + '#include "rta_host_io.h"\n' + adapted,
                        encoding="utf-8", errors="surrogateescape")
        shutil.copyfile(header, path.parent / header.name)
        changed += 1
print(f"R host adaptation: {changed} source files")
