# PACK -- deseq2-lrt

Evidence pack of module `deseq2-lrt` (ENGINEERING_PLAN 2.3). Status: **S0 complete (L1 locked release,
L3/L4 collected and independently verified, 2026-09-27); S1 drafted -- the pending
decisions at the end are the owner's. S2 (engine) not started** (built locally).

| Layer | Status | Where |
|---|---|---|
| L1 | DESeq2 1.52.0 and DEGreport 1.48.0 (Bioconductor 3.23, git.bioconductor.org RELEASE_3_23): vignette source + rendered text, Rd of `DESeq`, `nbinomLRT`, `results`, `degPatterns`, NEWS, `defaults.tsv` | `L1_bioc3.23/` (manifest with sha256 and git commit) |
| L2 | DESeq2 vignette "Likelihood ratio test", "Time-series experiments", FAQ "I ran a likelihood ratio test, but results() only gives me one comparison"; rnaseqGene workflow "Time course experiments" (fission) | cited below |
| L3 | 10 open-access full texts (tier-A journals), close-read notes | `literature/l3_notes.md` |
| L4 | 30 open-access articles 2020-2026 (whitelisted journals, CC BY / CC BY-NC, PubMed-echoed); **26 of 30 apply** (4: pseudobulk scRNA-seq 2, Patch-seq single-cell 1, ATAC-seq peaks 1) | `literature/corpus.jsonl`, `extraction.jsonl`, `efetch/` |
| Verification | 6 of 30 articles, 46 records: 46 pass (100.0 %), PMID echo 6/6 -> **pass** | `literature/verification.json` |

Collection history: the first corpus (13 of 30 applicable) came from a signal that matched any "LRT"
near DESeq2; the signal was tightened (DESeq2 and the LRT in one sentence of <= 250 characters; Cox,
PAML/codeml, lme4/glmer and Seurat `FindVariableFeatures` excluded) and the corpus re-collected: 7
articles carried over, 23 new. Extraction lines of dropped round-1 articles stay in `extraction.jsonl`
and are not counted (`collect.py summarize` counts only the current corpus).
Extractor judgment calls: two tRNA-seq papers (bulk tRNA counts) kept as applicable, with notes.

## T -- table skeleton

- Gene table: gene, baseMean, log2FoldChange (one coefficient, labelled as such), lfcSE, stat (deviance
  difference), pvalue, padj; header line "LRT p-value: '<full>' vs '<reduced>'" as DESeq2 prints it.
- Optional pattern table (time course): gene -> cluster (`degPatterns`), cluster sizes.

## F -- figure grammar

| Figure | Grammar | Source |
|---|---|---|
| Expression-pattern clusters | per cluster: z-scored expression over time / condition, one line per group, box per time point | `DEGreport::degPatterns(plot = TRUE)`; exemplars: k-means 2, hierarchical 2, Mfuzz / DEGreport / GPclust / DPGP 1 each |
| Top-gene trajectories | normalized counts of top LRT genes over time, coloured by condition | rnaseqGene workflow (fission `plotCounts` over time) |
| Heatmap | z-scored vst of LRT-significant genes, clustered | exemplars |

## W -- wording

Exemplar structure (L3): "a likelihood ratio test (LRT) in DESeq2 comparing a full model (<terms>) with a
reduced model (<terms>)"; the reduced model is stated by only 10 of 26 papers and the full model by 9;
the design type (time course, interaction, multi-level factor) is usually given in words. Template to
write at S2: DESeq2 version, full and reduced formulas verbatim, what the LRT tests (terms removed),
BH, FDR cutoff, the fact that the printed log2 fold change is one coefficient only, and the clustering
method if patterns are shown.

## V -- variant frequencies (L4: 26 applicable papers)

Source: `collect.py summarize deseq2-lrt`.

| Parameter (PACK) | Reported values | n.r. | Majority among reporting papers |
|---|---|---|---|
| Reduced model (D-L1) | intercept only (`~1`, in various words) 3; main effects without the interaction 3; nuisance terms only (`~cell_line`, `~replicate`) 2; other wording 2 | 16 | -- (varies with the design) |
| Full model (D-L2) | 9 distinct (interaction models 3; condition + replicate / cell line 2; ...) | 17 | -- |
| Design type (D-L3) | multi-level factor / across groups 9; time course 4; interaction term 3; paired or per-stage comparisons 3; covariate or batch association 2 | 5 | **multi-level factor** (9 of 21) |
| FDR cutoff (D-08) | 0.05: 12; 0.01: 4; 0.1: 2 | 8 | **0.05** (12 of 18) |
| Adjustment (D-08) | BH / FDR 6; IHW 1 | 19 | BH (6 of 7) |
| Post hoc FC filter (D-07) | 4 papers, 4 different rules (0.5, > 0 / < 0, abs > 0.5, FC >= 2) | 22 | none |
| Pattern clustering (D-L4) | k-means 2; hierarchical 2; Mfuzz 1; DEGreport 1; GPclust 1; DPGP 1 | 18 | none |
| DESeq2 version (X) | 1.18 - 1.44.0 (7 versions) | 19 | -- |

The design-type counts group the 21 free-text answers by the main feature; each paper counted once.

## C -- anchors

`acceptance/data/ANCHOR_REGISTRY.md` row 3: fission (rnaseqGene workflow "Time course experiments":
`~ strain + minute + strain:minute` vs `reduced = ~ strain + minute`) -- **package not installed** in
either tier (open item). The DESeq2 vignette's LRT chunks are `eval = FALSE`; fallback: replay anchor on
pasilla (`~ type + condition` vs `reduced = ~ type`), whose LRT p-value for a two-level factor must equal
the Wald p-value closely (a built-in consistency check).

## D -- defaults: function default / vignette / exemplar majority

Function defaults from `L1_bioc3.23/{DESeq2,DEGreport}/defaults.tsv` (DESeq2 1.52.0, DEGreport 1.48.0).

| Id | Parameter | (1) function default | (2) vignette / workflow | (3) exemplar majority (V) | Draft | Decision |
|---|---|---|---|---|---|---|
| D-L1 | `reduced` | none -- required for `test = "LRT"` | `reduced = ~1` (full `~condition`); `reduced = ~batch` (full `~batch + condition`); time course: drop the interaction | stated by 10/26, varied （2026-09-27 更正：10 篇中包括只用文字描述、未写出公式的，不能说 10 篇都给出了完整 reduced 公式） | required argument, echoed verbatim; no default | **S1 P-1 (A, owner 2026-09-27)**: required; nested / full-rank / df > 0 checked |
| D-L2 | `full` | `design(object)` | the design formula | stated by 9/26 | `design(dds)` | function default |
| D-L3 | `fitType`, `sfType`, `minReplicatesForReplace` | "parametric", "ratio", 7 | defaults (glmGamPoi requires LRT; recommended for single-cell) | n.r. | same as deseq2-wald | consistency with deseq2-wald |
| D-L4 | pattern clustering | `degPatterns(minc = 15, summarize = "merge", time = "time", reduce = FALSE, cutoff = 0.7, scale = TRUE)` | not in the DESeq2 vignette; DEGreport is the Bioconductor tool | 8 papers, 6 methods | optional `degPatterns` with its defaults on LRT-significant genes | **S1 P-2 (B, owner 2026-09-27)**: off by default; when enabled every result-affecting argument, the input gene selection and the metadata fields are written out |
| D-08 | `results(alpha, pAdjustMethod)` | 0.1, "BH" | `alpha = 0.05` in examples | BH 6/7; 0.05 12/18 | BH, alpha = 0.05 | same as deseq2-wald |
| D-07 | `lfcThreshold` / post hoc FC | 0; no post hoc filter | LRT p-values do not depend on the printed LFC (results Rd) | 4 papers, 4 rules | **no FC filter on LRT results** | **S1 P-3 (A, owner 2026-09-27)**: `lfcThreshold = 0`; effect sizes only from separately prespecified Wald contrasts |

## X -- version-sensitive behaviour (L1 NEWS, DESeq2 1.52.0)

- 1.44.0: Cook's distances for the LRT now use the fitted mean of the full model (previously a rough
  estimate) -- outlier flagging after an LRT can differ from DESeq2 < 1.44.
- 1.30.0: `fitType = "glmGamPoi"` (requires `test = "LRT"` and a reduced design).
- 1.15.3: `betaPrior` removed from `nbinomLRT`.
- `results()` for an LRT prints one log2 fold change (the last `resultsNames` coefficient unless `name`
  is given); the p-value covers all removed terms (vignette FAQ; results Rd).

## S1 drafts and pending decisions (the owner decides; no default is fixed yet)

- **P-1 Reduced model.** No default is possible (the test is defined by it). Draft: `reduced` is a
  required argument; the module echoes full and reduced formulas and the tested terms in the table
  header and the Methods sentence (only 10 of 26 papers state it).
- **P-2 Pattern clustering.** No majority (6 methods across 8 papers). Draft: optional
  `DEGreport::degPatterns` with its function defaults for time-course designs, off by default.
- **P-3 Fold-change filter after an LRT.** The printed LFC is one coefficient while the p-value covers
  several terms, so a post hoc |LFC| filter is ill-defined. Draft: no FC filter on LRT results; if the
  user asks for effect sizes, report the per-level Wald contrasts from deseq2-wald instead.
- **P-4 Anchor.** fission is not installed in either tier; decide between installing `fission` (Bioc
  data package) and the pasilla replay fallback.

## S1 审定附录（2026-09-27，所有者批准）

所有者于 2026-09-27 裁决：`docs/build/S1_DECISION_TABLE_M1M2.md`（下称"决策表"）中 A、B 类项目一律按「建议」栏批准（建议含可选项的，默认值与可选项一并冻结），C 类保持待定。上一节 "S1 drafts and pending decisions" 保留为历史；与本附录不一致处以本附录为准。下列参数在调用中一律显式写出，即使等于函数默认值（ENGINEERING_PLAN §3.3）。L1 路径相对于 `L1_bioc3.23/`。

| 编号 | 决定 | 类别 | 依据 |
|---|---|---|---|
| P-1 reduced 模型 | `DESeq(dds, test = "LRT", full = <full 公式>, reduced = <reduced 公式>)`，`reduced` 必填，无默认（不一律 `~1`）。运行前检查：full 与 reduced 嵌套、两者满秩、自由度差 > 0；批次等调整项在 full 与 reduced 中一致保留。输出两个公式原文、被检验的项及自由度。 | A | 决策表 deseq2-lrt P-1；`DESeq2/Rd/DESeq.Rd`、`DESeq2/Rd/nbinomLRT.Rd`；`DESeq2/vignettes/DESeq2.Rmd` "Likelihood ratio test" |
| P-2 模式聚类 | 默认关闭。时间过程需要时可选 `DEGreport::degPatterns(ma, metadata, minc = 15, summarize = "merge", time = "<metadata 时间列>", col = <分组列或 NULL>, consensusCluster = FALSE, reduce = FALSE, cutoff = 0.7, scale = TRUE, pattern = NULL, groupDifference = NULL, eachStep = FALSE, nClusters = NULL, skipDendrogram = TRUE)`：全部结果相关参数显式写出（取值为锁定版函数默认，`time`、`col` 按用户的 metadata 字段填写），并登记输入基因的选择规则与所用 metadata 字段。聚类是探索性展示，不作为新的确认性检验。 | B | 决策表 deseq2-lrt P-2；`DEGreport/Rd/degPatterns.Rd` Usage；`DEGreport/vignettes/DEGreport.Rmd` "Detect patterns of expression" |
| P-3 LRT 后的单一 FC 筛选 | LRT 联合显著性不加单系数 FC 门槛：`results(dds, lfcThreshold = 0)`（正 `lfcThreshold` 会改走 Wald 并覆盖 LRT p 值，不作 LRT 开关使用）。需要效应大小时，另外预先指定 Wald contrasts 单列报告，作为独立的检验家族；不得只在 LRT 命中基因里无说明地重算 BH。 | A | 决策表 deseq2-lrt P-3；`DESeq2/Rd/results.Rd` `lfcThreshold`、Details；`DESeq2/vignettes/DESeq2.Rmd` FAQ "I ran a likelihood ratio test, but results() only gives me one comparison." |
| P-4 锚点 | 后续在锁定容器中补齐 `fission` 并覆盖交互时间模型（`~ strain + minute + strain:minute` 对 `reduced = ~ strain + minute`），作为主锚点；`pasilla` 只作补充的嵌套模型 replay（`~ type + condition` 对 `reduced = ~ type`），不能代替时间过程验证。两者都记录容器版本、输入对象散列与结果来源。 | B | 决策表 deseq2-lrt P-4；`DESeq2/vignettes/DESeq2.Rmd` "Likelihood ratio test"（示例 `eval=FALSE`）；`acceptance/data/ANCHOR_REGISTRY.md` 第 3 行；`SUITE.md` M1-S0 待裁决第 2 项 |

待澄清：
- P-2：决策表要求"登记输入基因选择"，但没有给出默认规则（上一节草案写的是 LRT 显著基因，D-L4 草案列同）。问题：模式聚类的默认输入是否为"LRT padj < alpha 的基因"？在确认之前，输入规则由调用方显式给出并登记，不设默认。

- C 类待定：无。
- D 表：D-L1、D-L4、D-07 的 Decision 已同步；D-L1 的计数口径按决策表更正（见行内标注）。P-4 锚点决定见上表，C 节"open item"由此给出方向，fission 的安装仍属基础设施 M1-2。
