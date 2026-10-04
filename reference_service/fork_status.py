#!/usr/bin/env python3
"""Report the fork's provenance: which app/ files are unchanged, modified, removed or added relative to
the fork base (FORK_BASE.json = medstat-reference 07fdebd), and check that every change is declared in
FORK_CHANGES.json (and every declared change is real).

  python fork_status.py            # summary + consistency check (exit 1 on an undeclared/stale entry)
  python fork_status.py --verify-base --repo <medstat-reference>   # also re-derive FORK_BASE hashes from git

The v2.1 commits 7f0a999 / c1f39aa (unfixed audit finding) are not part of the base and must never be merged.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import subprocess
import sys
import tarfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
REFUSED = ("7f0a999", "c1f39aa", "003f630")


def tree_files(app: Path) -> dict[str, str]:
    out = {}
    for p in app.rglob("*"):
        rel = p.relative_to(app)
        if p.is_file() and "__pycache__" not in rel.parts and ".test-scratch" not in rel.parts and rel.parts[0] not in ("data", "logs"):
            out[rel.as_posix()] = hashlib.sha256(p.read_bytes()).hexdigest()
    return out


def classify() -> dict:
    base = json.loads((HERE / "FORK_BASE.json").read_text(encoding="utf-8"))
    declared = json.loads((HERE / "FORK_CHANGES.json").read_text(encoding="utf-8"))
    now = tree_files(HERE / base["fork_dir"])
    actual = {
        "unchanged": sorted(f for f, h in base["files"].items() if now.get(f) == h),
        "modified": sorted(f for f, h in base["files"].items() if f in now and now[f] != h),
        "removed": sorted(f for f in base["files"] if f not in now),
        "added": sorted(f for f in now if f not in base["files"]),
    }
    problems = []
    for kind in ("modified", "removed", "added"):
        want, have = set(declared[kind]), set(actual[kind])
        problems += [f"undeclared {kind}: {f}" for f in sorted(have - want)]
        problems += [f"declared {kind} but not so in the tree: {f}" for f in sorted(want - have)]
    return {"base_commit": base["base_commit"], "counts": {k: len(v) for k, v in actual.items()},
            "actual": actual, "problems": problems}


def verify_base(repo: str) -> list[str]:
    base = json.loads((HERE / "FORK_BASE.json").read_text(encoding="utf-8"))
    full = subprocess.run(["git", "-C", repo, "rev-parse", base["base_commit"]], check=True, capture_output=True, text=True).stdout.strip()
    if any(full.startswith(x) for x in REFUSED):
        return ["base commit is a refused v2.1 commit"]
    blob = subprocess.run(["git", "-C", repo, "archive", "--format=tar", full], check=True, capture_output=True).stdout
    with tarfile.open(fileobj=io.BytesIO(blob)) as tar:
        got = {m.name: hashlib.sha256(tar.extractfile(m).read()).hexdigest() for m in tar.getmembers() if m.isfile()}
    return [] if got == base["files"] else ["FORK_BASE.json hashes differ from git archive of the base commit"]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--verify-base", action="store_true")
    ap.add_argument("--repo")
    args = ap.parse_args()
    report = classify()
    if args.verify_base:
        report["problems"] += verify_base(args.repo)
    print(json.dumps({k: v for k, v in report.items() if k != "actual"}, indent=1))
    return 1 if report["problems"] else 0


if __name__ == "__main__":
    sys.exit(main())
