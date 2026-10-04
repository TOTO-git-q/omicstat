# PACK -- batchelor-integrate

Status: S0 evidence collected; S1 decisions drafted, not frozen. No `verification.json` is written.

| Layer | Evidence |
|---|---|
| L1 | Bioconductor RELEASE_3_23 batchelor 1.28.0: Rd/defaults, NEWS, DESCRIPTION, source and rendered correction/extension vignettes; `L1_bioc3.23/manifest.tsv`. |
| L2 | Locked `correction.Rmd` workflow with Zeisel and Tasic; exact commands and printed outputs archived in L1. |
| L3 | Ten applicable tier-A close readings in `literature/l3_notes.md`. |
| L4 | Thirty licence-gated OA articles with PubMed efetch echo; 26 applicable (11 Bioconductor-only, 13 mixed, 2 Seurat). |

## T -- table skeleton

- Batch table: batch/sample, cell count, assay and normalization, selected HVGs, correction route, corrected dimensions and merge order.
- Cell table: cell ID, batch, corrected coordinates, original coordinates and downstream embedding/cluster. Report per-batch mixing and biology preservation diagnostics separately.

## F -- figure grammar

- Show pre-correction and corrected PCA/UMAP coloured by batch and biological labels. Display per-batch cell counts and a mixing diagnostic; label which coordinates feed the UMAP.
- Keep a `rescaleBatches` output separate from `fastMNN` corrected reduced dimensions.

## W -- wording

- Name the assay, batch definition, `multiBatchNorm` settings, HVG set and `fastMNN` call (or alternative correction function), including `d`, `k`, cosine normalization and merge rule when used. Distinguish correction dimensions from dimensions selected later for UMAP or clustering.
- S2 draft: “Counts from <batches> were normalized with `multiBatchNorm` <settings>; <HVG rule> selected genes for `fastMNN` <k/d/cos.norm/merge settings>. Corrected coordinates <downstream dimensions> were used for <analysis>; pre/post batch and biology diagnostics were exported.”

## V -- variant frequencies

Corpus by ecosystem label (label = the article's single-cell front end): 14 Bioconductor-only (11 applicable, 3 inapplicable), 13 mixed (all applicable), 2 Seurat (both applicable; batchelor used only outside the Seurat front end) and 1 scverse (inapplicable). Mixed workflows may include SeuratWrappers or method comparators. Counts below use **applicable articles in each ecosystem** (11, 13 and 2), never a pooled denominator. Where a paper reports several analyses, the main-analysis value is counted. “Not reported” does not imply a function default.

### Bioconductor-only (11 applicable)

| Parameter | Reported values and paper counts | Reported / applicable | Not reported / applicable |
|---|---|---:|---:|
| `integration_route` | fastMNN: 4 (one written “fMNN”); rescaleBatches: 3; MNN on `multiBatchPCA` output, function not named: 1; MNN inside Monocle3 (fastMNN in a reanalysis): 1; limma removeBatchEffect with MNN tested: 1 | 10/11 | 1/11 |
| `normalization_route` | multiBatchNorm: 9; Monocle3 size-factor scaling: 1 | 10/11 | 1/11 |
| `batch_definition` | dataset or study: 4; sequencing batch or run: 2; 10X lane: 1; sample: 1; biological replicate: 1; plate: 1 | 10/11 | 1/11 |
| `n_batches` | 2: 4; 3: 2; 4: 1 | 7/11 | 4/11 |
| `fastmnn_d` | 50 (stated as default): 1 | 1/11 | 10/11 |
| `fastmnn_k` | 100: 1; 50 and 21 (two study pairs): 1 | 2/11 | 9/11 |
| `prop_k` | none | 0/11 | 11/11 |
| `ndist` | none | 0/11 | 11/11 |
| `sigma` | none | 0/11 | 11/11 |
| `merge_order` | none | 0/11 | 11/11 |
| `auto_merge` | none | 0/11 | 11/11 |
| `subset_row` | per-dataset HVGs (8093/2111/3614): 1; MetaNeighbor variable genes: 1; modelGeneVar biological variance > 0.1: 1 | 3/11 | 8/11 |
| `correct_all` | none | 0/11 | 11/11 |
| `assay_type` | multiBatchNorm-corrected data subset to variable genes: 1 | 1/11 | 10/11 |
| `batchnorm_pseudocount` | none | 0/11 | 11/11 |
| `batchnorm_min_mean` | none | 0/11 | 11/11 |
| `downstream_corrected_dims` | 20: 1 | 1/11 | 10/11 |
| `umap_dims` | 20: 2 (one for a subset only) | 2/11 | 9/11 |
| `batchelor_version` | 1.6.3: 2; 1.0.1: 1; 1.8.0: 1; 1.8.1: 1; 1.10.0: 1; 1.14.1: 1 | 7/11 | 4/11 |
| `cos_norm` | cosine normalization stated: 1 | 1/11 | 10/11 |
| `restrict` | none | 0/11 | 11/11 |
| `deferred` | none | 0/11 | 11/11 |
| `weights` | none | 0/11 | 11/11 |
| `get_variance` | none | 0/11 | 11/11 |
| `min_batch_skip` | none | 0/11 | 11/11 |
| `norm_args` | none | 0/11 | 11/11 |
| `normalize_all` | none | 0/11 | 11/11 |
| `preserve_single` | none | 0/11 | 11/11 |

### Mixed (13 applicable)

| Parameter | Reported values and paper counts | Reported / applicable | Not reported / applicable |
|---|---|---:|---:|
| `integration_route` | fastMNN through a Seurat wrapper (SeuratWrappers/RunFastMNN): 5; fastMNN called directly: 4; MNN correction, function not named: 2; batch-aware PCA + MNN / `multiBatchPCA` + `reducedMNN`: 1 | 12/13 | 1/13 |
| `normalization_route` | multiBatchNorm: 8; SCTransform: 2 | 10/13 | 3/13 |
| `batch_definition` | dataset: 5; sample: 4; preparation method and batch: 1 | 10/13 | 3/13 |
| `n_batches` | 3: 1; 6: 1; 7: 1; 10: 1 | 4/13 | 9/13 |
| `fastmnn_d` | 50: 1; 30: 1 | 2/13 | 11/13 |
| `fastmnn_k` | none | 0/13 | 13/13 |
| `prop_k` | none | 0/13 | 13/13 |
| `ndist` | none | 0/13 | 13/13 |
| `sigma` | none | 0/13 | 13/13 |
| `merge_order` | linear merge in developmental-time order: 1 | 1/13 | 12/13 |
| `auto_merge` | none | 0/13 | 13/13 |
| `subset_row` | 3000 genes: 3; 2000: 1; 2500: 1; 4000: 1; 6000: 1; scran HVGs, number not stated: 1 | 8/13 | 5/13 |
| `correct_all` | none | 0/13 | 13/13 |
| `assay_type` | log-normalized expression after multiBatchNorm: 5; normalized log-transformed counts: 1 | 6/13 | 7/13 |
| `batchnorm_pseudocount` | none | 0/13 | 13/13 |
| `batchnorm_min_mean` | none | 0/13 | 13/13 |
| `downstream_corrected_dims` | 50: 3; 10: 1; 25: 1; 30: 1 | 6/13 | 7/13 |
| `umap_dims` | 50: 3; 10: 1; 25: 1; 30: 1 | 6/13 | 7/13 |
| `batchelor_version` | 1.2.4: 3; 1.10.0: 2; 1.18.1: 2; 1.2.1: 1; 1.4.0: 1; 1.6.2: 1; 1.6.3: 1 | 11/13 | 2/13 |
| `cos_norm` | none | 0/13 | 13/13 |
| `restrict` | none | 0/13 | 13/13 |
| `deferred` | none | 0/13 | 13/13 |
| `weights` | none | 0/13 | 13/13 |
| `get_variance` | none | 0/13 | 13/13 |
| `min_batch_skip` | none | 0/13 | 13/13 |
| `norm_args` | none | 0/13 | 13/13 |
| `normalize_all` | none | 0/13 | 13/13 |
| `preserve_single` | none | 0/13 | 13/13 |

### Seurat (2 applicable)

| Parameter | Reported values and paper counts | Reported / applicable | Not reported / applicable |
|---|---|---:|---:|
| `integration_route` | fastMNN (multimodal reprocessing): 1; batchelor correction inside Monocle 3: 1 | 2/2 | 0/2 |
| `normalization_route` | computeSumFactors: 1 | 1/2 | 1/2 |
| `batch_definition` | age: 1 | 1/2 | 1/2 |
| `fastmnn_k` | 5: 1 | 1/2 | 1/2 |
| `batchelor_version` | 1.6.3: 1 | 1/2 | 1/2 |
| all other parameters | none | 0/2 | 2/2 |

Among Bioconductor-only applicable articles, `multiBatchNorm` is reported in 9/11, a majority for the normalization stage. `fastMNN` (one paper writes “fMNN”) is the most common correction route at 4/11, ahead of `rescaleBatches` at 3/11; neither is a majority. The batch unit is stated in 10/11 (dataset or study most common, 4/11); the genes given to the correction are stated in 3/11, each with a different rule. In the mixed group, `multiBatchNorm` is reported in 8/13, a majority for normalization; `fastMNN` is the correction route in 9/13 only when Seurat-wrapper calls (5/13) and direct calls (4/13) are counted together, and these spellings are not pooled into a locked batchelor default. Dataset (5/13) and sample (4/13) are the most common batch units, and 3000 genes (3/13) the most common stated gene subset. The two Seurat-labelled papers use batchelor only outside their Seurat front end. `fastMNN(d=...)` is stated in 1/11 (as the default 50), 2/13 and 0/2; values for corrected dimensions used downstream do not establish `d`.

## C -- anchors

- `acceptance/data/ANCHOR_REGISTRY.md` row 22: locked batchelor correction vignette uses `ZeiselBrainData()` and `TasicBrainData()`, ExperimentHub EH2580–2582 and EH2578–2579. All five files were downloaded and SHA256-verified against `fetch_anchor_data.sh hub` (Zeisel counts `4357e6850705c096c8c1276f32b415628dcc16c51ba2c61a36598948ca12a215`; Tasic counts `cfb44779bc27f0de3eee8086f510afd2d31a8cf2e354c80c457a10b1c72c156c`).
- The vignette runs `multiBatchNorm(sce1,sce2)` then `fastMNN(A=sce1,B=sce2,subset.row=chosen.hvgs)`, also demonstrating a combined object with `batch=`. Printed values are replay candidates; no R replay or numeric golden is claimed in S0.

## D -- locked function default / official guide / Bioconductor-only exemplars

Defaults derive from batchelor 1.28.0 locked Rd/source. The eleven applicable Bioconductor-only papers form the exemplar denominator.

| Parameter | Function default (locked version) | Official guide | Bioconductor-only exemplar evidence | S1 draft |
|---|---|---|---|---|
| `integration_route` | caller choice: `fastMNN`, `rescaleBatches`, `reducedMNN` are separate functions | correction vignette uses `fastMNN` on two batches and combined `batch=` form | fastMNN: 4 (one “fMNN”); rescaleBatches: 3; MNN on `multiBatchPCA` output: 1; MNN inside Monocle3: 1; limma removeBatchEffect: 1 (10/11 applicable) | pending S1 |
| `normalization_route` | `multiBatchNorm` is an explicit caller choice | vignette uses `multiBatchNorm(sce1,sce2)` before HVG/correction | multiBatchNorm: 9; Monocle3 size-factor scaling: 1 (10/11 applicable) | pending S1 |
| `batch_definition` | `batch=NULL`; separate input objects identify batches | not explicitly set | dataset or study: 4; sequencing batch or run: 2; 10X lane: 1; sample: 1; biological replicate: 1; plate: 1 (10/11 applicable) | pending S1 |
| `n_batches` | number of input batches; no fixed default | not explicitly set | 2: 4; 3: 2; 4: 1 (7/11 applicable) | pending S1 |
| `fastmnn_d` | `fastMNN(d=50)` | not explicitly set | 50, stated as default: 1 (1/11 applicable) | pending S1 |
| `fastmnn_k` | `fastMNN(k=20)` | not explicitly set | 100: 1; 50 and 21: 1 (2/11 applicable) | pending S1 |
| `prop_k` | `fastMNN(prop.k=NULL)` | not explicitly set | none (0/11 applicable) | pending S1 |
| `ndist` | `fastMNN(ndist=3)` | not explicitly set | none (0/11 applicable) | pending S1 |
| `sigma` | no `sigma` argument in locked `fastMNN` signature | not explicitly set | none (0/11 applicable) | pending S1 |
| `merge_order` | `fastMNN(merge.order=NULL)` | not explicitly set | none (0/11 applicable) | pending S1 |
| `auto_merge` | `fastMNN(auto.merge=FALSE)` | not explicitly set | none (0/11 applicable) | pending S1 |
| `subset_row` | `fastMNN(subset.row=NULL)`; `multiBatchNorm(subset.row=NULL)` | vignette passes `subset.row=chosen.hvgs` to `fastMNN` | per-dataset HVGs: 1; MetaNeighbor variable genes: 1; modelGeneVar biological variance > 0.1: 1 (3/11 applicable) | pending S1 |
| `correct_all` | `fastMNN(correct.all=FALSE)` | not explicitly set | none (0/11 applicable) | pending S1 |
| `assay_type` | `fastMNN(assay.type="logcounts")`; `multiBatchNorm(assay.type="counts")` | counts normalized first, logcounts then corrected | multiBatchNorm-corrected data: 1 (1/11 applicable) | pending S1 |
| `batchnorm_pseudocount` | no direct `pseudo.count`; pass via `norm.args=list()` | not explicitly set | none (0/11 applicable) | pending S1 |
| `batchnorm_min_mean` | `multiBatchNorm(min.mean=1)` | not explicitly set | none (0/11 applicable) | pending S1 |
| `downstream_corrected_dims` | caller choice after correction, distinct from `fastMNN(d)` | not explicitly set | 20: 1 (1/11 applicable) | pending S1 |
| `umap_dims` | downstream caller choice | not explicitly set | 20: 2 (2/11 applicable) | pending S1 |
| `batchelor_version` | locked batchelor 1.28.0 | release 3.23 correction vignette (1.28.0) | 1.6.3: 2; 1.0.1: 1; 1.8.0: 1; 1.8.1: 1; 1.10.0: 1; 1.14.1: 1 (7/11 applicable) | pending S1 |
| `cos_norm` | `fastMNN(cos.norm=TRUE)` | not explicitly set | cosine normalization stated: 1 (1/11 applicable) | pending S1 |
| `restrict` | `fastMNN(restrict=NULL)` | not explicitly set | none (0/11 applicable) | pending S1 |
| `deferred` | `fastMNN(deferred=TRUE)` | not explicitly set | none (0/11 applicable) | pending S1 |
| `weights` | `fastMNN(weights=NULL)` | not explicitly set | none (0/11 applicable) | pending S1 |
| `get_variance` | `fastMNN(get.variance=FALSE)` | not explicitly set | none (0/11 applicable) | pending S1 |
| `min_batch_skip` | `fastMNN(min.batch.skip=0)` | not explicitly set | none (0/11 applicable) | pending S1 |
| `norm_args` | `multiBatchNorm(norm.args=list())` | not explicitly set | none (0/11 applicable) | pending S1 |
| `normalize_all` | `multiBatchNorm(normalize.all=FALSE)` | not explicitly set | none (0/11 applicable) | pending S1 |
| `preserve_single` | `multiBatchNorm(preserve.single=TRUE)` | not explicitly set | none (0/11 applicable) | pending S1 |

## X -- version-sensitive behaviour

- The locked source is batchelor 1.28.0, while its available `NEWS.source` stops at 1.16; do not infer changes after that from the NEWS file. Older entries document `d=NA`/`subset.row` bug fixes (1.8), `correct.all` and deferred PCA (1.6), and merge-order/`auto.merge`/`prop.k` changes (1.2).
- `multiBatchNorm` balances normalization across batches; it is not a complete batch-correction route. `fastMNN` yields corrected low-dimensional coordinates; `rescaleBatches` is a separate full-expression-space approach.
- `ndist` affects MNN matching; it is not a numeric output tolerance. A paper’s downstream top 10, 20, 25, 30 or 50 corrected dimensions must not be entered as `fastMNN(d)`; `d` is recorded only where the paper states the dimension of the corrected space itself or states the default.

## S1 drafts and pending decisions

- P-1 Select a correction route (`fastMNN` versus `rescaleBatches` or other) and define which assay/corrected output is exposed. The Bioconductor-only corpus has no route majority.
- P-2 Freeze batch labels, `multiBatchNorm` recipe, HVG selection, `fastMNN(d/k/prop.k/cos.norm/ndist/merge.order)` and downstream corrected dimensions independently.
- P-3 Keep SeuratWrappers settings as a mixed workflow rather than importing them into the Bioconductor preset.
- P-4 Replay Zeisel + Tasic in the locked image before fixing numerical assertions, graph/UMAP diagnostics, seeds and tolerances.
