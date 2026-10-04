## 2026-09-27 07:33 UTC retriever (haiku)

**Search**: limma-array
- Status: FAILED - EBI 500 error on PMC8639773 full text XML
- Recording error: `requests.exceptions.HTTPError: 500 Server Error: for url: https://www.ebi.ac.uk/europepmc/webservices/rest/PMC8639773/fullTextXML`

**L1 from Bioconductor 3.23**:
- limma 3.68.5 @ RELEASE_3_23 (commit: 825d1c8330)

Next: extraction (pending successful literature search)

## 2026-09-27T07:37:44Z main session
- search rerun after collect.py was made robust to per-article Europe PMC 500 errors (previous run aborted). corpus 30 l3 10 gates {'screened': 30, 'licence_not_countable': 7, 'no_methods_signal': 1, 'excluded_by_regex': 13, 'pubtype_excluded': 1, 'fulltext_http_error': 2}
- next: extraction

## 2026-09-27T08:08:37Z extractor (sonnet)
- Read all 30/30 corpus articles with `collect.py methods limma-array <PMCID>`. Judged _applies per
  article against the module definition (limma lmFit/eBayes/topTable on normalised MICROARRAY
  intensities, not RNA-seq/proteomics): 13 yes, 17 no. Many candidate "microarray" regex hits were
  RNA-seq (voom/edgeR/kallisto counts), mass-spec proteomics (LFQ/TMT/iBAQ), or a "tissue microarray"
  (IHC), not gene-expression arrays -- these were coded _applies=no with a note explaining the platform
  mismatch, per module instructions.
- Wrote acceptance/exemplars/limma-array/literature/extraction.jsonl: 121 lines (1 `_applies` line per
  article; for the 13 `yes` articles, one line per profile parameter [normalization, probe_filter,
  ebayes, padj_cutoff, p_adjust_method, lfc_filter, limma_version]; `no` articles get only the
  `_applies` line, per the summarize-denominator rule). Every non-empty snippet verified FOUND with
  `collect.py check` (0 failures on final pass; 4 snippets were corrected for citation-marker/footnote
  breaks in the source text and re-verified before finalizing).
- Wrote l3_notes.md for the 10 L3+L4 exemplars (PMC12764432, PMC7775110, PMC10709144, PMC8664842,
  PMC13488902, PMC9825120, PMC8656144, PMC13558077, PMC13506345, PMC7648065), including the `no`
  articles (explaining what platform/tool was actually used instead of limma-on-array).
- Verified `find vendor -name __pycache__` prints nothing before committing.
- Next: run `collect.py summarize limma-array` and commit acceptance/exemplars/limma-array/literature/.

## 2026-09-27T09:05:00Z independent verifier (sonnet)
- Ran `collect.py sample limma-array --frac 0.2 --seed omicstat-s0` -> 6 PMIDs: 33305733, 34758847,
  37709492, 41388153, 42587147, 42616886 (PMCIDs PMC7775110, PMC8582123, PMC10715533, PMC12764429,
  PMC13558077, PMC13488902).
- Echo: fresh PubMed esummary/efetch call (pubmed_fetch.PubMedFetcher, tool=omicstat,
  email=$OMICSTAT_CONTACT_EMAIL fallback placeholder) per sampled PMID -- 6/6 title (html-unescaped,
  normalised) and year matched corpus.jsonl.
- extraction.jsonl: 41 lines for the 6 sampled articles (5 `_applies=yes` + 1 `_applies=no`, all 7
  parameters per `yes` article). All 22 non-empty snippets verified FOUND via `collect.py check`
  (0 failures). Read the full Methods (`collect.py methods limma-array <PMCID>`) for all 6 articles and
  confirmed every "not reported" line (19 lines) is a true absence, not a value stated elsewhere and
  mislabeled -- including the correct exclusion of an unrelated log2FC/pathway-enrichment threshold
  (PMC13488902), an unrelated DNA-methylation BH/log2FC threshold (PMC10715533, mRNA vs methylation
  sections), and a custom Z-score/MAD "HIT" definition standing in for eBayes/padj (PMC8582123).
  Confirmed `_applies=no` for PMC12764429 (SomaScan aptamer plasma-proteomics data, not microarray gene
  expression) is correct against the module definition.
- records_checked 41, records_passed 41, pass_rate 1.0000, echo_checked 6, echo_passed 6, failures: none.
- Verdict: pass.
- `find vendor -name __pycache__` printed nothing before commit.
- Resume point: none -- limma-array literature verification complete.
