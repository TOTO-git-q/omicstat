# PACK — wgcna-network

S0 evidence and an S1 draft. This version is the redo after the independent verification of 2026-09-29 (`docs/build/S0_REDO_lane_b.md`); `verification.json` is reserved for the verifier.

| Layer | Evidence |
|---|---|
| L1 | WGCNA **1.74** from the dated CRAN 2026-09-15 source snapshot. Nine core function Rd files, 132 parsed argument defaults, DESCRIPTION, CITATION and per-file/source SHA-256 in `L1_cran2026-09-15/`. The source tarball has no NEWS or vignette; absence is recorded. |
| L2 | Langfelder–Horvath method article PMC2631488; the authors’ female-liver tutorial PDF parts 1–3, R scripts and FAQ, from a commit-pinned third-party reupload with per-file hashes. The PDFs are rendered as text including printed output. These are not claimed to be bundled with 1.74 or cryptographically identical to the unavailable UCLA host. |
| L3 | Ten tier-A Methods readings, nine applicable to gene-expression networks (`literature/l3_notes.md`). |
| L4 | Thirty licensed open-access, PubMed-echoed articles. **23/30 applicable** to direct gene-expression WGCNA analysis. |

## T — table skeleton

Keep one row per gene with module label (including unassigned/grey), module eigengene membership, within-module connectivity, gene-trait significance and hub rank where calculated. Keep a module table with module size, eigengene, trait correlation, raw P, adjusted P, merge history and stability/preservation measures if requested. A sample table carries biological sample ID, expression preprocessing, trait values, outlier decision and its reason. Preserve all genes/modules; any highlighted hubs are a display subset.

## F — figure grammar

Plot sample clustering/outlier diagnostics before network construction. Show scale-free fit and mean connectivity across the tested soft powers, marking the selected power and its reason. Plot the gene dendrogram with module colors and a module–trait heatmap that labels the sample denominator and correction policy. A hub network or ranked-gene panel must show the ranking definition and display threshold. Signedness, correlation choice and data transform belong in figure captions.

## W — wording

Methods template: “A samples × genes expression matrix (`<normalization/transform>`) from `<n>` biological samples entered WGCNA v1.74. We checked missing genes/samples with `goodSamplesGenes` and handled outliers by `<documented rule>`. `pickSoftThreshold` examined `<power vector>` with a target scale-free fit of `<criterion>`; the selected power `<beta>` was used by `blockwiseModules` with `networkType=<...>`, `corType=<...>`, `TOMType=<...>`, `minModuleSize=<...>`, `deepSplit=<...>` and `mergeCutHeight=<...>`. Module eigengenes were associated with `<traits>` using `<test/correction>`, and hubs were ranked by `<metric>`.” Results template: “`<n>` modules contained `<range>` genes; `<named module>` associated with `<trait>` at `<effect, P, adjusted P>`. `<n>` genes met the stated hub criterion.” A correlation network is exploratory association; do not call a module or hub a causal regulator without separate evidence.

## V — variant frequencies

Redo after independent verification (2026-09-29): all 30 Methods were re-read and every parameter stated in a network sentence was extracted from that same sentence; counts below are recomputed from `extraction.jsonl`.

Denominator: **23 applicable / 30 corpus**; M4 ecosystem is **n/a for all 30**. Seven exclusions are two hdWGCNA-only analyses, a DiffCoEx mention, reuse of pre-existing modules, MEGENA chosen instead, a plasma-protein network, and a longitudinal protein/mixed-feature network without an isolated gene-expression recipe. PMC9907105 explicitly runs WGCNA as a comparator and remains applicable, but its comparator settings cannot define a general default. The direct bulk WGCNA arm of PMC13469711 is applicable; its hdWGCNA arm is not counted. PMC9873574 uses WGCNA only to select technical covariates and carries no network settings.

| Variant or reporting fact | Applicable count (n=23) | Not reported / no usable criterion |
|---|---:|---:|
| Selected soft power | 12/23; 5, 8, 10 each 2; 1, 4, 6, 7, 14, 15 each 1 | 11/23 |
| Explicit signed network | 9/23 (signed in 9/9 that state network type) | 14/23 do not state signedness |
| Network correlation type | biweight midcorrelation 4/23 (one adds `maxPOutliers = 0.05`); Pearson 1/23 | 18/23; downstream Pearson correlations of eigengenes with traits are kept separate |
| Minimum module size | 9/23; 10 in 2 (one is the comparator), 30 in 2, 15/20/40/50/200 each 1 | 14/23 |
| `deepSplit` | 4/23; 2 in 2, 4 in 2 | 19/23 |
| Merge threshold | 8/23: heights 0.25 in 2, 0.2 in 1, 0.1 in 1, MEDissThres 0.3 in 1; eigengene-correlation form 0.75 in 2, 0.85 in 1 | 15/23 |
| Scale-free fit target | numeric 4/23 (0.8 in 2, 0.85 in 1, 0.9 in 1); criterion named without a threshold 4/23 | 15/23 |
| Exact `TOMType` | unsigned 1/23 (comparator) | 22/23 |
| Expression input described | 18/23: unit or transform named in 7 (rlog, vsd, VST, FPKM, TPM, RPKM, log2 CPM residuals), generic "normalized" counts/matrix in 3, gene selection or filtering only in 8 | 5/23 |
| Sample outlier handling | 11/23 describe a method or rule; numeric threshold in 5/23 (3 SD network connectivity, 2.5 SD network connectivity, 2.5 SD PC1/PC2, standardized connectivity < -2, 3 SD PCA ellipse); `goodSamplesGenes` used in 2, stated as not used for RNA-seq in 1 | 12/23 |
| Module eigengene/trait analysis explicitly described | 13/23 | 10/23 |
| Named hub ranking basis | 4/23: module membership 2 (one with cutoff 0.85 and a gene-significance rank), edge-count permutation 1, modular gene centrality 1 | 19/23 |
| `maxBlockSize`, `reassignThreshold`, `pamRespectsDendro` | 0/23 each | 23/23 each |
| Package version | 5/23: 1.64 (1), 1.71 (1), 1.72.1 (1), 1.73 (2) | 18/23; a paper's "4.3.3" is inconsistent and excluded |

No reported value exceeds half of the 23 applicable papers. "Signed" is the only network type ever stated (9/9 stating one); this is **not** a corpus majority (9/23 = 39%). Power 5, 8 and 10 tie for most common reported value, each only 2/23. Merge and outlier criteria come in incompatible forms (heights versus correlations, standard deviations of different statistics) and cannot be pooled or transferred between studies. The earlier version of this pack under-counted deepSplit (3), merge (3), minimum module size (7) and signed networks (5) because parameters in the same sentence were only partly extracted.

## C — replay and printed anchor

Registry #31 is resolved as a **TLS-verified, commit-pinned third-party mirror** of the authors’ FemaleLiver tutorial ZIP: `FemaleLiver-Data.zip`, SHA-256 `bd4c9d182e7a47bba1bf2a6eb94f4c47c30eab64e3f002520b3a8aaf5cf57d17`. `unzip -t` passed. It contains `LiverFemale3600.csv` (3,600 data rows, 143 columns including metadata and 135 samples), `ClinicalTraits.csv` (361 data rows, 38 columns) and `GeneAnnotation.csv` (23,388 data rows, 34 columns). The tutorial PDF explicitly says the selected expression set contains 135 samples. These file structure facts are input assertions; the ZIP hash identifies the mirror bytes only. The original UCLA server’s expired certificate prevents a byte-for-byte provenance comparison.

The pinned tutorial part 2 prints a `blockwiseModules` example with power 6, unsigned TOM, minimum module size 30, reassignment threshold 0 and merge height 0.25. It prints 18 assigned modules ranging from 34 to 609 genes, plus label 0 with 99 unassigned genes (19 labels in the printed table; PDF rendered lines 149–153). Those outputs are historical tutorial reference values, **not** exact numeric assertions for WGCNA 1.74 until the locked runtime executes the same full recipe and environment. Part 3 computes module–trait correlations and `corPvalueStudent`. A replay fixture should first assert the ZIP hash, table dimensions and sample/gene orientation, then record locked-runtime outputs and any accepted differences with a justified comparison rule. A soft-power fit cutoff is a model-selection target, not a replay tolerance.

## D — function default / guide / exemplar evidence

L1 defaults are from WGCNA 1.74 Rd usage. The tutorial is L2 and older; its numeric values describe one liver dataset, not a function rule. Frequencies use 23 applicable papers.

| Parameter (profile) | Function default, locked 1.74 | Pinned tutorial / guide | Exemplar evidence (n=23) | S1 draft |
|---|---|---|---|---|
| Input expression (D-WG1) | `datExpr` required, samples × genes | female liver expression matrix, 135 samples × 3,600 genes after input selection | 18 describe an input (7 name a unit or transform, 3 say "normalized", 8 give only a gene filter or selection); 5 not reported | Require transform, filter, orientation and sample IDs |
| Sample outlier rule (D-WG2) | `goodSamplesGenes(minFraction=1/2)` checks missingness; no automatic biological outlier cutoff | sample clustering and manual review | 11 describe a method or rule; numeric threshold 5; 12 not reported | Document method and exclusions; no universal cutoff |
| Soft power (D-WG3) | `blockwiseModules(power=6)`; `pickSoftThreshold` evaluates supplied vector | liver example uses 6 after fit plot | 12 reported, 11 not; 5/8/10 tie at 2 each | Select from dataset fit and connectivity, record vector |
| Scale-free fit (D-WG4) | `pickSoftThreshold(RsquaredCut=0.85)` | guide examines fit and mean connectivity | numeric 0.8 in 2, 0.85, 0.9; qualitative criterion in 4; 15 not | Treat as diagnostic target with fallback justification |
| Network type (D-WG5) | `blockwiseModules(networkType="unsigned")` | liver example leaves default; FAQ discusses signed networks | signed 9; 14 not | Expose signed/unsigned; justify selection |
| Correlation (D-WG6) | `blockwiseModules(corType="pearson")` | `cor` used for eigengene–trait matrix | biweight midcorrelation 4; Pearson 1; 18 not | Pin/record network correlation separately from trait correlation |
| TOM type (D-WG7) | `blockwiseModules(TOMType="signed")` | liver example sets `"unsigned"` | unsigned 1 comparator; 22 not | Explicitly pin with network type |
| Minimum module size (D-WG8) | `min(20,ncol(datExpr)/2)` | liver example sets 30 | 30 in 2, 10 in 2 (one comparator); 15, 20, 40, 50, 200 one each; 14 not | Tune to gene count; retain unassigned genes |
| `deepSplit` (D-WG9) | 2 | tutorial explains split sensitivity at 2 | 2 in 2, 4 in 2; 19 not | Record and assess module stability |
| Merge height (D-WG10) | 0.15 | example 0.25 | heights 0.25 in 2, 0.2, 0.1, MEDissThres 0.3; correlation form 0.75 in 2, 0.85 in 1; 15 not | Record/justify |
| `maxBlockSize` (D-WG11) | 5000 | FAQ adjusts for dataset/memory | 0 reported; 23 not | Scale with genes and memory |
| `reassignThreshold` (D-WG12) | `1e-6` | example 0 | 0 reported; 23 not | Record when changed |
| `pamRespectsDendro` (D-WG13) | TRUE | not a universal recommendation | 0 reported; 23 not | Pin TRUE provisionally |
| Module–trait analysis (D-WG14) | `moduleEigengenes` computes eigengenes; `cor`/`corPvalueStudent` need explicit design | tutorial uses Pearson module–trait correlation/P values | explicit in 13; 10 not | Name trait, sample N, statistic and multiplicity method |
| Hub criterion (D-WG15) | no universal hub threshold; `chooseTopHubInEachModule` uses its own selection | guide examines membership and trait significance | 4 name a basis (membership 2, edge-count permutation 1, modular gene centrality 1); 19 not | Require declared ranking/threshold; report full gene table |
| WGCNA version (D-WG16) | 1.74 locked | tutorial predates current lock | versions named in 5; 18 not | Store package and runtime version |

## X — version-sensitive items

- WGCNA 1.74 source tarball supplies no NEWS/ChangeLog, so this pack cannot attribute a specific version change to release notes. Re-run the pinned tutorial under the locked runtime before freezing output assertions.
- The pinned FAQ describes R 3.6 RNG changes affecting old tutorial simulation examples and gives an explicit legacy RNG mode. This is upstream environment behavior, not a claim that WGCNA 1.74 changed its algorithm.
- The locked `blockwiseModules` defaults include unsigned `networkType` but signed `TOMType`; the older tutorial explicitly sets unsigned TOM. Both must be recorded to avoid silent version/tutorial drift.

## S1 drafts and pending decisions

1. Require a biological-sample × gene expression matrix with documented normalization/filtering, trait alignment and outlier audit. Review minimum sample size and stability with the real anchor and intended study designs; six-sample literature examples do not establish adequacy.
2. Select soft power using fit **and** mean connectivity diagnostics, with a recorded fallback if the target is not met. Set signedness, correlation, TOM, module size, splitting, merging, blocks and seed explicitly; do not promote the liver example’s 6/30/0.25 choices to general defaults.
3. Define the module–trait statistical test, adjustment and hub ranking before reporting. Retain grey/unassigned genes and full results.
4. Run the mirrored FemaleLiver fixture under WGCNA 1.74 in S1 and record actual module/trait outputs. The original UCLA archive remains unavailable for byte comparison, so the registry’s mirror provenance must remain visible.

## S2 printed-table clarification
The container replay reproduces all printed label counts 0–18: 99/609/460/409/316/312/221/211/157/123/106/100/94/91/77/76/58/47/34. Eighteen means assigned modules, excluding grey. No version difference or tolerance adjustment was needed.

## S1 adjudication addendum 2026-10-11 (owner decision, lock 7 record)

| Item | Decision |
|---|---|
| P-1 network type (D-WG5) | `--network-type` is **user-required** (no default) from module 1.1.0. Evidence: signed 9 / not reported 14 of 23 (no corpus majority); the package author recommends a signed variety and calls the unsigned default of `blockwiseModules` a historical compatibility choice (Langfelder, "Signed or unsigned: which network type is preferable?", 2018-11-25). The locked function default `"unsigned"` is still recorded as `function_default` in the registry. Signedness changes the adjacency, the modules and the useful `--power` range, so it is now chosen before the power diagnostics are read. The anchor replay passes `--network-type unsigned` explicitly, so the golden files are byte-identical. |
