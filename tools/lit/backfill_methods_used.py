#!/usr/bin/env python3
"""One-off, resumable backfill of `methods_used` for the S0 corpus (owner-approved 2026-10-10).

For every paper of the S0 evidence bundle (reference_service/app/s0_evidence/catalog.json) this obtains the
article's JATS full text, keeps it IN MEMORY ONLY, locates the Methods regions with the reference service's own
gate code (discovery.method_regions), checks the licence is countable (CC-BY / CC-BY-NC / CC0, no TDM
prohibition) and stores the sorted lexicon TOKENS (app/method_lexicon.json) -- never text.

Source order per paper: (1) a local JATS copy named <PMCID>.xml in --local-dir (the tracked efetch/<PMID>.xml
files are PubMed records without a body and are not usable), (2) Europe PMC fullTextXML, >= 1 s between
requests, two retries with back-off.  Progress is appended to --state (JSONL); a rerun skips finished papers.
Failures are written to --failures.  `compile` writes the deterministic sidecar that import_s0_evidence.py reads.

    backfill_methods_used.py run     --state S.jsonl --failures F.log [--local-dir DIR] [--limit N] [--retry-failed]
    backfill_methods_used.py compile --state S.jsonl --out reference_service/s0_methods_used.json
    backfill_methods_used.py report  --state S.jsonl
"""
from __future__ import annotations

import argparse
import collections
import datetime as dt
import hashlib
import json
import sys
import time
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[2]
APP = REPO / "reference_service" / "app"
sys.path.insert(0, str(APP))

import discovery  # noqa: E402
import harvest  # noqa: E402
import lexicon  # noqa: E402

BUNDLE = APP / "s0_evidence" / "catalog.json"
SCHEMA = "omicstat.s0-methods-used.v1"
SPACING_SECONDS = 1.2
MAX_BODY = 12_000_000
TERMINAL = {"ok", "licence_not_countable", "no_method_regions", "identity_mismatch", "no_body"}


def _now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def load_state(path: Path) -> dict[str, dict]:
    state: dict[str, dict] = {}
    if path.exists():
        for line in path.read_text(encoding="utf-8").splitlines():
            if line.strip():
                row = json.loads(line)
                state[row["pmid"]] = row
    return state


def fetch_europepmc(pmcid: str) -> bytes:
    url = "https://www.ebi.ac.uk/europepmc/webservices/rest/" + pmcid.upper() + "/fullTextXML"
    harvest._validate_url(url)
    last: Exception | None = None
    for attempt in range(3):
        try:
            with urlopen(Request(url, headers={"User-Agent": "omicstat-reference-s0-backfill/1.0 (one-off, 1 request/s)"}), timeout=30) as resp:
                body = resp.read(MAX_BODY + 1)
            if len(body) > MAX_BODY:
                raise ValueError("body larger than %d bytes" % MAX_BODY)
            return body
        except HTTPError as exc:
            last = exc
            if exc.code in (404, 403):
                break
        except (URLError, TimeoutError, ValueError, OSError) as exc:
            last = exc
        time.sleep(3 * (attempt + 1))
    raise RuntimeError("%s: %s" % (type(last).__name__, str(last)[:160]))


def process(paper: dict, raw: bytes, lex: dict) -> dict:
    """Pure: JATS bytes -> result row (no text kept)."""
    row = {"pmid": paper["pmid"], "pmcid": paper["pmcid"], "sha_match": hashlib.sha256(raw).hexdigest() == paper.get("jats_sha256")}
    try:
        article, _, _ = harvest._load_jats_article(raw, {"pmid": paper["pmid"], "pmcid": paper["pmcid"]})
    except harvest.HarvestError as exc:
        return row | {"status": "identity_mismatch" if exc.code in {"identifier_mismatch", "missing_jats_identifier"} else "parse_error", "detail": exc.code}
    body = article.find("./body")
    if body is None or not discovery._clean_text(body):
        return row | {"status": "no_body"}
    perm = article.find("./front/article-meta/permissions")
    links = [] if perm is None else [v for e in perm.iter() for k, v in e.attrib.items() if discovery._local(k).endswith("href")]
    rights = discovery.classify_rights(discovery._clean_text(perm), links)
    row["licence"] = rights["licence"]
    if rights["tdm_prohibited"] or rights["licence"] not in discovery.COUNTABLE_LICENCES:
        return row | {"status": "licence_not_countable"}
    regions = discovery.method_regions(body)
    if not regions:
        return row | {"status": "no_method_regions"}
    return row | {"status": "ok", "tokens": lexicon.scan(regions, lex)}


def cmd_run(a) -> int:
    bundle = json.loads(BUNDLE.read_text(encoding="utf-8"))
    papers = sorted(bundle["papers"], key=lambda p: p["pmid"])
    state_path = Path(a.state)
    state_path.parent.mkdir(parents=True, exist_ok=True)
    state = load_state(state_path)
    lex = lexicon.default_lexicon()
    local_dir = Path(a.local_dir) if a.local_dir else None
    done = fetched = local = failed = 0
    last_request = 0.0
    for paper in papers:
        prior = state.get(paper["pmid"])
        if prior and (prior["status"] in TERMINAL or not a.retry_failed):
            continue
        if a.limit and done >= a.limit:
            break
        raw, source = None, None
        if local_dir is not None and (local_dir / (paper["pmcid"] + ".xml")).is_file():
            candidate = (local_dir / (paper["pmcid"] + ".xml")).read_bytes()
            if b"<body" in candidate:
                raw, source = candidate, "local"
        error = None
        if raw is None:
            wait = SPACING_SECONDS - (time.monotonic() - last_request)
            if wait > 0:
                time.sleep(wait)
            last_request = time.monotonic()
            try:
                raw, source = fetch_europepmc(paper["pmcid"]), "europepmc"
            except RuntimeError as exc:
                error = str(exc)
            last_request = time.monotonic()
        if raw is None:
            row = {"pmid": paper["pmid"], "pmcid": paper["pmcid"], "status": "fetch_failed", "detail": error, "source": "europepmc", "at": _now()}
            failed += 1
            with open(a.failures, "a", encoding="utf-8") as fh:
                fh.write("%s\t%s\t%s\t%s\n" % (_now(), paper["pmid"], paper["pmcid"], error))
        else:
            row = process(paper, raw, lex) | {"source": source, "at": _now()}
            fetched += source == "europepmc"
            local += source == "local"
            if row["status"] not in {"ok", "licence_not_countable"}:
                with open(a.failures, "a", encoding="utf-8") as fh:
                    fh.write("%s\t%s\t%s\t%s %s\n" % (_now(), paper["pmid"], paper["pmcid"], row["status"], row.get("detail", "")))
        with open(state_path, "a", encoding="utf-8", newline="\n") as fh:
            fh.write(json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n")
        done += 1
        if done % 25 == 0:
            print("progress: %d processed (%d fetched, %d local, %d fetch failures)" % (done, fetched, local, failed), flush=True)
    print(json.dumps({"processed": done, "fetched_from_europepmc": fetched, "local_hits": local, "fetch_failures": failed}))
    return 0


def cmd_report(a) -> int:
    state = load_state(Path(a.state))
    print(json.dumps({"papers_in_state": len(state), "status": collections.Counter(r["status"] for r in state.values()),
                      "source": collections.Counter(r.get("source") for r in state.values()),
                      "sha_match": collections.Counter(r.get("sha_match") for r in state.values() if r["status"] != "fetch_failed")},
                     sort_keys=True, indent=1))
    return 0


def cmd_compile(a) -> int:
    bundle = json.loads(BUNDLE.read_text(encoding="utf-8"))
    state = load_state(Path(a.state))
    lex = lexicon.default_lexicon()
    papers, skipped = {}, {}
    for paper in sorted(bundle["papers"], key=lambda p: p["pmid"]):
        row = state.get(paper["pmid"])
        if row is None:
            skipped[paper["pmid"]] = "not_processed"
        elif row["status"] == "ok":
            papers[paper["pmid"]] = {"licence": row["licence"], "tokens": row["tokens"]}
        else:
            skipped[paper["pmid"]] = row["status"]
    doc = {"schema": SCHEMA, "lexicon_version": lex["version"],
           "lexicon_sha256": hashlib.sha256(lexicon.LEXICON_PATH.read_bytes()).hexdigest(),
           "note": "Lexicon tokens found in the Methods regions of countable-licence S0 corpus papers (tokens only, no text). Backfilled once from Europe PMC full text; papers whose licence is not countable or whose full text was unavailable carry no tokens.",
           "counts": {"papers": len(bundle["papers"]), "with_tokens": len(papers), "skipped": dict(sorted(collections.Counter(skipped.values()).items()))},
           "papers": papers, "skipped": skipped}
    Path(a.out).write_text(json.dumps(doc, ensure_ascii=False, indent=1, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps(doc["counts"], sort_keys=True))
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    run = sub.add_parser("run")
    run.add_argument("--state", required=True)
    run.add_argument("--failures", required=True)
    run.add_argument("--local-dir")
    run.add_argument("--limit", type=int, default=0)
    run.add_argument("--retry-failed", action="store_true")
    rep = sub.add_parser("report")
    rep.add_argument("--state", required=True)
    comp = sub.add_parser("compile")
    comp.add_argument("--state", required=True)
    comp.add_argument("--out", required=True)
    a = ap.parse_args()
    return {"run": cmd_run, "report": cmd_report, "compile": cmd_compile}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
