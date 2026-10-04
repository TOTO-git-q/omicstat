#!/usr/bin/env python3
"""omicstat S0 literature collection (L3/L4). Run with the retrieval venv:
  PY=/opt/retrieval-venv/bin/python

  $PY tools/lit/collect.py search    <module> [--target 30] [--max-candidates 400]
      Europe PMC section search -> whitelist / publication-type / year gate ->
      open-access full text -> Methods-region signal + licence gate -> PubMed
      efetch echo. Writes acceptance/exemplars/<module>/literature/:
        search_log.json   query, hit count, gate counts, date
        corpus.jsonl      one screened, countable, PMID-verified article per line
                          (metadata, licence, jats_sha256, signal snippet,
                          candidate parameter values with <= 25-word snippets)
        efetch/<PMID>.xml PubMed records (proof of the echo)
      The first 8-10 tier-A articles with the most reported parameters are marked
      layer "L3" (exemplars to read closely); all corpus articles count for L4.
  $PY tools/lit/collect.py methods   <module> <PMCID>          print the Methods regions (transient; not stored)
  $PY tools/lit/collect.py check     <PMCID> "<snippet>"       is the snippet in the article's Methods text?
  $PY tools/lit/collect.py sample    <module> [--frac 0.2]     deterministic >= 20 % sample for the verifier
  $PY tools/lit/collect.py summarize <module>                  V-section counts from extraction.jsonl

Extraction (by the parameter extractor) is written to literature/extraction.jsonl,
one line per (pmid, parameter): {"pmid", "parameter", "value" | "not reported",
"snippet" (<= 25 words, verbatim), "section_path", "ecosystem" (single-cell only: seurat / bioconductor / scverse / mixed)}.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import random
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import omlit  # noqa: E402

ROOT = HERE.parents[1]


def lit_dir(module: str) -> Path:
    d = ROOT / "acceptance" / "exemplars" / module / "literature"
    d.mkdir(parents=True, exist_ok=True)
    return d


def cmd_search(a):
    today = dt.date.today()
    journals = omlit.load_journals()
    profiles = omlit.load_profiles()
    prof = profiles["by_module"].get(a.module)
    if prof is None:
        sys.exit(f"no discovery profile for {a.module}")
    cfg = {"common_filter": profiles["common_filter"], "min_year": profiles["min_year"]}
    query = omlit.build_query(prof, cfg, journals, today)
    client = omlit.epmc_client()
    # Year-stratified candidates: one query per publication year (min_year..today),
    # each sorted newest first; then interleaved year by year (newest year first) so
    # the L4 sample spreads over the whole period instead of the latest months.
    years = list(range(today.year, cfg["min_year"] - 1, -1))
    per_year = -(-a.max_candidates // len(years))
    by_year, hit_counts = {}, {}
    for y in years:
        qy = query.replace(f"FIRST_PDATE:[{cfg['min_year']}-01-01 TO {today.isoformat()}]", f"FIRST_PDATE:[{y}-01-01 TO {min(today, dt.date(y, 12, 31)).isoformat()}]")
        fy = omlit.epmc_search_all(client, qy, max_records=per_year)
        hit_counts[y] = fy["hit_count"]
        by_year[y] = sorted(fy["results"], key=lambda r: (str(r.get("firstPublicationDate") or ""), str(r.get("pmid") or "")), reverse=True)
    cands = []
    for i in range(per_year):
        for y in years:
            if i < len(by_year[y]):
                cands.append(by_year[y][i])
    found = {"hit_count": sum(v or 0 for v in hit_counts.values()), "hit_count_by_year": hit_counts}
    gates = Counter()
    corpus = []
    errors = []
    for r in cands:
        if len(corpus) >= a.target:
            break
        verdict, info = omlit.screen_metadata(r, prof, journals, cfg, today)
        if verdict != "pass":
            gates[verdict] += 1
            continue
        pmcid, pmid = r.get("pmcid"), r.get("pmid")
        if not pmcid or not pmid:
            gates["no_pmcid_or_pmid"] += 1
            continue
        try:
            code, xml = client.full_text_xml(pmcid)
        except Exception as exc:  # noqa: BLE001 -- one article's server error must not stop the module
            gates["fulltext_http_error"] += 1
            errors.append({"pmcid": pmcid, "error": f"{type(exc).__name__}: {exc}"[:200]})
            continue
        if code != 200 or not xml:
            gates["no_oa_fulltext"] += 1
            continue
        try:
            v2, detail = omlit.screen_fulltext(xml, prof)
        except Exception as exc:  # noqa: BLE001 -- malformed JATS
            gates["fulltext_parse_error"] += 1
            errors.append({"pmcid": pmcid, "error": f"{type(exc).__name__}: {exc}"[:200]})
            continue
        if v2 != "screened":
            gates[v2] += 1
            continue
        if not detail["rights"]["countable"]:
            gates["licence_not_countable"] += 1
            continue
        gates["screened"] += 1
        corpus.append({"module": a.module, "pmid": str(pmid), "pmcid": pmcid, "doi": r.get("doi"),
                       "title": r.get("title"), "journal": info["journal"], "tier": info["tier"], "year": info["year"],
                       "first_publication_date": r.get("firstPublicationDate"), "licence": detail["rights"]["licence"],
                       "jats_sha256": omlit.sha256_bytes(xml), "signal": detail["signal"],
                       "candidates": detail["variants"], "n_method_regions": detail["n_method_regions"]})
    d = lit_dir(a.module)
    echo = omlit.efetch_echo([c["pmid"] for c in corpus], {c["pmid"]: c for c in corpus}, d / "efetch") if corpus else {}
    kept = []
    for c in corpus:
        c["pubmed_echo"] = echo.get(c["pmid"])
        if c["pubmed_echo"] and c["pubmed_echo"]["verified"]:
            kept.append(c)
        else:
            gates["pmid_echo_failed"] += 1
    # L3: tier-A articles with the most parameters carrying candidates (ties: newest first)
    ranked = sorted([c for c in kept if c["tier"] == "A"], key=lambda c: (-len(c["candidates"]), c["first_publication_date"] or ""), reverse=False)
    l3 = {c["pmid"] for c in ranked[: a.l3]}
    for c in kept:
        c["layer"] = "L3+L4" if c["pmid"] in l3 else "L4"
    with (d / "corpus.jsonl").open("w", encoding="utf-8") as fh:
        for c in kept:
            fh.write(json.dumps(c, ensure_ascii=False, sort_keys=True) + "\n")
    log = {"module": a.module, "date": today.isoformat(), "query": query, "hit_count": found["hit_count"],
           "hit_count_by_year": found["hit_count_by_year"], "stratification": "per publication year, interleaved newest year first",
           "candidates_fetched": len(cands), "target": a.target, "gates": dict(gates), "corpus": len(kept),
           "l3": len(l3), "errors": errors, "journals_sha256": hashlib.sha256((HERE / "journals.json").read_bytes()).hexdigest(),
           "profiles_sha256": hashlib.sha256((HERE / "discovery_profiles.json").read_bytes()).hexdigest(),
           "epmc_requests": client.n_requests}
    (d / "search_log.json").write_text(json.dumps(log, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({k: log[k] for k in ("module", "hit_count", "candidates_fetched", "gates", "corpus", "l3")}, ensure_ascii=False))


def _methods(pmcid: str):
    client = omlit.epmc_client()
    code, xml = client.full_text_xml(pmcid)
    if code != 200 or not xml:
        sys.exit(f"no open-access full text for {pmcid} (HTTP {code})")
    from lxml import etree
    root = etree.fromstring(xml)
    art = root if omlit._local(root.tag) == "article" else root.find(".//article")
    return omlit.method_regions(art.find("./body"))


def cmd_methods(a):
    for r in _methods(a.pmcid):
        print(f"### {r['section_path']}\n{r['text']}\n")


def _norm(s: str) -> str:
    return re.sub(r"\s+", " ", s).strip().lower()


def cmd_check(a):
    words = a.snippet.split()
    if len(words) > omlit.SNIPPET_MAX_WORDS:
        print(f"TOO_LONG {len(words)} words (max {omlit.SNIPPET_MAX_WORDS})")
        sys.exit(2)
    text = _norm(" ".join(r["text"] for r in _methods(a.pmcid)))
    ok = _norm(a.snippet) in text
    print("FOUND" if ok else "NOT_FOUND")
    sys.exit(0 if ok else 1)


def _read_jsonl(p: Path):
    return [json.loads(l) for l in p.read_text(encoding="utf-8").splitlines() if l.strip()] if p.exists() else []


def cmd_sample(a):
    corpus = _read_jsonl(lit_dir(a.module) / "corpus.jsonl")
    pmids = sorted(c["pmid"] for c in corpus)
    k = max(1, -(-len(pmids) * int(a.frac * 100) // 100))
    rnd = random.Random(f"{a.module}:{a.seed}")
    print("\n".join(sorted(rnd.sample(pmids, min(k, len(pmids))))))


def cmd_summarize(a):
    d = lit_dir(a.module)
    corpus = {c["pmid"]: c for c in _read_jsonl(d / "corpus.jsonl")}
    ext = _read_jsonl(d / "extraction.jsonl")
    profiles = omlit.load_profiles()["by_module"][a.module]
    # only articles of the current corpus count (a re-collected corpus leaves older lines in place)
    judged = {e["pmid"] for e in ext if e["parameter"] == "_applies" and e["pmid"] in corpus}
    applies = {e["pmid"] for e in ext if e["parameter"] == "_applies" and e["pmid"] in corpus
               and str(e.get("value")).lower() == "yes"}
    n_no = len(judged) - len(applies)
    by = defaultdict(Counter)
    for e in ext:
        if e["pmid"] in corpus and e["pmid"] in applies and e["parameter"] != "_applies":
            v = e.get("value", "not reported")
            by[e["parameter"]][str(v).strip().lower() if v != "not reported" else "not reported"] += 1
    unjudged = len(corpus) - len(judged)
    print(f"{len(applies)} of {len(corpus)} corpus papers apply to {a.module} ({n_no} excluded by _applies = no"
          + (f", {unjudged} without an _applies line" if unjudged else "") + ")")
    lines = [f"| Parameter | PACK | Values (count / {len(applies)} applicable papers) |", "|---|---|---|"]
    for p in profiles["parameters"]:
        c = by.get(p["parameter"], Counter())
        vals = "; ".join(f"{k}: {n}" for k, n in c.most_common())
        lines.append(f"| {p['parameter']} | {p['pack']} | {vals or '(no extraction)'} |")
    print("\n".join(lines))


ap = argparse.ArgumentParser()
sub = ap.add_subparsers(dest="cmd", required=True)
s = sub.add_parser("search"); s.add_argument("module"); s.add_argument("--target", type=int, default=30)
s.add_argument("--max-candidates", type=int, default=400); s.add_argument("--l3", type=int, default=10); s.set_defaults(fn=cmd_search)
s = sub.add_parser("methods"); s.add_argument("module"); s.add_argument("pmcid"); s.set_defaults(fn=cmd_methods)
s = sub.add_parser("check"); s.add_argument("pmcid"); s.add_argument("snippet"); s.set_defaults(fn=cmd_check)
s = sub.add_parser("sample"); s.add_argument("module"); s.add_argument("--frac", type=float, default=0.2); s.add_argument("--seed", default="omicstat-s0")
s.set_defaults(fn=cmd_sample)
s = sub.add_parser("summarize"); s.add_argument("module"); s.set_defaults(fn=cmd_summarize)
a = ap.parse_args()
a.fn(a)
