#!/usr/bin/env python3
"""Rehearse a candidate watch profile with the service's own gates on a temporary store (nothing is written to /data).

Run it in the service image (network allowed, about 13 requests per profile, 1 s apart):
  docker run --rm --read-only --tmpfs /tmp --user 1000:1000 -v <release>/watch_profiles:/profiles:ro \
      -v <release>/check_watch_profile.py:/check.py:ro -w /app IMAGE python /check.py /profiles/macs.profile.json

A profile is FEASIBLE when the live query returns whitelisted hits and, among the first ATTEMPTS full texts,
(a) at least MIN_SCREENED pass every gate (Methods signal, countable licence) and (b) at least half of the papers that
reach the licence gate are countable (CC-BY / CC-BY-NC / CC0).  The verdict is evidence for the owner, never an acceptance.
"""
from __future__ import annotations

import datetime as dt
import json
import sys
import tempfile
import time
from collections import Counter
from pathlib import Path

sys.path.insert(0, "/app" if Path("/app/harvest.py").exists() else str(Path(__file__).resolve().parent / "app"))
import discovery  # noqa: E402
import harvest  # noqa: E402

ATTEMPTS, MIN_SCREENED, MIN_CLEAN_SHARE = 12, 3, 0.5


def polite_fetch(url: str) -> bytes:
    time.sleep(1.0)
    return harvest._direct_fetch(url, timeout=30)


def check(path: Path) -> dict:
    raw = json.loads(path.read_text(encoding="utf-8"))
    profile = discovery.validate_profile(raw)
    config, journals = discovery.load_profiles(), discovery.load_journals()
    today = dt.date.today()
    with tempfile.TemporaryDirectory() as tmp:
        store = harvest.HarvestStore(Path(tmp) / "h.sqlite")
        run = harvest._Run(store, harvest._day(), transport="direct", max_requests=60, fetcher=polite_fetch)
        query = discovery.build_query(profile, config, journals, today=today)
        payload = harvest._search(run, query, None)
        results = sorted(payload["resultList"]["result"], key=lambda x: harvest._tier_key(x, journals))
        outcomes: Counter = Counter()
        screened = []
        for item in results[:ATTEMPTS]:
            outcome, record, _ = harvest._screen_one(run, item, profile, journals, set(), today)
            outcomes[outcome] += 1
            if outcome == "screened":
                screened.append({"pmid": record.get("pmid"), "journal": record.get("journal"), "licence": record.get("licence"), "year": record.get("year")})
    clean = outcomes.get("screened", 0) + outcomes.get("forget:off_topic", 0)
    restricted = outcomes.get("metadata_only:rights_restricted", 0) + outcomes.get("metadata_only:rights_unconfirmed", 0)
    share = (clean / (clean + restricted)) if (clean + restricted) else None
    feasible = bool(payload.get("hitCount")) and outcomes.get("screened", 0) >= MIN_SCREENED and share is not None and share >= MIN_CLEAN_SHARE
    return {"profile": raw["module"], "checked_on": today.isoformat(), "live_hit_count": payload.get("hitCount"),
            "attempted_fulltexts": min(ATTEMPTS, len(results)), "outcomes": dict(outcomes), "screened": outcomes.get("screened", 0),
            "licence_clean_share": None if share is None else round(share, 2), "requests": run.request_count, "feasible": feasible,
            "screened_papers": screened, "criteria": f"hits > 0, >= {MIN_SCREENED} screened of the first {ATTEMPTS}, licence-clean share >= {MIN_CLEAN_SHARE}"}


if __name__ == "__main__":
    print(json.dumps(check(Path(sys.argv[1])), indent=1))
