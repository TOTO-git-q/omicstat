# PACK -- limma-array

Evidence pack of module `limma-array` (ENGINEERING_PLAN 2.3). Status: **S0 complete (L1 locked release,
L3/L4 collected and independently verified, 2026-09-27); S1 drafted -- the pending
decisions at the end are the owner's. S2 (engine) not started** (built locally). The module receives a
normalized log-expression matrix; reading raw files (`read.maimages`, `rma`, `neqc`) belongs in the
fixture script (ANCHOR_REGISTRY row 6).

| Layer | Status | Where |
|---|---|---|
| L1 | limma 3.68.5 (Bioconductor 3.23, git.bioconductor.org RELEASE_3_23): limma User's Guide (release PDF, text), Rd of `normalizeBetweenArrays`, `avereps`, `lmFit`, `contrasts.fit`, `eBayes`, `topTable`, NEWS, `defaults.tsv` | `L1_bioc3.23/` (manifest with sha256 and git commit) |
| L2 | limma User's Guide 3.2 quick start (Affymetrix: `eBayes(fit, trend = TRUE, robust = TRUE)` "often helpful"), ch. 7 "Filtering unexpressed probes", 17.4 Agilent case study (normexp + quantile, probe filter, `eBayes(trend = TRUE, robust = TRUE)`) | cited below |
| L3 | 10 open-access full texts (tier-A journals), close-read notes | `literature/l3_notes.md` |
| L4 | 30 open-access articles 2020-2026 (whitelisted journals, CC BY / CC BY-NC, PubMed-echoed); **13 of 30 apply** -- 17 run limma on other data: RNA-seq (9), mass-spectrometry / SomaScan proteomics (6), CUT&RUN / ATAC peaks (1), methylation / proteomic residualisation (1) | `literature/corpus.jsonl`, `extraction.jsonl`, `efetch/` |
| Verification | 6 of 30 articles, 41 records: 41 pass (100.0 %), PMID echo 6/6 -> **pass** | `literature/verification.json` |

Profile lesson (applies to later collections): the Methods signal `lmFit`/`eBayes` does not identify
the platform; 13 applicable papers is thin. A re-collection that requires an array platform term
(Affymetrix, Agilent, Illumina BeadChip, `rma`, `neqc`, GPL accession) in the same sentence is
possible at small cost if the owner wants more exemplars (open item, section S1).

## T -- table skeleton

- Feature table per contrast (`topTable`): probe/feature id, symbol, Entrez id, logFC, AveExpr, t,
  P.Value, adj.P.Val, B; `decideTests` summary (Down / NotSig / Up) per coefficient, as printed in
  User's Guide 17.4.7.

## F -- figure grammar

Same family as limma-voom: MD / volcano, `plotSA` (sigma vs AveExpr, the check for `trend = TRUE`), MDS.

## W -- wording

Exemplar structure (L3): the pre-processing (RMA / gcRMA / normexp + quantile) is described in more
detail than the test, which is usually "the limma package (linear models with empirical Bayes)"; eBayes
options are never stated (0 of 13). Template to write at S2: platform and pre-processing (from the
fixture), probe filter, collapse of duplicate probes, `eBayes(trend, robust)`, BH, FDR cutoff.

## V -- variant frequencies (L4: 13 applicable papers)

Source: `collect.py summarize limma-array`.

| Parameter (PACK) | Reported values | n.r. | Majority among reporting papers |
|---|---|---|---|
| Normalization (D-A1; fixture side) | RMA family 5; gcRMA 1; background + quantile 2; normexp + cyclic loess (Agilent) / neqc (Illumina) 1 | 4 | **RMA** (5 of 9) |
| Probe filter (D-A2) | 7 different rules (expression threshold, control / unannotated probes, one probe per gene by CV or t) | 6 | none |
| eBayes options (D-A3) | -- | 13 | none stated |
| FDR cutoff (D-08) | 0.05: 4; 0.01: 1; 15 %: 1 | 7 | 0.05 (4 of 6) |
| Adjustment (D-08) | Benjamini-Hochberg 4 | 9 | BH (4/4) |
| Post hoc FC filter (D-07) | 0.5: 1 | 12 | -- |
| limma version (X) | 3.26.9, 3.36, 3.40.5 | 10 | -- |

## C -- anchors

`acceptance/data/ANCHOR_REGISTRY.md` row 6: GSE33005 = E-GEOD-33005 (rat thymus, Agilent, 19 arrays,
files F5 raw + F6 SDRF), limma User's Guide 17.4. Printed values in the release guide: after the probe
filter `dim(yfilt)` = **27024 x 19**; `summary(decideTests(fit[,-1]))` for 10 ml/kg corn oil: **Down 756,
NotSig 24734, Up 1534** (2 and 5 ml/kg: 0 / 27024 / 0); top gene RT1-Bb logFC 9.33. The fixture script
does `read.maimages` -> `backgroundCorrect(normexp)` -> `normalizeBetweenArrays(quantile)` -> filter;
the module starts at `lmFit`.

## D -- defaults: function default / User's Guide / exemplar majority

Function defaults from `L1_bioc3.23/limma/defaults.tsv` (limma 3.68.5).

| Id | Parameter | (1) function default | (2) User's Guide 3.23 | (3) exemplar majority (V) | Draft | Decision |
|---|---|---|---|---|---|---|
| D-A1 | normalization (fixture) | `normalizeBetweenArrays(method = NULL)` -> quantile for single-channel | Affymetrix: `rma` / `gcrma`; Agilent: normexp + quantile; Illumina: `neqc` | RMA 5/9 | platform rule in the fixture; module input = normalized log2 matrix | guide + majority agree |
| D-A2 | probe filter | none | ch. 7: keep probes above background on >= k arrays (k = smallest group), or an `Amean` cutoff; drop control / unannotated probes | 7 rules, none repeated | guide rule when detection / background data exist, otherwise none; always drop control probes | **S1 P-2 (B, owner 2026-09-27)**: drop explicit control probes; background rule only with platform background data and an explicit k |
| D-A3 | `eBayes(trend, robust)` | FALSE, FALSE | 3.2 and 17.4: `trend = TRUE, robust = TRUE` "often helpful, increasing power" （2026-09-27 更正/限定：quick start 只说 often helpful，不能推出所有芯片都必须 TRUE/TRUE；Rd 把 `trend` 与均值—方差关系联系起来） | never stated (0/13; silence is not FALSE) | **disagreement**: function default vs guide | **S1 P-1 (B, owner 2026-09-27)**: TRUE/TRUE preset for the registered Agilent (and corresponding) platform, user override kept; other platforms report and check the mean-variance trend |
| D-A4 | duplicate probes | none | `avereps` (collapse by ID) where needed | 4 papers collapse (average, or keep one probe per gene by t or CV) | keep probes; `avereps` as an option | **S1 P-2 (B, owner 2026-09-27)**: keep distinct probes; `avereps` only for a user-specified, validated technical ID; max-t probe selection rejected as a default |
| D-08 | adjustment, FDR | `topTable(adjust.method = "BH")` | BH | BH 4/4; 0.05 4/6 | BH, 0.05 | same as deseq2-wald |
| D-07 | post hoc FC filter | none | -- | 1 paper | none (display filter only) | same as deseq2-wald P-2 (owner 2026-09-27: display-only, off by default) |

## X -- version-sensitive behaviour (L1 NEWS, limma 3.68.5)

- 3.62.0: new hyperparameter estimation in `eBayes` / `treat` / `squeezeVar` when residual df are unequal
  (e.g. probes with missing values); `legacy = TRUE` restores the old fit.
- `eBayes(robust = TRUE)` and `trend = TRUE` change the moderated statistics; a result table must state
  both options (the exemplars never do).

## S1 drafts and pending decisions (the owner decides; no default is fixed yet)

- **P-1 eBayes trend / robust.** Function default FALSE/FALSE; the locked User's Guide uses
  `trend = TRUE, robust = TRUE` in its quick start and in the Agilent case study (the anchor). No
  exemplar states the options. Draft: `trend = TRUE, robust = TRUE` (guide + anchor), stated in the
  Methods sentence; the owner decides because it departs from the function default. The same rule
  would apply to limma-dupcor on arrays (its P-3).
- **P-2 Probe filtering and duplicates.** Draft: drop control probes; apply the guide's
  "above background on >= k arrays" rule when the platform provides it, else no expression filter;
  duplicates kept (no automatic collapse) unless the user asks for `avereps`.
- **P-3 Re-collection.** 13 applicable papers; optional re-collection with a platform-term signal (see
  the profile lesson above).

## S1 审定附录（2026-09-27，所有者批准）

所有者于 2026-09-27 裁决：`docs/build/S1_DECISION_TABLE_M1M2.md`（下称"决策表"）中 A、B 类项目一律按「建议」栏批准（建议含可选项的，默认值与可选项一并冻结），C 类保持待定。上一节 "S1 drafts and pending decisions" 保留为历史；与本附录不一致处以本附录为准。下列参数在调用中一律显式写出，即使等于函数默认值（ENGINEERING_PLAN §3.3）。L1 路径相对于 `L1_bioc3.23/limma/`。

| 编号 | 决定 | 类别 | 依据 |
|---|---|---|---|
| P-1 `eBayes` trend/robust | 当前已登记的 Agilent（及相应）平台预设：`eBayes(fit, trend = TRUE, robust = TRUE, proportion = 0.01, stdev.coef.lim = c(0.1, 4), span = NULL, winsor.tail.p = c(0.05, 0.1), legacy = NULL)`，保留用户显式覆盖。其他已归一化平台须报告并检查均值—方差趋势（`plotSA`），不称"芯片一律 TRUE"。与 limma-dupcor 使用同一平台规则；RNA-seq voom 不机械继承芯片 `trend`。 | B | 决策表 limma-array P-1；`Rd/eBayes.Rd` Usage、Details；`vignettes/usersguide.rendered.txt` §3.2、§17.4 |
| P-2 探针过滤与重复探针 | 去除明确的控制探针。仅在平台提供背景信息时使用"至少 k 张芯片高于背景"规则，`k` 显式给出（指南：最小处理组合的重复数），且在归一化后、建模前执行；否则不做表达过滤。默认保留不同探针；只有用户指定并经验证为同一技术 ID 时才 `avereps(x, ID = <该技术 ID>)`，并保留探针→基因映射。不同靶位的探针不能仅因同一 gene symbol 视为技术重复；"按最大检验 t 选探针"拒绝作为通用默认。 | B | 决策表 limma-array P-2；`Rd/avereps.Rd`；User's Guide 第 7 章 "Filtering"、"Probe Filtering and Array Quality Weights" |
| P-3 是否重新采集 | 后续以平台词分层补采，保留旧语料与判定记录；当前统计按 N = 13 发布，不凑成 N = 30。本次不执行采集。 | B | 决策表 limma-array P-3；`literature/corpus.jsonl`、`extraction.jsonl`（`_applies`、`ebayes`）；`SUITE.md` M1-S0 偏离之处第 4 项 |

待澄清：
- P-1：决策表写"TRUE/TRUE 作为当前已注册 Agilent/相应平台预设"，"其他已归一化平台需报告并检查均值—方差趋势"，没有说明其他平台（例如 Affymetrix RMA、Illumina neqc）的**预设值**。问题：这些平台的默认是也取 TRUE/TRUE（加 `plotSA` 检查与报告），还是不设预设、要求用户显式选择？在确认之前，本附录只冻结已登记 Agilent 平台的预设。
- P-2："相应平台"与"平台背景信息"的判定口径（哪些输入字段算作背景信息）未在决策表给出；S2 须在输入契约里写明，并回报所有者。

- C 类待定：无。
- D 表：D-A2、D-A3、D-A4、D-07 的 Decision 已同步；D-A3 的指南表述按决策表第 8 条限定（见行内标注）。
