## 2026-09-27 07:35 UTC retriever (haiku)

**Search**: sva-batch
- hit_count: 941
- candidates_fetched: 350
- gates: screened=30, licence_not_countable=13, pubtype_excluded=2, excluded_by_regex=11
- corpus: 30
- l3: 10

**L1 from Bioconductor 3.23**:
- sva 3.60.0 @ RELEASE_3_23 (commit: 87a4798db8)
- limma 3.68.5 @ RELEASE_3_23 (commit: 825d1c8330)

Next: extraction

## 2026-09-27T08:20:00Z extractor (sonnet)
- Read all 30/30 corpus articles with `collect.py methods sva-batch <PMCID>`. Judged _applies against
  the module definition (ComBat/ComBat-seq/sva/svaseq applied to BULK EXPRESSION data): 21 yes, 9 no.
  Excluded as _applies=no: a false-positive regex hit ("to combat bias", ordinary English, PMC13544906);
  CRISPR sgRNA/gene-essentiality score matrices (PMC10745716, PMC8686573); quantitative
  imaging/flow-cytometry features (PMC7784531); DNA-methylation beta/M-value array data (PMC12690895,
  PMC7710270); mass-spec proteomic intensities (PMC10849759); protein IHC biomarker TMA scores used only
  as one of several batch-mitigation methods being compared, not gene expression (PMC8849344); and a
  paper whose actual transcriptome was explicitly NOT batch corrected, only its metabolomics/lipidomics
  companion data was (PMC11584401). Each `no` line carries a `note` explaining the platform/data-type
  mismatch so a re-reader does not need to re-derive it.
- For every `yes` article, filled `corrected_used_for` -- the module's key misuse-question parameter --
  reading past the correction sentence to find what the corrected matrix (or the SVs) actually fed into:
  differential-expression testing (DESeq2/limma directly, the common and ComBat-seq-endorsed pattern),
  visualization/clustering only (PCA/UMAP), Z-score-based outlier testing, eQTL/TWAS model training, or
  "not reported" when the paper never restates the downstream consumer. One article (PMC13524377)
  explicitly separates the two uses in one sentence (batch as a design covariate for testing, sva/ComBat
  correction only for visualization) -- a clean positive control for this field. One paper (PMC12667713)
  is a batch-correction benchmarking/methods paper (ALPINE) that evaluates ComBat as one of several
  baseline tools on simulated data rather than drawing its own biological conclusion from it; flagged
  with a note rather than excluded, since it still literally applies ComBat to (simulated) bulk/pseudobulk
  expression data before a DE test.
- Wrote acceptance/exemplars/sva-batch/literature/extraction.jsonl: 135 lines (1 `_applies` line per
  article; 21 `yes` articles get one line per profile parameter [method, corrected_used_for, n_sv, mod,
  sva_version]; `no` articles get only the `_applies` line). Every non-empty snippet verified FOUND with
  `collect.py check` (initial pass found 4 issues -- 1 non-contiguous snippet across an inline citation,
  3 over the 25-word limit -- all corrected and re-verified; final pass: 0 failures).
- Wrote l3_notes.md for the 10 L3+L4 exemplars (PMC7737297, PMC8849344, PMC7775110, PMC8686573,
  PMC7705019, PMC8744672, PMC7784531, PMC13510735, PMC10703692, PMC12667713), including the `no`
  articles (explaining what data type ComBat/sva was actually applied to instead).
- Verified `find vendor -name __pycache__` prints nothing before committing.
- Next: run `collect.py summarize sva-batch` and commit acceptance/exemplars/sva-batch/literature/.

## 2026-09-27T09:05:00Z independent verifier (sonnet)
- Ran `collect.py sample sva-batch --frac 0.2 --seed omicstat-s0` -> 6 PMIDs: 33317623, 34939926,
  38055614, 38134284, 42490144, 42647619 (PMCIDs PMC7737297, PMC8849344, PMC10699809, PMC10745716,
  PMC13564084, PMC13510735).
- Echo: fresh PubMed esummary/efetch call (pubmed_fetch.PubMedFetcher, tool=omicstat,
  email=$OMICSTAT_CONTACT_EMAIL fallback placeholder) per sampled PMID -- 6/6 title (html-unescaped,
  normalised) and year matched corpus.jsonl.
- extraction.jsonl: 26 lines for the 6 sampled articles (4 `_applies=yes` + 2 `_applies=no`; `yes`
  articles get one line per profile parameter [method, corrected_used_for, n_sv, mod, sva_version]).
  All 16 non-empty snippets verified FOUND via `collect.py check` (0 failures). Read the full Methods
  (`collect.py methods sva-batch <PMCID>`) for all 6 articles and confirmed every "not reported" line
  (8 lines) is a true absence (no n.sv/mod stated for PMC7737297, PMC10699809, PMC13510735; no mod
  stated for PMC13564084). Confirmed both `_applies=no` calls against the module definition: PMC10745716
  applies ComBat-seq to CRISPR-Cas9 sgRNA read counts from a gene-essentiality screen, not bulk
  expression; PMC8849344 applies ComBat to protein IHC biomarker scores from tissue microarrays as one
  of eight batch-mitigation methods being compared (the paper itself notes ComBat "were initially
  designed for microarray studies of gene expression"), not to a gene-expression matrix.
- records_checked 26, records_passed 26, pass_rate 1.0000, echo_checked 6, echo_passed 6, failures: none.
- Verdict: pass.
- `find vendor -name __pycache__` printed nothing before commit.
- Resume point: none -- sva-batch literature verification complete.
