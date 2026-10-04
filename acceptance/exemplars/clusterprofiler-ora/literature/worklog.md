# worklog: clusterprofiler-ora

## 2026-09-27 13:00 UTC — retriever (haiku)

**Command:** `PYTHONDONTWRITEBYTECODE=1 /opt/retrieval-venv/bin/python tools/lit/collect.py search clusterprofiler-ora --target 30 --max-candidates 350 --l3 10`

**Results:**
- Corpus size: 30 articles (lines in corpus.jsonl)
- L3 articles: 10
- Gate counts: no_methods_signal=6, licence_not_countable=12, excluded_by_regex=3, pubtype_excluded=1, fulltext_http_error=1
- Hits: 3128, Candidates screened: 30
- Errors: 1 (HTTPError 500 for PMC8639773)

**Resume point:** extraction not started

## 2026-09-27 09:30 UTC — extractor (sonnet)

**Commands:** `PYTHONDONTWRITEBYTECODE=1 /opt/retrieval-venv/bin/python tools/lit/collect.py methods clusterprofiler-ora <PMCID>` for all 30 corpus articles; `... collect.py check <PMCID> "<snippet>"` for all 108 unique non-empty (pmcid, snippet) pairs (verified FOUND on every one, after fixing several verbatim-mismatch snippets — embedded citation markers/URLs, curly-quote punctuation, version-string typos, a 32-word over-length quote, and one sentence-initial capitalization mismatch).

**Results:**
- `_applies`: 30/30 yes, 0 no (every corpus article uses enrichGO/enricher/enrichKEGG/enrichPathway/enrichDO/enrichWP or explicit clusterProfiler ORA language)
- 270 extraction.jsonl lines written (30 articles x 1 `_applies` + 8 parameter lines)
- `l3_notes.md` written for all 10 L3 articles (layer "L3+L4")

**Judgment calls (see notes in extraction.jsonl for full text):** kept DE/upstream-filter cutoffs (e.g. TRRUST TF-enrichment cutoffs, VIP scores, permutation-based DEG filters) out of `enrich_cutoff`, recording them only in `input_genes`/note; recorded all gene-set databases tested per article (including custom/curated collections); recorded multiple parallel analyses (e.g. compareCluster across three gene-list types) with "; "-joined values and an explanatory note where settings differed; left several `input_genes`/`universe`/`p_adjust_method` fields as "not reported" with a note explaining an adjacent-but-not-restated value in the Methods text.

**Resume point:** extraction complete; ready for `collect.py summarize clusterprofiler-ora` and commit.

## 2026-09-27 09:35 UTC — independent verifier (sonnet)

**Commands:** `PYTHONDONTWRITEBYTECODE=1 /opt/retrieval-venv/bin/python tools/lit/collect.py sample clusterprofiler-ora --frac 0.2 --seed omicstat-s0` (6 PMIDs: 33239621, 34779829, 36282572, 36537238, 37871969, 39578099); a fresh live PubMed E-utilities `esummary.fcgi` call (tool=omicstat, email=omicstat-s0@example.invalid) per sampled PMID; `collect.py check <PMCID> "<snippet>"` for all 20 unique non-empty (pmcid, snippet) pairs among the 54 extraction.jsonl lines (6 articles x 9 lines) belonging to the sample; `collect.py methods clusterprofiler-ora <PMCID>` full-Methods read for every "not reported" line to confirm the value is truly absent.

**Results:**
- Echo: 6/6 passed (title html-unescaped + tag-stripped, and year, matched corpus.jsonl for every sampled PMID)
- Snippet check: 20/20 unique snippets FOUND live, all <=25 words
- Records checked: 54, records passed: 54, pass rate: 1.0000
- 0 failures. No "not reported" line found to conceal a stated value; no enrich_cutoff found holding a DE cutoff; all 6 sampled `_applies=yes` articles confirmed to name a real ORA function/language sharing a sentence with clusterProfiler
- One judgment call reviewed and accepted (see verification.json notes): PMC9753996 `input_genes` synthesizes two adjacent Methods sentences (enrichGO call + promoter-region definition) rather than quoting one sentence verbatim -- a defensible same-paragraph read, not a cross-topic misattribution

**Verdict:** pass (>= 0.95 threshold met, all echoes pass)

**Output:** `literature/verification.json` written; `literature/extraction.jsonl` not modified.

**Resume point:** verification complete; ready for main-session PACK.md / commit.
