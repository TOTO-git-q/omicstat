# PACK -- seurat-integrate

Status: S0 evidence collected; S1 choices drafted, not frozen. No `verification.json` is written by this lane.

| Layer | Evidence |
|---|---|
| L1 | Locked CRAN snapshot 2026-09-15: Seurat 5.5.1, harmony 2.0.5, SeuratObject 5.4.0. Rd, NEWS, DESCRIPTION/CITATION where shipped, versioned integration tutorial sources and rendered guides; `L1_cran2026-09-15/manifest.tsv`. |
| L2 | Seurat v5.5.1 integration vignette and harmony 2.0.5 Seurat vignette, archived under L1. Printed sessions use older companion versions; printed outputs are replay candidates, not assertions for the locked image. |
| L3 | Ten applicable tier-A close readings in `literature/l3_notes.md`. |
| L4 | Thirty licensed OA articles with PubMed efetch echo. Corpus labels (front-end rule): 21 Seurat, nine mixed. 26/30 applicable: 17 Seurat, nine mixed. Two spatial-spot analyses, one ArchR analysis and one separate CoNGA Harmony step were excluded. |

## T -- table skeleton

- Cell × sample metadata: cell ID, original sample/donor/batch, assay and layer, QC status, integration grouping variable and corrected reduction. Keep pre-integration PCA and integrated Harmony coordinates distinguishable.
- Diagnostics table by batch and biological group: number of cells before/after filters and within each cluster. Report which reduction and dimensions feed neighbours, clustering and display. Do not replace per-sample composition with a pooled total.

## F -- figure grammar

- Pair uncorrected PCA/UMAP and Harmony UMAP, colour each by batch and by biological identity in separate panels. Label the grouping covariate and corrected dimensions. The harmony Seurat guide shows batch mixing after `RunHarmony`, while the Seurat v5 guide compares integration methods on the same input.
- Batch mixing alone does not establish preservation of biological structure. Show cell-type/marker and batch composition diagnostics and name the reduction that generated each plot.

## W -- wording

- Name the Seurat assay/layers, PCA input, exact batch covariate, Harmony route (`RunHarmony` or `IntegrateLayers(method=HarmonyIntegration)`), reported tuning and dimensions fed downstream. When a paper says “default parameters” without values, record the values as not reported; do not fill them from a current package version.
- S2 Methods draft: “After <normalization>, <n> PCs from <assay/layer> were corrected with harmony <version> through <route>, grouping cells by <batch variable>. The corrected reduction <name>, dimensions <range>, informed <neighbours/clustering/UMAP>. Batch and biological-group diagnostics were inspected.”

## V -- variant frequencies

Corpus: 21 Seurat articles (17 applicable, four inapplicable) and nine mixed articles (all applicable); zero exclusively Bioconductor or scverse. Labels follow the single-cell front end (QC to cluster labels): an article is mixed when that front end crosses ecosystems (scater QC metrics, scDblFinder or decontX QC, emptyDrops, scverse doublet calling) or when a benchmark runs several ecosystems' pipelines. Denominators below are **applicable articles per ecosystem** (Seurat n=17, mixed n=9); ecosystems are never pooled. A value is a majority only if it is reported by more than half of that ecosystem's applicable articles; otherwise it is "most common". A value reported by one or two papers is never called a default or a majority. Values that differ only in wording (`first 30 PCs` / `top 30 PCs`) are counted once.

| Parameter | Seurat reports (n=17 applicable) | Reported / 17 | Not reported / 17 |
|---|---|---:|---:|
| `integration_route` | RunHarmony: 6 | 6 | 11 |
| `batch_variable` | patient: 2; sample: 2; nine other study-specific values (dataset; dataset + donor; two sequencing batches; sequencing batch; STICR dataset; orig.ident; sample name; individual 10x runs; sequencing batch + intestinal site + patient ID): 1 each | 13 | 4 |
| `input_reduction` | PCA: 12 | 12 | 5 |
| `input_dims` | 30 PCs: 2; 50 PCs: 2; 20 PCs (`1:20`), 67 PCs, 100 PCs: 1 each | 7 | 10 |
| `theta` | 2: 1 (stated as default) | 1 | 16 |
| `lambda` | 1: 1 (stated as default) | 1 | 16 |
| `sigma` | 0.1: 1 (stated as default) | 1 | 16 |
| `seurat_version` | 3.1.5, 4.0.1, 4.0.3, 4.1.1: 2 each; 3.0.1, 3.1, 3.1.4, 3.2.2, 4.0, 4.3.0, 4.4.0: 1 each | 15 | 2 |
| `harmony_version` | 1.0: 4; 0.1.0: 3; 0.1: 2 | 9 | 8 |
| `tau`, `block_size`, `max_iter_harmony`, `max_iter_cluster`, `epsilon_cluster`, `epsilon_harmony`, `reference_values`, `assay`, `nclust`, `early_stop`, `project_dim`, `integration_npcs` | none for each parameter | 0 each | 17 each |

Seurat (n=17): PCA as the Harmony input is the majority reading (12/17), mostly from a PCA step stated in the same paragraph directly before Harmony. `RunHarmony` is the only route named (6/17 applicable, most common, not a majority); no Seurat article names `IntegrateLayers`/`HarmonyIntegration`. A batch covariate is stated in 13/17, but it is study-specific: patient and sample are most common at 2/17 each. Input PCs are stated in 7/17 with no dominant count (30 and 50 PCs at 2/17 each). Seurat versions are stated in 15/17 with no majority string; grouped by major version, 4.x appears in 9/17 and 3.x in 6/17, and no Seurat-labelled article reports v5. harmony versions are stated in 9/17 (1.0 most common at 4/17; `0.1.0` and `0.1` are kept as written). theta 2, lambda 1 and sigma 0.1 come from one paper that states them as Harmony defaults.

Mixed (n=9, reported separately): `integration_route` RunHarmony 5/9; `batch_variable` 5/9, all different (batch + strain; sample identity; dataset + preparation type + sample ID; sample of origin; organoid); `input_reduction` PCA 4/9 (most common, not a majority); `input_dims` 3/9, all different (top 20 PCs; 50 PCs; top PCs cumulatively explaining >80% of variance); `seurat_version` 8/9, all different (3.1, 3.1.4, 4.0, 4.0.3 with 3.1.5 for a separate clustering arm, 4.1.0, 4.3.0.1, 5.3.0, v.5); `harmony_version` 5/9 (1.2.3: 2; 1.0: 2; 0.1.1: 1); `nclust` set to the true benchmark cluster count 1/9. All other tuning arguments are unreported in all nine. One mixed benchmark's oracle `nclust` must not become a production default. There is no exclusively scverse article in this corpus.

## C -- anchors

- `acceptance/data/ANCHOR_REGISTRY.md` row 17 and appended source-lock note: harmony's package-embedded `pbmc_stim.RData`, Kang IFN-beta ctrl/stim example (2,000 cells). Locked `harmony_2.0.5.tar.gz` source SHA256 `1e3a595201e9e82cf7919000a2cc511d5ea7494746994d53a77634b9f33bd42b`; embedded payload SHA256 `d85a18ce8ec9dcb4ac86c8e195ed53ff893c5952a7d6bf70035a17856c9dc0ef`. `fetch_anchor_data.sh pkgdata` downloaded, extracted and verified both.
- The harmony Seurat vignette loads `pbmc_stim`, uses 20 PCs, groups by `stim`, then runs `RunHarmony` and clustering on the corrected reduction. Its rendered output shows 2,000 graph nodes, 70,959 edges and ten communities, but the rendered session has Seurat 5.4.0, not locked 5.5.1. Treat these as smoke candidates pending S2 replay under locked versions.

## D -- locked function default / official guide / per-ecosystem exemplars

The two routes have different APIs. Defaults come from archived Rd usages, including `RunHarmony.Seurat` and `RunHarmony.default`. The Seurat v5 integration guide calls `IntegrateLayers(method=HarmonyIntegration, orig.reduction="pca", new.reduction="harmony")`; the harmony guide calls `RunHarmony` with a batch variable. An unreported exemplar setting is not a default claim.

| Parameter | Function default (locked version) | Official guide | Exemplar evidence (Seurat n=17; mixed n=9 applicable) | S1 draft |
|---|---|---|---|---|
| `integration_route` | no universal route | Seurat: IntegrateLayers/HarmonyIntegration; harmony: RunHarmony | Seurat: RunHarmony 6/17, most common, not a majority; mixed: RunHarmony 5/9; no IntegrateLayers/HarmonyIntegration report | keep both documented routes; select entry at S1 |
| `batch_variable` | `RunHarmony.Seurat`: required `group.by.vars`; IntegrateLayers uses layer groups | harmony: `stim` | Seurat: stated 13/17, patient and sample 2/17 each (most common), others study-specific; mixed: stated 5/9, all different | require explicit study covariate |
| `input_reduction` | `RunHarmony.Seurat(reduction.use="pca")`; `IntegrateLayers(orig.reduction="pca")` | PCA | Seurat: PCA 12/17 (majority); mixed: PCA 4/9 (most common) | explicit PCA/reduction choice |
| `input_dims` | `RunHarmony.Seurat(dims.use=NULL)` | first 20 PCs in harmony guide | Seurat: stated 7/17, 30 PCs and 50 PCs 2/17 each, no dominant count; mixed: 3/9, all different (20 PCs; 50 PCs; >80% variance rule) | document PC selection |
| `theta` | `NULL` (internal handling documented in Rd) | not set | Seurat: 2 in 1/17 (stated as default); mixed: 0/9 | pending S1 |
| `lambda` | `NULL` (internally estimated) | not set | Seurat: 1 in 1/17 (stated as default); mixed: 0/9 | pending S1 |
| `sigma` | `0.1` | not set | Seurat: 0.1 in 1/17 (stated as default); mixed: 0/9 | pending S1 |
| `tau` | `HarmonyIntegration`: 0; `harmony_options`: 0 | not set | not reported (Seurat 0/17; mixed 0/9) | explicit route-specific default |
| `block_size` | `HarmonyIntegration`: 0.05; `harmony_options`: 0.05 | not set | not reported (Seurat 0/17; mixed 0/9) | explicit route-specific default |
| `max_iter_harmony` | `HarmonyIntegration`: 10L; `RunHarmony.default(max_iter=10)` | optional RunHarmony convergence call: 10 | not reported (Seurat 0/17; mixed 0/9) | explicit route-specific default |
| `max_iter_cluster` | `HarmonyIntegration`: 20L; `harmony_options`: 4 | not set | not reported (Seurat 0/17; mixed 0/9) | decide route then fix |
| `epsilon_cluster` | `HarmonyIntegration`: 1e-05; `harmony_options`: 0.001 | not set | not reported (Seurat 0/17; mixed 0/9) | decide route then fix convergence threshold |
| `epsilon_harmony` | 0.01 in both route defaults | not set | not reported (Seurat 0/17; mixed 0/9) | explicit convergence threshold |
| `reference_values` | no reference integration in these calls | not set | not reported (Seurat 0/17; mixed 0/9) | pending S1 |
| `assay` | `IntegrateLayers(assay=NULL)` | layered RNA assay in Seurat v5 guide | not reported (Seurat 0/17; mixed 0/9) | require assay/layers in output |
| `nclust` | NULL in both route defaults | optional RunHarmony example sets 50 | Seurat: 0/17; mixed: 1/9 (oracle true cluster count in one benchmark) | pending S1 |
| `early_stop` | `RunHarmony.default`: TRUE | optional convergence call TRUE | not reported (Seurat 0/17; mixed 0/9) | route-specific |
| `project_dim` | `RunHarmony.Seurat`: TRUE | not set | not reported (Seurat 0/17; mixed 0/9) | route-specific |
| `integration_npcs` | `HarmonyIntegration`: NULL | not set | not reported (Seurat 0/17; mixed 0/9) | pending S1 |
| `seurat_version` | locked 5.5.1 | versioned Seurat tag v5.5.1 | Seurat: stated 15/17, no majority string (3.1.5, 4.0.1, 4.0.3, 4.1.1 at 2/17 each; 4.x 9/17 and 3.x 6/17 by major version); mixed: 8/9, all different | lock 5.5.1 |
| `harmony_version` | locked 2.0.5 | harmony 2.0.5 package vignette | Seurat: stated 9/17, 1.0 most common at 4/17; mixed: 5/9 (1.2.3 and 1.0 at 2/9 each) | lock 2.0.5 |

## X -- version-sensitive behaviour

- SeuratObject 5 introduced `Assay5` layers; Seurat v5 integration may operate across split layers. Record assay/layer identity to prevent a different integration target.
- Seurat NEWS around 5.3.0 says `HarmonyIntegration` switched to `harmony::RunHarmony` from deprecated `HarmonyMatrix`. The two integration routes still expose different convergence defaults, especially cluster iterations and `epsilon.cluster`; these are algorithm stopping thresholds, not output equality tolerances.
- The archived harmony NEWS ends at a 1.2.0 heading despite the locked source version 2.0.5. Version drift cannot be fully inferred from that NEWS; the 2.0.5 Rd and source vignette govern the draft.

## S1 drafts and pending decisions

- P-1 Choose the suite's integration entry route and which assay/layers it accepts. Preserve both APIs as evidence and state the selected route explicitly in Methods and output metadata.
- P-2 Require a study-specific batch covariate and compare pre/post correction by batch and biological identity. Decide how multiple covariates and reference/query workflows are exposed.
- P-3 Select input PCs and downstream corrected dimensions independently. The corpus has no dominant PC count; a single benchmark with oracle `nclust` is unsuitable as a general preset.
- P-4 Freeze route-specific Harmony settings and seeds at S1/S2, then replay the packaged `pbmc_stim` vignette under the locked image before adding numerical goldens. Define output tolerances separately from Harmony convergence thresholds.
