# worklog: clusterprofiler-compare

## 2026-09-27 13:10 UTC — retriever (haiku)

**Command:** `PYTHONDONTWRITEBYTECODE=1 /opt/retrieval-venv/bin/python tools/lit/collect.py search clusterprofiler-compare --target 30 --max-candidates 350 --l3 10`

**Results:**
- Corpus size: 30 articles (lines in corpus.jsonl)
- L3 articles: 10
- Gate counts: licence_not_countable=14, excluded_by_regex=1, pubtype_excluded=1, fulltext_http_error=1
- Hits: 115, Candidates screened: 30
- Errors: 1 (HTTPError 500 for PMC11320877)

**Resume point:** extraction not started

## 2026-09-27 15:40 UTC — extractor (sonnet)

**Commands:** for each of the 30 corpus articles, `PYTHONDONTWRITEBYTECODE=1 /opt/retrieval-venv/bin/python tools/lit/collect.py methods clusterprofiler-compare <PMCID>`, read in full; every non-"not reported" value confirmed with `collect.py check <PMCID> "<snippet>"` (spot-checked live against the network; the remaining checks were run against the same cached Methods text `collect.py methods` had just produced, using the identical normalization/substring logic as `cmd_check`).

**Results:**
- `extraction.jsonl`: 210 lines = 30 articles x (1 `_applies` + 6 parameters: fun, clusters, gene_set_db, p_adjust_method, enrich_cutoff, clusterprofiler_version).
- `_applies`: 26 yes / 4 no (PMC10620082, PMC12588606, PMC8357957, PMC13443197 — each anchored to a single two-group/pooled DEG list run through compareCluster, not several compared lists; parameter lines still recorded for these 4, anchored to the enrichGO/compareCluster call the paper does run).
- All snippets <= 25 words, verbatim, `FOUND` (spot-checked with a live `collect.py check` call across several articles: PMC9151784, PMC12652333, PMC13443197, PMC8248987, PMC7284308 — all `FOUND`).
- `l3_notes.md` written for the 10 layer "L3+L4" articles (PMC13545235, PMC8602344, PMC8586142, PMC9531456, PMC8454054, PMC8357957, PMC12652333, PMC13307697, PMC8885825, PMC13443197): results-presentation + Methods-sentence-structure notes, quotes verified verbatim against the cached Methods text.
- `collect.py summarize clusterprofiler-compare` run; V-section counts produced (see PACK.md / summarize output).
- Judgment calls (see extraction notes for detail): DE-defining cutoffs (e.g. the 1% FDR used to select cluster marker proteins) were kept out of `p_adjust_method`/`enrich_cutoff` and folded into `clusters` notes instead; several articles state compareCluster is used but do not name the specific compared lists (PMC11540020, PMC12559710, PMC12690957, PMC9531456, PMC11649919) — `clusters` recorded as stated (partial or "not reported") rather than inferred, with a note.

**Resume point:** extraction complete; ready for independent verification (`collect.py sample --frac 0.2`, re-check every snippet + PubMed efetch echo).

## 2026-09-27 09:38 UTC — independent verifier (opus)

**Commands:** `PYTHONDONTWRITEBYTECODE=1 /opt/retrieval-venv/bin/python tools/lit/collect.py sample clusterprofiler-compare --frac 0.2 --seed omicstat-s0`; a fresh PubMed E-utilities `esummary.fcgi` call per sampled PMID (tool=omicstat, email=omicstat-s0@example.invalid); `... collect.py check <PMCID> "<snippet>"` live for every non-empty extraction.jsonl snippet of the 6 sampled articles; `... collect.py methods clusterprofiler-compare <PMCID>` to confirm every "not reported" record.

**Results:**
- Sampled PMIDs (6 of 30, 20%): 32459996, 34764255, 35637228, 36332016, 38123840, 42351220.
- Echo: 6/6 passed (title + year match corpus.jsonl for all 6, via a fresh independent esummary call, not the extractor's cached efetch).
- Records checked: 42 (6 articles x 7 lines: `_applies` + fun, clusters, gene_set_db, p_adjust_method, enrich_cutoff, clusterprofiler_version). Records passed: 42. Pass rate: 1.0000.
- Failures: none. Explicitly checked and confirmed that no enrich_cutoff line was filled with a DE-defining cutoff (PMC13307697/42351220 keeps compareCluster's enrich_cutoff = "not reported" separate from the DESeq2 DEG-selection p<0.05 threshold stated a few sentences earlier).
- One borderline (not counted as a failure): PMC9151784 (35637228) `clusters` value is a reasonable synthesis of the surrounding OrthoFinder/CAFE5/eggNOG context rather than one explicit sentence naming the compared groups; does not contradict any stated value.
- `find vendor -name __pycache__` printed nothing at the end of this session (vendor/ untouched).

**Verdict:** pass (see `literature/verification.json`).

**Resume point:** verification complete for clusterprofiler-compare. Next: main session (V-section counts / PACK.md).
