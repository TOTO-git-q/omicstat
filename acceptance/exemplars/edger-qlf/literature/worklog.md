## 2026-09-27 07:30 UTC retriever (haiku)

**Search**: edger-qlf
- Status: FAILED - EBI 500 error on PMC10908398 full text XML (retried after 30s, same error)
- Recording error: `requests.exceptions.HTTPError: 500 Server Error: for url: https://www.ebi.ac.uk/europepmc/webservices/rest/PMC10908398/fullTextXML`

**L1 from Bioconductor 3.23**:
- edgeR 4.10.5 @ RELEASE_3_23 (commit: c4a54bdaec)

Next: extraction (pending successful literature search)

## 2026-09-27T07:37:44Z main session
- search rerun after collect.py was made robust to per-article Europe PMC 500 errors (previous run aborted). corpus 30 l3 10 gates {'screened': 30, 'excluded_by_regex': 11, 'fulltext_http_error': 3, 'licence_not_countable': 7}
- next: extraction

## 2026-09-27T08:10:00Z extractor (sonnet)
- edger-qlf: extracted 10/30 articles (PMC13569496, PMC12726832, PMC8604959, PMC7755388, PMC13577898, PMC9825163, PMC8709578, PMC7713251, PMC13518833, PMC12652261). All snippets verified with `collect.py check`.
- applies=no for PMC9825163 (edgeR QL on an in vitro translation oligo pool, not bulk RNA-seq), PMC7713251 (RNA-seq DE test is limma/eBayes, edgeR QL used only for ATAC/ChIP peaks), PMC13518833 (bulk RNA-seq DE test is DESeq2; edgeR QL used only for scRNA-seq pseudobulk/cell-type-proportion/ChIP-ATAC), PMC12652261 (no RNA-seq section; edgeR QL used only for ChIP/ICE-seq/ChBPseq).
- Next: PMC9710884 (pmid 36449607), continuing through the remaining corpus in file order.

## 2026-09-27T08:35:00Z extractor (sonnet)
- edger-qlf: extracted 16/30 (added PMC9710884, PMC13502174, PMC12644894, PMC11608373, PMC9681209, PMC8565318). All snippets verified with `collect.py check`.
- Next: PMC12828906 (pmid 41275493), continuing through the remaining corpus in file order.

## 2026-09-27T09:00:00Z extractor (sonnet)
- edger-qlf: extracted 22/30 (added PMC12828906, PMC9756944, PMC8565305, PMC7665889, PMC12623481, PMC10620403). All snippets verified with `collect.py check`.
- applies=no for PMC9756944 (ChIP-seq only, no RNA-seq section).
- Next: PMC9723631 (pmid 36399508), continuing through the remaining corpus in file order.

## 2026-09-27T09:45:00Z extractor (sonnet)
- edger-qlf: extraction complete, 30/30 articles, 270 lines (9 per article) in extraction.jsonl. All snippets verified with `collect.py check`.
- applies=no (8/30): PMC9825163 (oligo-pool translation assay), PMC7713251 (RNA-seq DE test is limma/eBayes, not edgeR), PMC13518833 (bulk RNA-seq DE test is DESeq2), PMC12652261 (no RNA-seq, ChIP/ICE-seq only), PMC9756944 (ChIP-seq only), PMC13558064 (edgeR QL used on snRNA-seq pseudobulk, genuine bulk RNA-seq in the same paper uses limma-voom), PMC12594174 (edgeR QL used on a proximity-labeling/BioID DNA-seq assay, not RNA-seq).
- Next: l3_notes.md for the 10 L3+L4 articles, then summarize + commit.

## 2026-09-27T14:15:00Z verifier (sonnet)
- edger-qlf: independent verification, 20% sample (6/30 articles: PMC8604959, PMC9825163, PMC9756944, PMC12594174, PMC13440409, PMC13558064; pmids 34799566, 36229039, 36420903, 41202128, 42555706, 42557328), 54/54 extraction.jsonl lines checked (9 params x 6 articles).
- Fresh PubMed esummary echo: 6/6 title+year match.
- All 20 non-empty snippets: FOUND via `collect.py check`, all <=25 words, pmid/pmcid pairs match corpus.jsonl.
- `_applies` calls confirmed against the module definition: yes for PMC8604959 (bulk RNA-seq, glmQLFit inferred by explicit 'similar to RNA-seq differential analysis' framing of the ATAC-seq glmQLFit paragraph) and PMC13440409; no for PMC9825163 (synthetic oligo-pool translation counts), PMC9756944 (ChIP-seq peaks/csaw), PMC12594174 (proximity-labeling/BioID DNA-seq windows), PMC13558064 (snRNA-seq pseudobulk; genuine bulk RNA-seq in the same paper correctly routed to limma-voom instead).
- 34/54 "not reported" lines checked against full Methods text via `collect.py methods`: 30 confirmed genuinely absent, 4 are real misses (see failures) -- PMC9756944 and PMC12594174 each have edgeR-QL-relevant values (padj cutoff / fold-change filter / normalization) stated in the very same matched Methods paragraph that were marked "not reported" instead of extracted, inconsistent with how comparable off-target (applies=no) articles elsewhere in the same extraction (PMC9825163, PMC13558064) correctly extracted stated-but-off-target values.
- pass_rate 50/54 = 0.926 (< 0.95) -> verdict REWORK. Extractor should re-check padj_cutoff/lfc_filter/normalization for all applies=no articles in the full 30-article corpus for the same omission pattern before re-submitting.
- Wrote acceptance/exemplars/edger-qlf/literature/verification.json.

## 2026-09-27T15:20:00Z extractor (rework after verification 0.926)
- edger-qlf: re-swept all 30/30 corpus articles (re-ran `collect.py methods edger-qlf <PMCID>` for every
  article, read the full Methods text, re-checked every profile parameter and the `_applies` line).
  extraction.jsonl kept its schema and line count (270 lines, 9 per article x 30 articles).
- Fixed the verifier's 4 failures (PMC9756944/pmid 36420903, PMC12594174/pmid 41202128), both stated in
  the same Methods paragraph as the edgeR QL signal:
  - PMC9756944 padj_cutoff: "not reported" -> "FDR < 0.05" (snippet "Only regions with FDR values below
    the 0.05 threshold were considered differentially bound between two samples").
  - PMC9756944 lfc_filter: "not reported" -> "2" (snippet "Only peaks with a log2-fold change >2 were
    retained for further analyses").
  - PMC12594174 normalization: "not reported" -> "trimmed mean of M-values (TMM)" (snippet "Sample
    normalization was performed with normFactors function using the trimmed mean of M-values (TMM)
    method and windows of 10 kb").
  - PMC12594174 padj_cutoff: "not reported" -> "FDR < 0.05" (snippet "Statistical significance was
    determined on the basis of false discovery rates (FDR; <0.05)").
- Found and fixed 3 more instances of the same omission pattern (stated-but-off-target or
  stated-elsewhere-in-Methods values marked "not reported") while sweeping the rest of the corpus:
  - PMC7713251/pmid 33273453 (applies=no, RNA-seq is limma not edgeR): all 8 non-`_applies` parameter
    lines were anchored to the limma RNA-seq paragraph instead of the paper's actual edgeR-QL usage
    (Methods > Classification of enhancers according to increase of accessibility, glmQLFit+glmLRT on
    ATAC-seq peaks); re-anchored section_path to that paragraph and extracted edger_version "3.20.9"
    (was "not reported"), stated in the same sentence as the glmQLFit/glmLRT call.
  - PMC13518833/pmid 42649219 (applies=no, bulk RNA-seq is DESeq2 not edgeR): all 8 non-`_applies`
    lines were anchored to the DESeq2 paragraph; re-anchored to the paper's edgeR-QL pseudobulk
    scRNA-seq differential-expression paragraph and extracted padj_cutoff "FDR < 0.05", p_adjust_method
    "Benjamini-Hochberg", lfc_filter "logFC > 0.2" (all from the same signature-derivation sentence),
    and edger_version "4.4.0" (stated in the paper's separate cell-type-proportion edgeR-QL analysis,
    noted as such).
  - PMC12828906/pmid 41275493 (applies=yes, Methods delegates parameters to prior papers "as previously
    described"): the paper's STAR Methods figure-legend statistics section repeatedly states "edgeR
    glmQLFTest, FC >= 2, p = <0.05" for the DE calls; extracted padj_cutoff "p < 0.05" (with a note that
    it is not explicitly labeled adjusted/FDR, unlike the GSEA step's separately-labeled BH-adjusted
    p-value) and lfc_filter "FC >= 2", both previously "not reported".
- All 11 changed snippets re-verified with `collect.py check` (all FOUND, all <=25 words). Confirmed the
  applies=no/yes split: 7 no / 23 yes (unchanged from before the rework -- no `_applies` verdicts were
  wrong, only parameter values and their section_path anchoring for the off-target usages).
- The other 25 articles (including the 6 the verifier sampled, minus the 2 that had a failure) were
  re-checked line by line against the full Methods text and left unchanged: all their "not reported"
  lines were confirmed genuinely absent from the Methods.
- l3_notes.md: checked for consistency. Only one corrected article (PMC7713251/pmid 33273453) is an
  L3 exemplar; its existing note ("edgeR's own glmQLFit()/glmLRT() functions do appear elsewhere in the
  same Methods... for the ATAC-seq and ChIP-seq peak analyses") remains accurate and needed no edit.
- Counts of lines changed by type: padj_cutoff 3, lfc_filter 3, normalization 1, p_adjust_method 1,
  edger_version 2 (value changes); section_path re-anchored for 16 lines (8 params x 2 articles,
  PMC7713251 and PMC13518833) with no value change beyond what's listed above.
- `collect.py summarize edger-qlf` re-run clean (23/30 apply, 7 excluded); vendor/ has no __pycache__.
- Next: none -- edger-qlf extraction rework is complete and ready for re-verification.

## 2026-09-27T16:05:00Z independent verifier, round 2 (sonnet)
- edger-qlf: round 2 independent verification, new seed `omicstat-s0-r2` (not the retriever/extractor for
  this module). Renamed round-1 `verification.json` (0.926, rework) to `verification_round1.json` via
  `git mv`; it is kept, not edited.
- `collect.py sample edger-qlf --frac 0.2 --seed omicstat-s0-r2` -> 6/30 articles: pmid 33350385
  (PMC7755388), 34320181 (PMC8565305), 34686194 (PMC8532352), 42555706 (PMC13440409), 42635042
  (PMC13502174), 42728798 (PMC13569496).
- Fresh PubMed esummary echo (tool=omicstat, email=omicstat-s0@example.invalid; `$OMICSTAT_CONTACT_EMAIL`
  unset) for all 6 sampled PMIDs: normalized, HTML-unescaped title and year both match corpus.jsonl,
  6/6.
- 54 extraction.jsonl lines checked (9 params x 6 articles). 29 non-empty snippets all FOUND via
  `collect.py check` (<=25 words each). All 25 "not reported" lines confirmed genuinely absent by
  reading the full Methods text (`collect.py methods edger-qlf <PMCID>`) for each of the 6 PMCIDs.
  `_applies` correct for all 6 (all yes): PMC7755388, PMC8565305 (RNA-seq validation of DMRcate DMRs --
  genuine glmQLFit/glmQLFTest on matched RNA-seq), PMC8532352/MINTIE (glmQLFit used for dispersion but
  the test is glmLRT, not glmQLFTest/glmTreat -- accepted as a documented borderline yes, consistent with
  round-1 precedent, since glmQLFit runs on RNA-seq-derived counts and the note records the caveat),
  PMC13440409, PMC13502174 (mouse-liver edgeR QL correctly distinguished from the same paper's
  human-platelet DESeq2 analysis), PMC13569496.
- Records checked 54/54 passed -> pass_rate 1.0000. No failures.
- Round-1 failures re-check (does not count toward the pass rate): all 4 confirmed fixed and correct
  against the full Methods text -- PMC9756944/pmid 36420903 padj_cutoff "FDR < 0.05" and lfc_filter "2";
  PMC12594174/pmid 41202128 normalization "trimmed mean of M-values (TMM)" and padj_cutoff "FDR < 0.05".
- verdict: pass (pass_rate >= 0.95 and 6/6 echoes pass). Wrote
  `acceptance/exemplars/edger-qlf/literature/verification.json` (round 2).
- `find vendor -name __pycache__` empty (vendor/ untouched, read-only).
- Next: none for verification -- edger-qlf is ready for the main session's V-section counts / PACK.
