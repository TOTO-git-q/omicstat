## 2026-09-27 07:34 UTC retriever (haiku)

**Search**: limma-dupcor
- Status: FAILED - EBI 500 error on PMC8437376 full text XML
- Recording error: `requests.exceptions.HTTPError: 500 Server Error: for url: https://www.ebi.ac.uk/europepmc/webservices/rest/PMC8437376/fullTextXML`

**L1 from Bioconductor 3.23**:
- limma 3.68.5 @ RELEASE_3_23 (commit: 825d1c8330)

Next: extraction (pending successful literature search)

## 2026-09-27T07:37:44Z main session
- search rerun after collect.py was made robust to per-article Europe PMC 500 errors (previous run aborted). corpus 30 l3 10 gates {'screened': 30, 'licence_not_countable': 7, 'excluded_by_regex': 11, 'no_methods_signal': 1, 'pubtype_excluded': 3, 'fulltext_http_error': 3}
- next: extraction

## 2026-09-27T08:08:37Z extractor (sonnet)
- Read all 30/30 corpus articles with `collect.py methods limma-dupcor <PMCID>`. All 30 genuinely use
  limma's duplicateCorrelation with lmFit(block=...) for repeated measures (arrays, RNA-seq/voom,
  ATAC-seq, DNA methylation and proteomics all appear as the underlying data type across the corpus,
  since the search targeted the duplicateCorrelation signal directly) -> _applies=yes for 30/30.
- Wrote acceptance/exemplars/limma-dupcor/literature/extraction.jsonl: 240 lines (8 lines per article:
  `_applies` + block, two_rounds, consensus_correlation, padj_cutoff, p_adjust_method, lfc_filter,
  limma_version). Where a paper reports two side-by-side dupCor analyses (e.g. RNA-seq + proteomics in
  PMC9237031) the primary/first-described analysis was used for each field, with a `note` pointing to
  the other section when a value (e.g. a numeric consensus correlation) was only given there. Flagged
  cases where a stated p-value is explicitly "unadjusted"/"nominal" rather than FDR-corrected
  (PMC7936006, PMC13313537) so they are not miscounted as padj_cutoff values.
  Only PMC8971130 explicitly runs the two-pass voomWithQualityWeights/duplicateCorrelation loop from the
  limma-voom guide (two_rounds coded "yes"); every other article leaves two_rounds and
  consensus_correlation's numeric value unreported.
  Every non-empty snippet verified FOUND with `collect.py check` (0 failures).
- Wrote l3_notes.md for the 10 L3+L4 exemplars (PMC9668748, PMC10686561, PMC9237031, PMC7695459,
  PMC9151768, PMC8971130, PMC7936006, PMC7063821, PMC10349101, PMC10259477).
- Verified `find vendor -name __pycache__` prints nothing before committing.
- Next: run `collect.py summarize limma-dupcor` and commit acceptance/exemplars/limma-dupcor/literature/.

## 2026-09-27T09:05:00Z independent verifier (sonnet)
- Ran `collect.py sample limma-dupcor --frac 0.2 --seed omicstat-s0` -> 6 PMIDs: 34533985, 37452040,
  39228367, 40632859, 40662355, 42048163 (PMCIDs PMC8448451, PMC10349101, PMC11514464, PMC12239959,
  PMC12259264, PMC13313537).
- Echo: fresh PubMed esummary/efetch call (pubmed_fetch.PubMedFetcher, tool=omicstat,
  email=$OMICSTAT_CONTACT_EMAIL fallback placeholder) per sampled PMID -- 6/6 title (html-unescaped,
  normalised) and year matched corpus.jsonl.
- extraction.jsonl: 48 lines for the 6 sampled articles (all `_applies=yes`, 8 lines each: `_applies` +
  block, two_rounds, consensus_correlation, padj_cutoff, p_adjust_method, lfc_filter, limma_version).
  All 22 non-empty snippets verified FOUND via `collect.py check` (0 failures). Read the full Methods
  (`collect.py methods limma-dupcor <PMCID>`) for all 6 articles and confirmed every "not reported" line
  (26 lines) is a true absence: no article in the sample ran the two-pass voom+duplicateCorrelation loop
  or stated a numeric consensus/intra-block correlation; the unadjusted-vs-adjusted p-value distinction
  flagged for PMC11514464 (nominal P<0.05, no BH stated) and PMC13313537 (BH applied to results but DE
  genes called at "nominal p value <0.05" -- an inconsistency the extractor correctly left as
  padj_cutoff=not reported rather than miscounting the nominal threshold as an adjusted cutoff) both
  held up on close reading.
- records_checked 48, records_passed 48, pass_rate 1.0000, echo_checked 6, echo_passed 6, failures: none.
- Verdict: pass.
- `find vendor -name __pycache__` printed nothing before commit.
- Resume point: none -- limma-dupcor literature verification complete.
