# PACK -- sva-batch

Evidence pack of module `sva-batch` (ENGINEERING_PLAN 2.3). Status: **S0 complete (L1 locked release,
L3/L4 collected and independently verified, 2026-09-27); S1 drafted -- the pending
decisions at the end are the owner's. S2 (engine) not started** (built locally).

| Layer | Status | Where |
|---|---|---|
| L1 | sva 3.60.0 and limma 3.68.5 (Bioconductor 3.23, git.bioconductor.org RELEASE_3_23): sva vignette (source + rendered text), Rd of `ComBat`, `ComBat_seq`, `sva`, `svaseq`, `num.sv`, limma `removeBatchEffect`, `defaults.tsv` (sva has no NEWS file in the release branch) | `L1_bioc3.23/` (manifest with sha256 and git commit) |
| L2 | sva vignette sections 3-9 (sva / num.sv, f.pvalue and limma with surrogate variables, ComBat, ComBat-Seq, batch in the linear model); limma `removeBatchEffect` help page | cited below |
| L3 | 10 open-access full texts (tier-A journals), close-read notes | `literature/l3_notes.md` |
| L4 | 30 open-access articles 2020-2026 (whitelisted journals, CC BY / CC BY-NC, PubMed-echoed); **21 of 30 apply** -- 9 correct other data (DNA methylation 2, CRISPR screens 2, proteomics 1, metabolomics 1, imaging / flow features 1, IHC tissue microarray scores 1) or use the English word "combat" (1) | `literature/corpus.jsonl`, `extraction.jsonl`, `efetch/` |
| Verification | 6 of 30 articles, 26 records: 26 pass (100.0 %), PMID echo 6/6 -> **pass** | `literature/verification.json` |

## T -- table skeleton

- Batch report: batch variable, levels and sizes, cross-table batch x biological group (confounding
  check), method and options (`mod` / `group`, `par.prior`, `mean.only`, `ref.batch`; n.sv for sva),
  and what the corrected matrix is used for. Output: the corrected matrix (display) and/or the batch
  terms / surrogate variables to add to the DE design.

## F -- figure grammar

| Figure | Grammar | Source |
|---|---|---|
| Before / after PCA | PC1 vs PC2 coloured by batch, shaped by group, two panels (raw vs corrected) | exemplars (PCA / UMAP before and after correction); `_shared` `os_pca_plot` |
| ComBat prior plots | kernel density vs parametric estimate of the batch effect | `ComBat(prior.plots = TRUE)`, vignette section 7 |

## W -- wording

Exemplar structure (L3): "batch effects were corrected with ComBat-seq (sva package)", often without the
preserved covariate and without saying what the corrected data were used for. Template to write at S2:
sva version, method, batch variable, preserved biological covariates (`mod` / `group`), and the use of
the corrected matrix (display only, or the model that carries the batch term / SVs for testing).

## V -- variant frequencies (L4: 21 applicable papers)

Source: `collect.py summarize sva-batch`.

| Parameter (PACK) | Reported values | n.r. | Majority among reporting papers |
|---|---|---|---|
| Method (D-S1) | ComBat-seq 8; ComBat 7 (1 via COCONUT); sva / svaseq / SmartSVA 4; ComBat + sva 2 | 0 | ComBat-seq 8 / ComBat 7 (count vs log data) |
| Use of the corrected data (D-S2) | **input to DE testing on the corrected matrix (DESeq2 5, limma 1, DESeq2 after clustering 1) 7**; input to custom z-score DE / hit calling 3; visualisation only 2 (one with batch as a DESeq2 covariate for the test); cross-cohort comparison / classifier 2; eQTL / TWAS 1; SVs as covariates in the DESeq2 design 1; benchmark 1 | 4 | corrected matrix used for testing (11 of 17) （2026-09-27 更正：原写 10 of 17，漏计一条含检验的记录；11 = DESeq2/limma 7 + 自定义 z-score 差异/hit calling 3 + PMC12667713 的 benchmark 1——若要排除基准比较，须显式重新定义类别，该文当前 `_applies = yes`；recount 2026-09-27）；display only or batch/SVs in the design 3/21 |
| Number of SVs (D-S3) | 1: 1 | 20 | -- |
| Covariates preserved, `mod` / `group` (D-S4) | biological covariates preserved 3; none 2; study site 1 | 15 | -- (6 reporting) |
| sva version (X) | 3.18.0 - 3.52.0 (6 versions); SmartSVA 0.1.3 | 14 | -- |

## C -- anchors

`acceptance/data/ANCHOR_REGISTRY.md` row 8: bladderbatch (`bladderEset`), the sva vignette's own data for
`sva`, `num.sv` (vignette prints "Number of significant surrogate variables is: 2") and `ComBat`;
**package not installed** in either tier (pending decision in the registry). The vignette's
`ComBat_seq` section uses a simulated `rnbinom` matrix -> a replay anchor only.

## D -- defaults: function default / vignette / exemplar majority

Function defaults from `L1_bioc3.23/{sva,limma}/defaults.tsv` (sva 3.60.0, limma 3.68.5).

| Id | Parameter | (1) function default | (2) vignette / help page | (3) exemplar majority (V) | Draft | Decision |
|---|---|---|---|---|---|---|
| D-S1 | method by data type | -- | counts: `ComBat_seq` ("specifically targets RNA-Seq count data ... preserve the integer nature"); log-scale / arrays: `ComBat`; unknown batch: `sva` / `svaseq` | ComBat-seq 8 (counts), ComBat 7 | counts -> ComBat_seq, log data -> ComBat, unknown batch -> svaseq / sva | vignette + majority agree |
| D-S2 | use of the corrected data | -- | sva vignette 7: f.pvalue on ComBat-adjusted data ("P-values ... now account for the known batch effects"); vignette 9 and 5-6: batch or SVs in `mod` / `mod0` ; **limma `removeBatchEffect`: "not intended to be used prior to linear modeling ... better to include the batch factors in the linear model"** | corrected matrix into testing 11/17 （2026-09-27 更正：原写 10/17；recount 2026-09-27，其中 DESeq2/limma 7/21） | batch term (known batch) or SVs (unknown) in the DE design of the DE module; corrected matrix for display | **S1 P-1 (A, owner 2026-09-27)**: corrected matrix for display / descriptive scoring only; a known corrected-matrix source is **refused** by the standard DE path |
| D-S3 | `ComBat(mod)` / `ComBat_seq(group, covar_mod)` | NULL (no covariate preserved); `full_mod = TRUE` | vignette ComBat example: `mod = model.matrix(~1)` (intercept only); ComBat_seq example with and without `group` | 3 preserve covariates, 2 none (15/21 n.r.) | require the biological group to be passed; refuse when batch and group are confounded | **S1 P-2 (A, owner 2026-09-27)**: research variable / design required (continuous allowed); full confounding refused, partial confounding reported with a contrast-estimability check |
| D-S4 | `ComBat(par.prior, mean.only, ref.batch)` | TRUE, FALSE, NULL | parametric by default; `mean.only = TRUE` "for milder batch effects"; `ref.batch` for training / test designs | n.r. | function defaults | function default |
| D-S5 | `ComBat_seq(shrink, shrink.disp)` | FALSE, FALSE | defaults ("Shrinkage off") | n.r. | FALSE, FALSE | function default |
| D-S6 | `sva(n.sv, method, numSVmethod)` | n.sv estimated, "irw", "be"; `num.sv(method = "be", B = 20)` | `num.sv(edata, mod, method = "leek")` in section 3 | 1 paper reports n.sv | estimate with `num.sv(method = "be")`, report n.sv | **S1 P-3 (B, owner 2026-09-27)**: `num.sv(method = "be", B = 20, vfilter = NULL, seed = <fixed>)`, n.sv passed explicitly; `"leek"` as an explicit sensitivity option |

## X -- version-sensitive behaviour

- The release branch of sva 3.60.0 has no NEWS file; version changes cannot be documented from L1.
  Exemplar versions span 3.18 - 3.52. Golden files are re-generated in the container (ENGINEERING_PLAN 3.5).
- limma `removeBatchEffect` gained `group` (convenience for the design) -- see its Rd; the help page's
  warning against modelling on the output is unchanged.

## S1 drafts and pending decisions (the owner decides; no default is fixed yet)

- **P-1 Corrected matrix as test input.** 10 of 17 reporting papers test on the corrected matrix (7 with
  DESeq2 / limma), 3 keep it for display or model the batch / SVs. Sources differ: the sva vignette runs
  f.pvalue on ComBat-adjusted data; limma's help page says `removeBatchEffect` output is not for linear
  modelling and the batch belongs in the model. Draft: sva-batch outputs the corrected matrix for
  display only; for testing it hands the batch term / surrogate variables to the DE module's design
  (deseq2-wald, edger-qlf, limma-*), and the DE module warns when it receives a batch-corrected matrix.
  This is what the module definition already says (ENGINEERING_PLAN 1.2 table A: the corrected
  matrix is "only for visualisation and downstream scoring, not fed to differential analysis") but it
  departs from the exemplar majority, so the owner confirms it.
- **P-2 Preserving the biological group.** `mod` / `group` default to NULL (nothing preserved); only 3 of
  21 papers state that they preserved covariates. Draft: the biological group is a required argument;
  a fully confounded batch x group table stops with an error; partial confounding gives a warning.
- **P-3 Surrogate variables.** Draft: `num.sv(method = "be")` (the function default; the vignette also
  shows "leek"), n.sv always reported; SVs are added to the DE design, never regressed out for testing.
- **P-4 Anchor.** bladderbatch is not installed in either tier (ANCHOR_REGISTRY open item); the S2 build
  needs it or an alternative registered dataset.

## S1 审定附录（2026-09-27，所有者批准）

所有者于 2026-09-27 裁决：`docs/build/S1_DECISION_TABLE_M1M2.md`（下称"决策表"）中 A、B 类项目一律按「建议」栏批准（建议含可选项的，默认值与可选项一并冻结），C 类保持待定。上一节 "S1 drafts and pending decisions" 保留为历史；与本附录不一致处以本附录为准。下列参数在调用中一律显式写出，即使等于函数默认值（ENGINEERING_PLAN §3.3）。L1 路径相对于 `L1_bioc3.23/`。

| 编号 | 决定 | 类别 | 依据 |
|---|---|---|---|
| P-1 校正矩阵能否进入 DE | 按套件边界：校正矩阵（`ComBat`、`ComBat_seq`、`removeBatchEffect` 的输出）只用于展示和描述性打分。DE 使用未校正的合法输入，已知 batch 或 SV 显式放进 DE 模块的设计。输入来源已知为校正矩阵时，标准 DE 路径**拒绝运行**（不是警告后照跑）。不把 limma 的限制夸大为 ComBat 在任何情境都无效。GSVA 分数若继续作推断，另须满足设计/不确定性要求（见 gsva-score P-3）。 | A | 决策表 sva-batch P-1；`limma/Rd/removeBatchEffect.Rd` Note；`sva/Rd/ComBat.Rd`、`sva/Rd/ComBat_seq.Rd`；`sva/vignettes/sva.Rnw` "Applying the ComBat function to adjust for known batches"、"Adjusting for surrogate variables using the limma package"；ENGINEERING_PLAN §1.2 A |
| P-2 保留生物学效应与混杂 | 研究变量/待检验设计必填（允许连续变量，不限二分类 group）：`ComBat(dat, batch = <batch>, mod = <含研究变量的设计矩阵>, par.prior = TRUE, mean.only = FALSE, ref.batch = NULL)`；`ComBat_seq(counts, batch = <batch>, group = <分类研究变量或 NULL>, covar_mod = <其他需保护的协变量矩阵或 NULL>, full_mod = TRUE, shrink = FALSE, shrink.disp = FALSE)`（`group` 与 `covar_mod` 不得同时为 NULL）；`sva/svaseq(dat, mod = <full 模型：研究变量 + 调整变量>, mod0 = <null 模型：去掉研究变量>)`。运行前验证 batch 与研究变量的联合可估性：完全混杂拒绝；部分混杂报告，并检查目标 contrast 可估。保护模型同时用于展示校正和向下游 DE 设计的传递。`par.prior`、`mean.only`、`ref.batch`、`shrink`、`shrink.disp` 取值来自 D-S4/D-S5（函数默认），按 §3.3 写出。 | A | 决策表 sva-batch P-2；`sva/Rd/ComBat.Rd`、`sva/Rd/ComBat_seq.Rd`、`sva/Rd/sva.Rd`；`sva.Rnw` "Setting up the data"、"Surrogate variables versus direct adjustment"、ComBat-Seq 节；跨模块 deseq2-wald `DESeq2.Rmd` "Model matrix not full rank" |
| P-3 SV 数与估计法 | `n.sv <- num.sv(dat, mod = <full 模型>, method = "be", B = 20, vfilter = NULL, seed = <套件固定 seed，写入 provenance>)`；所得 `n.sv` 显式传给 `sva(dat, mod, mod0, n.sv = n.sv, method = "irw", vfilter = NULL, B = 5, numSVmethod = "be")` 或 `svaseq(dat, mod, mod0, n.sv = n.sv, method = "irw", vfilter = NULL, B = 5, numSVmethod = "be", constant = 1)`（`sva`/`svaseq` 的 `method`、`B`、`constant` 为锁定版函数默认，按 §3.3 写出，决策表未另作取舍）。输出模型公式与 SV 数。可选 `num.sv(method = "leek")` 作为明确声明的敏感性方案。所有 SV 加入 DE 设计，不先回归掉再检验。 | B | 决策表 sva-batch P-3；`sva/Rd/num.sv.Rd`、`sva/Rd/sva.Rd`、`sva/Rd/svaseq.Rd`；`sva.Rnw` "Applying the sva function to estimate batch and other artifacts"、方差过滤节 |
| P-4 bladderbatch 锚点 | 后续补锁定版本的 `bladderbatch`，分别覆盖 ComBat 与"SV 入模型"两条链；另用指南中的模拟计数覆盖 `ComBat_seq`；不声称同一锚点验证所有方法。替代数据须重新登记，不得把不同数据的结果当作指南打印值。 | B | 决策表 sva-batch P-4；`sva.Rnw` "Overview"、"Setting up the data from an ExpressionSet"、"ComBat-Seq for batch adjustment on RNA-Seq count data"、"sva for sequencing (svaseq)"；`acceptance/data/ANCHOR_REGISTRY.md` 第 8 行 |

对上一节草案原文的更正（草案文本保留不改，更正记在这里）：
- P-1 草案"10 of 17 reporting papers test on the corrected matrix"：应为 11/17（2026-09-27 更正，见 V 节行内标注）。
- P-1 草案"the DE module warns when it receives a batch-corrected matrix"：只警告不足以贯彻模块契约，已改为标准 DE 路径拒绝已标记来源的校正矩阵（2026-09-27 更正，决策表第 10 条）。
- P-2 草案"`mod` / `group` default to NULL"：`ComBat(mod = NULL)`、`ComBat_seq(group = NULL, covar_mod = NULL)` 如此，但 `sva(mod = 必填, mod0 = NULL)`，不能把所有函数说成 mod 默认 NULL（2026-09-27 更正）。

待澄清：
- P-2：`ComBat_seq` 的研究变量为连续变量时，决策表只写"允许连续变量"，未写应放入 `covar_mod` 还是另行处理。本附录按 Rd 的参数分工写成"分类放 `group`、其余放 `covar_mod`"，请所有者确认。

- C 类待定：无。
- D 表：D-S2、D-S3、D-S6 的 Decision 已同步；V 节与 D-S2 的检验用途计数按决策表复算更正为 11/17（见行内标注）。
