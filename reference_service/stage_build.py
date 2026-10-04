#!/usr/bin/env python3
"""Assemble the Docker build context of omicstat-reference from the fork in app/.

  python stage_build.py --out <dir> [--commit <omic-MCP commit>]

1. Runs the fork provenance check (fork_status.classify): every change against the base
   medstat-reference 07fdebd must be declared in FORK_CHANGES.json; refuses otherwise.
2. Copies the app/ tree (without caches, data or logs) to <dir>, which must not exist or be empty.
3. Writes <dir>/STAGED.json (fork base, omic-MCP commit, hashes of the configuration files); it ends
   up at /app/STAGED.json in the image, so a running container can be traced to its inputs.
"""
from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import fork_status  # noqa: E402

CONFIG_FILES = ("journals.json", "discovery_profiles.json", "method_map.json", "decision_rules.json",
                "seed/catalog.json", "schemas/literature_request.v1.json")


def stage(out: Path, commit: str | None = None) -> dict:
    report = fork_status.classify()
    if report["problems"]:
        raise SystemExit("fork provenance check failed: %s" % report["problems"][:10])
    if out.exists() and any(out.iterdir()):
        raise SystemExit("output directory must be empty: %s" % out)
    app = HERE / "app"
    files = fork_status.tree_files(app)
    out.mkdir(parents=True, exist_ok=True)
    for name in files:
        target = out / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(app / name, target)
    record = {"schema": "omicstat.reference-service.staged.v1", "service": "omicstat_reference",
              "fork_base": "medstat-reference " + report["base_commit"], "omic_mcp_commit": commit,
              "fork_counts": report["counts"], "config": {n: files[n] for n in CONFIG_FILES}}
    (out / "STAGED.json").write_text(json.dumps(record, indent=1, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
    return record


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--commit")
    args = ap.parse_args()
    record = stage(args.out, args.commit)
    print(json.dumps({"status": "staged", "out": str(args.out), **record}, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
