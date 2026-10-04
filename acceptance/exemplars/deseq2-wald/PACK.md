# PACK -- deseq2-wald

Evidence pack of module `deseq2-wald` (ENGINEERING_PLAN 2.3). Status: **L1 (Bioconductor 3.23) and L3/L4
collected and independently verified (2026-09-27); S1 review drafted -- the pending decisions at the end
are the owner's.**

| Layer | Status | Where |
|---|---|---|
| L1 package documentation | dev tier: DESeq2 1.50.2, apeglm 1.32.0, ashr 2.2-63 (Bioconductor 3.22) in `L1/`; **locked release: DESeq2 1.52.0, apeglm 1.34.0 (Bioconductor 3.23, git.bioconductor.org RELEASE_3_23) in `L1_bioc3.23/`** -- vignette anchors and every registered function default identical to 3.22 | `L1*/manifest.tsv` (sha256 per file, git commit) |
| L2 official workflows | read: rnaseqGene workflow source (github.com/mikelove/rnaseqGene); DESeq2 vignette FAQ | cited by section below |
| L3 exemplar papers | **10 open-access full texts** (tier-A journals), close-read notes in `literature/l3_notes.md` | `literature/corpus.jsonl` (layer L3+L4) |
| L4 breadth sample | **30 open-access articles 2020-2026** from 17 whitelisted journals (Europe PMC `METHODS:` search, year-stratified, CC BY / CC BY-NC only); every PMID echoed by PubMed efetch (`literature/efetch/`); 29 of 30 run this analysis part (1 LRT-only paper excluded) | `literature/search_log.json`, `extraction.jsonl` |
| Independent verification | 6 of 30 articles (20 %), 60 records: 59 pass (98.3 %), PMID echo 6/6 -> **pass** | `literature/verification.json` |

Collected with `tools/lit/` (omicstat's own collector over the vendored Claude Science clients). Only
<= 25-word snippets, section paths and hashes are stored; no full text. One verified correction
(PMID 41407857, `lfc_filter`): the paper's second DESeq2 analysis ("Methods > IPA") states |log2FC| > 1
with padj < 0.1; the extraction recorded "not reported" for the primary analysis. Counted below as
reported for that secondary analysis only where noted.

## T -- table skeleton

- Main table (`tables/feature_table.csv`): one row per tested feature: feature_id, symbol, contrast,
  base_mean, log2fc (shrunken), log2fc_se, stat, pvalue, padj, method, shrinkage, n_group1 (target),
  n_group2 (reference), filtered_reason. Sorted by padj (NA last), then feature_id.
- Supplementary table (`tables/deseq2_results_full.csv`): MLE and shrunken log2FC side by side,
  Wald statistic, max Cook's distance -- the columns the vignette's "More information on results
  columns" section describes.
- Paper-facing top list: significant features ordered by padj; the results JSON keeps the top 10.
- Exemplars (L3, 10 papers): no Methods section describes the columns, sorting or truncation of its DE
  table (the collector reads Methods only; tables live in Results / supplements). The table skeleton
  therefore stays as designed from the vignette's results columns.

## F -- figure grammar

| Figure | Grammar | Source |
|---|---|---|
| Volcano | x = log2FC (shrunken), y = -log10 padj; up red / down blue / ns grey; dashed line at -log10(alpha), at +/- lfcThreshold only when it is > 0; counts as direct labels; 10 labels per side | `_shared` FIGURE_STYLE sec 8.1; thresholds = the test's |
| MA | x = mean of normalized counts (log10), y = log2FC; significant coloured; triangles at the limit | vignette "MA-plot" (`plotMA` convention) |
| Top heatmap | row z-scores of `vst(blind = FALSE)` for the 50 smallest padj, rows clustered, columns grouped reference first | vignette "Heatmap of the count matrix"; "Blind dispersion estimation" |

Exemplars: only 1 of the 10 L3 papers names a figure type for the DESeq2 result in its Methods
(volcano plots drawn with EnhancedVolcano from DESeq2 output, no thresholds stated); figure grammar
stays from the vignette and FIGURE_STYLE.

## W -- wording

Templates: `skills/deseq2-wald/references/reporting-templates.md` (the engine fills these exact
blocks). Granularity: software + version + function + result-changing arguments, in execution order.
The P values are attributed to the unshrunken Wald test; the fold changes to the shrinkage method.

Exemplar sentence structure (L3 notes): the most complete papers chain package + version -> comparison
-> test ("Wald test under a negative binomial GLM") -> multiple-testing method (Benjamini-Hochberg) ->
significance rule in one or two sentences; the typical paper states only "DESeq2" + a padj cutoff
(test named in 9 of 29, adjustment method in 9 of 29, version in 15 of 29, design in 5 of 29). The
template already states all of these; no change.

## V -- variant frequencies (L4: 29 applicable papers, 2020-2026)

Counts from `extraction.jsonl` (`tools/lit/collect.py summarize deseq2-wald`); "n.r." = not reported.

| Parameter (PACK) | Reported values | n.r. | Majority among reporting papers |
|---|---|---|---|
| padj cutoff (D-08) | 0.05: 14; 0.1: 4; 0.01: 2 | 9 | **0.05** (14 of 20) |
| Test (D-02) | Wald: 9 | 20 | Wald (9 of 9) |
| Multiple-testing adjustment (D-08) | Benjamini-Hochberg: 9 | 20 | BH (9 of 9) |
| Post hoc fold-change filter (D-07) | 10 papers, 8 different thresholds (FC > 1.5 or 2; \|log2FC\| > 0, 0.15, 1, 2) | 19 | none (no threshold reaches 3 papers); 10 of 29 filter, 19 do not state one |
| Fold-change threshold inside the test, lfcThreshold (D-07) | log2(1.5): 1; "fold-change threshold of 1.5" inside an `lfcShrink(type = "ashr")` call: 1 （2026-09-27 更正：原写 log2(1.5): 2；PMC12893922 的阈值属于 `lfcShrink`，不能认定为 Wald 阈值检验；recount 2026-09-27） | 27 | -- (1 Wald threshold test; 1 lfcShrink threshold) |
| LFC shrinkage (D-09) | ashr: 2; apeglm: 1 | 26 | ashr (2 of 3) -- denominator too small to be a majority |
| Pre-filter (D-11) | 6 papers, 6 different rules | 23 | none |
| Design / covariates (D-01) | 5 papers, 5 different formulas (batch, donor, source, demographic covariates) | 24 | none |
| DESeq2 version (X) | 13 versions from 1.12.4 to 1.46 | 14 | -- |

Observation: 7 of 29 papers run DESeq2 more than once with different cutoffs per assay or comparison;
the extraction records the primary analysis and notes the others.

## C -- anchors

Dataset: `pasilla` (the vignette's example), rebuilt by `skills/deseq2-wald/tests/fixtures/make_pasilla.R`
exactly as the vignette's "Count matrix input" section. All values are printed in the rendered vignette
(`L1/DESeq2/vignettes/DESeq2.rendered.txt`) and asserted by `tests/run_smoke_test.R`:

| Id | Setting | Value (vignette) | Engine |
|---|---|---|---|
| A1 | `~ condition`, pre-filter 10 x 3, alpha 0.1 | 8,148 tested; 1,069 padj < 0.1 = 533 up + 536 down | equal |
| A1 | same | FBgn0000017 log2FC -0.23842494, padj 0.289604; apeglm -0.18810628 | equal (tol 5e-7 rel.) |
| A1 | same | FBgn0000008 log2FC 0.00399148; apeglm 0.00195376 | equal |
| A2 | alpha 0.05 | 416 up, 437 down | equal |
| A3 | `~ type + condition`, alpha 0.1 | FBgn0000017 -0.2548984, padj 0.131475; FBgn0000037 0.4541562, padj 0.691941 | equal |

## D -- defaults: function default / vignette recommendation / exemplar majority

Function defaults from `L1/DESeq2/formals.tsv` (deparsed `formals()` of the installed version), identical in
`L1_bioc3.23/DESeq2/defaults.tsv` (Rd \usage of DESeq2 1.52.0). Column 3 from section V (29 papers).

| Id | Parameter | (1) function default | (2) vignette / workflow | (3) exemplar majority | Used | Decision |
|---|---|---|---|---|---|---|
| D-00 | `tidy`, `ignoreRank`, `minmu`, `format`, `quiet`, `parallel` | FALSE, FALSE, 0.5, "DataFrame", FALSE, FALSE | defaults | not reported | same (quiet TRUE, console only) | written out (lock 3) |
| D-01 | design / contrast | `~ condition` from user; `contrast` absent | condition last in the formula; relevel to the reference; `contrast = c(var, num, den)` | 5/29 state a design: batch, donor, source or demographic covariates | `~ <covariates> + <condition>`, releveled, contrast + coef | vignette |
| D-02 | `test`, `useT` | Wald (first of c("Wald","LRT")), FALSE | Wald for two-group comparisons | Wald 9/9 (20 n.r.) | "Wald", FALSE | vignette |
| D-03 | `fitType` | "parametric" | parametric; local / mean when the parametric trend fails | not reported by any of 29 | "parametric" (flag) | vignette |
| D-04 | `sfType` | "ratio" | ratio; poscounts for every-gene-has-a-zero data | not reported by any of 29 | "ratio" (flag) | vignette |
| D-05 | `betaPrior` | missing -> FALSE for the standard design | FALSE since 1.16; shrink with lfcShrink | not reported by any of 29 | FALSE | vignette |
| D-06 | `minReplicatesForReplace`, `cooksCutoff` | 7; missing -> 0.99 quantile F(p, m - p) | defaults ("Approach to count outliers") | not reported by any of 29 | 7; TRUE (= default cutoff) | vignette |
| D-07 | `lfcThreshold`, `altHypothesis` | 0, "greaterAbs" | 0; use lfcThreshold to test a fold-change criterion | lfcThreshold 2/29 （2026-09-27 更正：其中 PMC12893922 属于 `lfcShrink` 的阈值，可确认的 Wald 阈值检验 1/29；recount 2026-09-27）; post hoc FC filter 10/29 (8 thresholds; 11/29 only if PMID 41407857's secondary IPA analysis is counted -- the two counting rules are not mixed) | 0 (flag; a user-prespecified minimum effect goes here, log2 units), "greaterAbs"; display-only FC filter **off by default** (S2: implemented in module 1.1.0 as `--display-lfc-filter`) | **S1 P-2 (B, owner 2026-09-27)** |
| D-08 | `alpha`, `independentFiltering`, `pAdjustMethod` | 0.1, TRUE, "BH" | alpha should equal the reported padj cutoff | padj 0.05: 14/20 reporting; BH 9/9 | **0.05** (flag), TRUE, "BH" | **S1-1**; confirmed by S1 P-2 (owner 2026-09-27) |
| D-09 | `lfcShrink(type, apeAdapt, apeMethod, svalue, lfcThreshold)` | "apeglm", TRUE, "nbinomCR", FALSE, 0 | apeglm recommended for ranking and visualization | ashr 2, apeglm 1 (26 n.r.) | "apeglm" (flag; `ashr` optional), TRUE, "nbinomCR", FALSE, 0; P values from the unshrunken Wald test | vignette; **S1 P-1 (A, owner 2026-09-27)** |
| D-10 | `vst(blind, nsub, fitType)` | TRUE, 1000, "parametric" | blind = FALSE when the design is known and the transform is used downstream | not reported (heatmap transform not described) | FALSE, 1000, flag | vignette ("Blind dispersion estimation") |
| D-11 | pre-filter | none (not a DESeq2 argument) | count >= 10 in >= smallest group size | 6/29 report, 6 different rules | 10 / smaller compared group (flags) for two-group designs; complex designs or continuous covariates need an explicit user rule | vignette; **S1 P-3 (A, owner 2026-09-27)** |
| D-12 | replicate thresholds (QC) | -- | -- | -- | < 2 blocker, < 3 warning | ENGINEERING_PLAN 4.5 |

## X -- version-sensitive behaviour (from `L1/DESeq2/NEWS.txt`)

- **1.44.0: new method for `altHypothesis = "greaterAbs"`** with more power than the 2014-2023
  method (kept as `"greaterAbs2014"`). Exemplars that tested `lfcThreshold > 0` before this release
  used the old method: their P values are not comparable with this module's.
- **1.50.0: new `"greaterAbsUPSHOT"` method** for lfcThreshold tests; not used here (default stays
  `"greaterAbs"`).
- **1.45.1: integer counts no longer required by the DESeqDataSet object** (for glmGamPoi); DESeq,
  estimateDispersions and nbinomWaldTest still error on non-integer counts for the other fitTypes.
  This module blocks non-integer input itself (DW-01) before any fit.
- **1.49.4 / 1.49.6: fixes** for the SE of numeric contrasts with weights and for useT with
  greaterAbs -- paths this module does not use.
- The locked container (Bioconductor 3.23) will carry a newer DESeq2; `check_default_drift` compares
  every recorded function default at the first container run, and anchors A1-A3 re-run there.

## S1 decisions (appendix)

- **S1-1 alpha = 0.05.** The function default is 0.1; the vignette says `alpha` must equal the padj
  cutoff that is reported. 0.05 is chosen as the reported cutoff for this suite (consistent with the
  figure layer's default and the other modules). One flag (`--alpha`) drives both independent
  filtering and the significance call, so the two can never disagree. To be re-checked against the
  L4 majority.
- **S1-2 shrinkage for the reported log2FC = apeglm** (vignette recommendation), P values from the
  unshrunken Wald test (`lfcShrink(res = ...)`). nf-core's DESeq2 module uses ashr; kept as an option.
- **S1-3 pre-filter on by default** (vignette recommendation; nf-core leaves it to the user).
- **S1-4 DW-06 threshold 50%** of tested features significant -> warning. Not from literature; a
  sanity line for confounding or sample swaps. Revisit with L4.
- Decided by: build session 2026-09-27 on behalf of the project owner (user delegated S1 decisions);
  the owner may overrule any row, which bumps the module version.

### S1 review against L3/L4 (2026-09-27) -- draft, the owner decides

| Decision | Current value | Literature (29 papers) | Review |
|---|---|---|---|
| S1-1 alpha | 0.05 | 0.05 in 14 of 20 reporting papers; 0.1 in 4; 0.01 in 2 | **confirmed** by the majority |
| Test / adjustment | Wald, BH | Wald 9/9, BH 9/9 of reporting papers | confirmed |
| S1-2 shrinkage | apeglm | 3 papers report one: ashr 2, apeglm 1 | **pending decision P-1** (reporting majority differs; denominator 3) |
| S1-3 pre-filter on (10 counts x smaller group) | vignette rule | 6 papers, 6 different rules, none repeated | kept (no majority); **pending decision P-3** only if the owner wants a different default |
| Fold-change criterion | none by default; `--lfc-threshold` tests it | 10 papers apply a post hoc FC filter (8 thresholds); 2 use lfcThreshold | **pending decision P-2** |
| S1-4 DW-06 50 % line | 50 % | no evidence either way | kept |

### Pending decisions (not decided by the build session; defaults unchanged)

- **P-1 Shrinkage estimator.** Vignette recommends apeglm (current). Of the 3 papers that name one, 2
  use ashr (also a vignette-supported alternative; `--shrinkage ashr` exists). Options: keep apeglm
  (vignette), or switch to ashr (reporting majority of 3). The build session sees no reproducible reason
  to change a default on 3 papers.
- **P-2 Post hoc fold-change filter.** 10 of 29 papers call genes significant with padj AND a fold-change
  cut (FC > 1.5 or 2, |log2FC| > 0.15 to 2); the module deliberately offers only the test-based
  `--lfc-threshold` and its reporting template names the post hoc filter as a failure mode (DESeq2
  vignette: threshold tests). Options: keep as is; or add an optional, clearly labelled display/reporting
  filter (e.g. `--report-lfc-filter`) that never changes padj and is stated separately in the Methods.
- **P-3 Pre-filter default.** No literature majority. Keep the vignette rule (count >= 10 in >= smallest
  group) unless the owner prefers a CPM-based rule for consistency with edgeR/limma modules.

## S1 审定附录（2026-09-27，所有者批准）

所有者于 2026-09-27 裁决：`docs/build/S1_DECISION_TABLE_M1M2.md`（下称"决策表"）中 A、B 类项目一律按「建议」栏批准（建议含可选项的，默认值与可选项一并冻结），C 类保持待定。上面的 "S1 decisions (appendix)"、"S1 review against L3/L4" 与 "Pending decisions" 保留为历史；与本附录不一致处以本附录为准。下列参数在调用中一律显式写出，即使等于函数默认值（ENGINEERING_PLAN §3.3）。L1 路径相对于本目录 `L1_bioc3.23/DESeq2/`。

| 编号 | 决定 | 类别 | 依据 |
|---|---|---|---|
| P-1 LFC 收缩估计器 | `lfcShrink(dds, coef = "<condition>_<target>_vs_<reference>", res = <results() 对象>, type = "apeglm", lfcThreshold = 0, svalue = FALSE, apeAdapt = TRUE, apeMethod = "nbinomCR")`；`type = "ashr"` 为可显式选择的备选。保留未收缩 Wald 的 `stat`、`pvalue`、`padj`；收缩后的 LFC/SE 单独命名。`apeglm` 只能用 `coef`：任意 `contrast` 须先重参数化（relevel 得到对应 coef），或显式改用支持 contrast 的估计器。 | A | 决策表 deseq2-wald P-1；`Rd/lfcShrink.Rd` Usage、Arguments；`vignettes/DESeq2.Rmd` "Log fold change shrinkage for visualization and ranking"、"Alternative shrinkage estimators" |
| P-2 事后 FC 筛选与阈值检验 | 主分析为零阈值 Wald：`results(dds, contrast = c("<condition>", "<target>", "<reference>"), lfcThreshold = 0, altHypothesis = "greaterAbs", alpha = 0.05, pAdjustMethod = "BH")`，`alpha` 与报告的 padj 界值一致。用户预先给定的最小生物学效应进入同一调用的 `lfcThreshold = <log2 值>`（用户给线性倍数时先说明单位并换算为 log2）。另设**默认关闭**的仅展示 FC 筛选：完整结果表始终保留；筛选后的集合不得称仍享有原 BH 的同一 FDR 保证，Methods 中与检验分开陈述。不得用 `lfcShrink` 的 s-value 替代 Wald padj 而沿用原标签。 | B | 决策表 deseq2-wald P-2、「跨模块一致性」第 1 行；`Rd/results.Rd` `lfcThreshold`、`alpha`；`Rd/lfcShrink.Rd` `lfcThreshold`、`svalue`；`vignettes/DESeq2.Rmd` "Tests of log2 fold change above or below a threshold" |
| P-3 低计数预过滤 | 两组 bulk 设计默认显式预过滤：保留在至少"最小组样本数"个样本中计数 `>= 10` 的基因（引擎参数 `min_count = 10`、`min_samples = <最小组样本数>`，实际值写入 provenance）；报告输入数、保留数与所用规则。含连续协变量或复杂设计时，由用户给出明确规则（显式 `min_samples`），不硬造"最小组"。预过滤是可选的效率步骤，不写成统计有效性的前提；不改为 CPM 规则。它与 `results(independentFiltering = TRUE)` 是两个不同步骤。 | A | 决策表 deseq2-wald P-3；`Rd/DESeq.Rd`、`Rd/results.Rd`；`vignettes/DESeq2.Rmd` "Pre-filtering" |

与既有 S1 记录的关系：S1-1（alpha = 0.05）由 P-2 确认；S1-2（apeglm）由 P-1 确认；S1-3（预过滤默认开启）由 P-3 确认，并追加"复杂设计须显式规则"一条；S1-4（DW-06 50 % 警告线）不在决策表范围内，维持原状。

- C 类待定：无。待澄清：无。
- D 表：D-07、D-08、D-09、D-11 的 Used/Decision 已按本附录同步；D-07 与 V 节的 lfcThreshold 计数按决策表复算更正（见行内标注）。
- 已建模块与本附录的差异（展示筛选开关、主表收缩 LFC 的列名、复杂设计的预过滤规则）列入 `SUITE.md` "M1/M2 S1 审定"一节，作为 S2 跟进项（锁 7），本次未改模块代码。
