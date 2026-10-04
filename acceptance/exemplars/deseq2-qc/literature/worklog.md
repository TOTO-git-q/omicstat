## 2026-09-27 07:15 UTC retriever (haiku)

**Search**: deseq2-qc
- Status: FAILED - EBI 500 error on PMC9831293 full text XML (retried after 30s, same error)
- Recording error: `requests.exceptions.HTTPError: 500 Server Error: for url: https://www.ebi.ac.uk/europepmc/webservices/rest/PMC9831293/fullTextXML`

**L1 from Bioconductor 3.23**:
- DESeq2 1.52.0 @ RELEASE_3_23 (commit: 16aeab6d61)
- Functions without Rd page: estimateSizeFactors

Next: extraction (pending successful literature search)

## 2026-09-27T07:37:44Z main session
- search rerun after collect.py was made robust to per-article Europe PMC 500 errors (previous run aborted). corpus 30 l3 10 gates {'screened': 30, 'licence_not_countable': 7, 'excluded_by_regex': 9, 'fulltext_http_error': 2, 'no_methods_signal': 1}
- next: extraction

## 2026-09-27 07:45 UTC extractor (sonnet)
- Articles 1-5 done: PMC13584385 (42754892, no), PMC9829540 (36536241, no), PMC8783694 (34731091, no),
  PMC13577902 (42736449, no), PMC11687419 (39708805, yes).
- All five `_applies=no` cases are regex false positives worth flagging: the signal regex matched
  vst/rlog used for something OTHER than sample-level QC (Seurat FindVariableFeatures 'vst', vst as a
  generic pre-fold-change normalizer, vst feeding gene-level clustering/correlation instead of sample
  PCA/heatmap).
- Next: PMC10745701 (38134280)

## 2026-09-27 07:50 UTC extractor (sonnet)
- Articles 6-10 done: PMC10745701 (38134280, yes - heatmap+Pearson distance), PMC8714852 (35028607, no -
  rlog/VST feeds correlation ranking + deconvolution, not QC), PMC7819745 (33180747, no - rlog feeds
  WGCNA), PMC13563095 (42725433, yes - hierarchical clustering for reproducibility), PMC9754766
  (36515659, no - 'vst' hit is Seurat's FindVariableFeatures, unrelated to DESeq2).
- Next: PMC7781603 (33337321), then the remaining 20 L4-only articles.

## 2026-09-27 08:05 UTC extractor (sonnet)
- Articles 11-20 done: PMC7781603 (33337321, no - vst feeds a UMAP over genomic loci, not sample PCA),
  PMC12893922 (41407857, yes - Euclidean distance + PCA + heatmap on VST), PMC11662933 (39575480, yes -
  plotPCA on rlog), PMC8664294 (34755601, yes - PCA on VST), PMC7688323 (33239294, yes - VST for
  clustering+PCA, batch-corrected with limma), PMC13493127 (42623273, yes - rlog for heatmap clustering),
  PMC12700201 (41385642, yes - prcomp on vst + Spearman sample correlation), PMC10711438 (37953377, yes -
  blind vst + Pearson-distance hierarchical clustering + PCA), PMC9710879 (36449618, yes - plotPCA ntop
  2000 + Euclidean sample distance + Pheatmap), PMC8663557 (34554929, no - VST feeds WGCNA/QuSAGE/
  deconvolution only).
- Next: PMC7673811 (33208372), then the final 10 articles.

## 2026-09-27 08:20 UTC extractor (sonnet)
- Articles 21-30 done (module complete): PMC7673811 (33208372, yes), PMC13485302 (42611752, yes -
  explicit 'VST calculated for quality control and visualization only (PCA, sample-distance heatmaps)'),
  PMC12807868 (41381884, yes - VST + UMAP, not PCA), PMC10703692 (38036788, yes - VST then WGCNA-
  connectivity outlier removal), PMC9705439 (36443313, no - ambiguous, see note), PMC8791277 (34741808,
  yes - VST heatmap of top-50 genes), PMC13589506 (42594877, yes - vst + pheatmap), PMC12796325
  (41353448, yes - VST + PCA on metatranscriptome ORFs, an unusual bulk-community-RNA-seq domain),
  PMC8566602 (34732713, yes - VST + Euclidean dendrograms), PMC7673985 (33203890, yes - VST heatmap,
  Pearson/Euclidean row/column distances).
- extraction.jsonl: 170 lines (30 articles; _applies yes=18, no=12; 7 parameter lines per yes-applying
  article + the _applies line; no-applying articles get only the _applies line).
- Next: l3_notes.md for the 10 L3+L4 articles (42754892, 33337321, 41407857, 34755601, 33239294,
  41385642, 37953377, 41381884, 38036788, 33203890), then collect.py summarize + commit.

## 2026-09-27T08:19:14Z verifier (sonnet)
- Independent verification: `collect.py sample deseq2-qc --frac 0.2` -> 33203890, 34741808, 36515659,
  39708805, 42594877, 42754892 (6/30, 20%).
- Fresh PubMed esummary echo for all 6 PMIDs: title + year match corpus.jsonl for every one (6/6 pass).
- Every extraction.jsonl line for these 6 articles re-checked: 34 lines total (4 `_applies=yes`
  articles x 8 lines [7 params + `_applies`], 2 `_applies=no` articles x 1 line). All non-empty
  snippets verified FOUND via `collect.py check` and <= 25 words. All `not reported` fields confirmed
  absent by reading full Methods (`collect.py methods deseq2-qc <PMCID>`). Both `_applies=no` calls
  (42754892: vst used to normalize a per-patient DEG fold-change, not sample QC; 36515659: 'vst' hit is
  Seurat FindVariableFeatures, unrelated to the pseudobulk DESeq2 step) confirmed correct against the
  module definition, independent of the since-tightened signal_regex.
- One failure found: PMC7673985 (33203890) `outlier_rule` = "Samples retained in the dataset had at
  least 400,000 estimated counts..." -- literally present in the text but is a general sequencing-depth
  sample-inclusion criterion from the kallisto/tximport stage, not a QC/outlier rule tied to the
  vst-based heatmap/distance analysis; should have been "not reported".
- records_checked=34, records_passed=33, pass_rate=0.9706, echo 6/6 -> verdict PASS (>=0.95, all
  echoes pass). Wrote literature/verification.json.
- Next: none (module verification complete).
