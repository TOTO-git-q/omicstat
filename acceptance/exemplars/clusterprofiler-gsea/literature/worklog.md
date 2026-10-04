# worklog: clusterprofiler-gsea

## 2026-09-27 13:05 UTC — retriever (haiku)

**Command:** `PYTHONDONTWRITEBYTECODE=1 /opt/retrieval-venv/bin/python tools/lit/collect.py search clusterprofiler-gsea --target 30 --max-candidates 350 --l3 10`

**Results:**
- Corpus size: 30 articles (lines in corpus.jsonl)
- L3 articles: 10
- Gate counts: no_methods_signal=32, licence_not_countable=13, excluded_by_regex=4, fulltext_http_error=1
- Hits: 1804, Candidates screened: 30
- Errors: 1 (HTTPError 500 for PMC8639773)

**Resume point:** extraction not started

## 2026-09-27 09:35 UTC — extractor (sonnet)

**Commands:** `PYTHONDONTWRITEBYTECODE=1 /opt/retrieval-venv/bin/python tools/lit/collect.py methods clusterprofiler-gsea <PMCID>` for all 30 corpus articles; `... collect.py check <PMCID> "<snippet>"` for all 98 unique non-empty (pmcid, snippet) pairs (verified FOUND on every one, after fixing several verbatim-mismatch snippets — a cross-contaminated cutoff copy-pasted from a different article, an argument-order bug that would have flipped an `_applies` result, embedded citation markers, and a capitalization mismatch).

**Results:**
- `_applies`: 28/30 yes, 2 no
  - PMC8617197: Methods section titled "gene set enrichment analysis (GSEA)" but the clusterProfiler function actually invoked is `enricher` (ORA), not a ranked-list GSEA function — recorded as not applying
  - PMC10645602: sentence names `enrichKEGG`/`enrichGO` (ORA functions); a separate, unspecified "GSEA package" is mentioned but not clearly attributed to clusterProfiler — recorded as not applying
- 226 extraction.jsonl lines written (28 applies=yes articles x 1 `_applies` + 7 parameter lines, plus 2 applies=no articles x 1 `_applies` line only)
- `l3_notes.md` written for all 10 L3 articles (layer "L3+L4")

**Judgment calls (see notes in extraction.jsonl for full text):** fixed a real data bug where an `enrich_cutoff` value/snippet had been copied from a different article and did not appear in the source text (set to "not reported" instead); recorded `ranking_metric` as the statistic actually used to rank genes (DESeq2 Wald/test statistic, log2FC, correlation coefficients, model coefficients, etc.), distinguishing it from DE-cutoffs that define an input gene list; recorded multiple ranking metrics/gene-set databases with "; "-joined values and an explanatory note where a paper ran GSEA multiple times with different settings; noted several unusual GSEA uses (ranking by genomic breakpoint position rather than expression, ranking by correlation coefficient rather than a DE statistic).

**Resume point:** extraction complete; ready for `collect.py summarize clusterprofiler-gsea` and commit.

## 2026-09-27 09:35 UTC — independent verifier (sonnet)

**Commands:** `PYTHONDONTWRITEBYTECODE=1 /opt/retrieval-venv/bin/python tools/lit/collect.py sample clusterprofiler-gsea --frac 0.2 --seed omicstat-s0` (6 PMIDs: 33108271, 38001542, 39284687, 39361432, 41406948, 42658766); a fresh live PubMed E-utilities `esummary.fcgi` call (tool=omicstat, email=omicstat-s0@example.invalid) per sampled PMID; `collect.py check <PMCID> "<snippet>"` for all 19 unique non-empty (pmcid, snippet) pairs among the 48 extraction.jsonl lines (6 articles x 8 lines) belonging to the sample; `collect.py methods clusterprofiler-gsea <PMCID>` full-Methods read for every "not reported" line to confirm the value is truly absent.

**Results:**
- Echo: 6/6 passed (title html-unescaped + tag-stripped, and year, matched corpus.jsonl for every sampled PMID)
- Snippet check: 19/19 unique snippets FOUND live, all <=25 words
- Records checked: 48, records passed: 48, pass rate: 1.0000
- 0 failures. All 6 sampled `_applies=yes` articles confirmed to name a real GSEA function/language sharing a sentence with clusterProfiler. enrich_cutoff correctly never holds a DE cutoff in this sample -- specifically verified against DE thresholds stated in the same Methods paragraph for PMC13535199 (DESeq2 Padj<0.1 vs. gseGO "P cutoff = 0.05"), PMC10668425 (unstated DESeq2 DEG cutoff vs. GSEA "FDR<=0.25"), and PMC7591261 (edgeR DEG cutoff |FC|>=1.5/FDR<0.05, correctly left "not reported" for the GSEA enrich_cutoff rather than reused)
- Two judgment calls reviewed and accepted (see verification.json notes): PMC12765837 `ranking_metric` pulls the log2(fold-change)/AD-vs-controls definition from an adjacent Methods subsection of the same article (not from Results/figures); PMC10668425 `_applies=yes` is kept despite clusterProfiler being named jointly with the javaGSEA Desktop Application, matching the extractor's own flagged note

**Verdict:** pass (>= 0.95 threshold met, all echoes pass)

**Output:** `literature/verification.json` written; `literature/extraction.jsonl` not modified.

**Resume point:** verification complete; ready for main-session PACK.md / commit.
