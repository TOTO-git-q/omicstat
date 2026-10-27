#!/usr/bin/env python3
"""Monthly omicstat reference digest (host side, stdlib only).

Reads, strictly read-only: harvest.sqlite and reference.sqlite of the reference service, the web advisor's
unmet-need log (absent = zero records) and the environment description; writes
<out-dir>/digest-YYYY-MM.md and .json.  The digest only produces owner-review items: it never changes a
module, a default, a route, a profile or the method map, and it contains no LLM output.

Sections: A coverage ranking | B family trends | C locked defaults versus literature | D collection health |
E unmet needs, proposals, unavailable requests | F upgrade window.

    reference_digest.py --data-dir ~/omic-infra-reference/runtime/data --out-dir ~/omic-infra-reference/runtime/reports
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import sqlite3
import sys
from collections import Counter, defaultdict
from contextlib import closing
from pathlib import Path
from typing import Any, Mapping

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / "app"))

import defaults  # noqa: E402
import lexicon  # noqa: E402
import probe  # noqa: E402  (constants only; no network is used here)

SCHEMA = "omicstat.reference.digest.v1"
TOP_N = 15
# Alert thresholds are proposals for the owner to adjust (open question 'alert thresholds').
DECLINE_MIN_HITS = 30          # the member needs at least this many hits in its peak year
DECLINE_TO = 0.80              # latest share <= 80 % of the peak share, after two consecutive yearly declines
EMERGE_FROM, EMERGE_TO = 0.10, 0.25   # share of the family total: below 10 % two years ago, now above 25 %
TOTAL = probe.TOTAL_TERM


def ro(path: Path) -> sqlite3.Connection:
    con = sqlite3.connect(path.resolve().as_uri() + "?mode=ro", uri=True, timeout=10)
    con.row_factory = sqlite3.Row
    return con


# ------------------------------------------------------------------ data access

def rows(con: sqlite3.Connection, sql: str, args: tuple = ()) -> list[sqlite3.Row]:
    """All rows, or none when the table does not exist yet (a store that predates the v3 migration)."""
    try:
        return con.execute(sql, args).fetchall()
    except sqlite3.OperationalError as exc:
        if "no such table" in str(exc):
            return []
        raise


def load_series(con: sqlite3.Connection) -> tuple[dict[tuple[str, str], dict[int, dict[str, Any]]], dict[tuple[int, str], int]]:
    """series[(term, kind)][year] = latest window {hits, end}; totals[(year, window_end)] = whitelist total."""
    series: dict[tuple[str, str], dict[int, dict[str, Any]]] = defaultdict(dict)
    totals: dict[tuple[int, str], int] = {}
    for r in rows(con, "SELECT term,term_kind,year,window_end,hit_count,recorded_at FROM method_probe ORDER BY recorded_at"):
        if r["term_kind"] == "total":
            totals[(int(r["year"]), r["window_end"])] = int(r["hit_count"])
            continue
        slot = series[(r["term"], r["term_kind"])]
        year = int(r["year"])
        if year not in slot or r["window_end"] >= slot[year]["end"]:
            slot[year] = {"hits": int(r["hit_count"]), "end": r["window_end"]}
    return series, totals


def share(point: Mapping[str, Any], year: int, totals: Mapping[tuple[int, str], int]) -> float | None:
    total = totals.get((year, point["end"]))
    return None if not total else point["hits"] / total


def read_unmet_needs(path: Path | None) -> dict[str, Any]:
    """Merge the advisor's unmet-need log by id (same convention as omicstat-web's unmet_needs_report.py)."""
    if path is None or not path.is_file():
        return {"present": False, "items": [], "heavy": 0}
    merged: dict[str, dict[str, Any]] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        try:
            rec = json.loads(line)
        except ValueError:
            continue
        cur = merged.setdefault(rec.get("id") or rec.get("time", "?"), {"id": rec.get("id") or rec.get("time", "?"), "time": rec.get("time", "")})
        for key, value in rec.items():
            if key not in ("kind", "id", "time", "snapshot") and value not in ("", None, [], {}):
                cur[key] = value
    items = sorted(merged.values(), key=lambda m: m["time"])
    return {"present": True, "items": [m for m in items if m.get("category") != "heavy_for_yu"],
            "heavy": sum(1 for m in items if m.get("category") == "heavy_for_yu")}


def need_text(item: Mapping[str, Any]) -> str:
    parts = [str(item.get(k, "")) for k in ("requested_analysis", "method", "data_type")]
    parts += [str(p) for p in item.get("packages", [])] if isinstance(item.get("packages"), list) else [str(item.get("packages", ""))]
    return " ".join(parts)


def demand_for(entry: Mapping[str, Any], needs: list[Mapping[str, Any]], proposals: list[Mapping[str, Any]],
               unavailable: list[str]) -> dict[str, int]:
    pattern = re.compile(entry["regex"], re.I if entry.get("case_insensitive", True) else 0)
    return {"unmet_needs": sum(1 for n in needs if pattern.search(need_text(n))),
            # proposals written by this system itself (watch profiles) are not demand
            "domain_proposals": sum(1 for p in proposals if not str(p.get("proposer", "")).startswith("coverage-upgrade")
                                    and pattern.search(p["name"] + " " + p.get("rationale", ""))),
            "unavailable_requests": sum(1 for u in unavailable if pattern.search(u))}


# ------------------------------------------------------------------ sections

def section_a(lex: Mapping[str, Any], series, totals, mentions: Counter, s0_use: Counter, demand_src, year: int) -> dict[str, Any]:
    rows, unprobed = [], 0
    full, ytd_year = year - 1, year
    for entry in lex["entries"]:
        if not entry["rank_eligible"] or entry["our_module"]:
            continue
        pts = series.get((entry["token"], "candidate"), {})
        if not pts:
            unprobed += 1
            continue
        last, cur = pts.get(full), pts.get(ytd_year)
        s_full = share(last, full, totals) if last else None
        s_cur = share(cur, ytd_year, totals) if cur else None
        change = None if not (s_full and s_cur) else round((s_cur / s_full - 1) * 100)
        rows.append({"token": entry["token"], "name": entry["name"], "family": entry["family"], "hits_last_year": last["hits"] if last else None,
                     "per_1000_last_year": None if s_full is None else round(s_full * 1000, 2),
                     "hits_ytd": cur["hits"] if cur else None, "per_1000_ytd": None if s_cur is None else round(s_cur * 1000, 2),
                     "ytd_vs_last_year_pct": change, "co_use_harvest_papers": mentions.get(entry["token"], 0),
                     "co_use_s0_papers": s0_use.get(entry["token"], 0), "in_pkg_lock": entry["in_pkg_lock"],
                     "ecosystem": entry["ecosystem"], "licence_gate": entry["licence_note"], "demand": demand_src(entry)})
    rows.sort(key=lambda r: (-(r["hits_last_year"] or -1), -(r["hits_ytd"] or -1), r["token"]))
    for i, row in enumerate(rows, 1):
        row["rank"] = i
    return {"basis": f"Europe PMC Methods-section hitCount, whitelist journals, open access, non-review; last full year = {full}, year to date = {ytd_year} (to the end of last month).",
            "candidates_probed": len(rows), "candidates_not_yet_probed": unprobed, "top": rows[:TOP_N], "all": rows}


def family_alerts(members: dict[str, dict[int, float | None]], hits: dict[str, dict[int, int]]) -> tuple[list[dict], list[dict]]:
    decliners, risers = [], []
    totals_by_year: dict[int, int] = defaultdict(int)
    for m, by_year in hits.items():
        for y, h in by_year.items():
            totals_by_year[y] += h
    for name, by_share in members.items():
        years = sorted(y for y, s in by_share.items() if s is not None)
        if len(years) >= 3:
            a, b, c = years[-3:]
            if b == a + 1 and c == b + 1 and by_share[a] > by_share[b] > by_share[c]:
                peak = max(hits[name].values(), default=0)
                if peak >= DECLINE_MIN_HITS and by_share[c] <= DECLINE_TO * max(by_share[y] for y in years):
                    decliners.append({"member": name, "years": [a, b, c], "shares_per_1000": [round(by_share[y] * 1000, 2) for y in (a, b, c)]})
        fam_years = sorted(y for y in hits[name] if totals_by_year.get(y))
        if len(fam_years) >= 3:
            a, c = fam_years[-3], fam_years[-1]
            fa, fc = hits[name][a] / totals_by_year[a], hits[name][c] / totals_by_year[c]
            if fa < EMERGE_FROM and fc >= EMERGE_TO:
                risers.append({"member": name, "years": [a, c], "family_share_pct": [round(fa * 100, 1), round(fc * 100, 1)]})
    return decliners, risers


def section_b(lex, series, totals, year: int) -> dict[str, Any]:
    families: dict[str, Any] = {}
    modules_of_family: dict[str, list[str]] = defaultdict(list)
    for e in lex["entries"]:
        if e["family"] in probe.TREND_FAMILIES:
            for m in e["our_module"]:
                if m not in modules_of_family[e["family"]]:
                    modules_of_family[e["family"]].append(m)
    for family in probe.TREND_FAMILIES:
        members = [e for e in lex["entries"] if e["family"] == family and e["rank_eligible"]]
        tok_share, tok_hits = {}, {}
        for e in members:
            pts = series.get((e["token"], "candidate"), {}) or series.get((e["token"], "family_member"), {})
            if pts:
                tok_share[e["token"]] = {y: share(p, y, totals) for y, p in pts.items()}
                tok_hits[e["token"]] = {y: p["hits"] for y, p in pts.items()}
        mod_share, mod_hits = {}, {}
        for m in modules_of_family.get(family, []):
            pts = series.get((m, "module"), {})
            if pts:
                mod_share[m] = {y: share(p, y, totals) for y, p in pts.items()}
                mod_hits[m] = {y: p["hits"] for y, p in pts.items()}
        d_tok, r_tok = family_alerts(tok_share, tok_hits) if tok_share else ([], [])
        d_mod, r_mod = family_alerts(mod_share, mod_hits) if mod_share else ([], [])
        with_history = sum(1 for s in tok_share.values() if sum(v is not None for v in s.values()) >= 3)
        families[family] = {"members": len(members), "members_probed": len(tok_share), "members_with_3_years": with_history,
                            "token_series": {k: {str(y): hits_ for y, hits_ in sorted(v.items())} for k, v in tok_hits.items()},
                            "module_proxy_series": {k: {str(y): hits_ for y, hits_ in sorted(v.items())} for k, v in mod_hits.items()},
                            "decliners": d_tok, "risers": r_tok, "module_proxy_decliners": d_mod, "module_proxy_risers": r_mod}
    alerts = sum(len(f["decliners"]) + len(f["risers"]) + len(f["module_proxy_decliners"]) + len(f["module_proxy_risers"]) for f in families.values())
    return {"rules": {"decline": f"share (hits / whitelist total) fell in each of the last two years and is <= {int(DECLINE_TO * 100)}% of the peak share, peak >= {DECLINE_MIN_HITS} hits",
                      "emerging": f"share of the family's hits was < {int(EMERGE_FROM * 100)}% two years ago and is >= {int(EMERGE_TO * 100)}% now",
                      "note": "thresholds are proposals for the owner; token series need three yearly points, the module-proxy series come from the S0 baseline (module query hits, 2020-2026)"},
            "alerts": alerts, "families": families}


def section_c(data_dir: Path) -> dict[str, Any]:
    report = defaults.report(data_dir)
    flagged = [{"module": m, "option": o, **{k: s[k] for k in ("locked_default", "n_parsed", "n_unparsed", "n_excluded_cross_ecosystem", "default_share", "flags", "owner_verdict")},
                "top_values": s["top_values"][:3]}
               for m, opts in report.items() for o, s in opts.items() if s["flags"]]
    # open items first; an option the owner has already decided stays in the table with its verdict
    flagged.sort(key=lambda x: (x["owner_verdict"] is not None, x["default_share"], x["module"], x["option"]))
    open_flags = sum(1 for x in flagged if x["owner_verdict"] is None)
    return {"options_compared": sum(len(v) for v in report.values()), "modules": len(report), "flagged": flagged,
            "open_flags": open_flags, "adjudicated_flags": len(flagged) - open_flags,
            "note": "Context for owner review only; literature values are study-specific and the locked defaults / S1 appendix stay the authority."}


def section_d(con: sqlite3.Connection, journals_path: Path, month: str) -> dict[str, Any]:
    runs = [{"day": r["day"], "state": r["state"], "shortfall": json.loads(r["detail_json"]).get("shortfall"),
             "errors": json.loads(r["detail_json"]).get("errors", [])} for r in con.execute("SELECT day,state,detail_json FROM daily_runs ORDER BY day DESC LIMIT 7")]
    gates: Counter = Counter()
    for r in con.execute("SELECT gate,n FROM daily_gate_counts WHERE day >= date('now','-7 day')"):
        gates[r["gate"]] += int(r["n"])
    status = {r["status"]: int(r["n"]) for r in con.execute("SELECT status,count(*) n FROM candidates WHERE legacy_flag IS NULL GROUP BY status")}
    mp = con.execute("SELECT map_hash,order_json,next_module,state,updated_at FROM method_map_state").fetchone()
    reconciled = (rows(con, "SELECT day,module,detail FROM module_events WHERE outcome='reconciled' ORDER BY recorded_at DESC LIMIT 1") or [None])[0]
    probe_run = (rows(con, "SELECT run_month,requests,failures,state FROM probe_runs ORDER BY run_month DESC LIMIT 1") or [None])[0]
    mention_papers = int((rows(con, "SELECT count(*) FROM mention_papers") or [(0,)])[0][0])
    off_topic = int((rows(con, "SELECT count(*) FROM mention_papers WHERE from_outcome='off_topic'") or [(0,)])[0][0])
    restricted = gates.get("rights_restricted", 0) + gates.get("rights_unconfirmed", 0)
    verified = []
    if journals_path.is_file():
        verified = sorted({j.get("verified_on", "") for j in json.loads(journals_path.read_text(encoding="utf-8"))["journals"]})
    return {"recent_runs": runs, "gate_counts_7d": dict(sorted(gates.items())), "candidates_by_status": status,
            "rights_gate_share_7d": None if not sum(gates.values()) else round(restricted / sum(gates.values()), 3),
            "method_map": None if mp is None else {"state": mp["state"], "hash": mp["map_hash"][:12], "modules": len(json.loads(mp["order_json"])),
                                                  "next_module": mp["next_module"], "updated_at": mp["updated_at"]},
            "last_reconcile": None if reconciled is None else dict(reconciled),
            "probe_ledger": None if probe_run is None else dict(probe_run), "method_mention_papers": mention_papers, "mention_papers_off_topic": off_topic,
            "journal_whitelist_verified_on": {"oldest": verified[0] if verified else None, "newest": verified[-1] if verified else None,
                                              "age_days": None if not verified else (dt.date.today() - dt.date.fromisoformat(verified[0])).days}}


def section_f(env_json: Path | None, repo: Path | None) -> dict[str, Any]:
    out: dict[str, Any] = {"locked_environment": None, "drift_reports": [],
                           "note": "Bioconductor 3.24 is expected in October 2026; the owner decided on 2026-10-10 to skip it for now (stay on the locked release)."}
    if env_json and env_json.is_file():
        env = json.loads(env_json.read_text(encoding="utf-8"))
        out["locked_environment"] = {k: env.get(k) for k in ("env_version", "r_version", "bioconductor", "cran_snapshot", "image_tag")}
        out["locked_environment"]["python_lane"] = {k: (env.get("python_lane") or {}).get(k) for k in ("py_env_version", "pypi_cutoff", "image_tag")}
    if repo and (repo / "docs" / "upgrade").is_dir():
        out["drift_reports"] = sorted(str(p.relative_to(repo)) for p in (repo / "docs" / "upgrade").glob("*/drift_report.md"))
    return out


# ------------------------------------------------------------------ build + render

def build(data_dir: Path, *, month: str, now: dt.datetime, unmet_path: Path | None, env_json: Path | None, repo: Path | None) -> dict[str, Any]:
    lex = lexicon.load_lexicon()
    year = int(month[:4])
    with closing(ro(data_dir / "harvest.sqlite")) as hv:
        series, totals = load_series(hv)
        mentions: Counter = Counter(r["token"] for r in rows(hv, "SELECT token FROM method_mentions"))
        unavailable = [json.loads(r["payload_json"]).get("topic", "") + " " + " ".join(json.loads(r["keywords_json"]).get("required", []) if isinstance(json.loads(r["keywords_json"]), dict) else [])
                       for r in hv.execute("SELECT payload_json,keywords_json FROM literature_requests WHERE module='unmapped' AND status='unavailable'")]
        health = section_d(hv, HERE / "app" / "journals.json", month)
    s0_use: Counter = Counter()
    proposals: list[dict[str, Any]] = []
    ref = data_dir / "reference.sqlite"
    if ref.is_file():
        with closing(ro(ref)) as rc:
            for r in rows(rc, "SELECT candidate_json FROM reviewed_supplement WHERE status='active' AND supplement_id IN "
                              "(SELECT min(supplement_id) FROM reviewed_supplement WHERE status='active' GROUP BY json_extract(candidate_json,'$.pmid'))"):
                s0_use.update(json.loads(r["candidate_json"]).get("methods_used", {}).get("tokens", []))
            proposals = [{"name": r["name"], "kind": r["kind"], "status": r["status"], **json.loads(r["payload_json"])} for r in
                         rc.execute("SELECT name,kind,status,payload_json FROM domain_proposals")] if rc.execute("SELECT 1 FROM sqlite_master WHERE name='domain_proposals'").fetchone() else []
    needs = read_unmet_needs(unmet_path)
    demand = lambda entry: demand_for(entry, needs["items"], proposals, unavailable)  # noqa: E731
    a = section_a(lex, series, totals, mentions, s0_use, demand, year)
    b = section_b(lex, series, totals, year)
    c = section_c(data_dir)
    e = {"unmet_needs_file_present": needs["present"], "unmet_needs": len(needs["items"]), "heavy_for_yu": needs["heavy"],
         "items": [{"id": n["id"], "requested_analysis": n.get("requested_analysis"), "method": n.get("method"), "packages": n.get("packages")} for n in needs["items"]],
         "domain_proposals": [{"name": p["name"], "kind": p["kind"], "status": p["status"]} for p in proposals], "unavailable_unmapped_requests": len(unavailable),
         "demand_note": "Demand counts come from one user so far; they are shown next to, never merged with, the literature share."}
    f = section_f(env_json, repo)
    top = a["top"]
    return {"schema": SCHEMA, "month": month, "generated_at": now.replace(microsecond=0).isoformat(),
            "headline": {"candidates_probed": a["candidates_probed"], "top3": [r["token"] for r in top[:3]], "family_alerts": b["alerts"],
                         "flagged_defaults": c["open_flags"], "adjudicated_defaults": c["adjudicated_flags"], "unmet_needs": e["unmet_needs"], "probe": health["probe_ledger"]},
            "limits": ["Hit counts are mentions in Methods text of whitelisted open-access papers, not proof of use; a paper that names several tools counts for each.",
                       "Tokens seen next to our modules (method mentions) are conditional on papers that already matched one of our module profiles (adjacent demand).",
                       "Demand is one user and, at the time of writing, zero unmet-need records; rankings are not a single score.",
                       "Nothing in this digest changes a module, default, route or profile. Owner review items only."],
            "A_coverage": a, "B_trends": b, "C_defaults": c, "D_health": health, "E_demand": e, "F_upgrade": f}


def _pct(v: Any) -> str:
    return "-" if v is None else f"{v:+d}%"


def render(doc: Mapping[str, Any]) -> str:
    a, b, c, d, e, f = (doc[k] for k in ("A_coverage", "B_trends", "C_defaults", "D_health", "E_demand", "F_upgrade"))
    h = doc["headline"]
    out = [f"# omicstat reference digest {doc['month']}", "", f"Generated {doc['generated_at']} on GT103 from the live stores (read-only). Owner-review items only: nothing here changes a module, default, route or profile.", "",
           "## Headline", "",
           f"- Coverage candidates probed: {h['candidates_probed']} (not yet probed: {a['candidates_not_yet_probed']}); top three by last-year hits: {', '.join(h['top3']) or 'none yet'}",
           f"- Family-trend alerts: {h['family_alerts']}; locked defaults flagged against the literature and still open: {h['flagged_defaults']} (already decided by the owner: {h['adjudicated_defaults']}); unmet-need records: {h['unmet_needs']}"]
    if a["candidates_not_yet_probed"]:
        ledger = d["probe_ledger"] or {}
        out.append(f"- **Partial ranking**: {a['candidates_not_yet_probed']} candidates have no probe yet (month budget {ledger.get('requests')} requests used, {ledger.get('failures')} failed; the rest is probed next month). Rows below are ranked among the probed candidates only.")
    out += ["",
           "## A. Coverage ranking (top %d of candidates without an omicstat module)" % TOP_N, "", a["basis"], "",
           "| # | candidate | family | hits %s | per 1,000 | hits YTD | per 1,000 | YTD vs last yr | co-use (harvest / S0 papers) | in env lock | demand (needs / proposals / unavailable) | licence gate |" % "last yr",
           "|---|---|---|---:|---:|---:|---:|---:|---|---|---|---|"]
    for r in a["top"]:
        dm = r["demand"]
        out.append(f"| {r['rank']} | {r['name']} | {r['family']} | {r['hits_last_year']} | {r['per_1000_last_year']} | {r['hits_ytd']} | {r['per_1000_ytd']} | {_pct(r['ytd_vs_last_year_pct'])} | "
                   f"{r['co_use_harvest_papers']} / {r['co_use_s0_papers']} | {'yes' if r['in_pkg_lock'] else 'no'} | {dm['unmet_needs']} / {dm['domain_proposals']} / {dm['unavailable_requests']} | {r['licence_gate'] or '-'} |")
    out += ["", "Demand and literature share are separate columns on purpose; there is no combined score.", "",
            "## B. Family trends", "", f"Rules: decline = {b['rules']['decline']}; emerging = {b['rules']['emerging']}. {b['rules']['note']}.", "",
            f"Alerts this month: {b['alerts']}", ""]
    any_alert = False
    for name, fam in b["families"].items():
        lines = []
        for key, label in (("decliners", "declining"), ("risers", "emerging"), ("module_proxy_decliners", "declining (module query)"), ("module_proxy_risers", "emerging (module query)")):
            for item in fam[key]:
                lines.append(f"- {item['member']}: {label} ({item})")
        if lines:
            any_alert = True
            out += [f"### {name}", ""] + lines + [""]
    if not any_alert:
        out += ["No family meets the alert rules yet.", ""]
    out += ["| family | members | probed | with 3+ yearly points | module-proxy series |", "|---|---:|---:|---:|---:|"]
    for name, fam in b["families"].items():
        out.append(f"| {name} | {fam['members']} | {fam['members_probed']} | {fam['members_with_3_years']} | {len(fam['module_proxy_series'])} |")
    out += ["", "## C. Locked defaults versus literature", "", f"{c['options_compared']} options of {c['modules']} modules could be compared; flagged: {len(c['flagged'])}, of which open: {c['open_flags']}, already decided by the owner: {c['adjudicated_flags']}.", ""]
    if c["flagged"]:
        out += ["| module | option | locked default | papers parsed / unparsed | share at default | flags | most reported | owner verdict |", "|---|---|---|---:|---:|---|---|---|"]
        for x in c["flagged"]:
            verdict = "open" if x["owner_verdict"] is None else f"{x['owner_verdict']['verdict']} ({x['owner_verdict'].get('decided', '')})"
            excluded = f" (+{x['n_excluded_cross_ecosystem']} other-ecosystem values excluded)" if x["n_excluded_cross_ecosystem"] else ""
            out.append(f"| {x['module']} | {x['option']} | {x['locked_default']} | {x['n_parsed']} / {x['n_unparsed']}{excluded} | {x['default_share']} | {', '.join(x['flags'])} | {', '.join('%s (%d)' % (v['value'], v['n']) for v in x['top_values'])} | {verdict} |")
    out += ["", c["note"], "", "## D. Collection health", ""]
    mp = d["method_map"]
    out += [f"- Method map: {mp['state']}, {mp['modules']} modules, next module {mp['next_module']}, hash {mp['hash']}" if mp else "- Method map: not initialised",
            f"- Last map reconcile: {d['last_reconcile']}" if d["last_reconcile"] else "- Last map reconcile: none",
            f"- Candidates by status: {d['candidates_by_status']}", f"- Gate counts, last 7 days: {d['gate_counts_7d']}; rights-gate share {d['rights_gate_share_7d']}",
            f"- Probe ledger: {d['probe_ledger']}", f"- Papers with method mentions: {d['method_mention_papers']} (of which off-topic for the matched module: {d['mention_papers_off_topic']})",
            f"- Journal whitelist verified: oldest {d['journal_whitelist_verified_on']['oldest']}, newest {d['journal_whitelist_verified_on']['newest']} (age of the oldest entry: {d['journal_whitelist_verified_on']['age_days']} days)", "",
            "| day | state | shortfall | errors |", "|---|---|---:|---|"]
    out += [f"| {r['day']} | {r['state']} | {r['shortfall']} | {', '.join(r['errors']) or '-'} |" for r in d["recent_runs"]]
    out += ["", "## E. Unmet needs, proposals, unavailable requests", "",
            f"- Unmet-need log: {'present' if e['unmet_needs_file_present'] else 'not present yet'}; records: {e['unmet_needs']}; heavy requests for YU-san: {e['heavy_for_yu']}",
            f"- Domain proposals: {len(e['domain_proposals'])}; unavailable requests for unmapped methods: {e['unavailable_unmapped_requests']}"]
    if e["items"]:
        out += [""] + [f"- {i['id']}: {i['requested_analysis']} (method: {i['method']}; packages: {i['packages']})" for i in e["items"]]
    else:
        out += ["", "No unmet-need records this month (zero demand-side evidence)."]
    out += ["", e["demand_note"], "", "## F. Upgrade window", "", f"- {f['note']}",
            f"- Locked environment: {f['locked_environment']}", f"- Drift reports: {f['drift_reports'] or 'none'}", "", "## Limits", ""]
    out += [f"- {x}" for x in doc["limits"]]
    return "\n".join(out) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    home = Path.home()
    ap.add_argument("--data-dir", type=Path, default=home / "omic-infra-reference" / "runtime" / "data")
    ap.add_argument("--out-dir", type=Path, default=home / "omic-infra-reference" / "runtime" / "reports")
    ap.add_argument("--month", help="YYYY-MM (default: current month)")
    ap.add_argument("--unmet-needs", type=Path, default=home / "omicstat-runs" / "web" / "advisor" / "_state" / "unmet_needs.jsonl")
    ap.add_argument("--env-json", type=Path, default=home / "omicstat" / "env" / "omicstat-env.json")
    ap.add_argument("--repo", type=Path, default=home / "omicstat")
    args = ap.parse_args()
    now = dt.datetime.now(dt.timezone.utc)
    month = args.month or now.strftime("%Y-%m")
    doc = build(args.data_dir, month=month, now=now, unmet_path=args.unmet_needs, env_json=args.env_json, repo=args.repo)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    (args.out_dir / f"digest-{month}.json").write_text(json.dumps(doc, ensure_ascii=False, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    (args.out_dir / f"digest-{month}.md").write_text(render(doc), encoding="utf-8")
    print(json.dumps({"digest": str(args.out_dir / f"digest-{month}.md"), **doc["headline"]}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
