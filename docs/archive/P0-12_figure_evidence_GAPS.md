# Evidence gaps and concrete fill plan

The frozen corpus contains302 complete records,301 independent figures (0242 is a useful companion of0138),134 DOIs and30 journals. This is design evidence, not an all-function audit or current-version numerical validation. No new figures were acquired or viewed for this text-only task. [Coverage matrix](sources/evidence/docs/figure-evidence/coverage-matrix.json) and [source gaps](sources/evidence/docs/figure-evidence/source-gaps.json) retain the original limitations.

## Four baseline analysis routes with no direct evidence

| Module | Direct | Targeted next records | Source and figure mix |
|---|---:|---:|---|
| fgsea-prerank |0|20|6 exact fgsea running-score/null or leading-edge figures;6 independent application rank/positive-negative NES figures;4 zero-P/error/floor diagnostics;4 list/background/size-filter examples. Use original methods and applications with explicit null/permutation and ranking metric. ClusterProfiler GSEA is transferable only.|
| scater-qc |0|20|6 original scater/scuttle/scran QC distributions;6 batch-local MAD threshold/retention flow;4 counts-features-mito scatter;4 zero/sub1/missing and alternate-feature QC examples. Match actual current method, not a generic violin.|
| seurat-qc |0|20|6 original Seurat raw/object-creation/post-QC views;6 sample-specific QC scatter;4 count/UMI/mitochondrial source definitions;4 retained/removed/zero/missing population flows. Explain CreateSeuratObject prefilters.|
| cellchat-communication |0|20|6 original CellChat sender-receiver network/matrix pairs;6 count-versus-strength/information-flow;4 pathway/LR probability/filter/permutation examples;4 self-edge/isolated-group and cross-condition comparisons. Preserve inferred versus physical-signalling boundary.|

The20 targets are per coherent figure family, with exact-method sources required within each batch; one multi-panel figure counts once. The mix is a concrete collection target, not an instruction to reconstruct inaccessible images or run software here.

## Existing baseline and display routes

All38 analysis routes remain partial:34 have some direct evidence and4 have only transferable evidence. Three display/annotation routes are transferable-only; the two self-test utilities do not count as methods or research figures. Counts below are **record associations**, not complete figure-type coverage.

| Module | Direct records | Transferable records | Archived unresolved scope |
|---|---:|---:|---|
| deseq2-wald | 8 | 11 | modern shrinkage backends, Cook outlier and independent-filter diagnostics 0052 does not establish current-version null calibration or runtime validation; historical per-method missing-P denominator details unresolved. 0059 proxytruth precision not actual present-version FDR; zero-call code and versions unavailable. 0065 is a 2014 NB simulation comparison, not present-version or all-design validation. 0069 is historical proxy-truth sensitivity evidence; exact modern method configurations and source benchmark empty-set handling not fully recovered. |
| deseq2-qc | 3 | 24 | PCA native reference figure; transformation choice/version-specific validation |
| deseq2-lrt | 1 | 10 | Fitted NB mean/uncertainty and design-matrix diagnostic reference figures remain. Baseline time variables are factor-coded; continuous-time/spline inference is not currently supported. |
| edger-qlf | 1 | 18 | edgeR-specific BCV/QL dispersion and QLF test diagnostics 0037 is 2012 NB GLM, not modern robust/new QL null calibration; paired MDS and exact QL test still incomplete 0065 historic edgeR/robust benchmark is not modern QLF direct evidence. 0069 is historical proxy-truth sensitivity evidence; exact modern method configurations and source benchmark empty-set handling not fully recovered. |
| limma-voom | 7 | 22 | observation-weight schematic, sample-quality weights, repeated-subject precision modeling 0065 is a 2014 NB simulation comparison, not present-version or all-design validation. 0069 is historical proxy-truth sensitivity evidence; exact modern method configurations and source benchmark empty-set handling not fully recovered. |
| limma-array | 1 | 19 | array preprocessing provenance and sample QC modern robust/trend moderation diagnostics and effect interval specification 0063 OmicScope design transfer, not exact package-specific method validation. |
| limma-dupcor | 2 | 17 | repeated-subject block correlation, consensus correlation and within-subject contrasts 0038 is technical within-array spots, not modern repeated-subject voom validation; gene correlation and two-round diagnostics remain 0039 is comparative repeated-subject application; dream absent baseline, exact four-region sum contrast and source B/C P inconsistency unresolved |
| sva-batch | 3 | 4 | ComBat prior/posterior source figures sample-level PCA native source figure modern IRW implementation validation not established by 2007 original figure 0229/0230 add direct ComBat-seq and SVASeq simulation design; exact DE cutoff/source-code runtime replication remains unverified. |
| clusterprofiler-ora | 2 | 14 | direct package figure and universe/ID-mapping diagnostics 0058 is ArchR design transfer only; not direct RNA pseudobulk or clusterProfiler validation. 0063 OmicScope design transfer, not exact package-specific method validation. 0071 directly covers custom enricher/cnet example only; ROI-to-gene is not a baseline routed module, historical defaults and full ORA methods remain partial. 0073 supports metric/selection/rank-direction design; exact historical backend/defaults and every collection not covered. |
| clusterprofiler-gsea | 1 | 15 | direct clusterProfiler implementation figure native leading-edge and negative-NES/tie display verification; running-ES grammar now has transferable GSEApy evidence 0073 supports metric/selection/rank-direction design; exact historical backend/defaults and every collection not covered. |
| clusterprofiler-compare | 1 | 12 | prespecified list comparisons with common universe and missing-test states 0058 is ArchR design transfer only; not direct RNA pseudobulk or clusterProfiler validation. 0063 OmicScope design transfer, not exact package-specific method validation. 0068 is a descriptive six-set display demonstration, not a validation of cross-list ORA differences; no baseline UpSet implementation or full coverage claimed. 0072 direct compareCluster example, not a time interaction model; source blank-state/experimental-control details partial, no all-method coverage. |
| fgsea-prerank | 0 | 12 | fgsea-specific multilevel/log2err primary figure negative-NES native-leading-edge display; GSEApy sample-permutation figure is not direct fgsea evidence 0073 supports metric/selection/rank-direction design; exact historical backend/defaults and every collection not covered. |
| gsva-score | 7 | 10 | GSVA/ssGSEA-specific heatmap original pixels, score variant diagnostics, fixed-reference cohort sensitivity |
| limma-camera | 2 | 2 | direct barcode/worm pixels, ROAST rotation inference detail, mixed direction and correlation diagnostics 0039 is comparative repeated-subject application; dream absent baseline, exact four-region sum contrast and source B/C P inconsistency unresolved |
| scanpy-qc | 1 | 19 | modern sample-aware filtering/doublet QC source figures; exact historic percent_mito conversion not recovered 0061 ATAC metrics/thresholds are not RNA module validation; transfer design only. |
| scanpy-cluster | 1 | 31 | Leiden/UMAP modern direct source evidence HVG flavor/batch variants and neighbours stability 0054 uses Louvain/PAGA, not baseline Leiden; no direct modern Leiden stability reference or runtime computation yet. 0060 is PAGA design transfer; no baseline PAGA/geodesicKL implementation or present-version validation established. 0067 applied Scanpy1.5.1/Louvain context; not all current clustering or projection parameters validated; source kNN labelling not baseline ingest functionality. 0070 PAGA random-partition null is not a calibration of baseline Leiden clusters; no PAGA or graph-null calculation currently established. |
| scanpy-markers | 6 | 5 | rank_genes_groups native test/reference diagnostics exact historic violin expression transform not recovered 0067 applied Scanpy1.5.1/Louvain context; not all current clustering or projection parameters validated; source kNN labelling not baseline ingest functionality. |
| scvi-integrate | 5 | 9 | training diagnostics and posterior uncertainty native figures not yet directly studied; not all scvi-tools methods covered 0060 is PAGA design transfer; no baseline PAGA/geodesicKL implementation or present-version validation established. 0062 scCODA HMC is not baseline scVI variational or propeller inference; diagnostic display transfer only. |
| scanpy-annotate | 0 | 19 | explicit unknown/ambiguous labels and marker-panel completeness 0064 is transferable Squidpy display evidence only; exact package held-out calibration and independent truth remain incomplete. 0067 applied Scanpy1.5.1/Louvain context; not all current clustering or projection parameters validated; source kNN labelling not baseline ingest functionality. |
| scanpy-purity | 0 | 6 | display-only island removal/purity and before/after original cohort preservation |
| scanpy-ingest | 0 | 16 | ingest-specific fixed-reference position invariance and mapping uncertainty 0067 applied Scanpy1.5.1/Louvain context; not all current clustering or projection parameters validated; source kNN labelling not baseline ingest functionality. |
| scanvi-annotate | 4 | 17 | scANVI-specific calibration/open-set unknowns, held-out labels 0030 is integration benchmark evidence, not full native algorithm/annotation uncertainty coverage. Held-out calibration and cross-dataset unknown classes remain unreviewed. 0064 is transferable Squidpy display evidence only; exact package held-out calibration and independent truth remain incomplete. |
| seurat-qc | 0 | 20 | mitochondrial/gene-count filtering and doublet plots 0061 ATAC metrics/thresholds are not RNA module validation; transfer design only. |
| seurat-cluster | 5 | 21 | Seurat graph/clustering resolution and PCA/HVG direct diagnostics 0060 is PAGA design transfer; no baseline PAGA/geodesicKL implementation or present-version validation established. |
| seurat-integrate | 1 | 13 | modern HarmonyIntegration version-specific diagnostics multiple-covariate and nonoverlapping-celltype validation figures convergence and independent-label metrics implementation 0056 is Harmony on ATAC-LSI, not modern Seurat RNA API validation; source matrix normalization and exact parameters unresolved. 0060 is PAGA design transfer; no baseline PAGA/geodesicKL implementation or present-version validation established. |
| seurat-markers | 6 | 5 | current FindAllMarkers grouping and gene-selection validation exact native test-specific marker figures and conserved-marker meta-analysis not implemented |
| seurat-modulescore | 1 | 15 | Original 2016 supplement score details and final-version pixel equivalence unverified; modern AddModuleScore control-subtraction definition checked in official documentation. Control gene identities/cohort sensitivity and k=true method diagnostics remain. |
| scater-qc | 0 | 26 | scater-specific per-sample QC thresholds and missing metrics 0061 ATAC metrics/thresholds are not RNA module validation; transfer design only. |
| scran-cluster | 2 | 18 | modern modelGeneVar biological variance decomposition bluster graph clustering-specific diagnostic native small-cluster and factor validity behavior not dynamically verified |
| batchelor-integrate | 1 | 7 | fastMNN correction vectors, merge order and batch-specific effect diagnostics 0030 is integration benchmark evidence, not full native algorithm/annotation uncertainty coverage. |
| scran-markers | 5 | 4 | scran pairwise marker aggregation and direction/test semantics |
| aucell-score | 1 | 14 | native recovery-curve and gene-count QC figure remain; no claim that SCENIC network inference is implemented or all AUCell functions covered |
| singler-annotate | 1 | 17 | SingleR delta score, pruning and reference/test label heatmaps 0040 original method; modern pruning and pre/post tune outputs need targeted fixtures; no full package coverage 0064 is transferable Squidpy display evidence only; exact package held-out calibration and independent truth remain incomplete. |
| muscat-pseudobulk | 1 | 12 | Benchmark error control and alternative DS distributions not visually read. Exact Figure4 MDS settings and score scaling scope not recovered. Not all module output plots reviewed. 0058 is ArchR design transfer only; not direct RNA pseudobulk or clusterProfiler validation. |
| speckle-propeller | 5 | 22 | simulation calibration and mean-variance source figure current baseline group-only; complex designs require new analysis capability outlier/transform sensitivity not run 0053 source uses additive age+sex design unavailable in baseline group-only entry; actual count and proportion-derived pseudo-count provenance remain distinct. 0055 is scCODA reference sensitivity, not direct propeller support; Bayesian reference effects/HDI remain outside baseline module. 0057 historical benchmark does not establish current-version calibration; Monte Carlo uncertainty and final annotation code unavailable. 0062 scCODA HMC is not baseline scVI variational or propeller inference; diagnostic display transfer only. 0066 adds rare-class/denominator benchmark, not modern-version or all-design calibration; mean-variance direct diagnostic remains. |
| cellchat-communication | 0 | 5 | direct CellChat topology/edge meaning and communication probability; official candidate navigation dismissed |
| monocle3-trajectory | 1 | 12 | Moran graph-associated gene result figure current native root coverage and 3D rendering behavior not dynamically tested |
| slingshot-trajectory | 3 | 9 | Slingshot benchmark and uncertainty figures not visually reviewed. tradeSeq gene association plots not covered by this source. |
| wgcna-network | 4 | 8 | module preservation, TOM dendrogram and signed/unsigned sensitivity |
| maftools-landscape | 1 | 2 | direct TMB/callable-territory figure and variant summary not yet covered; CoMEt/driver/clinical panels are prospective extensions, not baseline support |
| immunedeconv-infiltration | 5 | 7 | EPIC/ABIS/ConsensusTME/ESTIMATE original method figures CIBERSORT full original method validation MCP-counter current signature version versus 2016 complete set 0228 adds xCell direct correlation validation, not absolute proportion calibration or all package functions. 0246/0247 add quanTIseq external fraction agreement and TIMER display/model separation; current backend versions and full callable options remain unaudited. |

Fill each baseline route by first collecting4 exact current-method source figures for its listed missing diagnostics, then expand each active figure family to20 independently counted records. Prioritize DESeq2 filtering/shrinkage; modern edgeR robust/new QL; limma observation/sample-quality/repeated-block weights; propeller donor/contrast scope; SingleR fine-tune/pruning; trajectory root/partition/lineage; integration biology/unique populations; infiltration native-unit validation. Use at least2 independent datasets/papers per diagnostic rather than repeatedly sampling panels from one paper.

## Five development modules — still separate from production

### drc-dose

Archived status: partial_direct_method_evidence; direct/related IDs: 0082, 0272; transferable IDs: 0259, 0266, 0269.

- residual diagnostics, multiple curves/relative potency, interval alternatives and real-data non-identifiability diagnostics remain partial

Concrete fill: Collect18 more independent dose-curve records to complement0082/0272:6 zero/log dose and multi-curve examples,6 ED/relative-potency and uncertainty,6 non-identifiability/residual/influence examples; include at least4 exact native drc method/application figures.

### lme4-lmm

Archived status: partial_direct_method_evidence; direct/related IDs: 0081, 0098, 0135, 0136, 0198; transferable IDs: 0091, 0103, 0118, 0120, 0121, 0122, 0137, 0196, 0202, 0205, 0206, 0207, 0209, 0211, 0215, 0226, 0227, 0240, 0241, 0258, 0259, 0262, 0266, 0269, 0287.

- 0098 covers raw subject facets and distinguishes separate OLS from mixed-model predictions; actual marginal/conditional prediction intervals remain uninspected
- singular-fit visualization and model residual diagnostics remain partial; 0081 supplies profile boundary contracts only
- 0103 supplies study-level meta-regression diagnostics, not implemented subject-deletion LMM diagnostics.
- 0118 supplies published repeated-measure mean geometry, but original error-bar type and prediction marginalization are not fully specified; not runtime validation.
- 0121 supplies basis-invariance diagnostic contract; multivariate response/residual covariance and conditional predictions not implemented or runtime-verified by this evidence.
- 0135 documents profile-density semantics and font rendering; no runtime profile implementation or current-version numerical validation.
- 0198 adds direct lme4 conditional prediction geometry and re.form provenance; actual conditional interval implementation remains uninspected/runtime-unverified.
- Records through0210 add transferable statistical design only; they do not establish current package implementation, all-functions coverage, or runtime validation.
- 0215 provides interval-family/grid and joint-covariance contrast design, not a fitted lme4/emmeans example or current runtime verification.

Concrete fill: Collect15 more exact-method figures beyond the5 direct records:5 conditional/population/new-subject prediction/interval cases,5 singular/convergence/profile boundary cases,5 row-linked residual/influence/subject-facet cases. Other model curves are transfer only.

### emmeans-contrast

Archived status: partial_related_method_family_evidence; direct/related IDs: 0091, 0092; transferable IDs: 0093, 0101, 0118, 0120, 0122, 0132, 0147, 0196, 0202, 0206, 0215, 0226, 0240, 0258, 0260, 0262, 0266, 0275, 0284, 0287.

- Evidence is 2016 lsmeans method-family paper, not a verified current emmeans plot run.
- Current development9d57ed0 restricts categorical factor/by; Figure1 numeric reference-grid example is outside implemented scope.
- Current emmeans marginal-means versus contrast adjustment, estimability, scale and numerical outputs remain runtime-unverified.
- 0092 ordinary-lm rank-deficiency example is outside current lmerMod-only module; design/reporting evidence, not runtime coverage.
- 0118 supplies published repeated-measure mean geometry, but original error-bar type and prediction marginalization are not fully specified; not runtime validation.
- Records through0210 add transferable statistical design only; they do not establish current package implementation, all-functions coverage, or runtime validation.
- 0215 provides interval-family/grid and joint-covariance contrast design, not a fitted lme4/emmeans example or current runtime verification.

Concrete fill: Collect20 current emmeans figures;0091/0092 are related2016 lsmeans-family evidence. Split into6 reference-grid/weights/response-scale,6 mean versus adjusted contrast CI/family,4 nonestimability,4 repeated-subject covariance-aware contrasts. Existing lmerMod/categorical restrictions remain.

### proda-diff

Archived status: transferable_design_only; direct/related IDs: none; transferable IDs: 0063, 0187, 0188, 0201, 0254, 0263.

- missingness/dropout mechanism and probabilistic differential abundance
- 0063 supplies protein-scale/spike-in display only; neither package method directly studied.
- Records through0210 add transferable statistical design only; they do not establish current package implementation, all-functions coverage, or runtime validation.

Concrete fill: Collect20 direct proDA figures:6 probabilistic dropout/missingness versus intensity,6 differential abundance/effect uncertainty,4 spike-in truth and tested denominator,4 comparison of missingness modeling versus imputation. Do not substitute mice or generic protein plots.

### msstats-diff

Archived status: transferable_design_only; direct/related IDs: none; transferable IDs: 0063, 0187, 0188, 0201, 0254, 0263.

- feature-to-protein summarization, missing values and group comparison intervals
- 0063 supplies protein-scale/spike-in display only; neither package method directly studied.
- Records through0210 add transferable statistical design only; they do not establish current package implementation, all-functions coverage, or runtime validation.

Concrete fill: Collect20 direct MSstats figures:6 feature/run/protein summaries,6 biological/technical replicate and contrast/effect uncertainty,4 missingness/censoring,4 normalization/QC with original IDs. Confirm exact version/model; no generic grouped plot counts as method coverage.

## Planned P1–P3 figure types below20 records

The table below is deliberately per emitted/planned figure family, checked against PR57 module.json.figure_builders and the frozen plan. Counts list only explicitly reviewed type candidates; they are conservative, not an exhaustive recoding of302 panels. Where one row lists multiple subtypes, **each subtype independently needs the stated additional number**; candidate IDs must be inspected for that subtype before credit. Exact-method coverage is separate from transferable geometry. The complete machine-readable table is [planned-figure-gaps.json](analysis/planned-figure-gaps.json).

For every family, collect at least20 independent eligible figures, including at least4 exact-method sources and4 independent applications across at least2 datasets. Prioritize native original methods/validation papers, then independent applications with complete captions/methods and explicit units. Do not use modern package defaults to fill historical unknowns.

| Module / package | Figure types (each) | Existing candidate IDs; direct subset | Additional per type | Kinds of sources / boundary |
|---|---|---|---:|---|
| omicstat-groupcompare (P1-1) | biological-unit box/raw points with supplied comparisons | 0002, 0005, 0009, 0013, 0053, 0096, 0113, 0116, 0173; direct: none | 11 | Original biological-replicate comparison figures, paired designs, technical-well aggregation examples and small-n reporting. Transferable display evidence only; no direct OmicStat inference validation. |
| omicstat-ddct (P1-2) | delta-Ct biological-unit points; fold-change reference-normalized points/intervals | none; direct: none | 20 | Original Livak-style qPCR methods plus applications with technical/biological counts, reference gene/calibrator and Ct-scale inference. Generic grouped points do not establish delta-Ct versus fold-change semantics. |
| drc-calibrate (P1-3) | 4PL/5PL standard curve with LLOQ/ULOQ; back-calculated unknown-sample interval | none; direct: none | 20 | Original assay-validation/calibration studies with certified standards, inverse predictions and independently established LLOQ/ULOQ. 0082/0272 dose-response can guide log/zero layout only, not calibrated limits or inverse uncertainty. |
| nlme-dose (P1-4) | subject-conditional dose curves; typical/population dose curve versus descriptive means | 0082, 0098, 0198, 0287; direct: none | 16 | Original repeated-dose nlme applications and nonlinear mixed-model methods with subject IDs, residual structure and population/conditional predictions. These four records transfer geometry; none verifies the planned nonlinear model/assay estimand. |
| survival-expr (P1-5) | KM with aligned risk table | 0005, 0006, 0089, 0247, 0283; direct: none | 15 | Original survival/expression studies with exact time/event definitions, censor marks, low-risk tails, fixed cutpoints and complete native risk rows. Do not count CIF-only/dynamic-state curves as additional KM records. |
| survival-expr (P1-5) | Cox HR forest | 0090, 0110; direct: none | 18 | Original Cox methods/applications reporting exact effect increments/references, covariates, PH checks and analysis events. Ratio/difference/meta forests elsewhere are related geometry, not interchangeable Cox evidence. |
| glmnet-coxsig (P1-6) | time-dependent ROC | none; direct: none | 20 | Original timeROC/IPCW and frozen Cox-signature validations, with evaluation horizon, risk sets, censoring estimator and train/test units. 0095/0104/0172 are generic ROC design, not audited time-dependent ROC records. |
| glmnet-coxsig (P1-6) | coefficient path | 0252; direct: none | 19 | Original penalized Cox/glmnet methods and applications with lambda grid, coefficient scale and frozen model selection. 0252 is general glmnet, not exact current Cox-signature validation. |
| glmnet-coxsig (P1-6) | CV loss and min/1SE selection companion | 0154; direct: none | 19 | Original glmnet/Cox CV studies with fold identity, error-bar type, feature selection inside folds and independent validation. One general glmnet CV figure does not establish all Cox loss types. |
| glmnet-coxsig (P1-6) | KM frozen-risk groups | 0005, 0006, 0089, 0247, 0283; direct: none | 15 | Original frozen-risk signature validation with same coefficients/cutpoint transferred to independent cohorts. KM design transfer is not evidence that the signature or cutpoint was frozen. |
| shared os_calibration (P0-5; possible survival consumer) (P1-5/6 support) | calibration with bin support/intervals | 0087, 0107, 0172, 0191; direct: none | 16 | Original survival/binary calibration methods with bin counts, censoring/competing-event estimator and independent evaluation. Module registry currently lists no calibration output for glmnet-coxsig; distinguish planned shared capability from actual emitted figure. |
| reactomepa-ora (P1-7) | ORA dotplot | 0007, 0071, 0072, 0073; direct: none | 16 | ReactomePA/Reactome original methods and applications with release, organism, tested universe, k/n and multiple-test family. All four are transferable enrichment layout; no exact ReactomePA record. |
| singler-annotate (P1-8) | relative/raw score heatmap; cluster-label count matrix; delta/pruning confidence companion | 0040; direct: 0040 | 19 | Original SingleR/celldex methods and independent reference applications with native fine-tuning/pruning, label ontology and missing classes. 0040 is direct SingleR evidence but one figure cannot cover every one of these types. |
| dropletutils-emptydrops (P1-9) | barcode-rank/knee diagnostic | 0238; direct: 0238 | 19 | Original EmptyDrops/DropletUtils figures with raw barcode universe, rank ties/knee/inflection and native tested/forced states. Other EmptyDrops records cover different quantities; do not borrow them into this type count. |
| dropletutils-emptydrops (P1-9) | ambient likelihood/P-FDR and calls; FDP/recall validation companion | 0239, 0256; direct: 0239, 0256 | 18 | Original EmptyDrops methods and independent raw-droplet applications with forced retention, MonteCarlo P and complete eligible barcode universe. Two direct-method records are related type support; validate each displayed panel before using either for a specific subtype. |
| scdblfinder-doublets (P2-1) | doublet score/status by capture | none; direct: none | 20 | Original scDblFinder methods plus truth-labelled multiplexing applications, capture-specific priors and annotation-only outputs. Generic classifier evidence does not cover native doublet thresholds. |
| celda-decontx (P2-2) | estimated contamination fraction; raw-versus-corrected totals | none; direct: none | 20 | Original decontX/celda methods and independent ambient-RNA mixtures with known controls, clustering assumptions and native correction scale. No exact ambient correction figures in corpus. |
| soupx-ambient (P2-2) | prespecified/estimated contamination fraction; raw-versus-corrected totals | none; direct: none | 20 | Original SoupX methods/applications with empty-droplet background, manual versus automatic rho and unrounded corrected totals. Manual rho is not inferred contamination or necessarily realized removed fraction. |
| decoupler-activity (P2-3) | signed activity heatmap | 0019; direct: none | 19 | Original decoupleR methods with method/resource/sign/coverage, independent perturbations and biological replicates. 0019 Holland2020 informs activity/perturbation semantics but not decoupleR current implementation. |
| celltypist-annotate (P2-4) | class-probability/confidence points | 0031, 0083; direct: none | 18 | Original CellTypist methods and external-label applications with model hash, majority voting, unknown classes and probability calibration. Both IDs transfer from other annotation methods; no direct CellTypist evidence. |
| liana-lr (P2-5) | consensus-rank display | none; direct: none | 20 | Original LIANA consensus methods and sample-resolved applications with method universe, eligibility, ties and per-sample aggregation. CellChat/network layouts cannot stand in for LIANA rank semantics. |
| tximport-import (P2-6) | import-library/offset diagnostic | none; direct: none | 20 | Original tximport/tximeta methods and offset-aware DE applications with transcript-to-gene mapping, abundance/count/length scale. No transcript-import figure evidence. |
| infercnv-cnv (P3-1) | chromosome-centered expression/CNV summary | none; direct: none | 20 | Original inferCNV methods/applications with normal references, chromosome boundaries, smoothing and relative-expression versus integer-CN separation. No direct CNV source; avoid interpreting inferred signals as measured copy number. |
| copykat-cnv (P3-1) | relative CNV chromosome means | none; direct: none | 20 | Original CopyKAT methods and independently validated tumor/normal CNV applications with baseline, reference and segment boundaries. Generic heatmaps cannot establish CopyKAT scale/accuracy. |
| scvelo-velocity (P3-2) | spliced-unspliced phase portrait | none; direct: none | 20 | Original scVelo dynamical/steady-state methods and applications with layer units, gene fit, uncertainty and projected-vector scaling. 0009 is velocyto.R0.6, not scVelo; it is not a phase portrait record. |
| cellrank-fate (P3-2) | terminal-state fate probability | none; direct: none | 20 | Original CellRank methods and lineage-tracing applications with explicit terminals/kernel, row-sum and missing/unreachable states. 0009 transition probabilities use velocyto and do not validate CellRank fate estimands. |
| nichenetr-lr (P3-3) | ligand-prior agreement/activity; ligand-target potential companion | none; direct: none | 20 | Original NicheNet methods/applications with response/background universes, resource release, scoring metric and independent perturbations. Actual PR module is nichenetr-lr; plan shorthand nichenet-lr is not the code path. |
| squidpy-spatial (P3-4) | native physical expression map | 0011, 0064, 0079; direct: 0011, 0064, 0079 | 17 | Original Squidpy methods and independent spatial studies with native units/orientation/spot calibration and exact display layers. These are direct Squidpy source figures but panels differ; none validates all current coordinate/backend paths. |
| seurat-spatial (P3-4) | native physical expression map | 0011, 0064, 0079; direct: none | 17 | Original Seurat spatial/Visium methods and independent histology-aligned applications with spot/scale-factor provenance. The same three Squidpy figures are transferable only for Seurat, not direct method evidence. |
| spatial prospective extensions (P3-4 support) | histology registration/scale bars; spatial co-occurrence; LR dotplot/nuclei density | 0011; direct: none | 19 | Original coordinate-calibrated spatial methods with actual histology, physical radius/area denominator, specimen counts and permutation LR semantics. These types are not implemented by PR33 scatter; inspect and classify each panel separately. |
| minfi-array (P3-5) | beta-value/distribution diagnostic | none; direct: none | 20 | Original minfi/array methylation methods and applications with probe/sample QC, beta versus M values and batch roles. No exact methylation records. |
| dss-dmr (P3-5) | DML/DMR effect/coverage diagnostic | none; direct: none | 20 | Original DSS methods/applications with read depth, methylated/total counts, smoothing, genomic build and CpG/region denominators. No exact DSS source; generic DE volcano conventions are insufficient. |
| diffbind-peaks (P3-6) | complete eligible peak effects | none; direct: none | 20 | Original DiffBind methods/applications with consensus peaks, biological units, raw counts/normalization and contrasts. 0021 is ArchR, not DiffBind; no direct evidence. |
| chipseeker-annotate (P3-6) | nearest-TSS distances/annotation | none; direct: none | 20 | Original ChIPseeker methods and genomic applications with strand/build/coordinate convention/ties/annotation hierarchy. Nearest gene is not causal target; no direct evidence. |
| signac-atac (P3-6) | LSI coordinate display | none; direct: none | 20 | Original Signac methods and independent ATAC studies with TF-IDF/SVD convention, fragment verification and biological n. 0017/0021/0056/0058/0061/0076/0080 are ArchR/ATAC transfer, not native Signac LSI evidence. |

## Acquisition and qualification protocol for the next evidence owner

1. Build a candidate ledger per figure type, with DOI/figure key, exact method/version, dataset and direct versus transferable scope. Reserve at least4 source-specific records for each unresolved statistical issue.
2. Read the original figure/caption/applicable methods together; record actual visual inspection, quantity/units/denominator, independent unit, transform, uncertainty, missing/failure states and contradictions. One figure remains one global record even if it informs several modules.
3. Preserve limits: raw score is not probability; velocyto0009 is not scVelo/CellRank; ArchR is not Signac/DiffBind; lsmeans is not current emmeans; CellChat design does not establish LIANA/NicheNet. A paper/package match alone is not proof of the same figure subtype or current runtime.
4. Respect archived access gaps and denials; do not retry blocked/CAPTCHA/IDP sources or obtain alternate copies to bypass them. Select independently accessible original sources. The caption/asset conflict for Chan g004 remains unqualified until genuinely resolved.
5. Store metadata/observations and original source links, not publisher images in the repository. Keep source hashes where available and label unavailable hashes honestly.
6. Rebuild unique DOI/figure counts and per-type coverage;0242 stays companion. Keep evidence_refs pending below20 and retain exact-method gaps even if transferable total reaches20. Numerical/visual acceptance is a separate exec/owner activity after code changes.

## Archive integrity versus scientific uncertainty

All302 files and1,278 proposal entries are present at frozen evidence SHA64a3319 and all indexed record hashes were verified in this task. FINAL-SUMMARY.md still says32 records await upload; that publication paragraph is stale relative to the actual frozen Git tree, not an evidence shortfall. Historical source conflicts (units,588/389 cases, algorithm defaults,100/10 repeats and interval definitions) remain in record_registry and source-gaps; no source contradiction was silently repaired.
