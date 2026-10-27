"""Monthly coverage probe (omicstat fork, coverage upgrade).

For every rank-eligible lexicon term, one Europe PMC section-level query returns a ``hitCount`` (never a
record, never full text): "how many whitelisted, open-access, non-review papers since 2020 name this tool in
their Methods".  The same filter, journal whitelist and date windows as the harvester are used, so a term's
share of the whitelist corpus is comparable with our own modules' shares.  Counts are written to
``method_probe`` (harvest.sqlite).  Nothing here changes a module, a profile, a default or a route.

Windows: every completed calendar year (window_end = Dec 31) and the current year up to the end of the
previous month (so a window is stable for the whole month).  Budget: at most ``BUDGET_PER_MONTH`` HTTP
requests per month (failures count), >= ``SPACING_SECONDS`` between requests, a few dozen per worker cycle,
so the 600 s worker heartbeat never stalls.  The plan is ordered by value: denominators first, then each
term's last full year and its year-to-date window, then the two-year-old history of family members that
feed the family-trend alerts.  Whatever the budget cannot reach waits for the next month.
"""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import re
import time
from pathlib import Path
from typing import Any, Callable, Mapping
from urllib.parse import urlencode

import discovery
import lexicon

BUDGET_PER_MONTH = 400
SPACING_SECONDS = 1.0
REQUEST_TIMEOUT_SECONDS = 30      # section queries over the whole whitelist can take several seconds
MAX_CONSECUTIVE_FAILURES = 3     # a hiccup of Europe PMC ends the chunk instead of burning the monthly budget
CHUNK_REQUESTS = 60
LEASE_SECONDS = 420
FIRST_YEAR = 2020
BASELINE_PATH = Path(__file__).with_name("s0_evidence") / "probe_baseline.json"
BASELINE_SCHEMA = "omicstat.reference.probe-baseline.v1"
TOTAL_TERM = "__whitelist_total__"
# Families whose members get a yearly history (family-trend alerts compare their shares year by year).
TREND_FAMILIES = ("bulk-de", "batch-correction", "enrichment", "sc-framework", "sc-integration", "sc-annotation",
                  "sc-trajectory", "rna-velocity", "cell-communication", "immune-deconvolution", "spatial-domain",
                  "spatial-deconvolution", "spatial-svg", "regulon-tf", "doublet-detection", "coexpression")
_FIRST_PDATE = re.compile(r"FIRST_PDATE:\[[^\]]*\]")


def _month(day: dt.date) -> str:
    return day.strftime("%Y-%m")


def windows(today: dt.date) -> list[tuple[int, str, str]]:
    """[(year, start, end)] oldest first: completed years, then the current year up to the previous month end."""
    out = [(y, f"{y}-01-01", f"{y}-12-31") for y in range(FIRST_YEAR, today.year)]
    last_month_end = today.replace(day=1) - dt.timedelta(days=1)
    if last_month_end.year == today.year:
        out.append((today.year, f"{today.year}-01-01", last_month_end.isoformat()))
    return out


def window_query(filter_text: str, start: str, end: str) -> str:
    return _FIRST_PDATE.sub(f"FIRST_PDATE:[{start} TO {end}]", filter_text.replace("{today}", end))


def term_query(fragment: str | None, filter_text: str, journals: Mapping[str, Any], start: str, end: str) -> str:
    """Section query (or whitelist total when fragment is None) + uniform filter + journal whitelist for one window."""
    parts = [fragment] if fragment else []
    parts += [window_query(filter_text, start, end), discovery.journal_clause(journals)]
    return " AND ".join(parts)


def query_url(query: str) -> str:
    # hitCount only: one lite record is requested, nothing is read from it
    return "https://www.ebi.ac.uk/europepmc/webservices/rest/search?" + urlencode(
        {"query": query, "format": "json", "pageSize": 1, "resultType": "lite"})


def sha(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


# ------------------------------------------------------------------ plan

def plan(store: Any, today: dt.date, *, config: Mapping[str, Any], journals: Mapping[str, Any], lex: Mapping[str, Any],
         method_map: Mapping[str, Any]) -> list[dict[str, Any]]:
    """Ordered list of probe tasks still to do this month (done = a stored row with the same term/kind/window)."""
    wins = windows(today)
    filt = config["filters"]["common_filter"]
    month = _month(today)
    done = store.probe_done(month)
    tasks: list[dict[str, Any]] = []
    queued: set[tuple[str, str, int, str]] = set()

    def add(term: str, kind: str, fragment: str | None, win: tuple[int, str, str], priority: int) -> None:
        year, start, end = win
        key = (term, kind, year, end)
        if key in done or key in queued:
            return
        queued.add(key)
        query = term_query(fragment, filt, journals, start, end)
        tasks.append({"term": term, "kind": kind, "year": year, "start": start, "end": end, "query": query, "priority": priority})

    for win in wins:                                   # 0: denominators (whitelist total per window)
        add(TOTAL_TERM, "total", None, win, 0)
    for term, year, end in store.baseline_total_needs():  # the S0 baseline's current-year window ends on its own date
        if (TOTAL_TERM, "total", year, end) not in done:
            add(TOTAL_TERM, "total", None, (year, f"{year}-01-01", end), 0)
    eligible = [e for e in lex["entries"] if e.get("rank_eligible") and e.get("epmc_query")]
    recent = [w for w in wins if w[0] >= wins[-1][0] - 1] if wins else []   # last full year + year to date
    for entry in eligible:                             # 1: each term's last full year and year to date, together
        for win in recent:
            add(entry["token"], "candidate" if not entry["our_module"] else "family_member", entry["epmc_query"], win, 1)
    for module, profile in sorted(config["profiles"].items()):   # 2: module series the S0 baseline does not cover
        have = store.probe_years(module, "module")
        latest = store.probe_latest_end(module, "module")
        for win in wins:
            if win[0] < today.year and win[0] in have:
                continue
            if win[0] == today.year and latest is not None and (today - dt.date.fromisoformat(latest)).days <= 60:
                continue
            add(module, "module", "(" + profile["epmc_query"] + ")", win, 2)
    history = [w for w in wins if w not in recent]
    members = [e for e in eligible if e["family"] in TREND_FAMILIES]
    for win in reversed(history):                      # 3: yearly history of trend-family members, newest year first
        for entry in members:
            add(entry["token"], "candidate" if not entry["our_module"] else "family_member", entry["epmc_query"], win, 3)
    tasks.sort(key=lambda t: t["priority"])
    return tasks


# ------------------------------------------------------------------ run

def parse_hit_count(raw: bytes) -> int:
    payload = json.loads(raw.decode("utf-8"))
    count = payload.get("hitCount") if isinstance(payload, dict) else None
    if not isinstance(count, int) or isinstance(count, bool) or count < 0:
        raise ValueError("no hitCount in the Europe PMC answer; not interpreted as zero")
    return count


def import_baseline(store: Any, path: str | Path | None = None) -> int:
    p = Path(path) if path is not None else BASELINE_PATH
    try:
        raw = json.loads(p.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return 0
    if not isinstance(raw, Mapping) or raw.get("schema") != BASELINE_SCHEMA:
        return 0
    return store.import_probe_rows(raw["rows"], run_month="baseline")


def run_probe(store: Any, *, now: dt.datetime | None = None, fetcher: Callable[[str], bytes] | None = None,
              sleep: Callable[[float], None] = time.sleep, max_requests: int = CHUNK_REQUESTS, budget: int = BUDGET_PER_MONTH,
              dry_run: bool = False, config: Mapping[str, Any] | None = None, journals: Mapping[str, Any] | None = None,
              lex: Mapping[str, Any] | None = None, method_map: Mapping[str, Any] | None = None,
              baseline_path: str | Path | None = None, owner: str = "probe") -> dict[str, Any]:
    """One bounded chunk of the month's probe plan.  Safe to call every worker cycle: a finished month is a no-op."""
    import harvest
    now = now or dt.datetime.now(dt.timezone.utc)
    today = now.astimezone(harvest.TZ_SHANGHAI).date()
    month = _month(today)
    config = config or discovery.load_profiles()
    journals = journals or discovery.load_journals()
    lex = lex or lexicon.default_lexicon()
    method_map = method_map or harvest._load_method_map()
    if not dry_run and not store.acquire_lease("probe:" + month, owner, seconds=LEASE_SECONDS):
        return {"month": month, "state": "lease_busy", "requests": 0}
    try:
        imported = import_baseline(store, baseline_path)   # no request; idempotent
        tasks = plan(store, today, config=config, journals=journals, lex=lex, method_map=method_map)
        used = store.probe_requests(month)
        if dry_run:
            return {"month": month, "state": "dry_run", "tasks_due": len(tasks), "budget_used": used, "budget": budget,
                    "by_priority": {p: sum(1 for t in tasks if t["priority"] == p) for p in sorted({t["priority"] for t in tasks})},
                    "sample_query": tasks[0]["query"] if tasks else None}
        failures, consecutive, last, done_ok = 0, 0, 0.0, 0
        counter = {"n": 0}
        raw_fetch = fetcher if fetcher is not None else (lambda url: harvest._direct_fetch(url, timeout=REQUEST_TIMEOUT_SECONDS))

        def counted(url: str) -> bytes:
            counter["n"] += 1          # every HTTP attempt, retries included, spends budget
            return raw_fetch(url)
        for task in tasks:
            if counter["n"] >= max_requests or used + counter["n"] >= budget:
                break
            if last:
                wait = SPACING_SECONDS - (time.monotonic() - last)
                if wait > 0:
                    sleep(wait)
            last = time.monotonic()
            try:
                count = parse_hit_count(counted(query_url(task["query"])))   # no immediate retry: a retry would spend budget twice
            except (harvest.HarvestError, ValueError, UnicodeDecodeError) as exc:
                failures += 1
                consecutive += 1
                store.probe_note_failure(month, task["term"], getattr(exc, "code", type(exc).__name__))
                if consecutive >= MAX_CONSECUTIVE_FAILURES:
                    break
                continue
            consecutive = 0
            store.add_probe_row(month, task["term"], task["kind"], task["year"], task["end"], count, sha(task["query"]))
            done_ok += 1
        sent = counter["n"]
        remaining = len(tasks) - done_ok
        state = "complete" if remaining <= 0 else ("budget_exhausted" if used + sent >= budget else "partial")
        total_used = store.probe_record(month, sent, failures, state)
        return {"month": month, "state": state, "requests": sent, "failures": failures, "budget_used": total_used,
                "budget": budget, "tasks_remaining": max(0, remaining), "baseline_rows_imported": imported}
    finally:
        if not dry_run:
            store.release_lease("probe:" + month, owner)


def run_to_completion(store: Any, **kwargs: Any) -> dict[str, Any]:
    """Operator helper (cli.py probe): repeat chunks until the plan or the monthly budget is done."""
    summary: dict[str, Any] = {}
    for _ in range(20):
        summary = run_probe(store, **kwargs)
        if summary["state"] not in ("partial",):
            break
    return summary
