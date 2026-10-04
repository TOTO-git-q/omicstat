# PACK -- gsva-score

Evidence pack of module `gsva-score` (ENGINEERING_PLAN 2.3). Status: **S0 complete (L1 locked release, L3/L4 collected and independently verified, 2026-09-27); S1 drafted -- the pending decisions at the
end are the owner's. S2 (engine) not started** (built locally).

| Layer | Status | Where |
|---|---|---|
| L1 | GSVA 2.6.6 (Bioconductor 3.23, git.bioconductor.org RELEASE_3_23): vignettes `GSVA`, `GSVA_scRNAseq`, `GSVA_spRNAseq`, `GSVA_proteomics` (source + rendered text), Rd of `gsva`, `gsvaParam`, `ssgseaParam`, `zscoreParam`, `plageParam`, NEWS, `defaults.tsv` | `L1_bioc3.23/` (manifest with sha256 and git commit) |
| L2 | GSVA vignette sections on the parameter objects, `kcdf`, `maxDiff`, and the pathway-level differential analysis with limma (+ sva) | cited below |
| L3 | 10 open-access full texts (tier-A journals), close-read notes | `literature/l3_notes.md` |
| L4 | 30 open-access articles 2020-2026 (whitelisted journals, CC BY / CC BY-NC, PubMed-echoed); **30 of 30 apply** (all name the GSVA R package) | `literature/corpus.jsonl`, `extraction.jsonl`, `efetch/` |
| Verification | 6 of 30 articles, 48 records: 48 pass (100.0 %), PMID echo 6/6 -> **pass** | `literature/verification.json` |

## T -- table skeleton

- Score matrix: gene set x sample (GSVA / ssGSEA / z-score / PLAGE scores), with the gene-set sizes after
  filtering. Optional: limma table per contrast on the scores (logFC, AveExpr, t, P.Value, adj.P.Val) --
  ENGINEERING_PLAN: "can be handed to limma for group comparison".

## F -- figure grammar

| Figure | Grammar | Source |
|---|---|---|
| Score heatmap | gene sets x samples, z-scored rows, annotation bar = group | exemplars; GSVA vignette |
| Score by group | box / violin of one set's scores per group, test result annotated | exemplars (Wilcoxon / limma) |
| Survival split | Kaplan-Meier by high / low score | exemplars (2) -- belongs to a survival module, not here |

## W -- wording

Exemplar structure (L3): "GSVA (R package, version) was used to compute <collection> scores from <input>";
the method is often implied ("GSVA"), `kcdf` and gene-set size limits are almost never given; the
downstream test is a separate sentence. Template to write at S2: GSVA version, method (`gsvaParam` /
`ssgseaParam` ...), input scale and the resulting `kcdf`, gene-set collection with version, `minSize` /
`maxSize`, and the downstream test (limma on scores, BH).

## V -- variant frequencies (L4: 30 applicable papers)

Source: `collect.py summarize gsva-score`.

| Parameter (PACK) | Reported values | n.r. | Majority among reporting papers |
|---|---|---|---|
| Method (D-GV1) | gsva 20 (incl. "the GSVA package" without a method; noted); ssgsea 7; both in one paper 3 | 0 | **gsva** (20 of 30) （2026-09-27 限定：20 篇含只写包名、未明确算法的行，不能当作已证实 20 次 `gsvaParam`/GSVA 算法） |
| kcdf (D-GV2) | Gaussian 1 | 29 | -- (1 paper) |
| Input scale (D-GV3) | TPM (raw, log or rank-normalised) 4; DESeq2 VST 3; log-CPM 2; other log-normalised data 4 | 17 | continuous log-scale data (none uses raw counts) （2026-09-27 更正：明确输入的 13/30 中含原尺度 TPM、rank-normalized TPM 与尺度不明的 pseudobulk，不全是 log 尺度；recount 2026-09-27） |
| Gene-set collection (D-GV4) | MSigDB Hallmark most often named; custom / published signatures frequent; KEGG-derived and GO terms | 7 | MSigDB (Hallmark), plus study-specific sets |
| Gene-set size limits (D-GV5) | -- | 30 | none stated (0/30) |
| Downstream test (D-GV6) | Wilcoxon / Mann-Whitney 6; correlation 4; survival split 4; limma 3; clustering 1 (several papers use more than one) | 15 | no majority (limma 3 of 15) |
| GSVA version (X) | 1.26 - 1.46 (12 papers); 1.50.0, 1.52.3 (2); 2.2.x (3) | 13 | 12 of 17 on the old API only (GSVA < 1.50) |

## C -- anchors

`acceptance/data/ANCHOR_REGISTRY.md` row 13: the vignette data are in GSVAdata, **not installed** in
either tier (open item). Installed alternative: the `GSVA_scRNAseq` vignette on TENxPBMCData pbmc4k
(file F2). The main vignette's leukemia result is only shipped as a cache
(`extdata/cache4vignette_leukemia_es.RData`), usable as a replay anchor.

## D -- defaults: function default / vignette / exemplar majority

Function defaults from `L1_bioc3.23/GSVA/defaults.tsv` (GSVA 2.6.6).

| Id | Parameter | (1) function default | (2) vignette 3.23 | (3) exemplar majority (V) | Draft | Decision |
|---|---|---|---|---|---|---|
| D-GV1 | method | `gsvaParam()` (GSVA); `ssgseaParam`, `zscoreParam`, `plageParam` | GSVA as the main example | gsva 20/30 (includes package-name-only rows; 2026-09-27 限定) | `gsvaParam`; ssGSEA as an option | vignette + majority agree |
| D-GV2 | `kcdf` | `"auto"` (GSVA >= 2.0) | "Gaussian" for continuous log data (log-CPM/TPM, arrays), "Poisson" for integer counts; one passage still says "Gaussian by default" (written before 2.0) | Gaussian 1 (29 n.r.) | `"auto"`, and print the kernel actually chosen | **S1 P-1 (A, owner 2026-09-27)**: `kcdf = "auto"`, `kcdfNoneMinSampleSize = 200`; actual branch (Gaussian / Poisson / none) reported |
| D-GV3 | input | expression matrix / SE assay | log-scale continuous values, or counts with Poisson | log-scale in every reporting paper （2026-09-27 更正：13 篇明确输入中含原尺度 TPM、rank-normalized TPM、尺度不明 pseudobulk，不全是 log） | log-CPM (TMM) from the bulk modules; refuse raw counts unless `kcdf = "Poisson"` | **S1 P-1 (A, owner 2026-09-27)**: bulk preset VST / logCPM (VST not logged again); integer counts only with explicit `kcdf = "Poisson"` |
| D-GV4 | `minSize`, `maxSize` | 1, Inf | examples use `minSize = 5, maxSize = 500` （2026-09-27 更正：bulk 定量一节用 5–500，"Differential expression at pathway level / Running GSVA"一节用 `minSize = 5, maxSize = 300`；不能说 vignette 一律 5–500） | never stated | 5, 500 (vignette examples) | **S1 P-2 (B, owner 2026-09-27)**: 5, 500 bulk preset; 5, 300 to reproduce the immunologic example; user-configurable |
| D-GV5 | `maxDiff`, `tau` | TRUE, 1 | defaults ("cover most of the use cases") | n.r. | TRUE, 1 | function default |
| D-GV6 | downstream test | -- | limma on the scores (with sva for heterogeneity), `eBayes(robust = TRUE)`, 5 % FDR | no majority | limma on scores via the limma-* modules, BH 5 % | **S1 P-3 (A, owner 2026-09-27)**: scoring and inference separate; raw scores to a limma entry for continuous values (no voom, no count model, no array probe filter / trend inherited) |

## X -- version-sensitive behaviour (L1 NEWS, GSVA 2.6.6)

- 1.50: new API -- `gsva()` takes a parameter object (`gsvaParam()` etc.); the old call
  `gsva(expr, gset.idx.list, method = ...)` deprecated. 1.52: old API defunct. 2.2: old API removed.
  12 of 17 exemplars that give a version used a GSVA with the old API only -- their argument names (`min.sz`, `max.sz`,
  `method =`) must be mapped, not copied.
- 2.0: `kcdf = "auto"` becomes the default (previously "Gaussian").
- Earlier: `rnaseq` / `kernel` replaced by `kcdf`; bootstrap arguments defunct.

## S1 drafts and pending decisions (the owner decides; no default is fixed yet)

- **P-1 kcdf and input.** Function default "auto" (GSVA >= 2.0); the vignette's guidance ties the kernel to
  the input scale. Draft: accept log-scale continuous input (from deseq2 VST / limma-voom logCPM), keep
  `kcdf = "auto"` and report the kernel chosen; counts only with an explicit `kcdf = "Poisson"`.
- **P-2 Gene-set size limits.** Function default 1..Inf; the vignette's examples use 5..500; no exemplar
  states limits. Draft: 5..500 with the number of sets removed reported; the owner decides because it
  departs from the function default.
- **P-3 Downstream comparison.** No exemplar majority (Wilcoxon, limma, correlation, survival). Draft:
  this module only scores; group comparison of scores goes through limma (vignette) in the limma-*
  modules; survival splits are out of scope here.

## S1 审定附录（2026-09-27，所有者批准）

所有者于 2026-09-27 裁决：`docs/build/S1_DECISION_TABLE_M1M2.md`（下称"决策表"）中 A、B 类项目一律按「建议」栏批准（建议含可选项的，默认值与可选项一并冻结），C 类保持待定。上一节 "S1 drafts and pending decisions" 保留为历史；与本附录不一致处以本附录为准。下列参数在调用中一律显式写出，即使等于函数默认值（ENGINEERING_PLAN §3.3）。L1 路径相对于 `L1_bioc3.23/GSVA/`。

| 编号 | 决定 | 类别 | 依据 |
|---|---|---|---|
| P-1 kernel 与输入尺度 | `gsvaParam(exprData, geneSets, kcdf = "auto", kcdfNoneMinSampleSize = 200, tau = 1, maxDiff = TRUE, absRanking = FALSE, sparse = TRUE, minSize = <P-2>, maxSize = <P-2>)`，经参数对象 API 调 `gsva(param)`。记录输入尺度与存储类型、`auto` 实际选中的分支（Gaussian / Poisson / none——none 时为无 kernel 的 ECDF）以及参数对象。套件 bulk 预设接 VST 或 logCPM；VST 不重复取 log。整数计数模式必须显式 `kcdf = "Poisson"`。拒绝默认计数输入是套件接口策略，不是声称 `auto` 本身不能处理计数。新 API/默认优先于旧文献（旧于 1.50 的 12/17 为 version artefact）。 | A | 决策表 gsva-score P-1；`Rd/gsvaParam.Rd` Usage、`kcdf`；`vignettes/GSVA.Rmd` "Overview of the GSVA functionality"、"Quantification of pathway activity in bulk microarray and RNA-seq data"；`NEWS.txt`；`extraction.jsonl` `kcdf`、`input`、`gsva_version` |
| P-2 集合大小 | bulk 通用预设 `minSize = 5, maxSize = 500`，完整报告过滤掉的集合数；复现 immunologic 示例时用 `minSize = 5, maxSize = 300`。集合大小是用户可配置的分析决定，不称官方统一标准；不为与 fgsea 一致而改成 15–500。 | B | 决策表 gsva-score P-2、「跨模块一致性」第 8 行；`Rd/gsvaParam.Rd`；`GSVA.Rmd` bulk 定量一节（5–500）与 "Differential expression at pathway level / Running GSVA"（5–300）；`extraction.jsonl` `gs_size` |
| P-3 下游组间检验 | 打分与推断分开：原始 scores 交给明确接收连续值的 limma 入口（`lmFit(<scores>, design)` → `eBayes`），保留样本与设计；不走 `voom` 或计数模型，不自动继承 limma-array 的探针过滤与 `trend` 设置；有重复单位时走相关设计（limma-dupcor 规则）；生存分析另行处理，不在本模块。批次校正后的 scores 只作展示，推断用原始 scores + 协变量（batch/SV 进设计）。不得把每个细胞直接当作独立的生物学重复。 | A | 决策表 gsva-score P-3、「跨模块一致性」第 6、7 行；`Rd/gsva.Rd` Value；`GSVA.Rmd` "Differential expression at pathway level"（`lmFit(assay(es), mod)`，SV 进设计，`eBayes(robust = TRUE)`，`trend = sqrt(gssizes)`）；`extraction.jsonl` `downstream_test`；ENGINEERING_PLAN §1.2 B |

待澄清：
- P-3：决策表确定了"交给 limma、不继承芯片 trend"，但没有冻结 scores 上 `eBayes` 的具体取值。GSVA 指南示例用 `eBayes(robust = TRUE)`，并展示 `trend = sqrt(gssizes)`（集合大小趋势，需单独声明）。问题：scores 的 limma 入口默认是 `eBayes(fit, trend = FALSE, robust = TRUE)`、`trend = sqrt(gssizes), robust = TRUE`，还是保持函数默认 FALSE/FALSE？在确认之前不写死。
- P-3：由哪个 limma 模块接收 scores（limma-array 的连续值入口，或新的专门入口）未定；ENGINEERING_PLAN §1.2 B 只写"可交给 limma 做组间比较"。

对上一节草案原文的更正（草案文本保留不改，更正记在这里）：
- P-1 草案"accept log-scale continuous input"：范本的输入不全是 log 尺度（见 V 节行内更正）；套件预设接 VST/logCPM 是接口策略（2026-09-27 更正）。
- P-2 草案"the vignette's examples use 5..500"：还有 5–300 的示例（2026-09-27 更正，决策表第 8 条）。

- C 类待定：本模块无；锚点相关的 M2-3（缺 GSVAdata）为 B 类，已批准（见 `SUITE.md`）。
- D 表：D-GV2、D-GV3、D-GV4、D-GV6 的 Decision 已同步；V 节与 D 表的方法计数、输入尺度、集合大小示例按决策表更正（见行内标注）。
