---
name: omicstat
description: >
  Route an omics question to a package-level analysis module or an explicit
  --from-run pipeline. Covers bulk differential expression, enrichment, pathway
  scores, Seurat, Bioconductor and scverse single-cell workflows, neutral
  back ends, coexpression networks, mutation landscapes and infiltration.
  Check the execution table before running a module. This router has NO analysis engine. Clinical survival,
  prediction modelling and clinical association are exported elsewhere.
---
# omicstat router

**Installed analysis status (S5, 2026-10-04):** all 38 analysis targets are installed:
14 M1/M2 modules and 24 accepted M3/M4 modules (19 R, five Python).
The five Python modules passed numerical replay and were re-sealed on the merged
tree under the coordinator's 2026-10-04 decision. Three additional scverse display/annotation targets are listed below; their acceptance is recorded in docs/build/UMAP_DISPLAY_REPORT.md. Two self-tests are utilities.
Acceptance scope and remaining owner items are recorded in SUITE.md and
`docs/build/S5_REPORT_m3m4.md`; seals do not establish manuscript readiness.

The parameter policy approved on 2026-09-29 overrides older majority-language:
use the locked function default, or its official tutorial recommendation with
an explicit source. Example QC thresholds, PC/HVG counts and resolutions are
not recommendations: require the user's values. Do not invent literature
majorities or resolve scientific choices on the owner's behalf.

## 1. Routing table - implemented entry points

This is the MCP execution registry. It lists only entry files that exist. The
reference service's one method_map contains all 38 analysis targets, with an
availability status; a literature target is not automatically executable.

<!-- registry:begin -->
| The question sounds like... | -> Module | CLI entry script |
|---|---|---|
| Test the R environment and output contract | `omicstat-selftest` | `scripts/run_omicstat_selftest.R` |
| Test the Python environment and cross-lane figure contract | `omicstat-selftest-py` | `scripts/run_omicstat_selftest_py.py` |
| Two-group bulk RNA-seq or a prespecified contrast; DESeq2 Wald and shrinkage | `deseq2-wald` | `scripts/run_deseq2_wald.R` |
| Bulk RNA-seq sample QC, variance stabilization, PCA and distances | `deseq2-qc` | `scripts/run_deseq2_qc.R` |
| Multi-group or time-course bulk expression likelihood-ratio test | `deseq2-lrt` | `scripts/run_deseq2_lrt.R` |
| Bulk count differential expression with edgeR quasi-likelihood | `edger-qlf` | `scripts/run_edger_qlf.R` |
| RNA-seq linear modelling with voom or explicit sample-quality weights | `limma-voom` | `scripts/run_limma_voom.R` |
| Already-normalized microarray expression differential analysis | `limma-array` | `scripts/run_limma_array.R` |
| Repeated-measure expression analysis with a prespecified subject block | `limma-dupcor` | `scripts/run_limma_dupcor.R` |
| Batch correction for visualization/scoring, or surrogate variables | `sva-batch` | `scripts/run_sva_batch.R` |
| Over-representation of a thresholded gene list against tested genes | `clusterprofiler-ora` | `scripts/run_clusterprofiler_ora.R` |
| Ranked gene-set enrichment using clusterProfiler | `clusterprofiler-gsea` | `scripts/run_clusterprofiler_gsea.R` |
| Compare enrichment across prespecified gene lists | `clusterprofiler-compare` | `scripts/run_clusterprofiler_compare.R` |
| Fast enrichment of a full prespecified ranked gene list | `fgsea-prerank` | `scripts/run_fgsea_prerank.R` |
| One pathway score per sample; not an automatic inference route | `gsva-score` | `scripts/run_gsva_score.R` |
| Competitive or self-contained gene-set tests; single roast tests one set | `limma-camera` | `scripts/run_limma_camera.R` |
| AnnData raw-count QC with explicitly supplied cell/gene/doublet thresholds | `scanpy-qc` | `scripts/run_scanpy_qc.py` |
| AnnData normalization, HVG, PCA, Leiden and UMAP | `scanpy-cluster` | `scripts/run_scanpy_cluster.py` |
| Descriptive cluster markers, never cell-wise condition inference | `scanpy-markers` | `scripts/run_scanpy_markers.py` |
| CPU scVI latent-space batch integration, preserving original counts/clusters | `scvi-integrate` | `scripts/run_scvi_integrate.py` |
| Marker-panel descriptive cluster naming with an explicit label map | `scanpy-annotate` | `scripts/run_scanpy_annotate.py` |
| Neighbour purity and isolated-cell flags for UMAP display curation | `scanpy-purity` | `scripts/run_scanpy_purity.py` |
| Query projection onto a fixed reference UMAP with ingest | `scanpy-ingest` | `scripts/run_scanpy_ingest.py` |
| CPU scANVI label transfer from a verified local scVI run | `scanvi-annotate` | `scripts/run_scanvi_annotate.py` |
| Seurat raw-count quality control | `seurat-qc` | `scripts/run_seurat_qc.R` |
| Seurat normalization and clustering | `seurat-cluster` | `scripts/run_seurat_cluster.R` |
| Seurat batch integration | `seurat-integrate` | `scripts/run_seurat_integrate.R` |
| Seurat cluster markers | `seurat-markers` | `scripts/run_seurat_markers.R` |
| Seurat gene-program scores | `seurat-modulescore` | `scripts/run_seurat_modulescore.R` |
| SCE per-cell quality control | `scater-qc` | `scripts/run_scater_qc.R` |
| SCE pooling, HVG, PCA, graph clustering and UMAP | `scran-cluster` | `scripts/run_scran_cluster.R` |
| SingleCellExperiment batch integration | `batchelor-integrate` | `scripts/run_batchelor_integrate.R` |
| SingleCellExperiment cluster marker scores | `scran-markers` | `scripts/run_scran_markers.R` |
| Single-cell gene-set activity by AUCell | `aucell-score` | `scripts/run_aucell_score.R` |
| Reference cell-type annotation by SingleR | `singler-annotate` | `scripts/run_singler_annotate.R` |
| Replicated differential expression within cell types / pseudobulk | `muscat-pseudobulk` | `scripts/run_muscat_pseudobulk.R` |
| Cell-type proportion differences across replicated samples | `speckle-propeller` | `scripts/run_speckle_propeller.R` |
| Inferred cell-cell ligand-receptor communication by CellChat | `cellchat-communication` | `scripts/run_cellchat_communication.R` |
| Monocle3 graph trajectory, rooted pseudotime and graph-associated genes | `monocle3-trajectory` | `scripts/run_monocle3_trajectory.R` |
| Lineages and pseudotime / Slingshot, tradeSeq | `slingshot-trajectory` | `scripts/run_slingshot_trajectory.R` |
| Normalized bulk expression: exploratory coexpression modules and traits | `wgcna-network` | `scripts/run_wgcna_network.R` |
| Somatic MAF: mutation landscape, TMB and cooccurrence | `maftools-landscape` | `scripts/run_maftools_landscape.R` |
| Human bulk TPM: explicit offline infiltration method | `immunedeconv-infiltration` | `scripts/run_immunedeconv_infiltration.R` |
| Independent biological-unit dose-response estimation | `drc-dose` | `scripts/run_drc_dose.R` |
| Gaussian linear mixed-effects models for repeated subjects | `lme4-lmm` | `scripts/run_lme4_lmm.R` |
| Declared marginal contrasts from a verified lme4 candidate model | `emmeans-contrast` | `scripts/run_emmeans_contrast.R` |
| Two-group protein abundance with probabilistic dropout | `proda-diff` | `scripts/run_proda_diff.R` |
| MSstats protein abundance contrasts with declared biological replication | `msstats-diff` | `scripts/run_msstats_diff.R` |
| Standard-curve inverse prediction and dilution titers | `drc-calibrate` | `scripts/run_drc_calibrate.R` |
| Repeated-subject nonlinear dose-response models | `nlme-dose` | `scripts/run_nlme_dose.R` |
| Prespecified biological-unit tests, source advisory diagnostics, or independent fixed-grid distribution effects | `omicstat-groupcompare` | `scripts/run_omicstat_groupcompare.R` |
| Normalize qPCR Ct per biological unit and reference gene using prespecified delta-delta-Ct | `omicstat-ddct` | `scripts/run_omicstat_ddct.R` |
| Associate prespecified genes with right-censored survival using expression handoff, continuous Cox and declared KM cutoffs | `survival-expr` | `scripts/run_survival_expr.R` |
| Train a prespecified expression LASSO-Cox signature and validate frozen coefficients with time-dependent ROC | `glmnet-coxsig` | `scripts/run_glmnet_coxsig.R` |
| Run Reactome over-representation with explicit eligible Entrez background and frozen offline annotation | `reactomepa-ora` | `scripts/run_reactomepa_ora.R` |
| Identify nonempty droplets with emptyDrops from unfiltered counts and explicit FDR/lower | `dropletutils-emptydrops` | `scripts/run_dropletutils_emptydrops.R` |
| A priori independent biological-unit sample sizes or event requirements for five explicit laboratory designs | `omicstat-samplesize` | `scripts/run_omicstat_samplesize.R` |
| Explicit-design method or rater agreement: Bland-Altman limits and CI, ICC form, Cohen or Fleiss kappa | `omicstat-agreement` | `scripts/run_omicstat_agreement.R` |
| Independent-unit biomarker discrimination, explicit-direction ROC/AUC, exploratory cutoffs and adjusted paired DeLong comparisons | `proc-roc` | `scripts/run_proc_roc.R` |
<!-- registry:end -->
## 2. Disambiguation trees

### Bulk expression and gene sets

Raw bulk counts with one contrast route to deseq2-wald; an explicit preference
for edgeR QLF or the limma workflow routes to edger-qlf or limma-voom. Multi-group
omnibus questions route to deseq2-lrt. Repeated-measure correlation routes to
limma-dupcor. Normalized microarrays route to limma-array. Do not switch engines
after inspecting significance. A batch-corrected expression matrix cannot enter
inference; use original counts and put batch in the design.

A thresholded gene list routes to clusterprofiler-ora with an explicit tested-gene
universe. KEGG, MSigDB, PanglaoDB and other unbundled gene sets route to the same
modules when the user supplies a local file (user-supplied collection contract):
clusterprofiler-ora, -gsea and -compare take --database custom --gene-sets <gmt>;
fgsea-prerank, gsva-score and limma-camera take --collection user --gene-sets <gmt>
--feature-id-type; aucell-score, seurat-modulescore and scanpy-annotate take their
usual file with --gene-sets-provenance and --feature-id-type. Provenance is
--gene-sets-provenance <json> or explicit --gene-sets-source, --gene-sets-version and
--gene-sets-id-type; never guess them. Without a local file, GO still runs and the
module refuses KEGG with OS_REFDATA_MISSING, explaining that KEGG gene sets must be
supplied as a local file (for example from the web app's public-data tool or the
KEGG REST API under its academic terms). Routing never rejects a question because
KEGG was mentioned. A gene symbol that happens to spell a test name (FRY, CAMERA, ROAST)
is a gene, not a method; a gene or gene list of interest routes like any other
to clusterprofiler-ora. A full ranking routes to clusterprofiler-gsea or fgsea-prerank. Sample-level pathway
scores on bulk or pseudobulk matrices route to gsva-score; per-cell gene-set
activity on a single-cell object routes to aucell-score. Neither AUCell nor GSVA
is the suite standard (coordinator decision 3, reversible by the owner). Competitive versus self-contained null hypotheses
must be settled before selecting camera/cameraPR versus fry/roast/mroast.
A single roast tests the one --set-id, not every overlapping set.

### Single-cell ecosystem and purpose

Marker-panel naming of AnnData clusters routes to scanpy-annotate. This records descriptive user decisions and retains unresolved clusters; SingleR and scANVI remain reference/model label transfer routes. Neighbour-purity or island cleanup for a display routes to scanpy-purity. Adding query cells to a fixed existing UMAP routes to scanpy-ingest, preserving reference positions. Rebuilding UMAP from a larger trained scVI latent uses scvi-integrate --latent-from-run; --leiden-resolution writes a new --scvi-cluster-col and preserves carried clusters. scanpy-cluster --use-rep uses an existing representation.

Cleaning, balanced object selection and ingest are display/curation only. Never route these curated objects into proportions, pseudobulk, markers or DE; use the original analysis cohort. A figure display-max-per-group cap only changes drawing, leaves objects/tables intact, and is stated in the caption. Consult reference_advise before choosing thresholds, resolution, caps or label-island parameters.

Existing Seurat, SingleCellExperiment and AnnData objects select the Seurat,
Bioconductor and scverse lanes respectively. An explicit user ecosystem or
reproduction target settles an otherwise ambiguous choice, and so does a named
ecosystem-specific method: SCTransform, FindClusters, Harmony-in-Seurat or
AddModuleScore mean the Seurat lane; scran, scater, batchelor or fastMNN mean
the Bioconductor lane; scanpy, scvi or an .h5ad file mean the scverse lane.
With none of these, request a prespecified ecosystem instead of asserting an
undocumented majority.
A front-end chain never switches ecosystems; OS_ECOSYSTEM_MIXED is a refusal,
not a request to silently convert and repeat analysis.

| Step | Seurat target | Bioconductor target | scverse target |
|---|---|---|---|
| QC | seurat-qc | scater-qc | scanpy-qc |
| Normalization/clustering | seurat-cluster | scran-cluster | scanpy-cluster |
| Integration | seurat-integrate | batchelor-integrate | scvi-integrate |
| Descriptive markers | seurat-markers | scran-markers | scanpy-markers |
| Scores | seurat-modulescore | aucell-score | no scoring engine |

Cluster descriptions are not between-condition inference. Replicated condition
questions route to muscat-pseudobulk (expression) or speckle-propeller
(proportions); samples are the replicates. Reference annotation routes to
singler-annotate; label transfer from a verified local scVI model routes to
scanvi-annotate. Communication routes to cellchat-communication; rooted graph
trajectories to monocle3-trajectory, and existing-embedding lineage curves plus
optional tradeSeq association to slingshot-trajectory. "monocle3 or slingshot?"
is answered by the chain, not by preference: a Seurat / graph-partition chain
takes monocle3-trajectory, a Bioconductor / existing-embedding chain takes
slingshot-trajectory. Require the biological root rationale, reference identity
and declared inputs before running.

A neutral R back end preserves the upstream `front_end_ecosystem` in provenance,
records `backend_ecosystem: neutral`, and adds informational QC
`OS_ECOSYSTEM_CROSSING` when a Python front end feeds it. This is coordinator
decision 4, reversible by the owner. The crossing is not a refusal.
`OS_ECOSYSTEM_MIXED` remains a refusal for front-end ecosystem switches.

### Network, mutation and infiltration

Normalized bulk expression and exploratory coexpression/module–trait questions
route to wgcna-network with explicit preprocessing, sample exclusions and power.
Somatic MAF landscape, TMB and cooccurrence questions route to maftools-landscape
with declared caller/build/filter history and callable territory. Human bulk TPM
infiltration routes to immunedeconv-infiltration with an explicit supported
method and its input/scale/species/licence declarations. Cell fractions and
scores are method-specific estimates; none of these routes provides causal hub,
mutation-free clinical-only sample, automatic TMB threshold or condition-effect
claims. CIBERSORT requires user-supplied licensed source and signature files.

## 3. Pipeline recipes and availability

Installed recipes (each module retains its documented acceptance scope):

- Bulk: deseq2-qc -> deseq2-wald -> clusterprofiler-ora / clusterprofiler-gsea.
- Multi-group: deseq2-qc -> deseq2-lrt -> clusterprofiler-compare.
- AnnData: scanpy-qc -> scanpy-cluster -> scanpy-markers.
- Multiple batches: scanpy-qc -> scanpy-cluster -> scvi-integrate -> scanvi-annotate.

Each step uses --from-run with the previous actual output directory. The
handoff verifies every file hash, object type, original front-end ecosystem,
StudyContract hash and known corrected-expression lineage. scVI corrects a
latent embedding, not the original count layer; it does not relabel clusters.

- Seurat: seurat-qc -> seurat-cluster -> seurat-markers / seurat-modulescore;
  multiple batches insert seurat-integrate before descriptive markers.
- Bioconductor: scater-qc -> scran-cluster -> scran-markers / aucell-score;
  multiple batches insert batchelor-integrate before descriptive markers.
- A "full chain" from raw matrix to markers or to pseudobulk includes the
  annotation step after integration: Seurat seurat-qc -> seurat-cluster ->
  seurat-integrate -> singler-annotate -> seurat-markers; Bioconductor scater-qc
  -> scran-cluster -> batchelor-integrate -> singler-annotate -> scran-markers;
  scverse condition comparison scanpy-qc -> scanpy-cluster -> scvi-integrate ->
  singler-annotate (or scanvi-annotate) -> muscat-pseudobulk.
- Any declared compatible front end -> singler-annotate -> muscat-pseudobulk
  -> clusterprofiler-gsea, with independent sample replication and a prespecified
  contrast; proportions instead use speckle-propeller.
- Objects processed outside omicstat re-enter at the front-end QC step: a
  hand-off requires a hash-verified upstream omicstat run, so "already processed
  in scanpy / Seurat" still means the lane's QC and clustering modules run first.
- A declared embedding/cluster object -> slingshot-trajectory or
  monocle3-trajectory; normalized expression and labels -> cellchat-communication.
- Sample expression -> wgcna-network; somatic MAF -> maftools-landscape;
  declared human TPM -> immunedeconv-infiltration. Clinical inference is exported.

Use each entry's documented object/layer contract and explicit --from-run;
these recipes do not authorize changing scientific parameters between steps.

## 4. Outside scope

Survival analysis, clinical prediction, diagnostic accuracy, meta-analysis and
clinical covariate-adjusted associations are not implemented here. Export
identified sample-level tables for a separately specified clinical workflow;
never treat a cell as a biological replicate. omicstat never bundles or
automatically downloads KEGG, CADD, PanglaoDB or DepMap content. User-supplied
local files (for example a KEGG GMT or PanglaoDB markers the user downloaded) are
accepted with recorded provenance and terms; the user is responsible for those
terms. Reference fetching is outside the offline analysis process and follows the
independent license gate.

Omics analyses that are not covered: answer "not covered by omicstat" instead of
routing to a near module. These are ATAC-seq and other chromatin accessibility or
ChIP-seq peak analysis, spatial transcriptomics (spot or spatial-domain methods),
proteomics and metabolomics differential analysis, RNA velocity, GWAS, variant
calling and fine-mapping, copy-number (CNV) inference, and alignment or
quantification from FASTQ. An expression-level question about data that the user
has already quantified into a gene-by-sample or gene-by-cell matrix still routes
by its matrix.

## 5. Parameters, labels and figures

Use the selected entry's --help and references/options.md (M1/M2 also retain references/parameters.md). Never assume
another module's flags. For the new Python modules, --species, --annotation,
--sample-col and --counts-layer are explicit; clustering dimensions and
resolution, QC thresholds and training epochs are explicit where needed.
Python emits data and figure requests only. Publication figures use the one
R layer, `_shared/scripts/render_figure_request.R`, and the shared style.
Use --journal nature|cell|science|generic; no separate Python publication style.

## 6. Via MCP

The existing tools remain exactly omicstat_list_modules, omicstat_describe,
omicstat_run, omicstat_read and omicstat_validate_publication. No new tool is
introduced. Arguments use the chosen entry's flags without leading --.
The default engine selects the pinned image by entry extension: .R uses
omicstat-r and .py uses omicstat-py, followed by the R renderer. The complete
run, including rendering, retains the 25-minute synchronous timeout.

Read exit_code, qc_triggered, engine_warnings, degenerate_estimates, artifacts,
upstream_runs, render_step and publication status. A successful source run does
not establish numerical acceptance or manuscript readiness. Utility self-test
numbers are never research results. A missing/inconsistent seal must not be
reported as a verified release.

## 7. Reference companion and routing evaluation

`reference_service/` is the separate omic-only companion. Search first, then
advise; insufficient evidence yields a literature request, not an invented
recommendation. Its catalog contains 38 targets even where the analysis engine
is unavailable. No deployment was performed by this source build.

The merged 146-question dataset is in tests/routing_eval.jsonl. Dataset/schema
checks are not a blinded agent routing score; no first-choice or acceptable-
alternative accuracy is claimed until independent predictions are supplied.
