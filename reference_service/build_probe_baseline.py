#!/usr/bin/env python3
"""Build app/s0_evidence/probe_baseline.json from the S0 search logs (2020-2026 module hit counts, no network).

Each S0 `search_log.json` records, for the module's own Europe PMC query, `hit_count_by_year` (same common
filter and journal whitelist as the reference service).  The first probe run imports these as the historical
baseline of the module series; later probes only add new rows.

    python build_probe_baseline.py            # write
    python build_probe_baseline.py --check    # exit 1 if stale
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
OUT = HERE / "app" / "s0_evidence" / "probe_baseline.json"
SCHEMA = "omicstat.reference.probe-baseline.v1"


def roots() -> list[Path]:
    """The merged repo first, then the S0 lane worktrees that hold the M3/M4 search logs (read-only)."""
    return [REPO] + [Path.home() / name for name in ("omic-s0-a", "omic-s0-b", "omic-s0-c")]


def build() -> dict:
    method_map = json.loads((HERE / "app" / "method_map.json").read_text(encoding="utf-8"))
    modules = [m["module"] for m in method_map["modules"]]
    rows, sources, missing = [], {}, []
    for module in modules:
        path = next((r / "acceptance" / "exemplars" / module / "literature" / "search_log.json" for r in roots()
                     if (r / "acceptance" / "exemplars" / module / "literature" / "search_log.json").is_file()), None)
        if path is None:
            missing.append(module)
            continue
        raw = path.read_bytes()
        log = json.loads(raw.decode("utf-8"))
        log_date = log["date"]
        qsha = hashlib.sha256(log["query"].encode("utf-8")).hexdigest()
        sources[module] = {"log_date": log_date, "search_log_sha256": hashlib.sha256(raw).hexdigest()}
        for year, count in sorted(log["hit_count_by_year"].items()):
            year = int(year)
            window_end = log_date if year == int(log_date[:4]) else f"{year}-12-31"
            rows.append({"term": module, "term_kind": "module", "year": year, "window_end": window_end,
                         "hit_count": int(count), "query_sha256": qsha, "source": "s0_search_log:" + log_date})
    return {"schema": SCHEMA, "note": "Module-query hit counts per publication year from the S0 search logs (same filter and journal whitelist as the service). The current-year value ends at the log date, not at year end.",
            "modules_without_log": missing, "sources": sources, "rows": rows}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    text = json.dumps(build(), ensure_ascii=False, indent=1, sort_keys=True) + "\n"
    if args.check:
        ok = OUT.exists() and OUT.read_text(encoding="utf-8") == text
        print("probe_baseline.json is current" if ok else "probe_baseline.json is stale")
        return 0 if ok else 1
    OUT.write_text(text, encoding="utf-8", newline="\n")
    doc = json.loads(text)
    print(f"{OUT.name}: {len(doc['rows'])} rows, {len(doc['sources'])} modules, without log: {doc['modules_without_log']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
