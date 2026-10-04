# PACK -- limma-voom

Evidence pack of module `limma-voom` (ENGINEERING_PLAN 2.3). Status: **S0 complete (L1 locked release,
L3/L4 collected and independently verified, 2026-09-27); S1 drafted -- the pending decisions at the end
are the owner's. S2 (engine) not started** (built locally, not in the cloud session).

| Layer | Status | Where |
|---|---|---|
| L1 | limma 3.68.5 and edgeR 4.10.5 (Bioconductor 3.23, git.bioconductor.org RELEASE_3_23): vignette sources + rendered text (limma User's Guide and edgeR User's Guide via the release PDFs), Rd of `voom`, `voomWithQualityWeights`, `lmFit`, `contrasts.fit`, `eBayes`, `treat`, `topTable`, `topTreat`, `filterByExpr`, `normLibSizes`, NEWS, `defaults.tsv` | `L1_bioc3.23/` (manifest with sha256 and git commit) |
| L2 | limma User's Guide ch. 15 "RNA-Seq Data" (15.3 normalization and filtering, 15.5 voom, 15.6 sample quality weights, 15.7 voomLmFit); RNAseq123 workflow (Law et al.) | cited below |
| L3 | 10 open-access full texts (tier-A journals), close-read notes | `literature/l3_notes.md` |
| L4 | 30 open-access articles 2020-2026 (whitelisted journals, CC BY / CC BY-NC, PubMed-echoed); **24 of 30 apply** (6 run voom outside bulk RNA-seq DE: ChIP-seq peaks, CRISPR screen sgRNA counts, or use another test for the RNA-seq) | `literature/corpus.jsonl`, `extraction.jsonl`, `efetch/` |
| Verification | 6 of 30 articles, 54 records: 54 pass (100 %), PMID echo 6/6 -> **pass** | `literature/verification.json` |

## T -- table skeleton

- Feature table per contrast (as `topTable(number = Inf)`): feature_id, symbol, logFC, AveExpr, t, P.Value,
  adj.P.Val, B; with `treat`: logFC, AveExpr, t, P.Value, adj.P.Val (no B). Paper-facing form: the DE
  table goes to a supplement; the main text states counts of up/down genes at the stated cutoff.

## F -- figure grammar

| Figure | Grammar | Source |
|---|---|---|
| voom mean-variance trend | sqrt(standard deviation) vs average log2 count, lowess trend | `voom(plot = TRUE)`; User's Guide 15.5 |
| MD / volcano | logFC vs AveExpr (MD, `plotMD`) or logFC vs -log10 P; significant genes highlighted at the stated FDR | User's Guide; L3 PMC13506345 (MD plots with BH < 0.05 highlighted) |
| Sample MDS | `plotMDS` of logCPM | RNAseq123 workflow; `_shared` `os_pca_plot` for the house style |

## W -- wording

Exemplar structure (L3): normalization is often attributed to edgeR ("TMM ... implemented in edgeR"),
the transformation to limma's `voom`, and the test described generically ("empirical Bayes moderation");
the richest papers name the full chain `filterByExpr -> calcNormFactors (TMM) -> voom -> lmFit ->
contrasts.fit -> eBayes/treat`. Cutoffs (FDR and fold change) are often in separate sentences.
Template to write at S2: limma and edgeR versions, filter (`filterByExpr` with the design), TMM, voom
(with/without sample weights), `eBayes` or `treat(fc = ...)`, BH, FDR cutoff, any post hoc FC filter
stated as a display filter.

## V -- variant frequencies (L4: 24 applicable papers)

Source: `collect.py summarize limma-voom` (only `_applies = yes`).

| Parameter (PACK) | Reported values | n.r. | Majority among reporting papers |
|---|---|---|---|
| voom variant (D-V1) | voom 21 (+ voom inside edgeR `voomLmFit` 1, "limmaVoom" 1, "precision weights" 1); voomWithQualityWeights 0 | 0 | **voom family** (24/24) （2026-09-27 更正：原写 **voom** (24/24)；24/24 是 voom 家族，其中 1/24 用 `voomLmFit`，不能写成 24 篇都是独立的 `voom + lmFit`） |
| Low-expression filter (D-V2) | `filterByExpr` 3 (+1 "filter_by_expression() in edgeR"); 12 bespoke CPM/count rules, none repeated | 8 | filterByExpr is the only rule used by > 1 paper (4 of 16) |
| Normalization (D-V3) | TMM 11 (in its various spellings); quantile 2; upper quartile 1; plain CPM 1 | 9 | **TMM** (11 of 15) |
| eBayes options (D-V4) | plain `eBayes` 6; `treat` (fc 1.2) 1; robust / trend never stated | 17 | plain eBayes (6 of 7) |
| FDR cutoff (D-08) | 0.05: 11 (incl. q, FDR); 0.1: 1; 0.001: 1; one paper uses raw P < 0.05; one uses 0.1 then 0.01 | 9 | **0.05** (11 of 15) |
| Adjustment (D-08) | Benjamini-Hochberg 9 | 15 | **BH** (9/9) |
| Post hoc FC filter (D-07) | > 0.2, >= 0.4, >= 1 (absolute FC), > 1.5, > 1 (log2) -- 5 papers, 5 values | 19 | none |
| limma version (X) | 3.28.14 - 3.64.1 (10 versions); one paper writes "4.2" | 13 | -- |

No applicable paper uses `voomWithQualityWeights` or `voomLmFit(sample.weights = TRUE)`.

## C -- anchors

`acceptance/data/ANCHOR_REGISTRY.md` row 5: GSE63310 (mouse mammary populations, 11 samples, file F4
`GSE63310_RAW.tar`), the RNAseq123 workflow (`filterByExpr -> calcNormFactors -> voom -> lmFit ->
contrasts.fit -> eBayes / treat`). Row 7b (Yoruba, `limma_Yoruba.RData`, User's Guide 18.1) is a second
voom anchor with printed values (shared with limma-dupcor). User's Guide 15.6 prints
`sum(top2$adj.P.Val < 0.05) = 1478` for the voomWithQualityWeights example (data not registered).

## D -- defaults: function default / vignette / exemplar majority

Function defaults from `L1_bioc3.23/{limma,edgeR}/defaults.tsv` (Rd `\usage`, limma 3.68.5, edgeR 4.10.5).

| Id | Parameter | (1) function default | (2) User's Guide 3.23 | (3) exemplar majority (V) | Draft | Decision |
|---|---|---|---|---|---|---|
| D-V1 | interface | `voom(normalize.method = "none", span = 0.5, adaptive.span = TRUE)`; `voomWithQualityWeights` separate | 15.5: `voom(dge, design)`; 15.6: quality weights "when an MDS plot ... indicates outlier samples"; **15.7: "we now recommend voomLmFit as the preferred interface ... replacing voom, lmFit and voomWithQualityWeights"** | voom family 24/24, of which voomLmFit 1 (2026-09-27 更正：不是 24 篇独立 `voom + lmFit`); quality weights 0 (0/24 recorded -- not evidence that none used them) | `voom` + `lmFit` (majority, ENGINEERING_PLAN module definition); `voomWithQualityWeights` as a flag | **P-1: C -- pending evidence** (owner accepts the direction `voomLmFit`, guide 15.7; call set not frozen until the locked edgeR 4.10.5 `voomLmFit` Rd/formals are collected); quality weights: **S1 P-3 (B, owner 2026-09-27)** |
| D-V2 | low-expression filter | `filterByExpr(min.count = 10, min.total.count = 15, large.n = 10, min.prop = 0.7)` with the design | 15.3: `filterByExpr(dge, design)`, `keep.lib.sizes = FALSE` | filterByExpr 4 of 16 reporting; the rest bespoke | `filterByExpr(y, design)` | guide + most common named rule |
| D-V3 | normalization | `normLibSizes(method = "TMM")` (formerly `calcNormFactors`) | 15.3: TMM "found to perform well" | TMM 11/15 | TMM | guide + majority agree |
| D-V4 | `eBayes(trend, robust)` | FALSE, FALSE; `legacy = NULL` (new hyperparameter estimation when residual df are unequal, limma 3.62.0) | 15.5: `eBayes(fit)` | plain eBayes 6/7 | `eBayes(fit)` defaults | guide + majority agree |
| D-V5 | `treat` | `fc = 1.2` (limma 3.68.5 Rd; `lfc` default log2(1.2) since 3.36.0) | 15.5: `treat(fit, lfc = log2(1.2))` "to give more weight to fold-changes" | 1 paper | option, not default | **S1 P-2 (B, owner 2026-09-27)**: `eBayes` default; `treat` only with a user-prespecified FC, converted to `lfc = log2(fc)` |
| D-08 | adjustment, FDR | `topTable(adjust.method = "BH", p.value = 1)` | examples count `adj.P.Val < 0.05` | BH 9/9; 0.05 11/15 | BH, 0.05 | same as deseq2-wald |
| D-07 | post hoc FC filter | none (`topTable(lfc = NULL)`) | `treat` instead of a post hoc filter | 5 papers, 5 values | none by default (display filter only, as deseq2-wald P-2) | **S1 P-2 (B, owner 2026-09-27)**: display-only filter, off by default |

## X -- version-sensitive behaviour (L1 NEWS)

- limma 3.66.0: `adaptive.span = TRUE` is now the default for `voom()` / `voomWithQualityWeights()`
  (span from `chooseLowessSpan()`); results differ numerically from limma < 3.66 with the old fixed
  `span = 0.5`. edgeR 4.8.0: same change for `voomLmFit()`.
- limma 3.62.0: new hyperparameter estimation (`fitFDistUnequalDF1`) used by default in `eBayes`,
  `treat`, `squeezeVar` whenever residual df are unequal (e.g. voomLmFit); `legacy = TRUE` restores it.
- limma 3.48.0: `treat(fc = )`; limma 3.36.0: `treat` default `lfc` changed from 0 to log2(1.2).
- edgeR 4.x: `normLibSizes()` is the new name of `calcNormFactors()` (both exported).
- Golden files written in the dev tier (limma 3.66 / Bioc 3.22) vs the container (3.68 / Bioc 3.23):
  byte check SKIPs on signature mismatch (ENGINEERING_PLAN 3.5).

## S1 drafts and pending decisions (the owner decides; no default is fixed yet)

- **P-1 voom vs voomLmFit.** The locked release's User's Guide (15.7) now recommends `voomLmFit` as the
  preferred interface (unbiased residual variances for genes with zeros in a group; automates sample
  weights and block correlation). Exemplars: 24 of 24 use `voom`, 1 via `voomLmFit`. The module is
  defined in ENGINEERING_PLAN as `voom`/`voomWithQualityWeights` + `lmFit`. Draft: keep `voom + lmFit`
  as the default (majority, and the definition), offer `voomLmFit` as an option, and state it in the
  W template; the owner decides whether the guide's recommendation should become the default instead.
- **P-2 Fold-change criterion.** `treat` (guide's option) is used by 1 paper; post hoc |logFC| filters by
  5 papers with 5 different values. Draft: default `eBayes`; `treat(fc = 1.2)` as an option; post hoc
  filter only as a labelled display filter, consistent with deseq2-wald P-2.
- **P-3 Sample quality weights.** No applicable paper uses them; the guide conditions them on outlier
  samples in the MDS plot. Draft: off by default; on by user flag or when deseq2-qc-style QA flags a
  sample (never automatic).

## S1 审定附录（2026-09-27，所有者批准）

所有者于 2026-09-27 裁决：`docs/build/S1_DECISION_TABLE_M1M2.md`（下称"决策表"）中 A、B 类项目一律按「建议」栏批准（建议含可选项的，默认值与可选项一并冻结），C 类保持待定。上一节 "S1 drafts and pending decisions" 保留为历史；与本附录不一致处以本附录为准。下列参数在调用中一律显式写出，即使等于函数默认值（ENGINEERING_PLAN §3.3）。L1 路径相对于 `L1_bioc3.23/`。

| 编号 | 决定 | 类别 | 依据 |
|---|---|---|---|
| P-1 `voom + lmFit` 或 `voomLmFit` | **C — pending evidence。** 所有者接受方法**方向**：按锁定指南 §15.7 改用 `voomLmFit` 作为默认入口，旧 `voom + lmFit` 管线保留为明确的复现选项（决策表建议）。但完整调用集合**未冻结**：必须先取得锁定 edgeR 4.10.5 的 `voomLmFit` Rd/formals，核对其完整默认值、输出对象（EList/weights）与下游（camera、GSVA→limma 等）所需契约，再按 §3.3 登记参数。缺少的证据：本地 L1 没有 `edgeR::voomLmFit` 的 Rd/formals。补证办法：按已存 release commit 补收 `voomLmFit.Rd`，或在锁定容器中导出 `formals(edgeR::voomLmFit)`。不得凭记忆补 API；在补证之前 S2 不得照旧草案默认旧入口而不说明取舍。 | C | 决策表 limma-voom P-1、「跨模块一致性」第 5 行；`limma/Rd/voom.Rd`、`limma/Rd/lmFit.Rd`；`limma/vignettes/usersguide.rendered.txt` §15.7；`edgeR/NEWS.txt` `voomLmFit` 条目；`literature/extraction.jsonl` `voom_variant`（PMC13506345）；ENGINEERING_PLAN §1.2 A、§3.3 |
| P-2 FC 判据 | 默认零效应 `eBayes(fit, proportion = 0.01, stdev.coef.lim = c(0.1, 4), trend = FALSE, span = NULL, robust = FALSE, winsor.tail.p = c(0.05, 0.1), legacy = NULL)`（取值为锁定版函数默认，D-V4）。可选最小效应检验：用户预先给定线性倍数 `fc`，显式换算为 `lfc = log2(fc)` 传入 `treat(fit, fc = <见待澄清>, lfc = log2(fc), trend = FALSE, robust = FALSE, winsor.tail.p = c(0.05, 0.1), legacy = NULL, upshot = FALSE)`；不把 1.2 当作所有研究的生物学阈值（锁定版 `treat(fc = 1.2)` 本身是有效参数，不是错误）。展示用 FC 筛选默认关闭，报告语义与 deseq2-wald P-2、edger-qlf P-3 共用。 | B | 决策表 limma-voom P-2、「跨模块一致性」第 1 行；`limma/Rd/treat.Rd`（Usage；`lfc` "If specified then takes precedence over fc"）、`limma/Rd/eBayes.Rd`；User's Guide §15.5 |
| P-3 样本质量权重 | 默认不启用，QA 标记只作提示，**不会自动启用**。用户依据预先规定的 QC 判断显式开启：旧入口 `voomWithQualityWeights(counts, design, var.design = NULL, var.group = NULL, method = "genebygene", normalize.method = "none", span = 0.5, adaptive.span = TRUE, maxiter = 50, tol = 1e-5)`；采用新入口时同样用显式开关（`sample.weights = TRUE`，完整调用随 P-1 冻结）。记录估计的样本权重、`var.design`/`var.group` 与所用选项。 | B | 决策表 limma-voom P-3；`limma/Rd/voom.Rd`、`limma/Rd/voomWithQualityWeights.Rd`；User's Guide §15.6–15.7；`extraction.jsonl` `voom_variant` |

待澄清：
- P-2：决策表写"显式转成 `lfc=log2(fc)`（同时 `fc` 按登记策略显式处理）"，但没有给出 `fc` 的登记策略。锁定版 `treat.Rd` 写明 `lfc` 一旦指定即优先于 `fc`。问题：调用中 `fc` 应显式写成与用户值一致的 `fc = <用户 fc>`（与 `lfc = log2(fc)` 同义冗余），还是写成 `fc = 1.2` 的函数默认并注明被 `lfc` 覆盖？在确认之前，建议 S2 采用前者（两者取同一用户值），以免登记表出现一个不起作用的 1.2。

对上一节草案原文的更正（草案文本保留不改，更正记在这里）：
- P-1 草案"keep `voom + lmFit` as the default (majority, and the definition)"：锁定指南 §15.7 明确推荐 `voomLmFit`，历史文献的 voom 家族频次不能推翻该推荐；且 24/24 是 voom 家族而非独立 `voom + lmFit`（2026-09-27 更正）。
- P-3 草案"on by user flag or when deseq2-qc-style QA flags a sample (never automatic)"前后含混：统一为 QA 标记只提示、由用户显式启用（2026-09-27 更正）。

- D 表：D-V1、D-V5、D-07 的 Decision 已同步；V 节与 D-V1 的计数口径按决策表更正（见行内标注）。
- 计划同步：ENGINEERING_PLAN §1.2 A 的 limma-voom 核心函数仍列 `voom`/`voomWithQualityWeights`、`lmFit`；方向改为 `voomLmFit` 后需同步，本次不改计划，记入 `SUITE.md`。
