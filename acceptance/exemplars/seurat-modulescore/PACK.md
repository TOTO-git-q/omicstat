# PACK -- seurat-modulescore

Status: S0 evidence collected; S1 choices drafted, not frozen. This lane writes no `verification.json`.

| Layer | Evidence |
|---|---|
| L1 | Locked CRAN 2026-09-15 Seurat 5.5.1 and SeuratObject 5.4.0; `AddModuleScore` generic and Seurat/StdAssay/Assay method defaults, NEWS, DESCRIPTION/CITATION, tagged cell-cycle and PBMC tutorial sources with rendered pages. Manifest in `L1_cran2026-09-15/manifest.tsv`. |
| L2 | Official tagged cell-cycle tutorial archived under L1. It calls `CellCycleScoring` (which uses module scores), and explicitly references `AddModuleScore`; it does not show a direct `AddModuleScore` call or define a global score cutoff. |
| L3 | Ten close readings in `literature/l3_notes.md` (nine applicable; 34936871 runs `AddModuleScore` only on spatial voxels). |
| L4 | Thirty licence-gated OA papers, PubMed efetch echoed; 29 applicable (21 Seurat, eight mixed front end); one not applicable because its only `AddModuleScore` use is on spatial transcriptomics voxels (34936871, mixed). 38110959 (Slide-seqV2 spatial beads) is kept applicable as verified; see P-5. |

## T -- table skeleton

- One row per cell and gene set: cell ID, sample, cluster, assay/layer, gene-set accession/version and membership, matched-feature count, control-pool settings, raw module score and any posthoc standardized score. Keep the raw score separate from a z-score or threshold label.
- Gene-set provenance table: source, intended organism, symbol mapping, supplied/matched/dropped genes and whether a background pool was customized. A score is relative to control genes with similar average expression, not a direct percentage of cells in a state.

## F -- figure grammar

- Violin or ridge plots of module scores by cluster and sample, and a UMAP display coloured by score, with a common legend across compared groups. Show S and G2M separately for the cell-cycle use case. Plots should say whether they display raw `AddModuleScore` values or standardized values.
- Compare an interpretable gene-level expression display for selected members. Cluster labels and thresholded scores are descriptive unless a replicate-aware condition test is separately run.

## W -- wording

- Name the exact gene-set source and matched features, Seurat version, assay/slot, control pool, `nbin`, `ctrl`, seed and any threshold or standardization. If a paper says “default settings,” individual argument values are **not reported** in the exemplar table.
- S2 Methods draft: “Per-cell <set> scores were computed with Seurat <version> `AddModuleScore` on <assay/slot>, using <N matched genes>, <control pool>, <nbin> bins, <ctrl> controls and seed <seed>. <Posthoc transformation/threshold> was applied only for <stated purpose>.”

## V -- variant frequencies

Corpus labels (front end, brief rule 7): 21 Seurat and nine mixed, zero exclusively Bioconductor or scverse. Applicable: 21 Seurat and eight mixed; the one not-applicable paper (34936871, mixed) scores only spatial voxels. 38110959 (mixed) scores Slide-seqV2 spatial beads and stays applicable pending P-5. The tables use **applicable papers within each ecosystem** as denominators; ecosystems are never pooled. Gene-set names are study-specific and all 29 applicable papers name one in `extraction.jsonl`; an argument absent from Methods stays not reported even when a paper claims “default settings.” Counts below are from `vcount.py` on the corrected extraction.

### Seurat (21 applicable)

| Parameter | Reported values and paper counts | Reported / 21 | Not reported / 21 |
|---|---|---:|---:|
| `gene_set` | 21 unique study-specific values (e.g. TRM/TEX signatures: 1; SASP, DNA repair and cell cycle: 1; Reactome MHC class I and II antigen presentation: 1); a cell-cycle gene list appears in 6 recorded values | 21/21 | 0/21 |
| `features_n` | 51 (+1q signature): 1; 50 (top DEGs per cell type): 1; 20 (PT markers): 1; 12 (hepatocyte signature): 1; 10 (ISG genes): 1; 5 (top DEGs per cluster): 1; 3 (NMJ markers): 1 | 7/21 | 14/21 |
| `pool` | none | 0/21 | 21/21 |
| `nbin` | none | 0/21 | 21/21 |
| `ctrl` | 100: 1; 10: 1 | 2/21 | 19/21 |
| `k` | none | 0/21 | 21/21 |
| `assay` | SCT: 1 | 1/21 | 20/21 |
| `seed` | none | 0/21 | 21/21 |
| `search` | none | 0/21 | 21/21 |
| `name` | none | 0/21 | 21/21 |
| `score_threshold` | > 1: 1; mean + 1 SD: 1; 3 SD below mean (and 2 SD above mean for cycling): 1; > 0.25 (cell-cycle phase score): 1; cohort-wide median of patient-level scores: 1 | 5/21 | 16/21 |
| `seurat_version` | 4.3.0: 3; 4.0.3: 3; v3: 2; 4.3.0.1, 4.2.0, 4.1.1, 4.0.4, 4.0.1, v4, 3.1.5, 3.1, 3.0.2, 3.0.1, 5.3.0: 1 each | 19/21 | 2/21 |
| `slot` | none | 0/21 | 21/21 |
| `kmeans_obj` | none | 0/21 | 21/21 |

### Mixed (eight applicable)

| Parameter | Reported values and paper counts | Reported / 8 | Not reported / 8 |
|---|---|---:|---:|
| `gene_set` | eight unique study-specific values (e.g. roX1/roX2 sex genes plus cell-type and early/late-born programs: 1; late CAR T signature: 1; inflammatory, cytokine and arachidonic-acid sets: 1; functional pathway signatures: 1) | 8/8 | 0/8 |
| `features_n` | 21 (late CAR T signature): 1; 6 dorsal and 10 ventral organizer markers: 1; 4, 13 and 7 (CD8 state signatures): 1; 2 (roX1, roX2) and 2 + 2 (early/late-born): 1 | 4/8 | 4/8 |
| `pool` | none | 0/8 | 8/8 |
| `nbin` | none | 0/8 | 8/8 |
| `ctrl` | none | 0/8 | 8/8 |
| `k` | none | 0/8 | 8/8 |
| `assay` | none | 0/8 | 8/8 |
| `seed` | none | 0/8 | 8/8 |
| `search` | none | 0/8 | 8/8 |
| `name` | none | 0/8 | 8/8 |
| `score_threshold` | 0 (sex split) and > 0 with highest l2-normalised score: 1; absolute DV score > 5: 1 | 2/8 | 6/8 |
| `seurat_version` | 4.3.0.1, 4.3.0, 4.1.0, 4.0.1, 3.2.3, 3.1.3 (and 3.2.0), v.5: 1 each | 7/8 | 1/8 |
| `slot` | none | 0/8 | 8/8 |
| `kmeans_obj` | none | 0/8 | 8/8 |

No gene set, gene-set size, score threshold or control count is shared by more than one paper in either ecosystem, so none is a majority or a most common value. Among the Seurat papers, one describes a random background set of 100 genes and one ten control features (each 1/21); neither prints a literal `ctrl=` call. Only one Seurat paper reports an assay (SCTransformed). `pool`, `nbin`, `k`, `seed`, `search`, `name`, `slot` and `kmeans_obj` are reported by no applicable paper. The Seurat version is the best-reported item (19/21 Seurat, 7/8 mixed); the most common exact releases in the Seurat group are 4.3.0 and 4.0.3 (3/21 each), and a 4.x release (including "v4") is reported by 12/21 Seurat papers, a majority of that group. Gene-set provenance, rather than a shared gene-list choice, is the main repeated reporting element. Mixed papers are labelled by their front end (QC, integration or clustering outside Seurat: DropletUtils/scvi-tools, Scanpy, decontX, scDblFinder, batchelor, Scanorama/MOFA); downstream scorers such as UCell, AUCell or irGSEA did not make a paper mixed. There is no exclusively scverse or Bioconductor paper.

## C -- anchors

- `acceptance/data/ANCHOR_REGISTRY.md` row 19 plus lane A append: exact tagged Seurat cell-cycle vignette input, Nestorowa murine hematopoietic progenitor matrix, public `cell_cycle_vignette_files.zip`, 11,257,951 bytes, SHA256 `6557fe2a2761d1550d41edf61b26c6d5ec9b42b4933d56c3161164a595f145ab`. The archive was downloaded and hashed; `fetch_anchor_data.sh sc` can retrieve it. Its expression-matrix member is 44,692,745 uncompressed bytes.
- The vignette uses package data `cc.genes`, member SHA256 `a911aa71023362756b37e31881acdd7c39ba36efbc6aec5b5f238b272fe0f1e7`. Row 19 had named `cc.genes.updated.2019`, also source-locked (SHA256 `ffd7a3644f3137098d0d4b35c5ff654d70377a3ceab597b8159b0b9d16d84edf`), but that is **not** the gene list used in the tagged tutorial. Both members were verified from locked Seurat 5.5.1 source tar; S1 chooses which list the suite exposes.
- A smaller PBMC 3k F1 fixture (row 19, SHA256 `847d6ebd9a1ec9a768f2be7e40ca42cbfe75ebeb6d76a4c24167041699dc28b5`) is already hash-verified from the earlier Seurat modules. It is a cross-module smoke input, not the cell-cycle tutorial dataset.

## D -- locked function default / official guide / Seurat exemplars

The locked `AddModuleScore.Seurat` defaults come from archived Rd. The vignette column describes `CellCycleScoring` and only supplies context for module scores. Counts in the exemplar column use the 21 applicable Seurat papers (denominator 21); the eight applicable mixed papers are counted separately in V and are not pooled here.

| Parameter | Function default (locked version) | Official guide | Seurat exemplar evidence (n = 21) | S1 draft |
|---|---|---|---|---|
| `gene_set` | `features` required: list of feature vectors | tagged cell-cycle vignette uses S/G2M lists from `cc.genes` via `CellCycleScoring` | 21 unique study-specific values (21/21 applicable) | pending S1 |
| `features_n` | list length and membership supplied by caller | vignette uses packaged lists; no fixed set size as suite rule | 51, 50, 20, 12, 10, 5, 3: 1 each (7/21 applicable) | pending S1 |
| `pool` | NULL (all object feature rows) | not explicitly set in direct AddModuleScore call | none (0/21 applicable) | pending S1 |
| `nbin` | 24 | not explicitly set in direct AddModuleScore call | none (0/21 applicable) | pending S1 |
| `ctrl` | 100 | not explicitly set in direct AddModuleScore call | 100: 1; 10: 1 (2/21 applicable) | pending S1 |
| `k` | FALSE | not explicitly set in direct AddModuleScore call | none (0/21 applicable) | pending S1 |
| `assay` | NULL (current/default assay) | vignette normalizes its input before scoring | SCT: 1 (1/21 applicable) | pending S1 |
| `seed` | 1 | not explicitly set in direct AddModuleScore call | none (0/21 applicable) | pending S1 |
| `search` | FALSE | not explicitly set in direct AddModuleScore call | none (0/21 applicable) | pending S1 |
| `name` | "Cluster" | not explicitly set in direct AddModuleScore call | none (0/21 applicable) | pending S1 |
| `score_threshold` | no score threshold in function | vignette classifies phase through `CellCycleScoring`; no universal AddModuleScore cutoff | five unique study-specific cut-offs, 1 each (5/21 applicable) | pending S1 |
| `seurat_version` | locked Seurat 5.5.1 | tagged v5.5.1 source; rendered page is a replay candidate | 4.3.0: 3; 4.0.3: 3; v3: 2; 11 other values 1 each; a 4.x release in 12/21 (19/21 applicable) | pending S1 |
| `slot` | "data" (log-normalized counts) | normalized expression in cell-cycle vignette | none (0/21 applicable) | pending S1 |
| `kmeans_obj` | required only in assay methods when `k=TRUE` | not explicitly set in direct AddModuleScore call | none (0/21 applicable) | pending S1 |

## X -- version-sensitive behaviour

- Seurat 5.3.0 NEWS says `AddModuleScore` gained multi-layer input support. Assay and layer selection therefore matters for replay under 5.5.1.
- Earlier NEWS records a random-seed option for `AddModuleScore`; a fixed seed is needed before numerical goldens. Older paper outputs may not share the locked implementation.
- Seurat NEWS later allowed `ctrl` to be set in `CellCycleScoring`; the tagged cell-cycle tutorial uses that wrapper. Its scores and any direct `AddModuleScore` preset should not be conflated.

## S1 drafts and pending decisions

- P-1 Choose between the tagged tutorial's `cc.genes` and the registry's newer `cc.genes.updated.2019`, with the list hash and organism visible in output. Do not silently substitute one list for the other.
- P-2 Freeze assay/layer, `nbin`, control count/pool and random seed for a direct `AddModuleScore` route. The papers barely report these arguments (`nbin`, `pool` and seed 0/21 Seurat and 0/8 mixed; `ctrl` 2/21 Seurat, 0/8 mixed; assay 1/21 Seurat), so owner review should favor the locked Rd and an anchor replay over an inferred literature majority.
- P-3 Define how unmatched gene symbols are handled. The locked `search=FALSE` default avoids remote HGNC synonym lookup during a deterministic run; any alternate mapping route needs a recorded versioned dictionary.
- P-4 Decide if raw scores, per-set standardized scores and optional thresholds appear as separate outputs. No universal zero cutoff or cross-signature score comparison is supported by this corpus.
- P-5 Decide whether `AddModuleScore` on spatial-bead data counts as applicable. 38110959 (Smoother, mixed) computes functional signature scores with `AddModuleScore` on Slide-seqV2 beads and then imputes them with a spatial prior; the verifier sampled it and accepted it as applicable, so it is counted (mixed n = 8). Under brief rule 8 (spatial spot data -> no) it would drop out, giving mixed n = 7 (`gene_set` 7/7, `features_n` 4/7, `score_threshold` 2/7, `seurat_version` 7/7; Seurat counts unchanged). Owner/verifier to decide.
