# PACK -- aucell-score

Status: S0 evidence collected and re-extracted in the S0 redo. Which single-cell route (Bioconductor AUCell versus the GSVA package's GSVA/ssGSEA) is the standard entry is an **open owner item** (reopened; see "S1 drafts and pending decisions"). No `verification.json`.

Module route definition used for `_applies`: per-cell gene-set/regulon scoring with the Bioconductor R packages AUCell or GSVA (including ssGSEA/plage/zscore inside the GSVA package) applied to dissociated single cells/nuclei. pySCENIC's Python AUCell, gseapy, decoupler, UCell, AddModuleScore, scDRS and bulk/pseudobulk GSVA are not this route; an R SCENIC workflow that calls R AUCell is.

| Layer | Evidence |
|---|---|
| L1 | Bioconductor RELEASE_3_23 AUCell 1.34.0 and GSVA 2.6.6; locked Rd/defaults, NEWS, DESCRIPTION, rendered AUCell and GSVA single-cell vignettes, and AUCell example members in `L1_bioc3.23/manifest.tsv`. |
| L2 | AUCell mouse-brain and GSVA PBMC4k single-cell workflows are archived under L1. |
| L3 | `literature/l3_notes.md`: eight of the ten corpus L3 articles remain applicable; 42758809 and 39854622 use AUCell only inside pySCENIC and are now `no`. Proposed applicable replacements (still L4 in `corpus.jsonl`, not edited): 36264636 and 42593403. |
| L4 | Thirty licence-gated OA articles with PubMed efetch echo. Front-end ecosystems: seurat 16, mixed 6, scverse 4, bioconductor 4. Applicable (R AUCell/GSVA on single cells): seurat 11, mixed 3, scverse 0, bioconductor 0. |

## T -- table skeleton

- Cell × gene-set matrix with cell/sample IDs, set name/source/size, method, score, rank cutoff or GSVA parameter object, and optional activity threshold. Include the gene ID overlap per set.
- Cluster/sample summary table: score distribution, median/quantiles, cell counts and number above a declared threshold. Keep regulon TF-target sets distinct from generic pathway sets.

## F -- figure grammar

- Show score distributions by cluster and sample, and a cell embedding coloured by continuous score. If thresholded, show the score histogram and threshold on the same scale; label gene-set size and matched genes.
- For AUCell compare detected-gene counts with `aucMaxRank`; for GSVA show the chosen method and input assay.

## W -- wording

- Report the scoring unit (cell), the implementation (Bioconductor AUCell or the GSVA package, with version; name pySCENIC/other re-implementations explicitly if used instead), source and mapping of gene sets, the AUCell rank/AUC settings or GSVA Param object, score normalization, any threshold and the aggregation used for plots. Do not equate a per-cell score difference with a biological-replicate treatment test.
- S2 draft: “<Gene sets> were matched to <expression assay> and scored per cell with <AUCell or GSVA single-cell route/version/settings>. Scores were summarized by <cluster/sample>; <threshold rule, if any> was declared before binary activity labels.”

## V -- variant frequencies

Corpus by single-cell front-end ecosystem (rule 7; the AUCell/GSVA scoring is downstream and does not by itself make an article mixed): seurat 16 (11 applicable), mixed 6 (3 applicable: 36548025 scanpy+Seurat QC; 41421361 DropletUtils/Scrublet/Solo QC + Seurat; 42764300 scDblFinder + Seurat), scverse 4 (0 applicable), bioconductor 4 (0 applicable). Denominators are never pooled. Seven articles counted as applicable in the first pass are now `no`: five use AUCell only inside pySCENIC or a Python workflow (42758809, 39854622, 41381484, 41398501, 42600005) and two are ambiguous about the implementation or unit (38071219 "SCENIC or pySCENIC" + GSVA on averaged expression; 33208554 unnamed AUCell in a Scanpy workflow). A value written in different words is counted once.

### Seurat front end (11 applicable)

| Parameter | Reported values and paper counts | Reported / 11 | Not reported / 11 |
|---|---|---:|---:|
| `scoring_route` | AUCell: 7; GSVA: 3; ssGSEA (via GSVA package): 1 | 11/11 | 0/11 |
| `gene_set_source` | all distinct: MSigDB C2: 1; MSigDB v6.0 hallmark (50 pathways): 1; MSigDB or custom datasets: 1; Broad Institute canonical pathways: 1; Chung et al. signatures + MSigDB HALLMARK_INTERFERON_GAMMA_RESPONSE: 1; 70 metabolism + 15 lipid metabolism pathways (ref 32): 1; WikiPathways metabolic sets + SCENIC regulons + Hammond et al. signatures: 1; SCENIC regulons: 1; study-derived time-point markers + published stress signature: 1; study-derived DEG signatures (c3_Inflam-Mono top 50; c9_CXCL10-Mac top 100): 1; signatures from existing studies: 1 | 11/11 | 0/11 |
| `gene_set_size` | more than 20 detectable genes: 1; top 25 genes per time point: 1; top 50 / top 100 DEGs (71-gene DEG set): 1 | 3/11 | 8/11 |
| `input_assay` | expression matrix (unspecified): 1 | 1/11 | 10/11 |
| `ranking_method` | AUCell_buildRankings (default parameters): 1 | 1/11 | 10/11 |
| `auc_max_rank` | none | 0/11 | 11/11 |
| `auc_max_rank_pct` | none | 0/11 | 11/11 |
| `norm_auc` | maximum possible AUC normalized to 1: 1 | 1/11 | 10/11 |
| `keep_zeroes_as_na` | none | 0/11 | 11/11 |
| `split_by_blocks` | none | 0/11 | 11/11 |
| `ncores` | none | 0/11 | 11/11 |
| `threshold_method` | none | 0/11 | 11/11 |
| `auc_threshold` | none | 0/11 | 11/11 |
| `gsva_method` | ssGSEA: 1 | 1/11 | 10/11 |
| `gsva_kcdf` | none | 0/11 | 11/11 |
| `gsva_tau` | none | 0/11 | 11/11 |
| `gsva_maxdiff` | none | 0/11 | 11/11 |
| `gsva_absranking` | none | 0/11 | 11/11 |
| `gsva_sparse` | none | 0/11 | 11/11 |
| `gsva_minsize` | none | 0/11 | 11/11 |
| `gsva_maxsize` | none | 0/11 | 11/11 |
| `ssgsea_alpha` | none | 0/11 | 11/11 |
| `ssgsea_normalize` | none | 0/11 | 11/11 |
| `aucell_version` | 1.16.0: 1; 1.10.1: 1; 2.0 (as printed; no such release): 1 | 3/11 | 8/11 |
| `gsva_version` | 1.36.3: 1; 1.32.0: 1; 2.2.1: 1 | 3/11 | 8/11 |
| `gene_set_id_mapping` | mouse-to-human orthologs via BioMart (Ensembl December 2021): 1 | 1/11 | 10/11 |
| `unit_scored` | individual/each cell (incl. tumour cells, CD8+ T cells, nuclei): 6; myeloid cells / all cells: 1; T, macrophage and DC cells (per-cell vs aggregated not stated): 1 | 8/11 | 3/11 |
| `feature_type` | none | 0/11 | 11/11 |
| `plot_stats` | none | 0/11 | 11/11 |
| `bpparam` | none | 0/11 | 11/11 |
| `mctype` | none | 0/11 | 11/11 |
| `gsva_check_na` | none | 0/11 | 11/11 |
| `gsva_use` | none | 0/11 | 11/11 |
| `gsva_filter_rows` | none | 0/11 | 11/11 |
| `gsva_ondisk` | none | 0/11 | 11/11 |
| `gsva_kcdf_min_samples` | none | 0/11 | 11/11 |
| `aucell_sc_mode` | yes: 7 | 7/11 | 4/11 |
| `gsva_sc_mode` | yes: 4 (GSVA 3, ssGSEA 1) | 4/11 | 7/11 |

In the Seurat-front-end group, per-cell R AUCell is documented in **7/11** applicable papers and per-cell GSVA/ssGSEA in **4/11**; no paper counts both. AUCell exceeds half of this group's denominator (7 > 5.5). This rests on small numbers and on two readings that are flagged in the notes: 33311457 (AUCell implementation inferred from an all-R workflow and the Aibar 2017 citation) and 42627902 ("AUCell package" in an R workflow). Without both it would be 5/9. Two articles with an ambiguous implementation or unit were judged `no` (38071219, 33208554), and 33287869 ran R SCENIC without naming AUCell. This is evidence for the owner decision, **not the decision itself**.

### Mixed front end (3 applicable)

| Parameter | Reported values and paper counts | Reported / 3 | Not reported / 3 |
|---|---|---:|---:|
| `scoring_route` | GSVA: 2; AUCell: 1 | 3/3 | 0/3 |
| `gene_set_source` | MSigDB-curated GO terms (9 listed): 1; pySCENIC high-confidence regulons (>50% of 100 runs): 1; downstream target gene sets of ABL1, ABL2 and DDR1: 1 | 3/3 | 0/3 |
| `gene_set_size` | at least 5 high-confidence target genes: 1 | 1/3 | 2/3 |
| `input_assay` | normalized scRNA-seq expression: 1 | 1/3 | 2/3 |
| `ranking_method` | per-cell ranking of all genes by expression: 1 | 1/3 | 2/3 |
| `auc_max_rank` | none | 0/3 | 3/3 |
| `auc_max_rank_pct` | none | 0/3 | 3/3 |
| `norm_auc` | none | 0/3 | 3/3 |
| `keep_zeroes_as_na` | none | 0/3 | 3/3 |
| `split_by_blocks` | none | 0/3 | 3/3 |
| `ncores` | none | 0/3 | 3/3 |
| `threshold_method` | AUC score cutoff per regulon (binary matrix; cutoff rule not stated): 1 | 1/3 | 2/3 |
| `auc_threshold` | none | 0/3 | 3/3 |
| `gsva_method` | none | 0/3 | 3/3 |
| `gsva_kcdf` | none | 0/3 | 3/3 |
| `gsva_tau` | none | 0/3 | 3/3 |
| `gsva_maxdiff` | none | 0/3 | 3/3 |
| `gsva_absranking` | none | 0/3 | 3/3 |
| `gsva_sparse` | none | 0/3 | 3/3 |
| `gsva_minsize` | none | 0/3 | 3/3 |
| `gsva_maxsize` | none | 0/3 | 3/3 |
| `ssgsea_alpha` | none | 0/3 | 3/3 |
| `ssgsea_normalize` | none | 0/3 | 3/3 |
| `aucell_version` | none | 0/3 | 3/3 |
| `gsva_version` | 1.50.0: 1 | 1/3 | 2/3 |
| `gene_set_id_mapping` | none | 0/3 | 3/3 |
| `unit_scored` | individual cells: 1; single cells: 1; each malignant cell (within each patient): 1 | 3/3 | 0/3 |
| `feature_type` | none | 0/3 | 3/3 |
| `plot_stats` | none | 0/3 | 3/3 |
| `bpparam` | none | 0/3 | 3/3 |
| `mctype` | none | 0/3 | 3/3 |
| `gsva_check_na` | none | 0/3 | 3/3 |
| `gsva_use` | none | 0/3 | 3/3 |
| `gsva_filter_rows` | none | 0/3 | 3/3 |
| `gsva_ondisk` | none | 0/3 | 3/3 |
| `gsva_kcdf_min_samples` | none | 0/3 | 3/3 |
| `aucell_sc_mode` | yes: 1; no (AUCell only via pySCENIC): 1 | 2/3 | 1/3 |
| `gsva_sc_mode` | yes: 2 | 2/3 | 1/3 |

In the mixed group GSVA is the most common route (2/3) and AUCell appears in 1/3 (41421361, whose Methods name "the AUCell Bioconductor package" inside a pySCENIC pipeline). With n = 3 and a two-paper count, no majority is claimed.

### Bioconductor and scverse front ends

Bioconductor 4 articles (0 applicable: bulk-only or no single-cell data; 37966117's front end is not described in the main Methods). scverse 4 articles (0 applicable: pySCENIC or Python AUCell, bulk-only GSVA). No per-ecosystem frequency can be estimated for either group.

## C -- anchors

- AUCell: registry row 24/F12, GEO GSE60361 Zeisel mouse cortex/hippocampus matrix (3,005 cells), downloaded and SHA256-verified `dd09532c73822b632b1914356bfca8e186aff2300b30299e066a6105205e5c4c`. The locked AUCell 1.34.0 archive plus its `geneSignatures.gmt`, `mouseBrain_cellLabels.tsv` and `cellsTsne.RData` members were separately downloaded/hashed and appended to the registry/fetch script. The vignette samples 5,000 genes with seed 333 and prints dimension/AUC candidates.
- GSVA single-cell comparison: locked `GSVA_scRNAseq.Rmd` uses `TENxPBMCData(dataset="pbmc4k")`; the registry F2 10x PBMC4k archive (18,784,558 bytes) was downloaded and SHA256-verified `87fe6bed5cd3a764a2e01a3fda30bb04dccb138b694c0c255645a0170123ee42`. Its accessor metadata and curated gene sets must be reconstructed in S1. No R replay or numeric golden is claimed in S0.

## D -- locked function default / official guide / exemplars per ecosystem

Defaults come from AUCell 1.34.0 and GSVA 2.6.6 locked Rd. Exemplar evidence is given per front-end ecosystem (seurat n = 11, mixed n = 3; bioconductor and scverse have no applicable exemplar). No exemplar setting is imported as a package default.

| Parameter | Function default (locked versions) | Official guide | Seurat-front-end exemplars (n = 11) | Mixed exemplars (n = 3) | S1 draft |
|---|---|---|---|---|---|
| `scoring_route` | caller chooses `AUCell_buildRankings` + `AUCell_calcAUC`, `gsva(gsvaParam(...))` or `gsva(ssgseaParam(...))` | AUCell vignette builds rankings then calculates AUC; GSVA scRNA vignette constructs `gsvaParam` and scores PBMC4k | AUCell: 7; GSVA: 3; ssGSEA (via GSVA): 1 (11/11) | GSVA: 2; AUCell: 1 (3/3) | open owner item (P-1) |
| `gene_set_source` | caller-supplied sets; no bundled universal pathway collection | AUCell vignette uses embedded `geneSignatures.gmt`; GSVA scRNA vignette imports curated sets | 11/11, all distinct (MSigDB collections, published or study-derived signatures, SCENIC regulons) | 3/3, all distinct (MSigDB GO terms, pySCENIC regulons, kinase target sets) | pending S1 |
| `gene_set_size` | caller-supplied; `gsvaParam(minSize=1,maxSize=Inf)` filters | not explicitly set | >20 detectable genes: 1; top 25 per time point: 1; top 50/100 DEGs: 1 (3/11) | ≥5 high-confidence targets: 1 (1/3) | pending S1 |
| `input_assay` | AUCell rankings use supplied expression matrix; `gsvaParam(assay=NA_character_)` resolves input assay | AUCell vignette uses GEO expression matrix; GSVA scRNA vignette uses normalized SCE assay | expression matrix (unspecified): 1 (1/11) | normalized scRNA-seq expression: 1 (1/3) | pending S1 |
| `ranking_method` | `AUCell_buildRankings` ranks genes within each cell; tied zero values are shuffled | AUCell vignette uses `AUCell_buildRankings(exprMatrix,plotStats=TRUE)` | AUCell_buildRankings (default parameters): 1 (1/11) | per-cell ranking of all genes by expression: 1 (1/3) | pending S1 |
| `auc_max_rank` | `AUCell_calcAUC(aucMaxRank=ceiling(0.05*nrow(rankings)))` | AUCell vignette explains top 5% and recommends checking detected-gene histogram | none (0/11) | none (0/3) | pending S1 |
| `auc_max_rank_pct` | 5% of ranked genes by default | not explicitly set | none (0/11) | none (0/3) | pending S1 |
| `norm_auc` | `AUCell_calcAUC(normAUC=TRUE)` | AUCell vignette uses normalized AUC and illustrates optional threshold exploration | maximum possible AUC normalized to 1: 1 (1/11) | none (0/3) | pending S1 |
| `keep_zeroes_as_na` | `AUCell_buildRankings(keepZeroesAsNA=FALSE)` | not explicitly set | none (0/11) | none (0/3) | pending S1 |
| `split_by_blocks` | `AUCell_buildRankings(splitByBlocks=FALSE)` | not explicitly set | none (0/11) | none (0/3) | pending S1 |
| `ncores` | buildRankings `nCores=NULL`; calcAUC `nCores=1` | not explicitly set | none (0/11) | none (0/3) | pending S1 |
| `threshold_method` | not set by core scoring functions; threshold exploration is optional | AUCell vignette explores distributions; no universal AUC cutoff | none (0/11) | AUC cutoff per regulon, rule not stated: 1 (1/3) | pending S1 |
| `auc_threshold` | not fixed; dataset and gene set dependent | not explicitly set | none (0/11) | none (0/3) | pending S1 |
| `gsva_method` | `gsvaParam` classical GSVA; `ssgseaParam` selects ssGSEA, explicit caller choice | GSVA single-cell vignette uses `gsvaParam`, then `gsvaRanks`/`gsvaScores` | ssGSEA: 1 (1/11) | none (0/3) | pending S1 |
| `gsva_kcdf` | `gsvaParam(kcdf=c("auto","Gaussian","Poisson","none"))`, first `auto` | not explicitly set | none (0/11) | none (0/3) | pending S1 |
| `gsva_tau` | `gsvaParam(tau=1)` | not explicitly set | none (0/11) | none (0/3) | pending S1 |
| `gsva_maxdiff` | `gsvaParam(maxDiff=TRUE)` | not explicitly set | none (0/11) | none (0/3) | pending S1 |
| `gsva_absranking` | `gsvaParam(absRanking=FALSE)` | not explicitly set | none (0/11) | none (0/3) | pending S1 |
| `gsva_sparse` | `gsvaParam(sparse=TRUE)` | not explicitly set | none (0/11) | none (0/3) | pending S1 |
| `gsva_minsize` | `gsvaParam(minSize=1)` and `ssgseaParam(minSize=1)` | not explicitly set | none (0/11) | none (0/3) | pending S1 |
| `gsva_maxsize` | `gsvaParam(maxSize=Inf)` and `ssgseaParam(maxSize=Inf)` | not explicitly set | none (0/11) | none (0/3) | pending S1 |
| `ssgsea_alpha` | `ssgseaParam(alpha=0.25)` | not explicitly set | none (0/11) | none (0/3) | pending S1 |
| `ssgsea_normalize` | `ssgseaParam(normalize=TRUE)` | not explicitly set | none (0/11) | none (0/3) | pending S1 |
| `aucell_version` | locked AUCell 1.34.0 | release 3.23 AUCell mouse-brain vignette | 1.16.0: 1; 1.10.1: 1; "2.0" as printed: 1 (3/11) | none (0/3) | pending S1 |
| `gsva_version` | locked GSVA 2.6.6 | release 3.23 GSVA single-cell vignette | 1.36.3: 1; 1.32.0: 1; 2.2.1: 1 (3/11) | 1.50.0: 1 (1/3) | pending S1 |
| `gene_set_id_mapping` | caller aligns gene IDs; no automatic common ID map | not explicitly set | BioMart mouse-to-human orthologs: 1 (1/11) | none (0/3) | pending S1 |
| `unit_scored` | AUCell per cell; GSVA uses columns of supplied input, including cells in scRNA vignette | both official workflows score cells | per cell stated: 7; cell types, per-cell vs aggregated not stated: 1 (8/11) | per cell: 3 (3/3) | pending S1 |
| `feature_type` | `AUCell_buildRankings(featureType="genes")` | not explicitly set | none (0/11) | none (0/3) | pending S1 |
| `plot_stats` | `AUCell_buildRankings(plotStats=TRUE)` | not explicitly set | none (0/11) | none (0/3) | pending S1 |
| `bpparam` | buildRankings `BPPARAM=NULL`; `gsva(BPPARAM=SerialParam(progressbar=verbose))` | not explicitly set | none (0/11) | none (0/3) | pending S1 |
| `mctype` | `AUCell_buildRankings(mctype=NULL)` | not explicitly set | none (0/11) | none (0/3) | pending S1 |
| `gsva_check_na` | `gsvaParam(checkNA=c("auto","yes","no"))`, first `auto` | not explicitly set | none (0/11) | none (0/3) | pending S1 |
| `gsva_use` | `gsvaParam(use=c("everything","all.obs","na.rm"))`, first `everything` | not explicitly set | none (0/11) | none (0/3) | pending S1 |
| `gsva_filter_rows` | `gsvaParam(filterRows=TRUE)` | not explicitly set | none (0/11) | none (0/3) | pending S1 |
| `gsva_ondisk` | `gsvaParam(ondisk=c("auto","yes","no"))`, first `auto` | not explicitly set | none (0/11) | none (0/3) | pending S1 |
| `gsva_kcdf_min_samples` | `gsvaParam(kcdfNoneMinSampleSize=200)` | not explicitly set | none (0/11) | none (0/3) | pending S1 |
| `aucell_sc_mode` | route flag, no function default | not explicitly set | yes: 7 (7/11) | yes: 1; no (pySCENIC only): 1 (2/3) | pending S1 |
| `gsva_sc_mode` | route flag, no function default | not explicitly set | yes: 4 (4/11) | yes: 2 (2/3) | pending S1 |

## X -- version-sensitive behaviour

- Locked AUCell 1.34.0 defaults are `aucMaxRank=ceiling(0.05*nrow(rankings))` and `normAUC=TRUE`; zero/tied expression ranks are randomized by the ranking step. The bundled NEWS text only has headings through 1.25, so it does not document every intervening change. A paper’s historical AUCell version or “default settings” cannot pin this output. Applicable papers cite AUCell 1.10.1 and 1.16.0; one prints "AUCell (2.0)", which is not a released version.
- GSVA 2.6.6 uses parameter objects (`gsvaParam`, `ssgseaParam`) with `gsva(param)`; old papers citing `gsva(...,method="ssgsea")` are not a callable locked API. NEWS 2.6 describes sparse/DelayedArray fixes and a revised single-cell vignette; 2.4 added the single-cell vignette and large sparse inputs. Applicable papers cite GSVA 1.32.0, 1.36.3, 1.50.0 and 2.2.1.
- pySCENIC's Python AUCell is a separate implementation; papers that score regulons only through pySCENIC are not evidence for the Bioconductor AUCell route or its defaults.
- The AUCell AUC score or an activity threshold is an analysis value, not a numeric output tolerance. `aucMaxRank` is a rank window, not a cell-count threshold.

## S1 drafts and pending decisions

- P-1 **OPEN OWNER ITEM, reopened: which route is the standard single-cell entry (Bioconductor AUCell versus the GSVA package's GSVA/ssGSEA, or both as alternatives).** Reason for reopening: the verifier found that the earlier count ("AUCell 16/21") included papers whose AUCell was pySCENIC's Python re-implementation. Recomputed evidence, per ecosystem: Seurat front end AUCell 7/11, GSVA 3/11, ssGSEA 1/11; mixed front end GSVA 2/3, AUCell 1/3; no applicable Bioconductor-only or scverse papers. Also relevant: the official vignettes of both packages and replay behaviour (P-4). Neither this agent nor S0 decides the route.
- P-2 Freeze gene-set source and identifier mapping, AUCell `aucMaxRank`/`normAUC`/tie handling or GSVA Param method/assay/`kcdf`/sparse settings, plus the score aggregation and optional threshold.
- P-3 Keep bulk/pseudobulk GSVA uses out of the single-cell denominator and route them to the existing `gsva-score` module. Keep per-cell group comparisons descriptive unless biological-replicate analysis is specified.
- P-4 Replay both locked official anchors before freezing score matrix shape, score values, plots, seeds and tolerances; decide whether to expose both routes as alternatives.
- P-5 Owner check of borderline `_applies` readings: 41421361 (Methods name "the AUCell Bioconductor package" inside a pySCENIC/cgat-core pipeline; counted yes), 33311457 (AUCell implementation inferred from an all-R workflow; counted yes), 38071219 ("SCENIC or pySCENIC"; GSVA on averaged expression; counted no), 33208554 (unnamed AUCell in a Scanpy workflow; counted no), 33287869 (R SCENIC 1.1.3 without an AUCell mention; counted no). 37966117's front-end label cannot be verified from the main Methods.
- P-6 L3 replacements for the two L3 articles that are now `no` (42758809, 39854622): proposed 36264636 and 42593403 (both applicable, currently L4); `corpus.jsonl` was not edited.
