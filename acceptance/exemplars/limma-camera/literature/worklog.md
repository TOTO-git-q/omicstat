# worklog: limma-camera

## 2026-09-27 13:25 UTC — retriever (haiku)

**Command:** `PYTHONDONTWRITEBYTECODE=1 /opt/retrieval-venv/bin/python tools/lit/collect.py search limma-camera --target 30 --max-candidates 350 --l3 10`

**Results:**
- Corpus size: 30 articles (lines in corpus.jsonl)
- L3 articles: 10
- Gate counts: no_methods_signal=29, licence_not_countable=7, fulltext_http_error=3, excluded_by_regex=1
- Hits: 709, Candidates screened: 30
- Errors: 3 (HTTPError 500 for PMC9780780, PMC8733895, PMC9010342)

**Resume point:** extraction not started

## 2026-09-27 09:22 UTC — extractor (sonnet)

**Commands:** `PYTHONDONTWRITEBYTECODE=1 /opt/retrieval-venv/bin/python tools/lit/collect.py methods limma-camera <PMCID>` for all 30 corpus articles;
`... collect.py check <PMCID> "<snippet>"` for every non-empty snippet (all FOUND, incl. live spot-checks);
`... collect.py summarize limma-camera`.

**Results:**
- `extraction.jsonl` written: 240 lines = 30 articles x (1 `_applies` + 7 parameters: test, inter_gene_cor, gene_set_db, expression_input, p_adjust_method, enrich_cutoff, limma_version).
- `_applies`: **11 of 30** apply (limma's `camera`/`cameraPR`/`roast` genuinely used: PMC10735226, PMC10849759, PMC11564874, PMC11602548, PMC12764432, PMC8630169, PMC8660905, PMC8783691, PMC9800282, PMC12685072, PMC8643633). **19 of 30 do not apply** — main reasons: the retrieval regex's "camera"+"limma" co-occurrence fires on papers whose actual gene-set test is GSVA, fgsea, a generic/unnamed "GSEA", PANTHER/clusterProfiler/GOrilla overrepresentation, STRING, GAGE, the Broad GSEA desktop tool, or the ToppGene/ToppFun portal, with limma used only for differential expression, batch correction, or (in 3 cases) not for any gene-set-adjacent step at all. Every `applies=no` line is anchored to the paper's actual gene-set method with a note, and parameters are filled from that anchor analysis where the wording permits (e.g. `gene_set_db`, `p_adjust_method` for the DE step), else "not reported".
- Every snippet confirmed FOUND against the article's Methods text (verified locally against the saved `collect.py methods` output, plus live `collect.py check` spot-checks).
- `l3_notes.md` written for the 10 L3+L4 exemplars (PMC10735226, PMC9859757, PMC13416155, PMC8656144, PMC8660905, PMC8643633, PMC7648065, PMC8630169, PMC7605249, PMC10745716); 6 of these 10 turned out on close reading to actually apply, 4 do not (called out explicitly in the notes as a useful negative-control pattern).
- Judgment calls: `inter_gene_cor` recorded "not reported" throughout (no article restates the value or says "estimated", even when "default settings" is mentioned generically); DE-step multiple-testing corrections (e.g. Benjamini-Hochberg for the underlying limma/edgeR/DESeq2 DE) are recorded under `p_adjust_method`/`limma_version` only where the Methods text ties them to the same sentence/paragraph as the gene-set step, otherwise left "not reported" with a note explaining the DE-vs-gene-set distinction was kept separate; PMC8630169 runs both `roast` and `cameraPR` for two different result types (analyte-set vs mediation-analysis), recorded on one line per parameter, "; "-joined, with a note.
- `summarize limma-camera` output: see PACK.md / commit for the full table; test = camera (6), cameraPR (3), roast (1), roast+cameraPR combined (1); inter_gene_cor and enrich_cutoff are "not reported" in nearly all applicable papers.

**Resume point:** extraction complete for all 30 corpus articles + 10 L3 notes. Next: independent verifier (`collect.py sample limma-camera`, re-check >=20%, write `verification.json`).

## 2026-09-27 -- main session: corpus re-collected after the signal was tightened
- Round 1: 11 of 30 applied; the signal alternative `camera (` matched microscope cameras.
- Profile signal tightened (test name in one sentence with limma, or cameraPR / mroast / "camera function|test|method"); `collect.py search limma-camera --target 30 --max-candidates 350 --l3 10` rerun.
- New corpus: 30 articles (10 L3); 10 carried over from round 1 (all applies = yes), 20 new. Gates: no_methods_signal 223, licence 9, fulltext_http_error 9, excluded_by_regex 5.
- Round-1 extraction lines stay in extraction.jsonl; `collect.py summarize` counts only the current corpus.
- Resume point: top-up extraction for the 20 new articles (no extraction lines yet), then l3_notes.md for the current L3 set, then independent verification.

## 2026-09-27 09:50 UTC — extractor (sonnet), top-up

**Commands:** `PYTHONDONTWRITEBYTECODE=1 /opt/retrieval-venv/bin/python tools/lit/collect.py methods limma-camera <PMCID>` for the 20 new corpus articles (no prior `_applies` line); `... collect.py check <PMCID> "<snippet>"` for every non-empty snippet (all FOUND after fixing 2 snippets that did not match verbatim on the first try); `... collect.py summarize limma-camera`.

**Results:**
- `extraction.jsonl`: 160 new lines appended (240 -> 400) = 20 articles x (1 `_applies` + 7 parameters). Round-1 lines for articles no longer in the current corpus were left untouched (not deleted, not counted by `summarize`).
- `_applies` among the 20 new articles: **19 yes, 1 no** (PMC9462502 / PMID 35993362 — "FRY" there is a gene symbol, part of a "FAT/FRY" molecular subtype name, not limma's `fry()` gene-set test; limma is used only to compare expression of that one gene between tumor and normal tissue, and the paper's separate "gene set enrichment analysis" step names no tool, using classic Broad-GSEA-style P<0.05/FDR<0.25 cutoffs). Combined with the 10 carried-over round-1 lines (all applies = yes), the current 30-article corpus is **29 of 30 apply**.
- Test values across the 19 new applies=yes articles: camera (10 total incl. carried-over, see `summarize`), fry (multiple runs across several papers, incl. within-paper splits where scRNA-seq/DSP data uses fry and bulk RNA-seq in the same paper uses fgsea instead), cameraPR, roast, and combinations (roast+camera, fry+camera, camera+cameraPR) in single papers with two distinct gene-set runs on different data modalities (RNA-seq vs Hi-C/ChIP-seq/ATAC-seq peaks, or two proteomics/metabolomics result types) — recorded on one line per parameter, "; "-joined, with a note, per the module's convention.
- Every snippet confirmed FOUND against the article's Methods text via live `collect.py check` (2 snippets needed a wording fix on the first pass: a citation number/period mismatch in "v3.46.0" vs "v.3.46.0", and a missing inline citation "(65)" between "voom" and "and eBayes" — both fixed and re-verified).
- `l3_notes.md` rewritten for the current 10 L3+L4 articles: 3 notes kept unchanged from round 1 (PMC8660905, PMC8643633, PMC8630169, still in the current corpus), 7 new notes written (PMC11564874, carried over from round 1 but not previously in `l3_notes.md`; PMC7673760, PMC12479364, PMC13388965, PMC9314343, PMC12286861, PMC11146594, all new to the corpus). All 10 of the current L3 set apply = yes — a change from round 1 (6 of 10 applied), attributable to the tightened signal filtering out the "camera" = microscope false positives that had inflated the round-1 L3 candidate pool; this absence of negative-control L3 examples is flagged in the notes file for the verifier.
- Judgment calls: (1) `inter_gene_cor` recorded as an explicit numeric value ("0.01 (default)" / "0.01 (standard)") only for the 2 new articles that literally restate the number (PMC7511692, PMC12618235); "default settings" mentioned generically (e.g. PMC9589007's cameraPR) is still recorded "not reported", consistent with round-1 policy. (2) Following the round-1 precedent (PMC11602548), `p_adjust_method` is recorded "not reported" whenever the Methods text says only "FDR correction" / "FDR-corrected" generically without naming Benjamini-Hochberg (or another method) for the gene-set step itself, even when a numeric `enrich_cutoff` is available — the snippet and a note point to where FDR is mentioned. (3) DE-step multiple-testing corrections and DE cutoffs are kept out of the gene-set `p_adjust_method`/`enrich_cutoff` fields unless the same sentence/paragraph explicitly reattaches them to the camera/roast/fry/mroast call. (4) PMC9462502 is a clean instance of the module's core false-positive risk (a gene symbol "FRY" rather than the function), recorded as `applies=no` with a note. (5) Several papers run 2 (occasionally more) distinct limma gene-set tests on different data types/modalities in one paper (e.g. PMC9314343: fry x2 + camera + kegga; PMC11146594: roast + fry; PMC13388965: fry x3 on 3 input matrices) — each such `test`/`gene_set_db`/`expression_input` line is "; "-joined across runs with a note, per the module's multi-run convention, rather than split into extra `_applies` lines.
- `summarize limma-camera` output: 29 of 30 corpus papers apply; test = camera (10), cameraPR (5), fry (5), roast (3), plus 6 single-paper multi-test combination strings; `inter_gene_cor`, `p_adjust_method` and `enrich_cutoff` are "not reported" in the large majority of applicable papers; `limma_version` stated in only 8 of 29 applicable papers (3.1.6.8, 3.42.0, 3.42.2 x2, 3.44.3, 3.46.0, 3.48.1, 3.50.3 x2).

**Resume point:** extraction complete for all 30 corpus articles (10 carried over unchanged + 20 new) and `l3_notes.md` rewritten for the current 10 L3 articles. Next: independent verification (`collect.py sample limma-camera`, re-check >=20%, write `verification.json`).

## 2026-09-27 09:57 UTC — independent verifier (sonnet/opus)

**Commands:** `PYTHONDONTWRITEBYTECODE=1 /opt/retrieval-venv/bin/python tools/lit/collect.py sample limma-camera --frac 0.2 --seed omicstat-s0`; a fresh PubMed `esummary.fcgi` call (tool=omicstat, email=omicstat-s0@example.invalid -- `$OMICSTAT_CONTACT_EMAIL` was unset) per sampled PMID; `... collect.py check <PMCID> "<snippet>"` for every non-empty snippet of the sampled articles' extraction lines; `... collect.py methods limma-camera <PMCID>` (full Methods) for every "not reported" line and for every `_applies` judgment call.

**Results:**
- Sample (6 of 30 = 20%): PMIDs 38032734 (PMC10849759), 40500437 (PMC12286861), 40926076 (PMC12479364), 42209519 (PMC13388965), 42258354 (PMC13383671), 42258753 (PMC13313547). All 6 are current-corpus articles (no round-1-dropped articles in the sample).
- Echo: 6/6 passed -- fresh esummary title (html-unescaped, normalized) and year matched `corpus.jsonl` exactly for every sampled PMID.
- 48 extraction lines checked (6 articles x (1 `_applies` + 7 parameters)). 27 non-empty snippets, all re-checked live: FOUND, <=25 words, and confirmed to say what the recorded value claims and to answer the anchored parameter's question for the limma gene-set test the line is anchored to. 21 "not reported" + empty-snippet lines confirmed truly absent from the full Methods text of the anchored test. 2 more "not reported" lines (PMC13313547 `p_adjust_method`, `enrich_cutoff`) carry a non-empty snippet + note; read in full paragraph context, both are correctly kept "not reported" for the gene-set test itself (tied to the DE step / to unrelated tests in the same Statistics paragraph, not to ROAST/CAMERA's own output) -- no DE-cutoff-as-gene-set-cutoff violation found.
- `_applies` re-checked for all 6: all 6 correctly `yes`; no microscope-camera, metabolomics-CAMERA-package, or gene-symbol-FRY false positives in the sample (PMC12286861 does contain an unrelated "Mrc 5 camera" microscope mention, correctly not the anchor used). One borderline case accepted and flagged in `verification.json` notes: PMC13383671 runs "CAMERA-PR" via the TMSig Bioconductor package's `cameraPR.matrix` rather than calling `limma::cameraPR` directly; TMSig's own Bioconductor page lists `limma` under `Depends` and its vignette describes `cameraPR.matrix` as the same test "via a flexible matrix method (see limma for the original implementation)" -- treated as a genuine limma-cameraPR run, not an unrelated tool.
- records_checked = 48, records_passed = 48, pass_rate = 1.0000, echo_checked = 6, echo_passed = 6, failures = [], **verdict = pass**.
- `verification.json` written to `acceptance/exemplars/limma-camera/literature/verification.json`.

**Resume point:** independent verification complete, verdict pass. Next: main session (V-section counts, D-section three-way table, draft S1 decisions, PACK.md).
