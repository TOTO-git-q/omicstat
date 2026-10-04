# method-basis -- deseq2-qc

Format: claim -> source. "Vignette" = the DESeq2 vignette shipped with the installed package,
exported with its sha256 to `acceptance/exemplars/deseq2-qc/L1_bioc3.23/`. Literature citations
are the ones the package itself declares (`citation()`); no reference here is written from memory.

Versions: DESeq2 1.52.0, Bioconductor 3.23 (this exemplar's own L1 was collected directly against
the locked release; `check_default_drift` re-checks every function default in `calls_registry.json`
against the running container regardless).

## Method

| Claim | Source |
|---|---|
| Negative binomial GLM framework; size factors, dispersion trend and transformations are shared infrastructure of DESeq2 | Love MI, Huber W, Anders S (2014). Genome Biology 15:550. doi:10.1186/s13059-014-0550-8 (DESeq2 `citation()`); vignette "Data transformations and visualization" |
| DESeq2 needs un-normalized integer counts | vignette "Why un-normalized counts?" |
| Pre-filter: count >= 10 in at least the smallest group size (simple two-group design) | vignette "Pre-filtering" (`smallestGroupSize <- 3; keep <- rowSums(counts(dds) >= 10) >= smallestGroupSize`) |
| `vst`/`rlog`/`varianceStabilizingTransformation` all default `blind = TRUE`; `blind = TRUE` re-estimates dispersions using only an intercept, "in order to compare samples in a manner wholly unbiased ... for example to perform sample QA (quality assurance)" | vignette "Blind dispersion estimation"; `Rd/vst.Rd`, `Rd/rlog.Rd`, `Rd/varianceStabilizingTransformation.Rd` |
| `blind = FALSE` is for downstream/display use once the design is trusted, and reuses an already-estimated dispersion trend when present | vignette "Blind dispersion estimation"; same Rd files |
| `vst()` subsamples `nsub = 1000` genes with mean normalized count > 5 to fit the trend and is a faster wrapper of `varianceStabilizingTransformation()`; below `nsub` eligible rows it cannot subsample | `Rd/vst.Rd`; NEWS 1.9.42 ("VST recommended for very large matrices (100s of samples)"); PACK section X |
| Sample clustering / PCA use the transformed matrix, never raw or shifted-log counts, "to remove the dependence of the variance on the mean" | vignette "Data transformations and visualization" introduction |
| `plotPCA`: top `ntop` (default 500) most-variable rows by variance, `prcomp`, PCs 1:2 by default, coloured/shaped by `intgroup` | `Rd/plotPCA.Rd`; vignette "Principal component plot of the samples" (`plotPCA(vsd, intgroup=c("condition", "type"))`) |
| Sample-to-sample distances: `dist(t(assay(vsd)))` (Euclidean), visualized as a clustered heatmap | vignette "Heatmap of the sample-to-sample distances" |
| DESeq2's Cook's-distance outlier handling is per GENE, not per sample; no numeric per-sample outlier statistic or threshold is given anywhere in the vignette or Rd | vignette "Approach to count outliers"; `Rd/plotPCA.Rd` (no threshold argument); PACK S1 appendix P-2 (class C, pending) |
| Displaying PCA on a batch-corrected (`limma::removeBatchEffect`) matrix is a distinct, separately-labelled step, not part of the QA transform itself | vignette FAQ "Why after VST are there still batches in the PCA plot?"; PACK S1 appendix P-3 (belongs to sva-batch, off by default here) |

## Open-source implementations consulted (design, not evidence)

| What | Where | Used for |
|---|---|---|
| Bioconductor workflow rnaseqGene (source) | github.com/mikelove/rnaseqGene | ordering of pre-filter -> transform -> PCA / sample-distance in a full workflow, consistent with the vignette |

## Anchor (PACK section C)

The pasilla example of the vignette (same construction as `skills/deseq2-wald/tests/fixtures/make_pasilla.R`:
design `~ condition`, pre-filter count >= 10 in >= 3 samples -> 8,148 features, 7 samples). Anchors
(`tests/run_smoke_test.R`):

- **Printed anchor (blind = FALSE, `--blind-false-supplement`)**: the vignette prints
  `head(assay(vsd), 3)` for `vsd <- vst(dds, blind=FALSE)` on this exact dataset:
  FBgn0000008 = 7.777746, 7.984491, 7.765448, 7.735026, 7.807720, 7.997378, 7.832458;
  FBgn0000017 = 11.954934, 12.035700, 12.028610, 12.049838, 12.295662, 12.471723, 12.089675;
  FBgn0000018 = 9.219162, 9.089390, 9.028791, 9.374577, 9.173538, 9.052143, 9.142848
  (columns: treated1, treated2, treated3, untreated1, untreated2, untreated3, untreated4).
  The engine's supplement matrix is asserted against these to the printed precision.
- **Replay anchors (vignette code run in the test session, independent of the engine)**: the
  test runs the vignette's own chunks (`DESeq2.Rmd` loadPasilla, reorderPasila, matrixInput,
  prefilter, factorlvl, deseq, rlogAndVST, sampleClust, figPCA2; line numbers in the test) on
  the vignette's own input files (DESeq2 `extdata`) and never calls the engine or a `_shared`
  helper. Primary path (blind = TRUE; the vignette prints no blind = TRUE values, so the only
  change to its code is `blind=TRUE`, which its "Blind dispersion estimation" text prescribes for
  sample QA): the whole 8,148 x 7 transformed matrix, PC1 and PC2 of all 7 samples from
  `plotPCA(vsd, intgroup=c("condition","type"), returnData=TRUE)`, both `percentVar` values and
  the whole 7 x 7 `dist(t(assay(vsd)))` matrix (engine: `tables/sample_distances.csv`).
  Supplement (blind = FALSE, the vignette chunk as written, after `DESeq(dds)`): the whole
  transformed matrix and the two `percentVar` values.
- **What "equal" means here.** The engine's own PCA (`_shared` `os_pca_scores`) is the same
  computation as `plotPCA` (top 500 rows by variance, `prcomp` centred, not scaled) but not the
  same code: it breaks variance ties by feature id and makes the largest-|loading| of each
  component positive. The test therefore allows exactly one transformation of the vignette
  output -- a whole-column sign flip per component, printed in the log -- and otherwise requires
  agreement to relative 1e-8, the precision of the 10-significant-digit tables. Printed values
  are matched to their printed decimals, not beyond.
