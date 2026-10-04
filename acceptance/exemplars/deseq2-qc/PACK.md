# PACK -- deseq2-qc

Evidence pack of module `deseq2-qc` (ENGINEERING_PLAN 2.3). Status: **S0 complete (L1 locked release,
L3/L4 collected and independently verified, 2026-09-27); S1 drafted -- the pending decisions at the end
are the owner's. S2 (engine) not started** (built locally, not in the cloud session).

| Layer | Status | Where |
|---|---|---|
| L1 | DESeq2 1.52.0 (Bioconductor 3.23, git.bioconductor.org RELEASE_3_23): vignette source + rendered text, Rd of `DESeqDataSetFromMatrix`, `vst`, `rlog`, `varianceStabilizingTransformation`, `plotPCA`, `estimateSizeFactors`, NEWS, `defaults.tsv` | `L1_bioc3.23/` (manifest with sha256 and git commit) |
| L2 | DESeq2 vignette "Data transformations and visualization", "Blind dispersion estimation", "Data quality assessment by sample clustering and visualization"; rnaseqGene workflow (source) | cited below |
| L3 | 10 open-access full texts (tier-A journals), close-read notes | `literature/l3_notes.md` |
| L4 | 30 open-access articles 2020-2026 (whitelisted journals, CC BY / CC BY-NC, PubMed-echoed); **20 of 30 apply** (10 use vst/rlog for other purposes: per-patient fold changes, UMAP of genomic loci, WGCNA input, deconvolution, or Seurat's unrelated `selection.method = "vst"`) | `literature/corpus.jsonl`, `extraction.jsonl`, `efetch/` |
| Verification | 6 of 30 articles, 34 records: 33 pass (97.1 %), PMID echo 6/6 -> **pass** | `literature/verification.json` |

Correction from verification: PMID 33203890 `outlier_rule` recorded a sequencing-depth inclusion rule
("at least 400,000 estimated counts ...") that is not an outlier rule; counted below as not reported.
The profile's signal regex was tightened after this extraction (transformation and a sample-level QC
use must share a sentence); the 20 applicable articles were judged against the module definition.

## T -- table skeleton

- Sample table with the QC verdict: sample, group(s), size factor, PC1/PC2 scores, distance to the group
  centroid, outlier flag + reason. Paper-facing form: none -- QC results appear as figures and a sentence;
  none of the 10 L3 Methods describes a QC table (tables live in supplements, not searched).

## F -- figure grammar

| Figure | Grammar | Source |
|---|---|---|
| PCA of samples | PC1 vs PC2 of the transformed matrix, top 500 most variable genes, % variance on the axes, colour = condition, shape = second factor | vignette `plotPCA(vsd, intgroup = c("condition", "type"))`; `plotPCA(ntop = 500)` default; `_shared` `os_pca_plot` |
| Sample-distance heatmap | Euclidean distances between samples on the transformed matrix, hierarchical clustering, annotation bar = condition | vignette `dist(t(assay(vsd)))` + heatmap; `_shared` `os_sample_distance` |
| Exemplars | PCA, sample-distance or sample heatmaps are named; one L3 paper runs PCA on a batch-corrected (limma `removeBatchEffect`) vst matrix （2026-09-27 更正：`l3_notes.md` 中至少 2/20 描述 VST 后的批次校正展示——PMC12893922 与 PMC7688323，其中明确使用 `removeBatchEffect` 的 1/20；结构化摘录没有该字段，这不是完整普查）; no paper states a numeric PCA/outlier threshold | `literature/l3_notes.md` |

## W -- wording

Exemplar structure (L3): a short sentence "PCA was performed on counts after the DESeq2 variance
stabilizing transformation", often without version, `blind` or the number of genes; the richest papers
chain transformation -> its uses (distances, PCA, heatmaps) -> any batch correction applied for display.
Template to write at S2: DESeq2 version, transformation (`vst`, `blind = ...`), the genes used for PCA
(`ntop`), the distance, and the outlier rule, stated as display/QA, never as a test.

## V -- variant frequencies (L4: 20 applicable papers)

| Parameter (PACK) | Reported values | n.r. | Majority among reporting papers |
|---|---|---|---|
| Transformation (D-QC1) | vst / variance-stabilizing transformation: 18; rlog: 2 | 0 | **vst** (18 of 20) |
| blind (D-QC2) | TRUE: 1 | 19 | -- (1 paper) |
| Genes for PCA, ntop (D-QC3) | 2000: 1 | 19 | -- (1 paper) |
| Sample distance (D-QC4) | Euclidean: 4; Pearson correlation: 2; Spearman correlation: 1 | 13 | Euclidean (4 of 7) |
| Outlier rule (D-QC5) | WGCNA connectivity < -3: 1; "all samples retained after QC review": 1 | 18 （2026-09-27 更正：原始摘录为 17/20 未报告；PMC7673985 的 400,000 counts 是测序深度纳入标准，按核查修正为 18/20，两种口径分列） | none |
| Pre-filter (D-11) | 8 different rules | 12 | none |
| DESeq2 version (X) | 1.18.1 - 1.42.1 (8 versions) | 11 | -- |

## C -- anchors

`acceptance/data/ANCHOR_REGISTRY.md` rows 1 / 1b: pasilla (package-embedded; the vignette's `dds`) for a
replay anchor of `vst(dds, blind = ...)`, `plotPCA(vsd, intgroup = c("condition", "type"))` and the
sample distances; airway (rnaseqGene workflow) as the alternative. The rendered vignette shows the
PCA only as a figure, so the anchor is a replay anchor (vignette code in-session = engine), not printed
values.

## D -- defaults: function default / vignette / exemplar majority

Function defaults from `L1_bioc3.23/DESeq2/defaults.tsv` (Rd `\\usage` of DESeq2 1.52.0).

| Id | Parameter | (1) function default | (2) vignette / workflow | (3) exemplar majority (V) | Draft | Decision |
|---|---|---|---|---|---|---|
| D-QC1 | transformation | `vst` and `rlog` both available | vst recommended for speed and large n; rlog for small n (vignette: "rlog may take 30 seconds, while vst takes less than 1 second"; NEWS 1.9.42: VST recommended for 100s of samples) | vst 18/20 | `vst` default, `rlog` as option | vignette + majority agree |
| D-QC2 | `blind` | TRUE | text: TRUE "to compare samples in a manner wholly unbiased ... to perform sample QA"; example code uses `blind = FALSE` | TRUE 1/20 (19 n.r.) | TRUE | **S1 P-1 (A, owner 2026-09-27)**: TRUE for QA; FALSE only for post-fit DE display |
| D-QC3 | `plotPCA(ntop)` | 500 | 500 (default, vignette call) | 2000: 1/20 | 500 | vignette |
| D-QC4 | sample distance | -- (not a DESeq2 argument) | Euclidean `dist(t(assay(vsd)))` | Euclidean 4/7 reporting | Euclidean | vignette + majority agree |
| D-QC5 | outlier rule | -- | none given for samples (Cook's distance is per gene) | none (17/20 n.r. in the raw extraction, 18/20 after verification; recount 2026-09-27) | report PCA/distance outliers descriptively, never remove automatically | **P-2: C -- pending evidence** (no statistic or threshold frozen) |
| D-QC6 | `vst(nsub, fitType)` | 1000, "parametric" | defaults | n.r. | 1000, "parametric" | vignette |
| D-11 | pre-filter | none | count >= 10 in >= smallest group (vignette "Pre-filtering") | 8 rules, none repeated | same as deseq2-wald | consistency with deseq2-wald |
| D-QC7 | batch-corrected display (row added 2026-09-27) | not a DESeq2 step; limma `removeBatchEffect(design = NULL, group = NULL)` protects only the intercept | DESeq2 FAQ "Why after VST are there still batches in the PCA plot?"; limma `removeBatchEffect` Rd Note: display/exploration only | no structured field; >= 2/20 in L3 notes, explicit `removeBatchEffect` 1/20 | off by default; via `sva-batch` with the biological design protected, shown next to the uncorrected plot | **S1 P-3 (A, owner 2026-09-27)** |

## X -- version-sensitive behaviour (L1 NEWS, DESeq2 1.52.0)

- 1.42.0: `plotPCA()` prints its `ngenes` (ntop) setting and gains `pcsToUse` (PCs other than 1-2; first in 1.41.2).
- 1.9.42: `rlog`'s "fast" option removed; VST recommended for very large matrices (100s of samples).
- `vst()` is the fast wrapper of `varianceStabilizingTransformation()` (added 1.11.18 / 1.12.0); `vst` subsamples
  `nsub = 1000` genes to fit the trend, so it fails on fewer than 1000 rows -- the engine must fall back
  to `varianceStabilizingTransformation()` (as deseq2-wald does).

## S1 drafts and pending decisions (the owner decides; no default is fixed yet)

- **P-1 `blind`.** Function default and vignette text say TRUE for sample QA (unbiased by the design);
  the vignette's own example uses FALSE (for downstream use). Only 1 of 20 papers states it (TRUE).
  Draft: `blind = TRUE` in deseq2-qc (QA), while deseq2-wald keeps `blind = FALSE` for its heatmap
  (downstream display after the fit) -- two modules, two purposes, both from the same vignette section.
- **P-2 Outlier samples.** No source gives a numeric sample-outlier rule (DESeq2's Cook's distance is
  per gene; the one paper with a numeric rule uses WGCNA connectivity). Draft: flag samples descriptively
  (PCA / distance to group centroid) with a QC warning and never drop them automatically; any removal is a
  user flag and is reported. Needs the owner's confirmation of the flagging statistic.
- **P-3 Batch-corrected display.** One L3 paper plots PCA of a limma `removeBatchEffect`-adjusted vst
  matrix. Draft: allowed only for display, labelled as such, via the `sva-batch` module's rules, never
  inside deseq2-qc by default.

## S1 审定附录（2026-09-27，所有者批准）

所有者于 2026-09-27 裁决：`docs/build/S1_DECISION_TABLE_M1M2.md`（下称"决策表"）中 A、B 类项目一律按「建议」栏批准（建议含可选项的，默认值与可选项一并冻结），C 类保持待定。上一节 "S1 drafts and pending decisions" 保留为历史；与本附录不一致处以本附录为准。下列参数在调用中一律显式写出，即使等于函数默认值（ENGINEERING_PLAN §3.3）。L1 路径相对于 `L1_bioc3.23/DESeq2/`。

| 编号 | 决定 | 类别 | 依据 |
|---|---|---|---|
| P-1 QA 的 `blind` | 样本 QA：`vst(object, blind = TRUE, nsub = 1000, fitType = "parametric")`；行数 < 1000 时回退 `varianceStabilizingTransformation(object, blind = TRUE, fitType = "parametric")`；选 rlog 时 `rlog(object, blind = TRUE, fitType = "parametric")`。已拟合模型后的 DE 展示（deseq2-wald 的热图等）显式 `blind = FALSE`。图题/图注写明用途与 `blind` 取值。存在大量真实组间差异时，用户可要求追加一张 `blind = FALSE` 的补充图。不得凭 blind QA 图自动删去生物学分组。 | A | 决策表 deseq2-qc P-1；`Rd/vst.Rd`、`Rd/rlog.Rd`、`Rd/varianceStabilizingTransformation.Rd`；`vignettes/DESeq2.Rmd` "Blind dispersion estimation" |
| P-2 样本离群警告的统计量/阈值 | **C — pending evidence。** 不冻结任何离群统计量或阈值；`plotPCA(ntop = 500, pcsToUse = 1:2)` 只出图。缺少的证据：PCA 到组中心距离的统计量定义、缩放方式、组大小要求及经校准的警戒阈值。补证办法：下一阶段用已登记的 QA 数据和已知异常标签校准，给出误报/漏报结果后再定；不得把 WGCNA connectivity 阈值移植为 PCA 阈值。 | C | 决策表 deseq2-qc P-2；`Rd/plotPCA.Rd`；`vignettes/DESeq2.Rmd` "Data quality assessment by sample clustering and visualization"、"Approach to count outliers"；`literature/verification.json` PMID 33203890 |
| P-3 批次校正后的图 | 默认关闭；需要时由 `sva-batch` 提供保护生物学设计的校正展示（`limma::removeBatchEffect` 须显式给出 `batch = <batch>` 与 `design = <生物学设计矩阵>`，不用只保护截距的 `design = NULL`），与未校正的原图并列并标注"仅展示"。校正矩阵不得进入 DE；输入来源约束与 sva-batch P-1 共用。 | A | 决策表 deseq2-qc P-3；`vignettes/DESeq2.Rmd` FAQ "Why after VST are there still batches in the PCA plot?"；`literature/l3_notes.md` PMC12893922、PMC7688323；跨模块 `sva-batch/L1_bioc3.23/limma/Rd/removeBatchEffect.Rd` Note |

待澄清：
- P-2：决策表写"可先确定'只展示、人工标记、不自动剔除'；草案的定量 QC warning 暂不冻结"。所有者裁定 C 类整体待定——请确认"只展示、人工标记、不自动剔除"这一行为是否先行批准，还是随 P-2 一起待定？在确认之前，本附录不把它写成冻结决定。

对上一节草案原文的更正（草案文本保留不改，更正记在这里）：
- P-2 草案说"flag samples descriptively (PCA / distance to group centroid) with a QC warning"：定量 warning 的统计量和阈值没有证据支持，属于 C 类待定（2026-09-27 更正）。
- P-3 草案说"One L3 paper plots PCA of a limma `removeBatchEffect`-adjusted vst matrix"：校正展示在 L3 笔记中至少 2/20（PMC12893922、PMC7688323），明确 `removeBatchEffect` 的 1/20；不是结构化字段的完整普查（2026-09-27 更正）。

- D 表：D-QC2、D-QC5 的 Decision 已同步，新增 D-QC7（批次校正展示）；V 节与 F 节按决策表更正（见行内标注）。
