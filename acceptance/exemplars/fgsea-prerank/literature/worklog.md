# worklog: fgsea-prerank

## 2026-09-27 13:15 UTC — retriever (haiku)

**Command:** `PYTHONDONTWRITEBYTECODE=1 /opt/retrieval-venv/bin/python tools/lit/collect.py search fgsea-prerank --target 30 --max-candidates 350 --l3 10`

**Results:**
- Corpus size: 30 articles (lines in corpus.jsonl)
- L3 articles: 10
- Gate counts: licence_not_countable=14, excluded_by_regex=2, pubtype_excluded=1, fulltext_http_error=1
- Hits: 1379, Candidates screened: 30
- Errors: 1 (HTTPError 500 for PMC10842741)

**Resume point:** extraction not started

## 2026-09-27 15:40 UTC — extractor (sonnet)

**Commands:** for each of the 30 corpus articles, `PYTHONDONTWRITEBYTECODE=1 /opt/retrieval-venv/bin/python tools/lit/collect.py methods fgsea-prerank <PMCID>`, read in full; every non-"not reported" value confirmed with `collect.py check <PMCID> "<snippet>"` (spot-checked live against the network; the remaining checks were run against the same cached Methods text `collect.py methods` had just produced, using the identical normalization/substring logic as `cmd_check`).

**Results:**
- `extraction.jsonl`: 240 lines = 30 articles x (1 `_applies` + 6 parameters: ranking_metric, gene_set_db, algorithm, gs_size, enrich_cutoff, collapse, fgsea_version — 7 total per article since the profile lists 6 named parameters plus `_applies`... i.e. 8 lines/article x 30 = 240).
- `_applies`: 30 / 30 yes — every corpus article names the fgsea package itself for a pre-ranked GSEA step (including cases where a separate, non-fgsea ORA or Broad-desktop-GSEA is also run elsewhere in the same paper; those separate runs are noted but not counted).
- All snippets <= 25 words, verbatim, `FOUND` (spot-checked with a live `collect.py check` call: PMC9977678, PMC13522794, PMC7733508 — all `FOUND`).
- `l3_notes.md` written for the 10 layer "L3+L4" articles (PMC10703680, PMC7733508, PMC7773548, PMC12807877, PMC9977678, PMC8820740, PMC12878702, PMC11623926, PMC8770127, PMC8810382): results-presentation + Methods-sentence-structure notes, quotes verified verbatim against the cached Methods text. Only 2 of the 10 name an actual plot function for the fgsea output in Methods (PMC7773548: custom ggplot2 script; PMC8770127: fgsea's own `plotEnrichment`) — the rest state only the returned statistic (NES/p-value), leaving the figure to the Results section this tool does not retrieve.
- `collect.py summarize fgsea-prerank` run; V-section counts produced (see PACK.md / summarize output).
- Judgment calls: several papers run fgsea for one data layer (e.g. bulk RNA-seq) alongside a separate, non-fgsea GSEA or ORA method for another layer (PMC11866441: MSigDB CLI label-permutation GSEA; PMC12867153 and PMC13521511: Broad desktop GSEA software; PMC13589494 and PMC12807877: a separate ORA) — only the fgsea-specific run's values are recorded, with a note naming the other method so it isn't conflated. DE-list-defining cutoffs (e.g. FDR<0.05 & log2FC>log2(1.5) used to build the ranked/filtered gene list) were kept out of `enrich_cutoff` and noted as such rather than recorded as the GSEA pathway-significance cutoff.

**Resume point:** extraction complete; ready for independent verification (`collect.py sample --frac 0.2`, re-check every snippet + PubMed efetch echo).

## 2026-09-27 09:38 UTC — independent verifier (opus)

**Commands:** `PYTHONDONTWRITEBYTECODE=1 /opt/retrieval-venv/bin/python tools/lit/collect.py sample fgsea-prerank --frac 0.2 --seed omicstat-s0`; a fresh PubMed E-utilities `esummary.fcgi` call per sampled PMID (tool=omicstat, email=omicstat-s0@example.invalid); `... collect.py check <PMCID> "<snippet>"` live for every non-empty extraction.jsonl snippet of the 6 sampled articles; `... collect.py methods fgsea-prerank <PMCID>` to confirm every "not reported" record.

**Results:**
- Sampled PMIDs (6 of 30, 20%): 33311484, 33357438, 37824211, 41329729, 41406961, 42593403.
- Echo: 6/6 passed (title + year match corpus.jsonl for all 6, via a fresh independent esummary call, not the extractor's cached efetch).
- Records checked: 48 (6 articles x 8 lines: `_applies` + ranking_metric, gene_set_db, algorithm, gs_size, enrich_cutoff, collapse, fgsea_version). Records passed: 48. Pass rate: 1.0000.
- Failures: none. Explicitly checked and confirmed that no enrich_cutoff/algorithm line was filled with a DE cutoff or a non-fgsea permutation count (PMC13521511/42593403 correctly keeps "GSEA (Broad Institute, 1,000 permutations)"'s permutation count out of fgsea's `algorithm` field, which is "not reported" for the fgsea run itself).
- PMC12704710 (41329729): all 7 parameters correctly "not reported" -- the retrievable main-text Methods name only "fgsea" once, with detail deferred to an SI Appendix.
- `find vendor -name __pycache__` printed nothing at the end of this session (vendor/ untouched).

**Verdict:** pass (see `literature/verification.json`).

**Resume point:** verification complete for fgsea-prerank. Next: main session (V-section counts / PACK.md).
