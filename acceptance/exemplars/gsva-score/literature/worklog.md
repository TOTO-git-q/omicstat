# worklog: gsva-score

## 2026-09-27 13:20 UTC — retriever (haiku)

**Command:** `PYTHONDONTWRITEBYTECODE=1 /opt/retrieval-venv/bin/python tools/lit/collect.py search gsva-score --target 30 --max-candidates 350 --l3 10`

**Results:**
- Corpus size: 30 articles (lines in corpus.jsonl)
- L3 articles: 10
- Gate counts: licence_not_countable=7
- Hits: 1047, Candidates screened: 30
- Errors: none

**Resume point:** extraction not started

## 2026-09-27 09:22 UTC — extractor (sonnet)

**Commands:** `PYTHONDONTWRITEBYTECODE=1 /opt/retrieval-venv/bin/python tools/lit/collect.py methods gsva-score <PMCID>` for all 30 corpus articles;
`... collect.py check <PMCID> "<snippet>"` for every non-empty snippet (all FOUND, incl. live spot-checks);
`... collect.py summarize gsva-score`.

**Results:**
- `extraction.jsonl` written: 240 lines = 30 articles x (1 `_applies` + 7 parameters: method, kcdf, input, gene_set_db, gs_size, downstream_test, gsva_version).
- `_applies`: 30 of 30 corpus papers apply (all name the GSVA R package, method gsva/ssgsea/zscore, or ssgsea via GSVA). None excluded.
- Every snippet confirmed FOUND against the article's Methods text (verified independently: locally against the saved `collect.py methods` output, and with live `collect.py check` spot-checks across both modules).
- `l3_notes.md` written for the 10 L3+L4 exemplars (PMC7755902, PMC12807877, PMC9705439, PMC8683505, PMC7730477, PMC10689851, PMC8439149, PMC8791834, PMC7720616, PMC12764429).
- Judgment calls: `method` recorded as "gsva" (with a note) whenever only "the GSVA package/R package" is named without a method argument, per protocol; several articles run 2+ GSVA calls with different gene-set collections or downstream tests, recorded on one line joined by "; " with a note; `gs_size` is "not reported" for all 30 (no article states min.sz/max.sz); one article (PMC12807877) also runs a separate, non-R-package "gsva" via the Python GSEApy reimplementation for other figures — not counted toward the extracted parameters, noted instead.
- `summarize gsva-score` output: see PACK.md / commit for the full table; most-common values are method=gsva (20), ssgsea (7); gsva_version reported in 17/30 articles (mostly 1.26-1.52 range).

**Resume point:** extraction complete for all 30 corpus articles + 10 L3 notes. Next: independent verifier (`collect.py sample gsva-score`, re-check >=20%, write `verification.json`).

## 2026-09-27 09:38 UTC — independent verifier (opus)

**Commands:** `PYTHONDONTWRITEBYTECODE=1 /opt/retrieval-venv/bin/python tools/lit/collect.py sample gsva-score --frac 0.2 --seed omicstat-s0`; a fresh PubMed E-utilities `esummary.fcgi` call per sampled PMID (tool=omicstat, email=omicstat-s0@example.invalid); `... collect.py check <PMCID> "<snippet>"` live for every non-empty extraction.jsonl snippet of the 6 sampled articles; `... collect.py methods gsva-score <PMCID>` to confirm every "not reported" record.

**Results:**
- Sampled PMIDs (6 of 30, 20%): 36433984, 36548025, 39688922, 41424381, 42702610, 42704368.
- Echo: 6/6 passed (title + year match corpus.jsonl for all 6, via a fresh independent esummary call, not the extractor's cached efetch).
- Records checked: 48 (6 articles x 8 lines: `_applies` + method, kcdf, input, gene_set_db, gs_size, downstream_test, gsva_version). Records passed: 48. Pass rate: 1.0000.
- Failures: none.
- Notable judgment calls confirmed sound: PMC13549129's `gene_set_db = "not reported"` for the custom "T cell suppression signature" (correctly distinguished from a named public DB, documented with a note); PMC11948580's blanket "not reported" for kcdf/input/gene_set_db/gs_size/downstream_test/gsva_version confirmed against the full Methods (RNA-Seq, ATAC-Seq, Statistics sections) -- no value is stated tied specifically to the GSVA/ECDF step.
- `find vendor -name __pycache__` printed nothing at the end of this session (vendor/ untouched).

**Verdict:** pass (see `literature/verification.json`).

**Resume point:** verification complete for gsva-score. Next: main session (V-section counts / PACK.md).
