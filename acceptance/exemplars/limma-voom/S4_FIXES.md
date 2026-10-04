# limma-voom S4 fixes (S3_REVIEW_astra F1-F3)

Branch `s4/limma-voom-dupcor` (from `integrate/m1m2` @53006d8, merged again at 6c22204). Module 1.0.1 -> **1.1.0**
(`scripts/limma_voom_core.R:5`). All R ran in `omicstat-r:2026.09.1` (limma 3.68.5, edgeR 4.10.5) on GT103, run dir
`~/omic-build-logs/s4/limma-voom/` (logs `~/omic-build-logs/s4/limma-voom-<tag>.log`).

- Goldens written: `limma-voom-golden2.log` (`OMICSTAT_WRITE_GOLDEN=1`, SMOKE PASSED).
- Final normal run on the merged tree (shared `limma_io` `res[["expr"]]` fix included): `limma-voom-v1.log`
  SMOKE PASSED, EXIT 0, `PASS: container golden`, no FAIL/SKIP lines (earlier pre-merge run: `limma-voom-final2.log`).
- Lock: `limma-voom-lock3.log` (1.1.0, 14 files, tier container); `limma-voom-lockcheck3.log` `OK (14 files)`.

History: a first helper made these edits and was cut off by a rate limit; its uncommitted work was saved unverified in
WIP c34d593. The module tree of c34d593 is byte-identical (md5) to the tree that ran `limma-voom-final2.log`; it was
re-run on the merged tree, the voomLmFit span claim was checked against the edgeR 4.10.5 source (below), all PNGs were
looked at again, and the lock was regenerated after the last edit.

## F1 - PACK C anchors (fixed)

What changed
- `tests/fixtures/make_gse63310.R`: the RNAseq123 workflow's own import on the sha-locked
  `acceptance/data/GSE63310_RAW.tar` (F4): the workflow's 9 files (Rmd:83-87), `readDGE(columns = c(1, 3))`
  (Rmd:94), sample names, `group` (LP/ML/Basal) and `lane` (L004/L006/L008) (Rmd:109-116). All 27179
  genes x 9 samples go to the engine; the old first-5-files / first-5000-genes / A,A,B,B,B subset is gone.
  Only deviation: the `.txt.gz` members are read directly instead of `R.utils::gunzip` first (same content).
- Source evidence `acceptance/exemplars/limma-voom/_s4/rnaseq123/` (MANIFEST.tsv):
  `limmaWorkflow.Rmd` from https://git.bioconductor.org/packages/RNAseq123 branch RELEASE_3_23 commit
  09a5145cc779e0e9772311c8420378df63241031 (RNAseq123 1.36.0); upstream sha256 f4375bc3... (CRLF),
  stored LF-normalised by the repository `.gitattributes` (sha256 ce90daf5...). `limmaWorkflow.rendered.txt`:
  text of https://bioconductor.org/packages/release/workflows/vignettes/RNAseq123/inst/doc/limmaWorkflow.html
  fetched 2026-09-29 (HTML sha256 dcf684fa...; text sha256 549f49f5...), built with limma 3.68.4 /
  edgeR 4.10.1 (rendered:555-585). The fixture refuses a changed file (`OS_ANCHOR_HASH_MISMATCH`).
- `scripts/run_limma_voom.R`: `os_limma_design(..., allow_multilevel = TRUE)`: the compared pair is one
  coefficient of `~ covariates + condition`; further condition levels stay in the model (the workflow's
  3-group + lane design). Previously the module refused more than two levels.
- `tests/fixtures/guide_yoruba.R` (same file as in limma-dupcor): User's Guide sec 18.1 code with the
  voom span written out.
- `tests/run_smoke_test.R` sections A (printed), B (replay), C (suite route), D (Yoruba).

Anchors and their kind (all in `limma-voom-v1.log`)
| kind | what | asserted |
|---|---|---|
| PRINTED (workflow's own code, run in the test) | rendered:86 dim 27179 x 9; :205 all-zero 22026/5153; :212 16624 x 9 after `filterByExpr(x, group=group)`; :249 TMM factors; :416 voom span 0.401; :377-381/:386-390 voom E and weights (5 genes x 9); :432-435 `decideTests(efit)` Basal-LP 4646/7118/4860, Basal-ML 4936/7008/4680, LP-ML 3141/10953/2530; :440-443 `treat(lfc=1)` 1633/12977/2014, 1777/12793/2054, 223/16211/190; :447 de.common 2782; :465-470 and :473-478 both `topTreat` heads (IDs, logFC, AveExpr, t, P, adj.P) | at printed precision; all PASS |
| REPLAY (engine `--interface legacy` vs the workflow chain) | same 9 samples, 27179 genes, `~ lane + group`, Basal vs LP. Two documented interface differences: **D1** engine filters with the design (`filterByExpr(y, design)`, PACK D-V2) -> 17062 genes (a superset of the workflow's 16624 group-filtered genes); **D2** the engine tests the `groupBasal` coefficient exactly; the workflow's `contrasts.fit` gives approximate SEs for a weighted non-orthogonal design (contrasts.fit Rd; probe: max abs dP 0.106 on identical genes). | logFC/AveExpr/t/P/BH/B for all 17062 genes, direction summary (4713/7370/4979), treat (fc = 2 = the workflow's lfc = 1), MDS coordinates (Rmd:280/285 `plotMDS(lcpm)`), voom trend points, span and TMM factors: all equal (tol 1e-10) |
| SUITE (owner-pending voomLmFit call set, kept provisional) | default engine vs an independent `voomLmFit(defaults) + eBayes`; sample weights vs `voomLmFit(sample.weights = TRUE)`; legacy sample weights vs `voomWithQualityWeights + lmFit + eBayes` | equal |
| PRINTED (Yoruba, guide code) | guide 18.1.9 with `adaptive.span = FALSE` (limma NEWS 3.66.0; S4_ANCHOR_TRACE.md): consensus 0.4455442/0.4459984 print 0.446/0.446 (guide:7402,:7410); `summary(decideTests(fit))` all four coefficients (guide:7418-7421); all 49 printed topTable rows, every column (guide:7423-7473) | all PASS |
| REPLAY (Yoruba, engine) | the guide-filtered 16918 x 86 counts (guide:7204-7208) into the engine (`--interface legacy --min-count 0`, filterByExpr then keeps every gene); engine EList E, weights and span 0.400455 equal guide:7398 `voom(y, design)` under the locked adaptive span | PASS |

Printed vs engine: the printed Basal-LP counts belong to the workflow route (group filter + contrasts.fit);
the engine route is replayed, not forced onto the printed numbers (NOTE line in the log shows both). The
guide's blocked Yoruba fit (duplicateCorrelation) is outside limma-voom; limma-dupcor's RNA engine asserts it.

## F2 - Methods from the actual run (fixed)

- `scripts/limma_voom_core.R` `lv_template_values()` + `references/reporting-templates.md` (new slots
  `edger_version`, `interface_label`, `filter_sentence`, `norm_sentence`, `voom_sentence`,
  `weights_sentence`, `moderation_sentence`): edgeR version; filterByExpr arguments and the thresholds
  filterByExpr applied (CPM cutoff = min.count / median library size, minimum sample size from the design
  leverage, total count) and genes kept; TMM settings and factor range; interface (voomLmFit or legacy
  voom + lmFit / voomWithQualityWeights) with `adaptive.span = TRUE` and the chosen span (voomLmFit:
  `limma::chooseLowessSpan(nrow, 50, 0.3, 1/3)` at `scripts/limma_voom_core.R:55`; the edgeR 4.10.5 body of voomLmFit
  lines 85-87 is `if (adaptive.span) span <- chooseLowessSpan(nrow(counts), small.n = 50, min.span = 0.3, power = 1/3)`,
  printed in the container, `limma-voom-vlf.log`; the smoke also checks it equals voom's span on the same genes);
  sample-weight settings and every estimated weight; eBayes settings with estimated prior df / prior
  variance, or treat `fc`, `lfc = log2(fc)` and the interval null. Results JSON `details` carry the same.
- Smoke assertions: Methods (default), (legacy), (treat), (sample weights, voomLmFit), (legacy sample
  weights); the reported CPM cutoff and minimum sample size reproduce the 17062 retained genes.

## F3 - voom trend and sample MDS (fixed)

- `voom`/`voomLmFit`/`voomWithQualityWeights` now `save.plot = TRUE` (registered; display only):
  `figures/voom_trend.*` + `tables/voom_trend_points.csv`. Sample MDS: `limma::plotMDS(cpm(dge, log = TRUE,
  prior.count = 2), top = 500, gene.selection = "pairwise", plot = FALSE)` (registered with `edgeR::cpm`):
  `figures/mds.*` + `tables/mds_coordinates.csv`. Captions state n features/samples, span, top 500 and
  input scale; the draft ends with "Figure legends".
- Figures looked at (every PNG of `_smoke/limma-voom-smoke`: a0, legacy, treat, weighted, legacy_weighted, yoruba;
  the five RNAseq123 MDS PNGs are byte-identical, as expected from the same log-CPM input):
  - a0/voom_trend: 17061 trend points, lowess line visible, axes labelled, nothing clipped.
  - a0/mds: 9 samples, three groups clearly separated, legend "group", % variance on axes.
  - a0/volcano, treat/volcano: counts in legend (4974/4717; treat 2055/1659), BH line, labels readable.
  - a0/md: coloured by BH, zero line, no clipping.
  - legacy_weighted/voom_trend: trend drawn for the voomWithQualityWeights route.
  - yoruba/mds: 86 samples by gender, no clipping. yoruba/voom_trend: 16918 points, trend drawn. yoruba/volcano: 33/23
    (unblocked voom fit, differs from the guide's blocked 27/22 as expected); labels are Entrez IDs. yoruba/md fine.
  - legacy, weighted, legacy_weighted: volcano counts 4713/4979, 4834/5163, 4854/5177; md coloured by BH; trends drawn.
    In legacy_weighted/volcano one label (269132) sits over red points but stays readable (shared label layout).
  - MD plots carry no in-panel legend; colours and counts are stated in the caption (shared plot, unchanged).

## Other checks
- calls registry C1-C3 and default drift, check_defaults.py, check_flag_docs.py, lint_r.py: PASS in the
  container (smoke). Spec replay byte-identical (tables, MDS, all PNG/spec), display filter, typed unknown
  flag, from-run chain and tamper refusal: PASS. `tools/make_module_lock.R limma-voom` then `--check` OK.

## Known failing anchors
None.

## Owner items
- P-1 voomLmFit call set: still owner-pending; the provisional default is unchanged and only checked by
  a suite replay (not a source anchor).
- P-2 treat fc registration: unchanged (fc = user value, lfc = log2(fc)).
- **adaptive.span (new)**: the sec 18.1.9 Yoruba printed anchor is asserted with the guide-era voom span
  (`adaptive.span = FALSE`, limma NEWS 3.66.0; docs/build/S4_ANCHOR_TRACE.md) while every engine route keeps
  `adaptive.span = TRUE` (frozen S1 default). Whether the suite should switch is not decided here. (RNAseq123 needs no
  such split: its release rendering already used the adaptive span 0.401.)
- Acknowledge the two RNAseq123 interface differences (D1 filter with the design per PACK D-V2; D2 exact
  coefficient instead of `contrasts.fit`) and that limma-voom now accepts more than two condition levels
  (other levels stay in the model), which the registered workflow design needs.

## Shared needs (not edited here)
1. `os_limma_direction_summary()`: the `lfc` column is always 0; for treat runs it should record the treat
   lfc (the counts themselves follow the treat P values correctly).
(Reported by the first helper and now fixed on integrate/m1m2 fa9227c: `limma_io` read `res$expr`, which partially
matched `res$expr_scale`. The core still sets `expr` explicitly, `scripts/limma_voom_core.R:108-109`.)

## Notes for the final verifier
- Anchor evidence: `_s4/rnaseq123/` (hash-locked in the fixture); probes `_s4/probe_workflow.R`
  (GT103 `limma-voom-probe1.log`) and `acceptance/exemplars/limma-dupcor/_s4/probe_guide_yoruba.R`
  (`limma-voom-yprobe.log`).
- Smoke runtime about 4 minutes (Yoruba guide fit about 1.3 min).
