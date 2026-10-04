# PACK -- fgsea-prerank

Evidence pack of module `fgsea-prerank` (ENGINEERING_PLAN 2.3). Status: **S0 complete (L1 locked
release, L3/L4 collected and independently verified, 2026-09-27); S1 drafted -- the pending decisions
at the end are the owner's. S2 (engine) not started** (built locally).

| Layer | Status | Where |
|---|---|---|
| L1 | fgsea 1.38.0 (Bioconductor 3.23, git.bioconductor.org RELEASE_3_23): vignettes `fgsea-tutorial`, `geseca-tutorial` (source + rendered text), Rd of `fgsea`, `fgseaMultilevel`, `fgseaSimple`, `collapsePathways`, `plotEnrichment`, NEWS, `defaults.tsv` | `L1_bioc3.23/` (manifest with sha256 and git commit) |
| L2 | fgsea tutorial (example pathways / ranks, `minSize = 15, maxSize = 500`, `eps`, `collapsePathways`, `plotEnrichment`, `plotGseaTable`) | cited below |
| L3 | 10 open-access full texts (tier-A journals), close-read notes | `literature/l3_notes.md` |
| L4 | 30 open-access articles 2020-2026 (whitelisted journals, CC BY / CC BY-NC, PubMed-echoed); **30 of 30 apply** | `literature/corpus.jsonl`, `extraction.jsonl`, `efetch/` |
| Verification | 6 of 30 articles, 48 records: 48 pass (100.0 %), PMID echo 6/6 -> **pass** | `literature/verification.json` |

## T -- table skeleton

- Pathway table: pathway, pval, padj, log2err, ES, NES, size, leadingEdge (as `fgsea()` returns), sorted
  by NES within significant / non-significant; optional `collapsePathways` main-pathway flag.

## F -- figure grammar

| Figure | Grammar | Source |
|---|---|---|
| Enrichment curve | running ES along the ranked list, ticks for set members | `plotEnrichment`; `_shared` GSEA curve |
| GSEA table plot | top up / down pathways with mini enrichment plots, NES, padj | `plotGseaTable` (tutorial) |
| NES bar plot | NES per pathway, coloured by padj | exemplars; `_shared` `os_nes_bar` (gallery 08) |

## W -- wording

Exemplar structure (L3): "pre-ranked GSEA was performed with fgsea against <collection>" -- half the
papers do not say how genes were ranked; permutations / multilevel and size limits are rarely stated.
Template to write at S2: fgsea version, ranking statistic and its source module, collection with
version, `minSize` / `maxSize`, multilevel algorithm with `eps`, BH padj cutoff, collapse if used.

## V -- variant frequencies (L4: 30 applicable papers)

Source: `collect.py summarize fgsea-prerank`.

| Parameter (PACK) | Reported values | n.r. | Majority among reporting papers |
|---|---|---|---|
| Ranking statistic (D-F1) | signed -log10(P) 3; DESeq2 Wald statistic 2; log fold change 2; t statistic 2; study-specific scores 6 | 15 | none (signed -log10 P 3 of 15) |
| Collection (D-F2) | MSigDB Hallmark in at least 11 papers; Reactome, KEGG, GO; custom signatures frequent | 5 （2026-09-27 更正：按"该次 fgsea 运行所用集合"口径应为 7——PMC11866441 的 GO 属于另一 GSEA 运行，PMC13589494 的 Hallmark/Reactome 属于另一 proteomics ORA，二者对 fgsea 集合是未知；明确该运行集合的 23/30；recount 2026-09-27） | most common: **Hallmark** (11 of 30, not a majority; PMC10688992's second fgsea run counted once) （2026-09-27 更正：原只写 **Hallmark**，未注分母） |
| Algorithm (D-F3) | permutations (simple): 10,000 x2, 100,000, 5,000; multilevel 2; "default" 1 | 23 | -- (7 reporting, split) |
| Size limits (D-F4) | minSize 10: 1 | 29 | -- |
| Pathway cutoff (D-F5) | padj / FDR 0.05: 5; 0.1: 2; 0.01: 1; nominal P 0.05 only: 1 | 19 (2 with DE cutoffs noted, not counted) | padj 0.05 (5 of 9) |
| Collapse (D-F6) | leading edge reported 1; `collapsePathways` 0 | 29 | -- |
| fgsea version (X) | 1.3.0 - 1.34.2 (9 papers) | 21 | -- |

## C -- anchors

`acceptance/data/ANCHOR_REGISTRY.md` row 12: fgsea `examplePathways` + `exampleRanks` (package-embedded)
and the file variant `naive.vs.th1.rnk` + `mouse.reactome.gmt`; tutorial calls with `minSize = 15,
maxSize = 500`. Multilevel P values are stochastic within `eps`; the anchor fixes the seed and compares
ES / NES exactly and padj within the log2err band (tolerance tier).
（2026-09-27 更正：上句不成立——`eps` 是计算 P 值的下限（`fgseaMultilevel.Rd`："sets the boundary for calculating the p value"），不是随机误差容差；`log2err` 是 log P 的误差量，不能直接当作 padj 的保证区间；NES 用随机样本的平均 ES 标准化，不能跨 seed/引擎无条件承诺精确一致；ENGINEERING_PLAN §3.5 把富集主表列为**逐字节**档，PACK 不能无依据改为容差档。现行做法：同镜像、平台、RNG、输入与参数时主表逐字节核对；环境签名不同只 SKIP；若重复运行证明固定环境仍有差异，另提有数据支持的容差变更建议。另注：教程的 Reactome 调用只设 `maxSize = 500`，并非所有教程调用都是 15–500。）

## D -- defaults: function default / vignette / exemplar majority

Function defaults from `L1_bioc3.23/fgsea/defaults.tsv` (fgsea 1.38.0).

| Id | Parameter | (1) function default | (2) tutorial 3.23 | (3) exemplar majority (V) | Draft | Decision |
|---|---|---|---|---|---|---|
| D-F1 | ranking statistic | `stats` must be supplied | `exampleRanks` (statistic not described) | none (half n.r.) | required input with the statistic named; from deseq2-wald: Wald stat; limma: t | **S1 P-1 (B, owner 2026-09-27)**: same ranking contract as clusterprofiler-gsea; Wald / t preset, any other statistic named; finite / unique / direction / ties checked |
| D-F2 | collection | -- | Reactome (example) | most common Hallmark 11/30, not a majority (recount 2026-09-27) | Hallmark via the refdata registry (msigdbr, pinned release) （2026-09-27 更正：registry 目前只对开发层有具体 msigdbr 记录，锁定容器的 `msigdb_collections` 条目仍待填，不能称已钉版本、可直接运行——依赖基础设施 M1-3（C 类待定））, others by flag | **S1 P-2 (B, owner 2026-09-27)**: Hallmark preselected bulk entry; registered custom collections allowed; collection / species / version / hash resolved, no silent download |
| D-F3 | algorithm | `fgsea()` = multilevel; `eps = 1e-50`, `sampleSize = 101`, `nPermSimple = 1000` | multilevel; text still cites `eps = 1e-10` (written before 1.19.2) | permutations 4, multilevel 2 | multilevel with the function defaults | function default (locked release) |
| D-F4 | `minSize`, `maxSize` | 1, `length(stats) - 1` | **15, 500** in every tutorial call （2026-09-27 更正："Quick run"与"Starting from files"用 15–500，"Using Reactome pathways"只设 `maxSize = 500`，"every"不成立） | minSize 10: 1 (29 n.r.) | 15, 500 | **S1 P-3 (B, owner 2026-09-27)**: explicit 15, 500; retained / excluded sets reported after ID intersection |
| D-F5 | pathway cutoff | -- (padj BH in the table) | `padj < 0.01` for the collapse example | padj 0.05 (5 of 9) | padj < 0.05 | majority |
| D-F6 | collapse | not run | `collapsePathways(fgseaRes[order(pval)][padj < 0.01], ...)` | 0 papers | optional, off | tutorial option |

## X -- version-sensitive behaviour (L1 NEWS, fgsea 1.38.0)

- 1.13.2: `fgsea()` switched from the simple (permutation) to the multilevel algorithm -- exemplars that
  report "N permutations" used `fgseaSimple`-style estimates.
- 1.19.2: default `eps` changed to 1e-50 (the tutorial text still says 1e-10).
- 1.35.1: better cross-platform reproducibility, "but the exact results differ from previous versions";
  1.37.1: hash-based resolution of tied gene sets, integer-scaled gene weights (minor discrepancies).
  Golden files must be regenerated in the container (3.23).

## S1 drafts and pending decisions (the owner decides; no default is fixed yet)

- **P-1 Ranking statistic.** Half the exemplars do not state it; no majority among the rest. Draft: the
  statistic is a required, named input taken from the upstream DE module (Wald statistic from
  deseq2-wald, moderated t from limma, signed -log10 P as an option), and printed in the Methods.
- **P-2 Collection.** Hallmark is the most named collection. Draft: Hallmark by default (msigdbr release
  pinned in `env/refdata_registry.json`), other collections by flag; KEGG excluded by the licence gate.
- **P-3 Size limits.** Function default 1..n-1; the tutorial uses 15..500 throughout; 1 exemplar states
  minSize 10. Draft: 15..500 (tutorial), reported with the number of sets kept; the owner decides because
  it departs from the function default.

## S1 审定附录（2026-09-27，所有者批准）

所有者于 2026-09-27 裁决：`docs/build/S1_DECISION_TABLE_M1M2.md`（下称"决策表"）中 A、B 类项目一律按「建议」栏批准（建议含可选项的，默认值与可选项一并冻结），C 类保持待定。上一节 "S1 drafts and pending decisions" 保留为历史；与本附录不一致处以本附录为准。下列参数在调用中一律显式写出，即使等于函数默认值（ENGINEERING_PLAN §3.3）。L1 路径相对于 `L1_bioc3.23/fgsea/`。

| 编号 | 决定 | 类别 | 依据 |
|---|---|---|---|
| P-1 排序统计量 | 与 clusterprofiler-gsea P-1 使用同一排名输入契约与 provenance：DE 衔接预设为 DESeq2 Wald `stat` / limma moderated t，其他统计量必须命名。运行前检查 `stats` 为有限值、ID 唯一且有名称、方向明确，并报告 ties。选 signed P 时必须说明零 P 与无穷值的处理。不得只给显著 DEG 子集却称全排序 GSEA。调用：`fgseaMultilevel(pathways, stats, minSize = <P-3>, maxSize = <P-3>, gseaParam = 1, scoreType = "std", sampleSize = 101, eps = 1e-50, nPermSimple = 1000, absEps = NULL, nproc = 1)`，并 `set.seed(<套件 seed>)`（`gseaParam` 至 `absEps` 为锁定版函数默认，决策表未另作取舍；`nproc = 1` 与种子来自 ENGINEERING_PLAN §3.4）。 | B | 决策表 fgsea-prerank P-1、「跨模块一致性」第 2 行；`Rd/fgseaMultilevel.Rd` `stats`、`gseaParam`；`vignettes/fgsea-tutorial.Rmd` "Quick run"、"Starting from files"；`extraction.jsonl` `ranking_metric`；ENGINEERING_PLAN §5 富集路由 |
| P-2 默认基因集 | 提供预选 Hallmark 的 bulk 入口；允许研究问题需要的、已登记的自定义集合。集合、物种、版本及散列必须已解决，不得默默下载，也不认定 registry 已完备。Hallmark 是常见选择，不是官方默认。锁定容器的 msigdb 条目仍待填，依赖基础设施 M1-3（C 类待定），在其补齐前不能称可直接运行。 | B | 决策表 fgsea-prerank P-2；`Rd/fgseaMultilevel.Rd` `pathways`；`fgsea-tutorial.Rmd` "Quick run"、"Using Reactome pathways"；`extraction.jsonl` `gene_set_db`；`env/refdata_registry.json` `msigdb_collections` 与开发层条目 |
| P-3 集合大小 | 主流程显式 `minSize = 15, maxSize = 500`，报告 ID 交集后保留与排除的集合数；研究小集合时用户可预设其他范围。与 clusterprofiler-gsea 的 10–500 保持明确差异；同一研究做两引擎对照时，预先统一基因宇宙、排名、集合、交集后尺寸、权重指数与 cutoff（即使统一，也不保证数值相同）。15–500 是教程实例，不是包的普遍强制规则。 | B | 决策表 fgsea-prerank P-3、「跨模块一致性」第 8 行；`Rd/fgseaMultilevel.Rd` Usage、Value `size`；`fgsea-tutorial.Rmd` 上述三节；`extraction.jsonl` `gs_size`（PMC11866449） |

对上一节草案原文的更正（草案文本保留不改，更正记在这里）：
- P-2 草案"Hallmark is the most named collection ... msigdbr release pinned in `env/refdata_registry.json`"：Hallmark 11/30 只是最常见、未过半；registry 只对开发层有具体记录，容器条目仍待填（2026-09-27 更正，决策表第 5、7、13 条）。
- P-3 草案"the tutorial uses 15..500 throughout"：Reactome 那次调用只设 `maxSize = 500`（2026-09-27 更正，决策表第 8 条）。

- C 类待定：本模块无；P-2 依赖的基础设施 M1-3 为 C 类待定，见 `SUITE.md`。待澄清：无。
- D 表：D-F1、D-F2、D-F4 的 Decision 已同步；V 节集合计数、D-F2 草案列的 registry 表述、D-F4 教程表述与 C 节 `eps`/`log2err` 描述按决策表更正（见行内标注）。
