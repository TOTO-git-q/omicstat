# PACK -- limma-dupcor

Evidence pack of module `limma-dupcor` (ENGINEERING_PLAN 2.3). Status: **S0 complete (L1 locked release,
L3/L4 collected and independently verified, 2026-09-27); S1 drafted -- the pending
decisions at the end are the owner's. S2 (engine) not started** (built locally).

| Layer | Status | Where |
|---|---|---|
| L1 | limma 3.68.5 and edgeR 4.10.5 (Bioconductor 3.23, git.bioconductor.org RELEASE_3_23): limma User's Guide (release PDF, text), Rd of `duplicateCorrelation`, `lmFit`, `eBayes`, `topTable`, `voom`, NEWS, `defaults.tsv` | `L1_bioc3.23/` (manifest with sha256 and git commit) |
| L2 | limma User's Guide 9.7 "Multi-level experiments" (patient as random effect), 17.3 Illumina case study (within-donor correlation), 18.1 Yoruba RNA-seq (voom + block, two rounds) | cited below |
| L3 | 10 open-access full texts (tier-A journals), close-read notes | `literature/l3_notes.md` |
| L4 | 30 open-access articles 2020-2026 (whitelisted journals, CC BY / CC BY-NC, PubMed-echoed); **30 of 30 apply** (the Methods signal requires `duplicateCorrelation`) | `literature/corpus.jsonl`, `extraction.jsonl`, `efetch/` |
| Verification | 6 of 30 articles, 48 records: 48 pass (100.0 %), PMID echo 6/6 -> **pass** | `literature/verification.json` |

## T -- table skeleton

- Feature table per contrast, as limma-voom / limma-array (`topTable`), plus a header block: block factor,
  number of blocks, consensus intra-block correlation, rounds of voom/duplicateCorrelation (RNA-seq).

## F -- figure grammar

Same as limma-voom / limma-array (MD / volcano, MDS). Exemplars show no figure specific to the block
correlation; the consensus correlation is a number in the text.

## W -- wording

Exemplar structure (L3): "<individual/donor/patient> was treated as a random effect / blocking factor using
`duplicateCorrelation`", then the usual limma chain; the consensus correlation value is almost never
given (1 of 30), neither is the second voom round (1 of 30). Template to write at S2: block factor and
why (repeated measures of the same unit), consensus correlation printed, voom rounds (RNA-seq),
`eBayes`, BH and FDR cutoff.

## V -- variant frequencies (L4: 30 applicable papers)

Source: `collect.py summarize limma-dupcor`.

| Parameter (PACK) | Reported values | n.r. | Majority among reporting papers |
|---|---|---|---|
| Block factor (D-D1) | the individual (patient / donor / subject / participant / animal / mouse / fly / bird) 23; clone or clone donor 2; family 1; replicate population / experimental repeat 2; **sequencing lane (batch) 1; species 1** | 0 | **the biological individual** (23 of 30) |
| Two rounds voom + duplicateCorrelation (D-D2) | yes 1 (with voomWithQualityWeights, following the guide) | 29 | -- (1 paper) |
| Consensus correlation reported (D-D3) | 0.83: 1 | 29 | -- (1 paper) |
| FDR cutoff (D-08) | 0.05 / 5 %: 14; 0.1 / 10 %: 4; 0.01: 1 | 11 | **0.05** (14 of 19) |
| Adjustment (D-08) | Benjamini-Hochberg 17; local fdr (fdrtool) 1; Storey q-value 1 | 11 | **BH** (17 of 19) |
| Post hoc FC filter (D-07) | 1.5: 2; 1: 1 | 27 | none |
| limma version (X) | 3.30.13 - 3.64.1 (12 versions; one written "3.3.49") | 18 | -- |

The two block factors in bold are candidates for misuse (a technical batch or a factor that may be
spanned by the design) （2026-09-27 限定："候选"只表示需要核查——技术批次作 block 并非 Rd 所禁止；family/clone 等也可表示相关单位，判断依据是相关单位与可估性，见 S1 审定附录 P-2）; limma >= 3.48 returns zero correlation with a warning when the block is
spanned by the design (X).

## C -- anchors

`acceptance/data/ANCHOR_REGISTRY.md` row 7 (limma User's Guide 17.3, Illumina BeadChip, files F7-F9,
`block = targets$Donor`, printed `dupcor$consensus.correlation` = **0.134**) and row 7b (User's Guide 18.1,
Yoruba RNA-seq, F10, `block = Targets$cellline`, printed `cor$consensus` = **0.446** after both rounds).
Both are printed-value anchors.

## D -- defaults: function default / User's Guide / exemplar majority

Function defaults from `L1_bioc3.23/limma/defaults.tsv` (limma 3.68.5).

| Id | Parameter | (1) function default | (2) User's Guide 3.23 | (3) exemplar majority (V) | Draft | Decision |
|---|---|---|---|---|---|---|
| D-D1 | `block` | NULL (no block) | the subject / donor / cell line with repeated measurements ("treat Patient as a random effect") | the individual 23/30 | required argument: the unit measured repeatedly; refuse a block spanned by the design | **S1 P-2 (A, owner 2026-09-27)**: correlated unit described and mapped to samples; estimability, design rank and residual df checked; technical batch goes into the design by default |
| D-D2 | rounds (RNA-seq) | -- | 18.1: voom -> duplicateCorrelation -> voom(block, correlation) -> duplicateCorrelation ("the correlation has hardly changed on the second iteration"); NEWS 3.42.0: guide changed to two rounds | 1 of 30 states it | two rounds | guide |
| D-D3 | `trim` | 0.15 | default | n.r. | 0.15 | function default |
| D-D4 | correlation passed to `lmFit` | -- | `corfit$consensus` (= `consensus.correlation`) | 1 paper prints it | consensus, always printed in the output | guide; **S1 P-1 (A, owner 2026-09-27)**: estimate passed explicitly to `lmFit(correlation = )` and always reported |
| D-D5 | `eBayes` | `trend = FALSE, robust = FALSE` | 17.3 arrays: `eBayes(fit2, trend = TRUE)`; 18.1 voom: `eBayes(fit)` | n.r. (no countable trend field; not evidence of FALSE) | voom: plain; arrays: `trend = TRUE` as in 17.3 | **S1 P-3 (B, owner 2026-09-27)**: arrays inherit the limma-array P-1 platform preset and override; the trend rule does not change with the presence of a block |
| D-08 | adjustment, FDR | `topTable(adjust.method = "BH")` | `adj.P.Val < 0.05` in examples | BH 17/19; 0.05 14/19 | BH, 0.05 | same as deseq2-wald |
| D-07 | post hoc FC filter | none | -- | 3 papers | none (display filter only) | same as deseq2-wald P-2 (owner 2026-09-27: display-only, off by default) |

## X -- version-sensitive behaviour (L1 NEWS, limma 3.68.5)

- 3.48.0: `duplicateCorrelation()` made more robust -- `weights` handled as in `lmFit()`; returns zero
  intrablock correlation with a warning when the block factor is spanned by the design (previously NA
  or near 1); genewise correlations bounded away from +-1 by 0.01. Results can differ from older limma.
- 3.42.0: `voom()` gains `block`, `correlation`, `weights`; User's Guide Yoruba case study now calls
  voom and duplicateCorrelation twice.
- limma 3.66.0 `voom(adaptive.span = TRUE)` default (see limma-voom X) also changes the dupcor-RNA-seq path.

## S1 drafts and pending decisions (the owner decides; no default is fixed yet)

- **P-1 Reporting the consensus correlation.** 29 of 30 papers do not report it. Draft: the module always
  prints the consensus correlation (and the number of blocks) in the table header and the Methods
  sentence -- a reporting choice, no numerical default changes.
- **P-2 Block validation.** One paper blocks on the sequencing lane (a technical batch), one on species.
  Draft: the block must be the repeatedly-measured unit; a block spanned by the design is refused with
  the limma warning surfaced; a technical batch goes into the design (or sva-batch), not the block.
- **P-3 eBayes trend on arrays.** The guide's Illumina case study uses `trend = TRUE`; exemplars never
  state it. Draft: follow the platform rule of limma-array (see its P-1) so the two modules agree.

## S1 审定附录（2026-09-27，所有者批准）

所有者于 2026-09-27 裁决：`docs/build/S1_DECISION_TABLE_M1M2.md`（下称"决策表"）中 A、B 类项目一律按「建议」栏批准（建议含可选项的，默认值与可选项一并冻结），C 类保持待定。上一节 "S1 drafts and pending decisions" 保留为历史；与本附录不一致处以本附录为准。下列参数在调用中一律显式写出，即使等于函数默认值（ENGINEERING_PLAN §3.3）。L1 路径相对于 `L1_bioc3.23/limma/`。

| 编号 | 决定 | 类别 | 依据 |
|---|---|---|---|
| P-1 必报一致性相关 | `corfit <- duplicateCorrelation(object, design = <design>, block = <block>, trim = 0.15, weights = <voom 权重或 NULL>)`（block 非 NULL 时 `ndups`/`spacing` 被忽略）；估计值显式传入 `lmFit(object, design = <design>, block = <block>, correlation = corfit$consensus.correlation)`。输出与 Methods 必报：估计的 consensus correlation、block 含义、block 数目与大小、输入设计、RNA-seq 的估计轮次。不得把指南示例 0.134 / 0.446 或文献 0.83 当作默认值。 | A | 决策表 limma-dupcor P-1；`Rd/duplicateCorrelation.Rd` Value、Details；`vignettes/usersguide.rendered.txt` §17.3 "Within-patient correlations"、§18.1 |
| P-2 block 校验与伪重复 | 默认要求：block 所代表的相关单位的说明，以及 block 与样本的对应；运行前检查重复、可估性、design rank、残差 df（样本数须至少比 design rank 多 2）。不得把同一 block 的全部固定效应列与随机相关重复同时放入模型。技术批次默认进入 design（固定效应）；需要把特殊因素作随机 block 的，须明确说明理由。family、clone 等也可作相关单位，不只同一个体。 | A | 决策表 limma-dupcor P-2；`Rd/duplicateCorrelation.Rd` Arguments、Details；User's Guide §9.4.2 "Blocking"、§9.7 "Multi-level Experiments" |
| P-3 芯片的 `trend` 与 array 统一 | 芯片输入继承 limma-array P-1 的平台预设及显式覆盖（已登记 Agilent 平台：`eBayes(fit, trend = TRUE, robust = TRUE, ...)`，其余参数同 limma-array 附录）；同一输入尺度、平台与设计采用一致的 `trend` 规则，不因是否有 block 而改变。`robust = TRUE` 是跨模块预设，不声称由 §17.3 Illumina 示例直接证明（该示例只用 `trend = TRUE`）。 | B | 决策表 limma-dupcor P-3；`Rd/eBayes.Rd`；User's Guide §17.3；跨模块 `limma-array/PACK.md` S1 审定附录 P-1 |

待澄清：
- P-3 继承了 limma-array P-1 的待澄清问题（Agilent 以外平台的预设值）；本模块 C 节的 Illumina 锚点（§17.3，`trend = TRUE`、未设 `robust`）在锚点回放时应按指南原调用运行，还是按套件预设 `robust = TRUE` 运行？锚点断言的 consensus correlation 0.134 不受 `eBayes` 影响，但若将来对该锚点的 DE 结果做断言则需要先定。

对上一节草案原文的更正（草案文本保留不改，更正记在这里）：
- P-2 草案"a technical batch goes into the design (or sva-batch), not the block"语气过强：技术批次默认进 design 是本套件的策略，不是 `duplicateCorrelation.Rd` 的定理；判断依据是相关单位与可估性（2026-09-27 更正，决策表第 10 条）。

- C 类待定：无。
- D 表：D-D1、D-D4、D-D5、D-07 的 Decision 已同步；V 节关于"误用候选"的措辞按决策表第 10 条限定（见行内标注）。
