# PACK -- clusterprofiler-gsea

Evidence pack of module `clusterprofiler-gsea` (ENGINEERING_PLAN 2.3). Status: **S0 complete (L1 locked
release, L3/L4 collected and independently verified, 2026-09-27); S1 drafted -- the pending decisions
at the end are the owner's. S2 (engine) not started** (built locally).

| Layer | Status | Where |
|---|---|---|
| L1 | clusterProfiler 4.20.0, enrichplot 1.32.1, DOSE 4.6.0 (Bioconductor 3.23, RELEASE_3_23): Rd of `gseGO`, `GSEA`, `gseaplot2`, `ridgeplot`, current NEWS, `defaults.tsv`; **enrichit 0.2.1** (CRAN snapshot 2026-09-15 of the locked image), which now carries the GSEA computation (`gsea`, `gsea_gson`) | `L1_bioc3.23/`, `L1_cran2026-09-15/` (manifests with sha256) |
| L2 | clusterProfiler book chapters (`enrichment-foundations`, `enrichment-overview`, `go-enrichment`, `universal-enrichment`, `enrichplot-gsea`, `leading-edge-nonmodel`, `data-contract`), pinned by commit 5496131 + sha256, not copied | `L2/manifest.tsv`, `L2/README.md` |
| L3 | 10 open-access full texts (tier-A journals), close-read notes | `literature/l3_notes.md` |
| L4 | 30 open-access articles 2020-2026 (whitelisted journals, CC BY / CC BY-NC, PubMed-echoed); **28 of 30 apply** (2 run ORA functions under a "GSEA" heading) | `literature/corpus.jsonl`, `extraction.jsonl`, `efetch/` |
| Verification | 6 of 30 articles, 48 records: 48 pass (100.0 %), PMID echo 6/6 -> **pass** | `literature/verification.json` |

## T -- table skeleton

- GSEA table: ID, Description, setSize, enrichmentScore, NES, pvalue, p.adjust, qvalue, rank,
  leading_edge, core_enrichment; header: ranking statistic and its source, database release, method
  (multilevel / eps), seed, size limits.

## F -- figure grammar

| Figure | Grammar | Source |
|---|---|---|
| GSEA running score | running ES, hits, ranked metric; several sets overlaid | `gseaplot2`; `_shared` gallery 09 |
| Ridge plot | distribution of core-enrichment fold changes per set | `ridgeplot` |
| Dot plot | NES or GeneRatio vs term, colour = p.adjust, split by sign | `dotplot(split = ".sign")`; `_shared` gallery 07 |

## W -- wording

Exemplar structure (L3): "GSEA was performed with clusterProfiler (gseGO / GSEA) on genes ranked by
<statistic>"; the ranking statistic is missing in about half of the papers, permutations and size limits
are rarely given. Template to write at S2: clusterProfiler (and enrichit) version, ranking statistic and
source module, database and release, method (multilevel), seed, size limits, BH, cutoff.

## V -- variant frequencies (L4: 28 applicable papers)

Source: `collect.py summarize clusterprofiler-gsea`.

| Parameter (PACK) | Reported values | n.r. | Majority among reporting papers |
|---|---|---|---|
| Ranking statistic (D-G1) | (log2) fold change 7; test statistic (Wald / DESeq2) 3; correlation coefficient 2; model coefficient 2; signed -log10 P 1; other 1 | 13 | most common: fold-change type (7 of 15) （2026-09-27 更正：原写 **log2 fold change** (7 of 15) 作多数；7/15 未过半，只是最常见；这 7 篇还包括 mixed LME/ROTS 与非 log 的 FC，mixed 行可与其他类别重叠；recount 2026-09-27） |
| Database (D-G2) | GO most often (BP where specified); KEGG; MSigDB Hallmark 5; Reactome; custom sets | 3 | GO |
| Permutations / method (D-G3) | nPerm 10,000: 3; 20,000: 1; 100,000: 1; defaults / seed only: 2 | 21 | -- (7 reporting) |
| Size limits (D-G4) | 3 / 800: 2; 10 / 500 (defaults) 1; 5 / 500 1; min 20 1; max 20000 1 | 22 | -- |
| Adjustment (D-G5) | BH 5 | 23 | BH |
| Set cutoff (D-G6) | adjusted P / q < 0.05: 6; pvalueCutoff 0.05 (applies to p.adjust in clusterProfiler) 3 + "P cutoff" only 1 (PMC13535199, cannot be confirmed as adjusted); FDR < 0.25 (Broad convention) 2; nominal P 1; 0.1 / 0.01 1 | 14 | **0.05** (9 of 14; the ambiguous one kept separate) （2026-09-27 更正：原写 pvalueCutoff 0.05: 4 与 **0.05** (10 of 14)；PMC13535199 只写 "P cutoff"，不能推为 adjusted；`qvalueCutoff`、nominal P 与 BH adjusted P 不得互相替换；recount 2026-09-27） |
| clusterProfiler version (X) | 3.10.1 - 4.16.0 (12 papers) | 16 | -- |

## C -- anchors

`acceptance/data/ANCHOR_REGISTRY.md` row 10: DOSE `geneList` with `gseGO` (book examples), GO from the
refdata registry. Multilevel P values are stochastic within `eps`: seed fixed, NES / ES compared exactly,
p.adjust in the tolerance tier.
（2026-09-27 更正：上句"stochastic within `eps`"是错的——`eps` 是可估计的最小 P 值（计算下限，enrichit `gsea.Rd`），不是随机误差容差；NES 用随机样本的平均 ES 标准化，不能跨 seed/引擎无条件承诺精确一致；ENGINEERING_PLAN §3.5 把富集主表列为**逐字节**档，PACK 不能无依据把 p.adjust 改到容差档。现行做法：同镜像、平台、RNG、输入与参数时主表逐字节核对；环境签名不同只 SKIP 基线检查；若重复运行证明固定环境仍有差异，另提有数据支持的容差变更建议。见 S1 审定附录 P-2。）

## D -- defaults: function default / book / exemplar majority

Function defaults from `L1_bioc3.23/clusterProfiler/defaults.tsv` (`gseGO`, `GSEA`) and
`L1_cran2026-09-15/enrichit/Rd/gsea.Rd`.

（2026-09-27 更正/限定：列 (2) 的"book"内容是在线书的转述；本地 vignette 只有外链、`L2/` 只存 manifest 与散列，这些转述未经独立核实。决策表第 13 条。）

| Id | Parameter | (1) function default | (2) book | (3) exemplar majority (V) | Draft | Decision |
|---|---|---|---|---|---|---|
| D-G1 | ranking statistic | `geneList` must be supplied (decreasing named numeric) | `geneList` (log fold changes) in examples | most common FC-type 7 of 15, not a majority (recount 2026-09-27) | log2FC (shrunken LFC from deseq2-wald) or the test statistic, named | **S1 P-1 (B, owner 2026-09-27)**: signed test statistic (DESeq2 Wald `stat` / limma moderated t) as the DE hand-off preset, shared with fgsea-prerank; LFC etc. by explicit, named choice |
| D-G2 | `ont` / database | `gseGO(ont = "BP")` | BP | GO | GO BP; Hallmark via `GSEA(TERM2GENE)` from the registry; KEGG excluded | default + majority agree |
| D-G3 | method | `method = "multilevel"` (enrichit C++, "derived from fgsea"), `nPerm = 1000` only for permutation methods, `adaptive = FALSE` | multilevel | nPerm stated by 5 (older versions) | multilevel, seed fixed and reported | function default; **S1 P-2 (A, owner 2026-09-27)**: goldens only from the locked container; all downstream arguments and seed/RNG/parallel settings written out |
| D-G4 | `minGSSize`, `maxGSSize` | 10, 500 | defaults | defaults 1 of 6 reporting | 10, 500 | function default |
| D-G5 | `pvalueCutoff`, `pAdjustMethod` | 0.05 (on p.adjust), "BH" | defaults | 0.05 (adjusted or `pvalueCutoff`) 9 of 14 reporting, 1 ambiguous kept separate; BH (recount 2026-09-27) | function defaults; report the full table, flag significant | **S1 P-3 (A, owner 2026-09-27)**: compute with `pvalueCutoff = 1`, `pAdjustMethod = "BH"`; flag `p.adjust < 0.05`; 0.25 only as a pre-declared exploratory option |

## X -- version-sensitive behaviour

- **Engine change.** Bioconductor 3.23 (DOSE 4.6.0 / clusterProfiler 4.20.0): GSEA is computed by
  enrichit (C++ multilevel, "derived from fgsea"); the dev tier (Bioconductor 3.22: clusterProfiler
  4.18.4, DOSE 4.4.0) still calls fgsea. enrichit 0.2.0 aligned its rank scaling with
  `fgsea::prepareStats()` "to reduce result drift relative to the long-used fgsea backend" (a regression
  test compares it with `fgseaMultilevel`); 0.2.1 intersects gene sets with the ranked genes before the
  size filter (clusterProfiler#824) -- set counts can differ from older versions. Goldens: container only.
- Exemplars reporting `nPerm` used the permutation GSEA of older clusterProfiler / DOSE versions.
- DOSE 3.x: `qvalues` column renamed `qvalue` (2022).

## S1 drafts and pending decisions (the owner decides; no default is fixed yet)

- **P-1 Ranking statistic.** Required input; exemplars favour log2 fold change (7 of 15). Draft: the
  shrunken log2FC from deseq2-wald (or the moderated t from limma) with the choice printed; the owner
  decides between LFC and the test statistic as the default.
- **P-2 Engine difference between tiers.** The dev tier (fgsea backend) and the locked image (enrichit)
  produce different P values. Draft: accept; dev-tier goldens are marked SKIP by signature, only the
  container goldens count (ENGINEERING_PLAN 3.5). Needs the owner's acknowledgement.
- **P-3 Cutoff convention.** Two papers use the Broad desktop convention FDR < 0.25. Draft: p.adjust < 0.05
  (function default and majority), the full table always written.

## S1 审定附录（2026-09-27，所有者批准）

所有者于 2026-09-27 裁决：`docs/build/S1_DECISION_TABLE_M1M2.md`（下称"决策表"）中 A、B 类项目一律按「建议」栏批准（建议含可选项的，默认值与可选项一并冻结），C 类保持待定。上一节 "S1 drafts and pending decisions" 保留为历史；与本附录不一致处以本附录为准。下列参数在调用中一律显式写出，即使等于函数默认值（ENGINEERING_PLAN §3.3）。

| 编号 | 决定 | 类别 | 依据 |
|---|---|---|---|
| P-1 排序统计量 | 与 fgsea-prerank 统一的排名输入契约：同一上游 contrast 生成一份带名称、带方向的统计量，DE 衔接预设为 DESeq2 单一 contrast 的 Wald `stat`、limma 的 moderated t；LFC、相关系数等只能由用户显式选择并在输出中命名（选 LFC 时两个 GSEA 模块用同一明示的 LFC 类型，不得一边 MLE、一边 shrinkage）。全部可排名基因进入 `geneList`（有名称、降序），不预先按显著性截断。LRT / 多自由度 F 等无方向统计量不能直接作方向性排名：须指定具体 contrast，或明示为非方向分析。 | B | 决策表 clusterprofiler-gsea P-1、「跨模块一致性」第 2 行；`L1_bioc3.23/clusterProfiler/Rd/GSEA.Rd`、`Rd/gseGO.Rd`；`L1_cran2026-09-15/enrichit/Rd/gsea.Rd` `geneList`；`extraction.jsonl` `ranking_metric`；跨模块 DESeq2 `results.Rd` Value、limma `eBayes.Rd` Value |
| P-2 开发层与锁定容器的引擎及金标准 | 接受版本分层（引擎迁移是 version artefact）：权威金标准只由锁定容器生成；开发层环境签名不符时只 SKIP 逐字节基线检查，其余可执行检查照常运行。同签名下主表按 §3.5 逐字节核对，不预先把 p.adjust 改到容差档。调用显式写出：`GSEA(geneList, TERM2GENE = <集合>, TERM2NAME = <名称或 NA>, exponent = 1, minGSSize = 10, maxGSSize = 500, pvalueCutoff = 1, pAdjustMethod = "BH", nPerm = 1000, method = "multilevel", adaptive = FALSE, minPerm = 101, maxPerm = 1e5, pvalThreshold = 0.1)`（`gseGO` 同，另加 `ont`、`OrgDb`、`keyType`）；并登记 enrichit 0.2.1 下游参数 `eps = 1e-10, sampleSize = 101, nPermSimple = 1000, scoreType = "std", weight = NULL` 与 seed/RNG/并行配置（`set.seed(<套件 seed>)`，单线程）。`eps` 是可估计的最小 P 值，不是数值容差；NES 不能跨引擎保证精确相等。 | A | 决策表 clusterprofiler-gsea P-2、「跨模块一致性」第 9 行；`Rd/GSEA.Rd`、`Rd/gseGO.Rd`；`L1_bioc3.23/DOSE/NEWS.txt` 4.5.1；`L1_cran2026-09-15/enrichit/Rd/gsea.Rd`、`NEWS.txt` 0.2.0–0.2.1；ENGINEERING_PLAN §3.4–3.5 |
| P-3 0.05 或 Broad 0.25 | 主推断显式 BH 0.05：计算时 `pvalueCutoff = 1`、`pAdjustMethod = "BH"` 保存全部可检验的集合，另存 `p.adjust < 0.05` 标记，原始表不裁剪。FDR 0.25 只作事先声明的探索性/历史复现选项。nominal P、`qvalueCutoff`、BH adjusted P 不互相替换。 | A | 决策表 clusterprofiler-gsea P-3、「跨模块一致性」第 4 行；`Rd/GSEA.Rd` `pvalueCutoff`；`extraction.jsonl` `enrich_cutoff`（含混 PMC13535199；0.25 PMC7592056、PMC10668425） |

待澄清：
- P-2（S2 须核对，不是新裁决）：enrichit `gsea.Rd` 写明 `seed` 默认 FALSE 时"a random seed is generated"。clusterProfiler `GSEA`/`gseGO` 的 Usage 里没有 `seed` 形参，只有 `...`。问题：锁定容器中 `set.seed()` 是否足以固定 enrichit 的 multilevel 抽样，还是必须经 `...` 显式传入 `seed = <整数>`？在锁定容器用最小调用核查之前，不能宣称主表逐字节可复现。
- P-2 的调用中 `pvalueCutoff = 1` 来自 P-3。

对上一节草案原文的更正（草案文本保留不改，更正记在这里）：
- P-1 草案"exemplars favour log2 fold change (7 of 15)"并以 deseq2-wald 的收缩 LFC 为候选：7/15 未过半，只是最常见；与 fgsea 草案（Wald/t）在同一输入上默认不一致，现按 P-1 统一（2026-09-27 更正，决策表第 5 条及跨模块第 2 行）。
- P-3 草案"p.adjust < 0.05 (function default and majority)"：可靠支持是 9/14（含混 1 篇另计），不是 PACK 原写的 10/14（2026-09-27 更正，决策表第 6 条）。

- C 类待定：本模块无；相关的基础设施项 M2-2（enrichit 是否进入容器 pkg_lock、金标准来源）为 C 类待定，见 `SUITE.md`。
- D 表：D-G1、D-G3、D-G5 的 Decision 已同步；V 节与 D 表的排序统计量、cutoff 计数按决策表更正；C 节 `eps` 描述更正；列 (2) 在线书转述标注为未经本地核实（见行内标注）。
