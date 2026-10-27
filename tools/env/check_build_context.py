#!/usr/bin/env python3
"""Offline COPY/ADD/bind context audit; absent archives remain a real failure.

This is a conservative static check, not a Docker build. It supports the local
syntax used by this repository and refuses unresolved variables/remote ADDs.
Dockerfile-specific ignore files take precedence over the context root file.
"""
from __future__ import annotations
import argparse
import fnmatch
import hashlib
import json
import pathlib
import re
import shlex
from functools import lru_cache


def _match(pattern, path):
    pats = tuple(pattern.split("/"))
    parts = tuple(path.split("/"))
    @lru_cache(None)
    def visit(i, j):
        if i == len(pats):
            return j == len(parts)
        if pats[i] == "**":
            return visit(i + 1, j) or (j < len(parts) and visit(i, j + 1))
        return j < len(parts) and fnmatch.fnmatchcase(parts[j], pats[i]) and visit(i + 1, j + 1)
    return visit(0, 0)


def ignore_rules(path):
    if not path.is_file():
        return []
    rules = []
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        if line.startswith("#") or not line.strip():
            continue
        line = line.strip()
        negate = line.startswith("!")
        line = line[1:] if negate else line
        line = line.strip("/")
        if line == ".":
            continue
        if not line or "\\" in line or ".." in line.split("/"):
            raise ValueError("unsupported/unsafe dockerignore pattern: " + line)
        rules.append((line, negate))
    return rules


def included(path, rules):
    parts = pathlib.PurePosixPath(path).parts
    prefixes = ["/".join(parts[:i]) for i in range(1, len(parts) + 1)]
    keep = True
    for pattern, negate in rules:
        if any(_match(pattern, prefix) for prefix in prefixes):
            keep = negate
    return keep


def references(dockerfile):
    logical = []
    current = ""
    for line in dockerfile.read_text().splitlines():
        if re.match(r"^#\s*escape\s*=",line,re.I) and line.split("=",1)[1].strip() != "\\":
            raise ValueError("unsupported Dockerfile escape directive")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if line.rstrip().endswith("\\"):
            current += line.rstrip()[:-1] + " "
            continue
        logical.append(current + line)
        current = ""
    if current:
        raise ValueError("unfinished Dockerfile continuation")
    refs = []
    for line in logical:
        instr, _, args = line.strip().partition(" ")
        instr = instr.upper()
        if instr == "RUN":
            for mount in re.findall(r"--mount=([^\s]+)", args):
                opts = dict(p.split("=", 1) if "=" in p else (p, True) for p in mount.split(","))
                if opts.get("type", "bind") == "bind" and "from" not in opts:
                    refs.append(str(opts.get("source", opts.get("src", "."))))
            continue
        if instr not in ("COPY", "ADD"):
            continue
        stage = False
        while args.startswith("--"):
            flag, _, args = args.partition(" ")
            args = args.lstrip()
            key = flag.split("=", 1)[0]
            if key == "--from":
                stage = True
                if "=" not in flag:
                    _, _, args = args.partition(" ")
                    args = args.lstrip()
            elif key not in ("--chown", "--chmod", "--link", "--parents"):
                raise ValueError("unsupported COPY/ADD flag: " + flag)
            elif key in ("--chown", "--chmod") and "=" not in flag:
                _, _, args = args.partition(" ")
                args = args.lstrip()
        values = json.loads(args) if args.startswith("[") else shlex.split(args)
        if not isinstance(values, list) or len(values) < 2 or not all(isinstance(v, str) for v in values):
            raise ValueError("COPY/ADD requires explicit source and destination")
        if not stage:
            refs.extend(values[:-1])
    for value in refs:
        p = pathlib.PurePosixPath(value)
        if "$" in value or "://" in value or p.is_absolute() or ".." in p.parts or "\\" in value:
            raise ValueError("unresolved/remote/unsafe build context source: " + value)
    return refs


def check(dockerfile, context, required_files=(), expected_files=None):
    context = pathlib.Path(context).resolve()
    dockerfile = pathlib.Path(dockerfile).resolve()
    specific = dockerfile.with_name(dockerfile.name + ".dockerignore")
    ignore = specific if specific.is_file() else context / ".dockerignore"
    rules = ignore_rules(ignore)
    refs = references(dockerfile)
    errors = []
    checked = {}
    missing = []
    excluded = []
    def inspect(path, explicit=False):
        rel = path.relative_to(context).as_posix()
        if path.is_symlink() or any(p.is_symlink() for p in path.parents if p != context and p.is_relative_to(context)):
            errors.append("symlink build input requires explicit review: " + rel)
            return False
        if not included(rel, rules):
            if explicit:
                excluded.append(rel)
                errors.append("build input excluded by dockerignore: " + rel)
            return False
        if path.is_file():
            checked[rel] = hashlib.sha256(path.read_bytes()).hexdigest()
            return True
        return False
    for source in refs:
        pattern = source.removeprefix("./").rstrip("/") or "."
        paths = [context] if pattern == "." else sorted(context.glob(pattern))
        if not paths:
            missing.append(source)
            errors.append("missing build context source: " + source)
            continue
        for path in paths:
            if path.is_symlink():
                inspect(path, True)
            elif path.is_dir():
                present = [p for p in path.rglob("*") if p.is_file() or p.is_symlink()]
                kept = [inspect(p) for p in present]
                if not any(kept):
                    errors.append("directory has no included regular build input: " + source)
            else:
                inspect(path, True)
        # A directory COPY in a partial checkout must not look complete merely
        # because one small child exists. An external verified Git inventory can
        # bind the expected tracked inputs without fabricating their bytes.
        for value in expected_files or ():
            p = pathlib.PurePosixPath(value)
            if p.is_absolute() or ".." in p.parts or "\\" in value:
                raise ValueError("unsafe inventory build input")
            rel = p.as_posix()
            selected = pattern == "." or _match(pattern, rel) or any(
                _match(pattern, "/".join(p.parts[:i])) for i in range(1, len(p.parts)))
            if selected and included(rel, rules) and not (context / p).is_file():
                missing.append(rel)
                errors.append("missing inventoried build input: " + rel)
    for value in required_files:
        p = pathlib.PurePosixPath(value)
        if p.is_absolute() or ".." in p.parts or "\\" in value:
            raise ValueError("unsafe required build input")
        path = context / p
        if not path.is_file():
            missing.append(value)
            errors.append("missing required build input: " + value)
        else:
            inspect(path, True)
    return {"schema": "omicstat.build-context.v1", "dockerfile": str(dockerfile),
            "context": str(context), "ignore_file": str(ignore), "references": refs,
            "ok": not errors, "errors": sorted(set(errors)), "missing": sorted(set(missing)),
            "excluded": sorted(set(excluded)), "included_files_sha256": checked,
            "expected_inventory_supplied": expected_files is not None,
            "docker_build_executed": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dockerfile", type=pathlib.Path, required=True)
    parser.add_argument("--context", type=pathlib.Path, required=True)
    parser.add_argument("--required-file", action="append", default=[])
    parser.add_argument("--out", type=pathlib.Path)
    args = parser.parse_args()
    result = check(args.dockerfile, args.context, args.required_file)
    text = json.dumps(result, indent=2) + "\n"
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(text)
    print(text, end="")
    return int(not result["ok"])


if __name__ == "__main__":
    raise SystemExit(main())
