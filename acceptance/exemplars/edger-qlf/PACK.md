# PACK -- edger-qlf

Evidence pack of module `edger-qlf` (ENGINEERING_PLAN 2.3). Status: **S0 complete (L1 locked release,
L3/L4 collected and independently verified after one rework round, 2026-09-27); S1 drafted -- the pending decisions at the
end are the owner's. S2 (engine) not started** (built locally).

| Layer | Status | Where |
|---|---|---|
| L1 | edgeR 4.10.5 (Bioconductor 3.23, git.bioconductor.org RELEASE_3_23): edgeR User's Guide (release PDF, text) and intro vignette, Rd of `DGEList`, `filterByExpr`, `normLibSizes`, `calcNormFactors`, `estimateDisp`, `glmQLFit`, `glmQLFTest`, `glmTreat`, `topTags`, NEWS, `defaults.tsv` | `L1_bioc3.23/` (manifest with sha256 and git commit) |
| L2 | edgeR User's Guide 1.4 "Quick start", ch. 2 (QL vs LRT), 4.4 case study "RNA-Seq profiles of mouse mammary gland" (GSE60450) | cited below |
| L3 | 10 open-access full texts (tier-A journals), close-read notes | `literature/l3_notes.md` |
| L4 | 30 open-access articles 2020-2026 (whitelisted journals, CC BY / CC BY-NC, PubMed-echoed); **23 of 30 apply** (7 run edgeR QL on other data: ChIP / ATAC peaks, oligo-pool or proximity-labelling counts, pseudobulk single-cell, or use limma / DESeq2 for their RNA-seq) | `literature/corpus.jsonl`, `extraction.jsonl`, `efetch/` |
| Verification | round 1: 6 articles, 54 records, 50 pass (92.6 %) -> **rework** (4 values stated in the Methods recorded as "not reported"); extraction redone for all 30 articles (11 lines corrected); round 2 (new seed, 6 other articles): 54/54 pass (100 %), PMID echo 6/6 -> **pass**; the 4 round-1 lines re-checked and correct | `literature/verification_round1.json`, `verification.json` |

## T -- table skeleton

- Feature table per contrast (`topTags(n = Inf)`): gene, logFC, logCPM, F, PValue, FDR; with `glmTreat`:
  logFC, unshrunk.logFC, logCPM, PValue, FDR. `decideTests` summary (Down / NotSig / Up) as in the
  User's Guide.

## F -- figure grammar

| Figure | Grammar | Source |
|---|---|---|
| MD plot | logFC vs logCPM, DE genes at FDR 5 % highlighted | `plotMD(qlf)`; User's Guide 4.4.8 |
| QL dispersion | raw / squeezed / trended QL dispersion vs average logCPM | `plotQLDisp(fit)` |
| BCV | biological coefficient of variation vs logCPM (only with `estimateDisp`) | `plotBCV(y)`; ENGINEERING_PLAN lists it as a product |
| MDS | `plotMDS` of logCPM | User's Guide 4.4.5 |

## W -- wording

Exemplar structure (L3): "genes were filtered (<rule>), normalised by TMM, and tested with the
quasi-likelihood F-test (glmQLFit / glmQLFTest) in edgeR", then FDR (and often a fold-change) cutoff.
`robust` and the edgeR version are rarely given. Template to write at S2: edgeR version and whether the
new (edgeR >= 4.2 default) or legacy QL method was used, filter (`filterByExpr` with the design), TMM,
`glmQLFit(robust = ...)`, `glmQLFTest` or `glmTreat(lfc = ...)`, BH, FDR cutoff.

## V -- variant frequencies (L4: 23 applicable papers, after the rework)

Source: `collect.py summarize edger-qlf`.

| Parameter (PACK) | Reported values | n.r. | Majority among reporting papers |
|---|---|---|---|
| Low-expression filter (D-E1) | `filterByExpr` 2 (+1 "filtered by expression"); 15 bespoke CPM / count / RPKM rules, none repeated | 5 | none (filterByExpr is the only named function) |
| Normalization (D-E2) | TMM 11 (various spellings); cqn 2; library-size scaling 1 | 9 | **TMM** (11 of 14) |
| `glmQLFit(robust)` (D-E3) | TRUE 1 | 22 | -- (1 paper) |
| `glmTreat` (D-E4) | lfc = log2(1.2): 2 (one also log2(1.5)) | 21 | -- (2 papers) |
| FDR cutoff (D-08) | 0.05: 10; 0.01: 2; P < 0.05 (not labelled adjusted): 1 | 10 | **0.05** (10 of 13) |
| Adjustment (D-08) | Benjamini-Hochberg 7 | 16 | **BH** (7/7) |
| Post hoc FC filter (D-07) | 9 papers; FC 2 / abs(log2FC) 1 is the most frequent (about 5), others 1.5, 0.58, 5 | 14 | abs(log2FC) >= 1, but only among the 9 filtering papers |
| edgeR version (X) | 3.16.5 - 3.40.2 (12 papers); 4.0.16 (1) | 10 | 12 of 13 reporting papers used edgeR 3.x (legacy QL method) （2026-09-27 更正：这是 version artefact，不是 12 篇显式报告 `legacy = TRUE`；4.0.16 那篇也不能仅凭版本认定用了新法——新法 4.0.0 引入、4.2.0 才成为默认） |

Sensitivity count (added 2026-09-27, owner decision on the verifier Note, see the S1 appendix): excluding PMC8532352 (MINTIE: `glmQLFit` + final test `glmLRT`) from the "final QLF pipeline" denominator gives N = 22: edgeR 3.x 11 of 12 version-reporting papers, `robust = TRUE` 0/22, post hoc FC filter 8/22, `glmTreat` 2/22. The table above keeps the current N = 23; `_applies` is not changed.

## C -- anchors

`acceptance/data/ANCHOR_REGISTRY.md` row 4: GSE60450 (mouse mammary gland, 6 groups x 2, file F3
`GSE60450_Lactation-GenewiseCounts.txt.gz`), edgeR User's Guide 4.4. Printed values in the locked
release's guide: `filterByExpr` keeps **15969** of 27179 genes; `estimateDisp(robust = TRUE)` common
dispersion **0.0134**; `glmQLFit(y, design, robust = TRUE)` `fit$dispersion` **0.013**; QL F-test
B.pregnant - B.lactate: **Down 2607, NotSig 10546, Up 2816** (top gene Mrgprf logFC -5.15); `glmTreat(lfc =
log2(1.2))`: **Down 1533, NotSig 12573, Up 1863**. These are printed-value anchors for S2.

## D -- defaults: function default / User's Guide / exemplar majority

Function defaults from `L1_bioc3.23/edgeR/defaults.tsv` (edgeR 4.10.5).

| Id | Parameter | (1) function default | (2) User's Guide 3.23 | (3) exemplar majority (V) | Draft | Decision |
|---|---|---|---|---|---|---|
| D-E1 | filter | `filterByExpr(min.count = 10, min.total.count = 15, large.n = 10, min.prop = 0.7)` | quick start and 4.4.4: `filterByExpr(y)` (4.4.4 keeps 15969 of 27179) | named function 2 of 18; rest bespoke | `filterByExpr(y, design)` | guide (no majority) |
| D-E2 | normalization | `normLibSizes(method = "TMM")` | TMM "to eliminate composition biases" | TMM 11/14 | TMM | guide + majority agree |
| D-E3 | dispersion step | `estimateDisp` separate function | 4.4.7: "this step is now optional as all the NB dispersion estimates will not be used further under the latest QL pipeline" | n.r. | skip for the test; run only for the BCV plot | guide |
| D-E4 | `glmQLFit(legacy)` | FALSE (new QL method, edgeR >= 4.2.0) | new method | 12 of 13 reporting papers used edgeR 3.x (legacy method; version artefact, not an explicit `legacy = TRUE` -- 2026-09-27 更正) | `legacy = FALSE` (locked release) and say so in the Methods sentence | **S1 P-1 (A, owner 2026-09-27)**: `legacy = FALSE`; TRUE only to reproduce an old analysis, reported separately |
| D-E5 | `glmQLFit(robust)` | FALSE | 4.4.7: "Setting robust=TRUE in glmQLFit is strongly recommended"; quick start omits it | TRUE 1 (22 n.r.; 0/22 with PMC8532352 excluded) | **disagreement**: function default vs guide | **S1 P-2 (A, owner 2026-09-27)**: `robust = TRUE` (guide), `winsor.tail.p = c(0.05, 0.1)` |
| D-E6 | test | `glmQLFTest(coef = ncol(design))`; `glmTreat(lfc = log2(1.2))` | QL F-test; `glmTreat` "to narrow down the list ... more biologically meaningful" | glmTreat 2 | `glmQLFTest` default; `glmTreat` as an option | **S1 P-3 (B, owner 2026-09-27)**: `glmQLFTest` default; `glmTreat(lfc = log2(<user FC>), null = "interval")` only with a user-prespecified FC |
| D-08 | adjustment, FDR | `topTags(adjust.method = "BH")` | BH; "at a FDR of 5%" | BH 7/7; 0.05 10/13 | BH, 0.05 | same as deseq2-wald |
| D-07 | post hoc FC filter | none | `glmTreat` instead | 9 papers | none (display filter only) | **S1 P-3 (B, owner 2026-09-27)**: display-only filter, off by default; same reporting semantics as deseq2-wald P-2 / limma-voom P-2 |

## X -- version-sensitive behaviour (L1 NEWS, edgeR 4.10.5)

- 4.2.0 (2024-04-28): the new QL pipeline becomes the default for `glmQLFit()` (`legacy = FALSE`).
- 4.0.0 (2023-10-25): new QL method (adjusted residual deviances and df for small counts,
  `top.proportion`); off by default in 4.0, on by default from 4.2. Results differ numerically from
  edgeR 3.x, which almost all exemplars used.
  （2026-09-27 补注：锁定版 `glmQLFit.Rd` 自身不一致——`top.proportion` 的参数说明写的是 legacy = TRUE 时的用法，Details 则写新法在 `dispersion = NULL` 时估计；不能用任一段覆盖 Usage/NEWS，S2 须在锁定容器用 `formals()` 与最小调用核查。来源：决策表「PACK 草案中与证据不符或需要限定之处」第 14 条。）
- 4.x: `normLibSizes()` is the new name of `calcNormFactors()`; `decideTestsDGE()` deprecated in favour
  of `decideTests()` (4.2.0).
- Dev tier (Bioconductor 3.22, edgeR 4.8) and container (3.23, 4.10.5) both default to the new method.

## S1 drafts and pending decisions (the owner decides; no default is fixed yet)

- **P-1 New vs legacy QL method.** The locked release uses `legacy = FALSE` by default; 12 of 13 exemplars
  that give a version ran edgeR 3.x (legacy). Draft: keep the release default (new method), print
  "edgeR x.y, quasi-likelihood pipeline of edgeR >= 4.2 (legacy = FALSE)" in the Methods sentence, and
  offer `legacy = TRUE` for users reproducing an older analysis.
- **P-2 `robust`.** Function default FALSE; the guide's case study strongly recommends TRUE; 1 exemplar
  states TRUE. Draft: `robust = TRUE` (guide), stated in the output; the owner decides because it departs
  from the function default.
- **Note (verifier).** PMC8532352 (MINTIE) fits `glmQLFit` but tests with `glmLRT`; counted as applicable
  with a note -- a borderline case the owner may want excluded.
- **P-3 Fold-change criterion.** `glmTreat` in 2 papers, post hoc |logFC| filters in 9. Draft: default
  `glmQLFTest`; `glmTreat(lfc = log2(1.2))` as an option; post hoc filters only as labelled display
  filters (consistent with deseq2-wald P-2 and limma-voom P-2).

## S1 审定附录（2026-09-27，所有者批准）

所有者于 2026-09-27 裁决：`docs/build/S1_DECISION_TABLE_M1M2.md`（下称"决策表"）中 A、B 类项目一律按「建议」栏批准（建议含可选项的，默认值与可选项一并冻结），C 类保持待定。上一节 "S1 drafts and pending decisions" 保留为历史；与本附录不一致处以本附录为准。下列参数在调用中一律显式写出，即使等于函数默认值（ENGINEERING_PLAN §3.3）。L1 路径相对于 `L1_bioc3.23/edgeR/`。

| 编号 | 决定 | 类别 | 依据 |
|---|---|---|---|
| P-1 新旧 QL 方法 | `glmQLFit(y, design, legacy = FALSE, dispersion = NULL, abundance.trend = TRUE, top.proportion = NULL)`；`legacy = TRUE` 只在复现旧分析时由用户显式选择，并另列结果。不把 `estimateDisp` 的 trended dispersion 强塞给新流程（`estimateDisp` 只为 BCV 图运行）。Methods 写明所用 edgeR 版本与 `legacy` 取值。 | A | 决策表 edger-qlf P-1；`Rd/glmQLFit.Rd` Usage、Details；`vignettes/edgeRUsersGuide.rendered.txt` §4.4.7 "Dispersion estimation"；`NEWS.txt` 4.0.0、4.2.0 |
| P-2 `robust` | `glmQLFit(..., robust = TRUE, winsor.tail.p = c(0.05, 0.1))`；输出与 Methods 报告"采用稳健 QL 先验估计"。 | A | 决策表 edger-qlf P-2；`Rd/glmQLFit.Rd`；User's Guide §4.4.7（"Setting robust=TRUE in glmQLFit is strongly recommended"） |
| Note MINTIE（PMC8532352）的计数范围 | 模块范围按**最终检验**定义：该论文（`glmQLFit` 拟合、`glmLRT` 检验）保留为邻近方法实例，从"最终 QLF 流程"频次分母中剔除。V 节仍如实给当前 N = 23，并附排除后的敏感性计数（N = 22：3.x 11/12 报版本、robust TRUE 0/22、事后 FC 8/22、glmTreat 2/22）。本次不改 `_applies`。 | B | 决策表 edger-qlf Note；`literature/extraction.jsonl`（`_applies`、`robust`、`lfc_filter`、`edger_version`）、`literature/verification*.json`；`Rd/glmQLFTest.Rd` Details |
| P-3 FC 判据 | 默认 QL F 零效应检验：`glmQLFTest(fit, coef = <coef>, contrast = <contrast 或 NULL>, poisson.bound = TRUE)`。可选最小效应检验：用户预先指定线性倍数 `fc`，显式换算 `glmTreat(fit, coef = <coef>, contrast = <contrast 或 NULL>, lfc = log2(fc), null = "interval")`；不以函数默认 1.2 作为所有研究的生物学阈值。另设默认关闭的仅展示 FC 筛选，报告语义与 deseq2-wald P-2、limma-voom P-2 共用（零效应主检验／预先指定最小效应检验／仅展示筛选三个字段）。三个包的阈值检验只统一假设目标和 FC 单位，不声称统计方法或 p 值等价。 | B | 决策表 edger-qlf P-3、「跨模块一致性」第 1 行；`Rd/glmTreat.Rd` Usage、Details；`Rd/glmQLFTest.Rd`；User's Guide §2.14、§4.4.8 |

- C 类待定：无。待澄清：无。
- D 表：D-E4、D-E5、D-E6、D-07 的 Decision 已同步；V 节与 D-E4 的版本计数口径按决策表更正，V 节补排除 MINTIE 后的敏感性计数；X 节补注 `glmQLFit.Rd` 内部不一致（见行内标注）。
- 说明：P-3 中 `poisson.bound = TRUE` 是锁定版 `glmQLFTest` 的函数默认（`defaults.tsv`），按 §3.3 显式写出；决策表未对它另作取舍。
