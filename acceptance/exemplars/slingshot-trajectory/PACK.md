# PACK — slingshot-trajectory

S0 evidence pack and S1 draft. Independent verification is pending; this lane does not write `verification.json`.

| Layer | Evidence |
|---|---|
| L1 | slingshot **2.20.0** and tradeSeq **1.26.0**, Bioconductor `RELEASE_3_23`: Rd, rendered vignettes with printed outputs, NEWS, CITATION, sha256 manifest and S4-method defaults in `L1_bioc3.23/`. The generic Rd export captures only short generic signatures, so `defaults_s4.tsv` is extracted from the locked S4 usage blocks and manifest-listed. |
| L2 | Street et al. 2018 Slingshot method (PMC6007078) and Van den Berge et al. 2020 tradeSeq method (PMC7058077), URL/sha256 pinned in `L2/`. |
| L3 | 9 applicable tier-A close readings; one tier-A bulk RNA-seq Slingshot use excluded (`literature/l3_notes.md`). |
| L4 | 30 licensed, open-access, PubMed-echoed articles; **27/30 applicable** to single-cell lineage inference, 3/30 use bulk or spatial-location units. |

## T — table skeleton

Retain a cells-by-lineages table with cell ID, biological sample, front-end cluster label, low-dimensional coordinates, lineage ID, pseudotime, lineage weight and NA/unassigned status. A lineage table records starting and terminal clusters, MST edges and curve parameters. For tradeSeq, retain all genes' convergence status, test name, statistic, raw P, adjusted P and effect summary by lineage/condition. Displayed Top-N genes are a view of the complete result.

## F — figure grammar

Draw the cluster MST and fitted principal curves on the same reduced-dimension axes with clearly labelled start/end groups. A second view colors cells by lineage-specific pseudotime and distinguishes cells not assigned to a lineage. A tradeSeq smoother panel plots expression against pseudotime with lineage/condition labels; gene heatmaps are tied to a named test and cutoff. Embedding labels must state PCA, UMAP or diffusion coordinates and whether they came from Seurat, scverse or Bioconductor.

## W — wording

Methods template: “Cell `<cluster labels>` and `<embedding>` were passed to slingshot (v2.20.0; `start.clus=<...>`, `end.clus=<...>`, `omega=<...>`, curve settings `<...>`). The biological start was chosen because `<rationale>`. `slingPseudotime` and `slingCurveWeights` supplied trajectory values to tradeSeq (v1.26.0), where `fitGAM(nknots=<...>, conditions=<...>)` fit `<genes>` and `<named test>` tested `<question>`.” Results template: “`<n>` lineages connected `<start>` to `<ends>`; `<n>` cells had assigned pseudotime in lineage `<id>`. `<n>` genes passed `<adjustment/cutoff>` for `<test>`.” Pseudotime is relative ordering, not measured elapsed time. Do not call sample IDs cell-type clusters without validation.

## V — variant frequencies

Denominator: **27 applicable / 30 corpus**. Applicable front ends: **Seurat 17/27, mixed 7/27, scverse 2/27, not reported 1/27, Bioconductor-only 0/27**. The three exclusions are bulk DNA methylation, bulk RNA-seq and spatial-location trajectories; they contribute no defaults. tradeSeq is explicitly used by **4/27** Slingshot papers. Frequencies for fitGAM or tradeSeq tests can also be read with 4 as the reporting subgroup denominator, but that subgroup is too small to set defaults.

| Reported variant | Seurat (n=17) | Mixed (n=7) | scverse (n=2) | Front end not reported (n=1) | All applicable (n=27) |
|---|---:|---:|---:|---:|---:|
| Biological root rationale | 3 | 4 | 0 | 0 | 7; not reported 20 |
| Exact starting cluster | 3 | 2 | 0 | 0 | 5; not reported 22 |
| Exact ending cluster(s) | 1 | 2 | 0 | 0 | 3; not reported 24 |
| Explicit embedding tied to Slingshot | 4 | 2 | 1 | 0 | 7; not reported 20 |
| tradeSeq explicitly used | 1 | 2 | 1 | 0 | 4; not reported 23 |
| `nknots` for tradeSeq | 1 | 1 | 0 | 0 | 5 in 1, 6 in 1; not reported 25 |
| Explicit tradeSeq test | `patternTest` 1 | `conditionTest` 1, `associationTest` 1 | `associationTest` 1 | 0 | 4; not reported 23 |
| Named adjusted-P method for trajectory-gene test | 0 | BH 1 | Bonferroni 1 | 0 | 2; not reported 25 |
| Slingshot `omega=TRUE` | 1 | 0 | 0 | 0 | 1; not reported 26 |
| Explicit curve distance/extension/shrink settings | 0 | 1 | 0 | 0 | 1; not reported 26 |

No parameter setting has a >50% majority of the 27 applicable articles. Seven root rationales are different biological choices; the root must be explicit in an executable contract. Four tradeSeq users select three different tests, so neither a “tradeSeq default test” nor a single test majority exists. One paper uses sample names as Slingshot cluster identifiers; that is flagged for S1 validation and is not a usable cell-label default. A quoted `v3.18` for Slingshot is retained as a historical report with an inconsistency note, not used as a version pin.

## C — replay and printed anchors

Registry #30 uses package-embedded data: `slingshotExample` is a **bifurcating** 140-cell, two-dimensional coordinate/cluster fixture (`dim(rd) = 140 × 2`, `length(cl) = 140` in the locked vignette). The same vignette independently generates a **single-lineage** count matrix of 750 genes × 300 cells; its rendered example prints a pseudotime summary with minimum 0.000, median 21.121 and maximum 43.185, but the simulation code does not set a seed, so those numbers are **not** replay assertions. The earlier registry row conflated the two, so an append-only correction follows in `ANCHOR_REGISTRY.md`. tradeSeq embeds `countMatrix`, `crv` and `celltype`; its vignette uses `set.seed(7)`, `fitGAM(nknots=6)` and prints 240 converged genes for that exact package data/recipe. The embedded-data dimensions and the seeded tradeSeq result are replay assertions for their exact locked recipes; the unseeded Slingshot simulation has no exact numeric assertion. None is a numerical tolerance or a claim that every study has 240 converged genes. No external download is needed for #30; the fixture versions follow the pinned packages.

## D — function default / official guide / exemplar evidence

Defaults below are read from locked S4 usage blocks (`defaults_s4.tsv`) and Rd; guide recipes are examples. Frequencies use the 27 applicable papers. A field that is biological orientation or downstream display has no function default.

| Parameter (profile) | Function default, locked release | Locked vignette / guide | Exemplar evidence (n=27) | S1 draft |
|---|---|---|---|---|
| `cluster_labels` (D-ST1) | required | vignette supplies cell clusters | cell type labels 1/27; sample names 1/27; cluster labels 1/27; not reported 24/27 | Require biological cell-state labels |
| `reduced_dim` (D-ST2) | reducedDim=NULL; supply matrix/object | simulated 2D/PCA examples | UMAP 4/27; first 2 diffusion components 1/27; first 12 PCs 1/27; first 15 diffusion components 1/27; not reported 20/27 | Record embedding source |
| `start_cluster` (D-ST3) | start.clus=NULL | vignette uses known origin when available | AP progenitor cells 1/27; Au-iNKT1 1/27; preOPCs 1/27; GBCs 1/27; prCAFs 1/27; not reported 22/27 | Require explicit start or documented unsupervised choice |
| `end_cluster` (D-ST4) | end.clus=NULL | can constrain terminal clusters | Ac-iNKT1 1/27; mOLs 1/27; V1R and V2R mVSNs 1/27; not reported 24/27 | Explicit if biologically known |
| `root_rationale` (D-ST5) | biological choice, not argument | known progenitor used in examples | AP progenitor cells 1/27; Au-iNKT1 differentiation origin 1/27; preOPCs progenitor population 1/27; Rest MG / MGPC-nearest, by analysis subset 1/27; GBC progenitors 1/27; progenitor root and male/female branches 1/27; prCAFs as progenitor 1/27; not reported 20/27 | Document rationale |
| `dist_method` (D-ST6) | slingshot | MST on cell clusters | mnn 1/27; not reported 26/27 | Pin method; expose alternatives |
| `use_median` (D-ST7) | FALSE | cluster center by mean | not reported 27/27 | Pin FALSE provisionally |
| `omega` (D-ST8) | FALSE | optional outlier/origin handling | TRUE 1/27; not reported 26/27 | Explicit policy |
| `omega_scale` (D-ST9) | 1.5 | not universal | not reported 27/27 | Record if omega enabled |
| `times` (D-ST10) | NULL | known time points optional | not reported 27/27 | Provide when design supports |
| `shrink` (D-ST11) | TRUE | simultaneous curves share early cells | FALSE 1/27; not reported 26/27 | Pin TRUE provisionally |
| `extend` (D-ST12) | y | curve extension in vignette | n 1/27; not reported 26/27 | Explicit choice |
| `reweight` (D-ST13) | TRUE | iterative fitting | not reported 27/27 | Pin TRUE provisionally |
| `reassign` (D-ST14) | TRUE | iterative fitting | not reported 27/27 | Pin TRUE provisionally |
| `curve_thresh` (D-ST15) | 0.001 | convergence setting | not reported 27/27 | Record convergence |
| `maxit` (D-ST16) | 15 | curve iteration cap | not reported 27/27 | Record if changed |
| `stretch` (D-ST17) | 2 | curve fitting | 0 1/27; not reported 26/27 | Pin 2 provisionally |
| `approx_points` (D-ST18) | NULL | large-data vignette recommends approximation | not reported 27/27 | Choose by dataset scale |
| `smoother` (D-ST19) | smooth.spline | principal curves | not reported 27/27 | Pin smooth.spline provisionally |
| `shrink_method` (D-ST20) | cosine | shared-lineage shrinkage | not reported 27/27 | Pin cosine provisionally |
| `allow_breaks` (D-ST21) | TRUE | curve fitting | not reported 27/27 | Record break policy |
| `tradeSeq_used` (D-ST22) | downstream optional, not slingshot arg | tradeSeq analysis follows curve weights | yes 4/27; not reported 23/27 | Explicit gene-analysis branch |
| `fit_counts` (D-ST23) | counts required | raw countMatrix in tradeSeq vignette | raw count matrix 1/27; not reported 26/27 | Require raw counts |
| `fit_pseudotime` (D-ST24) | NULL if sds supplied | slingPseudotime(crv, na=FALSE) | Slingshot pseudotime 1/27; not reported 26/27 | Preserve NA/lineage structure |
| `fit_cellweights` (D-ST25) | NULL if sds supplied | slingCurveWeights(crv) | Slingshot cell weights 1/27; not reported 26/27 | Preserve weights |
| `fit_conditions` (D-ST26) | NULL | multiple-conditions vignette models separate smoothers | H3 status (K27M or ctl) 1/27; not reported 26/27 | Explicit only with replicates/design |
| `fit_genes` (D-ST27) | all genes | vignette uses package countMatrix | 5,000 most variable genes 1/27; not reported 26/27 | Record selection |
| `fit_weights` (D-ST28) | NULL | zero-inflation weights optional | not reported 27/27 | Explicit if used |
| `fit_offset` (D-ST29) | NULL; TMM-derived | guide describes normalization | not reported 27/27 | Record offsets |
| `nknots` (D-ST30) | 6 | evaluateK suggested; example chooses 6 | 6 1/27; 5 1/27; not reported 25/27 | Use evaluateK or justify fixed 6 |
| `fit_family` (D-ST31) | nb | negative-binomial GAM | not reported 27/27 | Pin nb provisionally |
| `assoc_global` (D-ST32) | TRUE | omnibus test | not reported 27/27 | State tested lineage scope |
| `assoc_lineages` (D-ST33) | FALSE | can test lineages separately | not reported 27/27 | Explicit if selected |
| `assoc_l2fc` (D-ST34) | 0 | effect threshold optional | not reported 27/27 | Explicit when used |
| `assoc_npoints` (D-ST35) | 2 × nknots(models) | association contrasts between points | not reported 27/27 | Record if changed |
| `assoc_contrast_type` (D-ST36) | start | other choices end/consecutive | not reported 27/27 | State contrast reference |
| `p_adjust` (D-ST37) | no fitGAM/associationTest adjustment argument | vignette shows raw P; report correction | Benjamini-Hochberg 1/27; Bonferroni 1/27; not reported 25/27 | Apply and name correction |
| `fdr_cutoff` (D-ST38) | no universal cutoff | full test table retained | 0.05 BH adjusted P 1/27; 0.05 Bonferroni corrected P 1/27; not reported 25/27 | S1 select reporting threshold |
| `slingshot_version` (D-ST39) | 2.20.0 pinned | locked vignette | 2.6.0 1/27; 1.2.0 1/27; 1.6.1 1/27; 1.4.0 2/27; 2.2.0 1/27; 2.12.0 2/27; 1.8.0 1/27; 2.4.0 1/27; 3.18 1/27; 2.16.0 1/27; not reported 15/27 | Store version |
| `tradeSeq_version` (D-ST40) | 1.26.0 pinned | locked vignette | 1.18.0 1/27; 1.4.0 1/27; not reported 25/27 | Store version |
| `test_method` (D-ST41) | caller selects test | association/start-end/diff-end examples | conditionTest 1/27; patternTest 1/27; associationTest 2/27; not reported 23/27 | Require named biological question |
| `test_l2fc` (D-ST42) | selected test usually 0 | guide discusses thresholded tests | log2(1.25) 1/27; not reported 26/27 | Explicit if changed |
| `display_top_n` (D-ST43) | not function argument | examples display subsets | 200 1/27; not reported 26/27 | Retain full table |

The value `curve_thresh=0.001` is a curve-fitting stopping criterion, not a numerical tolerance for replay. The default `nknots=6` is a model-basis choice; the tradeSeq vignette recommends evaluating knot count rather than treating six as universal. `associationTest`'s fold-change threshold and contrast type do not describe `conditionTest` or `patternTest` in application papers.

## X — version-sensitive items

- slingshot NEWS 2.0.0 changes the default output class from `SlingshotDataSet` to `PseudotimeOrdering`, and `getLineages` uses `createClusterMST`; code that indexes old object slots may fail or differ. Locked version is 2.20.0.
- tradeSeq NEWS 1.5.02 changes `associationTest` contrasts to `nPoints` rather than knots and adds `contrastType`; NEWS 1.5.17 adds `inverse` for multiple-condition association contrasts. Older numeric Wald outputs may not be comparable. Locked version is 1.26.0.
- tradeSeq removed its own fitGAM/evaluateK seed arguments in 0.99.9902; the locked vignette calls `set.seed()` externally. Record the seed and model convergence. One paper reports “Slingshot v3.18,” inconsistent with the pinned 2.x series; it is retained as reported, without deriving defaults.
- The standard L1 exporter emits only generic `slingshot(data, ...)` and `fitGAM(counts, ...)` rows in `defaults.tsv`; manifest-listed `defaults_s4.tsv` records result-affecting S4 method defaults directly from locked Rd. No shared collection tool was modified for this.

## S1 drafts and pending decisions

1. Validate true cell-state cluster labels, sample IDs and the embedding before Slingshot; reject sample-name-as-cluster input. Require a biologically argued start and optional end states, and report lineage-specific NA pseudotimes and weights.
2. Pin slingshot 2.20.0 with explicit distance, omega, shrink/extension and approximation settings. Let data scale and sensitivity checks determine `approx_points`; do not turn a single paper's curve-control values into defaults.
3. When tradeSeq is requested, pass raw counts and Slingshot pseudotime/weights, set and record an external seed, evaluate knot count, report fit convergence, and select a named test (`associationTest`, `patternTest`, `conditionTest`, etc.) matched to the question. A condition-specific smoother requires biological samples/design review.
4. Preserve full gene results with raw and adjusted P and show selected genes as a separate display. State the multiple-testing scope and any effect-size threshold.
5. Replay the package-embedded bifurcating and single-lineage fixtures separately, using the registry correction to avoid a wrong-topology expectation.
