#!/usr/bin/env python3
"""One real call per vendored retrieval component (VENDOR_INTEGRATION_BRIEF sec 1.3).

Usage: /opt/retrieval-venv/bin/python tools/lit/vendor_live_check.py [--json out.json]

The vendored code (vendor/claude_science) is imported read-only: no bytecode is
written next to it, and nothing in it is modified. Each check prints PASS / FAIL /
SKIP with the evidence (counts, first identifiers). OpenAlex needs an API key in
OPENALEX_API_KEY (the vendored client refuses anonymous use); without one it is SKIP.
Contact address sent to NCBI / EBI: OMICSTAT_CONTACT_EMAIL, default a placeholder.
"""
import asyncio
import json
import os
import sys
import time

sys.dont_write_bytecode = True
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "vendor", "claude_science", "bio_tools", "lib"))
sys.path.insert(0, os.path.join(ROOT, "vendor", "claude_science", "skills", "literature-review"))
CONTACT = os.environ.get("OMICSTAT_CONTACT_EMAIL", "omicstat-s0@example.invalid")

results = []


def run(name, fn):
    t0 = time.time()
    try:
        status, evidence = fn()
    except Exception as exc:  # noqa: BLE001 -- a failed check is data here
        status, evidence = "FAIL", f"{type(exc).__name__}: {exc}"[:400]
    results.append({"component": name, "status": status, "evidence": evidence, "seconds": round(time.time() - t0, 1)})
    print(f"{status:4}  {name:28} {evidence}")


def pubmed_search():
    from pubmed_search import PubMedSearch
    r = PubMedSearch(email=CONTACT, tool="omicstat-s0").search('"DESeq2"[tiab] AND "apeglm"[tiab]', max_records=20)
    ids = r.get("pmids") or r.get("ids") or r.get("idlist") or []
    return ("PASS" if int(r.get("count", 0)) > 0 else "FAIL"), f"count={r.get('count')} first={list(ids)[:3]}"


def pubmed_efetch():
    from pubmed_fetch import PubMedFetcher
    recs = PubMedFetcher(email=CONTACT, tool="omicstat-s0").fetch_records(["25516281"])
    r = recs[0]
    title = r.get("title") or r.get("article_title") or ""
    journal = r.get("journal") or r.get("journal_title") or ""
    ok = "DESeq2" in title
    return ("PASS" if ok else "FAIL"), f"PMID 25516281 -> {title[:70]!r} | {str(journal)[:40]!r}"


def europepmc_fulltext():
    from europepmc_fulltext import EuropePMCClient, check_availability, fetch_fulltext_xml, extract_sections
    c = EuropePMCClient()
    av = check_availability(["PMC4302049"], client=c)[0]
    code, xml = fetch_fulltext_xml("PMC4302049", client=c)
    secs = extract_sections(xml) if xml else {}
    titles = [s.get("title") for s in (secs.get("sections") or [])][:6]
    return ("PASS" if code == 200 and xml else "FAIL"), f"PMC4302049 oa={av.get('is_open_access', av.get('isOpenAccess'))} http={code} bytes={len(xml or b'')} sections={titles}"


def openalex():
    if not os.environ.get("OPENALEX_API_KEY"):
        return "SKIP", "OPENALEX_API_KEY not set (vendored client requires a key)"
    from openalex_works import OpenAlexWorks
    w = OpenAlexWorks()
    r = w.search_works(search="DESeq2", per_page=2) if hasattr(w, "search_works") else None
    return ("PASS" if r else "FAIL"), str(r)[:200]


def crossref_verify():
    import kernel
    r = kernel.verify_dois(["10.1186/s13059-014-0550-8", "10.1093/bioinformatics/bty895"])
    ok = all(v.get("status") in ("ok", "verified", "resolved") or v.get("exists") or v.get("title") for v in r.values())
    summ = {k: (v.get("title") or v.get("status") or str(v))[:50] for k, v in r.items()}
    return ("PASS" if ok else "FAIL"), json.dumps(summ)[:300]


def mygene():
    from mygene_query import MyGeneQueryClient
    r = MyGeneQueryClient().querymany(["TP53", "DESI1"], scopes="symbol", fields="entrezgene,ensembl.gene,symbol", species="human")
    return ("PASS" if r and r[0].get("entrezgene") else "FAIL"), json.dumps([{k: x.get(k) for k in ("query", "entrezgene")} for x in r])[:200]


def quickgo():
    from quickgo_annotations import QuickGOClient, AnnotationQuery, fetch_annotations
    r = fetch_annotations(QuickGOClient(), AnnotationQuery(gene_product_id="UniProtKB:P04637", aspect="biological_process"))
    n = len(r.get("records") or r.get("annotations") or [])
    return ("PASS" if n > 0 else "FAIL"), f"P04637 BP annotations={n} keys={list(r)[:6]}"


def reactome():
    from reactome_map import map_identifiers, compact_view
    r = map_identifiers(["TP53", "MDM2", "CDKN1A"], "symbol")
    cv = compact_view(r)
    return ("PASS" if r else "FAIL"), json.dumps(cv)[:250]


def geo():
    from geo_meta import fetch_series, PoliteClient
    r = fetch_series("GSE52778", client=PoliteClient(user_agent=f"omicstat-s0 ({CONTACT})"))
    return ("PASS" if r.get("title") else "FAIL"), f"GSE52778 {str(r.get('title'))[:70]!r} samples={len(r.get('samples') or [])}"


def arrayexpress():
    from arrayexpress_experiments import SearchSpec, search_experiments
    r = search_experiments(SearchSpec(query="airway smooth muscle dexamethasone RNA-seq"), max_records=5)
    hits = r.get("records") or r.get("hits") or []
    return ("PASS" if hits else "FAIL"), f"records={len(hits)} keys={list(r)[:5]} first={[h.get('accession') for h in hits[:3]]}"


def cellguide():
    from mcp_cellguide.client import CellGuideClient

    async def go():
        c = CellGuideClient()
        try:
            snap = await c.get_snapshot_id()
            desc = await c.get_description("CL:0000236")
            return snap, desc
        finally:
            await c.close()
    snap, desc = asyncio.run(go())
    return ("PASS" if snap else "FAIL"), f"snapshot={snap} B cell description={str(desc)[:80]!r}"


for name, fn in [("pubmed_search (esearch)", pubmed_search), ("pubmed_fetch (efetch)", pubmed_efetch),
                 ("europepmc_fulltext", europepmc_fulltext), ("openalex_works", openalex),
                 ("literature-review verify_dois", crossref_verify), ("mygene_query", mygene),
                 ("quickgo_annotations", quickgo), ("reactome_map", reactome), ("geo_meta", geo),
                 ("arrayexpress_experiments", arrayexpress), ("mcp_cellguide", cellguide)]:
    run(name, fn)

if "--json" in sys.argv:
    with open(sys.argv[sys.argv.index("--json") + 1], "w", encoding="utf-8") as fh:
        json.dump(results, fh, indent=1, ensure_ascii=False)
sys.exit(1 if any(r["status"] == "FAIL" for r in results) else 0)
