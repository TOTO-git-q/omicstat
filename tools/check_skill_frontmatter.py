#!/usr/bin/env python3
"""Every skills/<module>/SKILL.md must start with YAML front matter that parses
and carries `name` and `description`.

The MCP server reads the one-line description from this block for
list_modules; an unquoted colon inside the description silently produced an
empty summary once (limma-voom, found by the full-suite run on 2026-10-01).
This check runs without PyYAML: it validates the shape that the suite uses --
a block of `key: value` lines where a value is a scalar, a quoted scalar or a
`>`/`|` block -- and refuses any scalar value that contains `: ` or ends with
`:` unless it is quoted.

Usage: python3 tools/check_skill_frontmatter.py [suite_root]
Exit 0 when every file passes; 1 otherwise (problems are printed).
"""
import glob
import os
import re
import sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
KEY = re.compile(r"^([A-Za-z_][A-Za-z0-9_-]*):(?:\s+(.*))?$")


def check(path):
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    if not text.startswith("---\n"):
        return ["no YAML front matter at the top of the file"]
    end = text.find("\n---\n", 4)
    if end < 0:
        return ["front matter is not closed with a '---' line"]
    block = text[4:end].split("\n")
    problems, keys, i = [], {}, 0
    while i < len(block):
        line = block[i]
        if not line.strip():
            i += 1
            continue
        m = KEY.match(line)
        if not m:
            problems.append("line %d is not 'key: value': %r" % (i + 2, line[:80]))
            i += 1
            continue
        key, value = m.group(1), (m.group(2) or "").strip()
        if value in (">", "|", ">-", "|-"):
            # folded/literal block: the following indented lines belong to it
            j = i + 1
            while j < len(block) and (not block[j].strip() or block[j].startswith((" ", "\t"))):
                j += 1
            body = " ".join(x.strip() for x in block[i + 1:j] if x.strip())
            keys[key] = body
            i = j
            continue
        if value and not (value[0] in "\"'" and value[-1] == value[0] and len(value) > 1):
            if ": " in value or value.endswith(":") or value[0] in "[{&*!|>%@`":
                problems.append("line %d: value of '%s' must be quoted (it contains ': ' or starts with a YAML indicator): %r"
                                % (i + 2, key, value[:80]))
        keys[key] = value
        i += 1
    for required in ("name", "description"):
        if not keys.get(required):
            problems.append("front matter lacks a non-empty '%s'" % required)
    expected = os.path.basename(os.path.dirname(path))
    if keys.get("name") and keys["name"].strip("\"'") != expected:
        problems.append("name %r differs from the directory name %r" % (keys["name"], expected))
    return problems


def main():
    files = sorted(glob.glob(os.path.join(ROOT, "skills", "*", "SKILL.md")))
    bad = 0
    for path in files:
        for problem in check(path):
            bad += 1
            print("FAIL %s: %s" % (os.path.relpath(path, ROOT), problem))
    print("%d SKILL.md front matter(s) checked; %d problem(s)" % (len(files), bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
