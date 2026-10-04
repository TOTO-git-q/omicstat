# PACK -- clusterprofiler-compare

Evidence pack of module `clusterprofiler-compare` (ENGINEERING_PLAN 2.3). Status: **S0 complete (L1
locked release, L3/L4 collected and independently verified, 2026-09-27); S1 drafted -- the pending
decisions at the end are the owner's. S2 (engine) not started** (built locally).

| Layer | Status | Where |
|---|---|---|
| L1 | clusterProfiler 4.20.0 and enrichplot 1.32.1 (Bioconductor 3.23, git.bioconductor.org RELEASE_3_23): Rd of `compareCluster`, `dotplot`, NEWS, `defaults.tsv`; the package vignettes only point to the online book | `L1_bioc3.23/` (manifest with sha256 and git commit) |
| L2 | clusterProfiler book chapters `comparecluster-analysis`, `comparecluster-visualization`, `enrichplot-comparison`, pinned by commit 5496131 + sha256, not copied (no licence file) | `L2/manifest.tsv`, `L2/README.md` |
| L3 | 10 open-access full texts (tier-A journals), close-read notes | `literature/l3_notes.md` |
| L4 | 30 open-access articles 2020-2026 (whitelisted journals, CC BY / CC BY-NC, PubMed-echoed); **26 of 30 apply** (4 run compareCluster / enrichGO on a single list) | `literature/corpus.jsonl`, `extraction.jsonl`, `efetch/` |
| Verification | 6 of 30 articles, 42 records: 42 pass (100.0 %), PMID echo 6/6 -> **pass** | `literature/verification.json` |

## T -- table skeleton

- One long table: Cluster (list name), ID, Description, GeneRatio, BgRatio, pvalue, p.adjust, qvalue,
  geneID, Count -- as `as.data.frame(compareCluster(...))`; plus the list sizes before / after ID mapping.

## F -- figure grammar

| Figure | Grammar | Source |
|---|---|---|
| Comparison dot plot | x = gene list, y = term, size = GeneRatio, colour = p.adjust; `showCategory` per list | `enrichplot::dotplot(compareClusterResult)`; `_shared` gallery 10 |
| Term network | terms coloured by list share (emapplot pies) | book `comparecluster-visualization` (not in the exemplars' Methods) |

## W -- wording

Exemplar structure (L3): "functional profiles of the <clusters / modules / up-down sets> were compared with
compareCluster (clusterProfiler)"; the enrichment function is usually implied (`fun` n.r. in 17 of 26),
cutoffs often missing. Template to write at S2: clusterProfiler version, `fun` and ontology, what the
lists are and how each was defined (DE module + cutoffs), universe, BH and the p / q cutoffs, list sizes.

## V -- variant frequencies (L4: 26 applicable papers)

Source: `collect.py summarize clusterprofiler-compare`.

| Parameter (PACK) | Reported values | n.r. | Majority among reporting papers |
|---|---|---|---|
| `fun` (D-C1) | enrichGO 8; enrichKEGG + enrichPathway + enrichGO 1 | 17 | **enrichGO** (9 of 9) （2026-09-27 更正：原写 8 of 9，只数了单一 enrichGO 行；含 enrichGO 的合计 9/26 = 9/9 报 `fun`；recount 2026-09-27） |
| Lists compared (D-C2) | single-cell or consensus clusters 6+; up / down DE sets; modules (WGCNA); peak sets per tissue / genotype; protein groups | 4 | clusters of cells or genes |
| Ontology / database (D-C3) | GO (BP most often named; "GO" alone 7) in 23 papers; KEGG 6; Reactome 2; MSigDB Hallmark 1 | 1 | **GO** (BP where specified) （2026-09-27 更正：BP-only 8/26、BP/CC/MF 或 ALL 3/26（PMC10578035、PMC8454054、PMC9531456）、CC-only 1/26（PMC8111910）；明确本体的 12 篇中 BP 出现 11/12，不能写成全部 BP；CC 与 ALL 是真实需求，不是提取错误；recount 2026-09-27） |
| Adjustment (D-C4) | BH 6; Bonferroni 1; "FDR" 1 | 18 | BH (6 of 8) |
| Term cutoff (D-C5) | 0.05 (p.adjust / q / p) 7; q 0.1 1; FDR 10 % 1; 0.2 1; 0.001 1; pvalueCutoff 0.05 + qvalueCutoff 0.2 (the function defaults) 1 | 14 | 0.05 (7 of 12) |
| clusterProfiler version (X) | 3.10.1 - 4.8.1 (13 papers) | 13 | -- |

## C -- anchors

`acceptance/data/ANCHOR_REGISTRY.md` row 11: clusterProfiler `gcSample` (8 gene clusters,
package-embedded), `compareCluster(gcSample, fun = "enrichGO", OrgDb = org.Hs.eg.db)` as in the book; GO
from the refdata registry (org.Hs.eg.db / GO.db). The book is not a release document, so this is a
replay anchor (no printed values from the locked release).

## D -- defaults: function default / book / exemplar majority

Function defaults from `L1_bioc3.23/{clusterProfiler,enrichplot}/defaults.tsv` (clusterProfiler 4.20.0);
the inner function's defaults are those of clusterprofiler-ora (`enrichGO(ont = "MF", pvalueCutoff = 0.05,
qvalueCutoff = 0.2, pAdjustMethod = "BH", minGSSize = 10, maxGSSize = 500)`).

（2026-09-27 更正/限定：列 (2) 的"book"内容是在线书的转述；本地 vignette 只有外链、`L2/` 只存 manifest 与散列，这些转述未经独立核实，不能写成已从正文重导的官方推荐。决策表第 13 条。）

| Id | Parameter | (1) function default | (2) book | (3) exemplar majority (V) | Draft | Decision |
|---|---|---|---|---|---|---|
| D-C1 | `fun` | `"enrichGO"` | enrichGO / enrichKEGG examples | enrichGO 9/9 reporting （2026-09-27 更正：原写 8/9；recount 2026-09-27） | `enrichGO` | default + majority agree; **S1 P-1 (A, owner 2026-09-27)**: `fun = "enrichGO"` written out |
| D-C2 | `ont` (inside enrichGO) | "MF" | book `comparecluster-analysis` example: `compareCluster(gcSample, fun = enrichGO, OrgDb = org.Hs.eg.db, ont = "BP")` | BP-only 8/26, BP/CC/MF or ALL 3/26, CC-only 1/26; BP in 11/12 naming an ontology (recount 2026-09-27) | **disagreement** function default vs practice | **S1 P-1 (A, owner 2026-09-27)**: `ont = "BP"` preset, same as clusterprofiler-ora |
| D-C3 | p / q cutoffs, adjustment | 0.05 / 0.2, BH | defaults | 0.05 (7 of 12), BH 6/8 | function defaults (0.05 / 0.2, BH) | function default |
| D-C4 | universe | all annotated genes of the OrgDb | book `data-contract`: the universe is "the set of genes that could have been selected in the experiment", not every annotated gene | field not collected: verifiable background 0/26 -- not evidence that the 26 papers gave none （2026-09-27 更正：原写 n.r.） | expressed genes of the upstream DE module | **S1 P-2 (A, owner 2026-09-27)**: per-list candidate background and source; one explicit shared universe only for one selectable population; never the union of all lists |
| D-C5 | lists | `geneClusters` (named list) or formula interface | both | clusters, up/down, modules | named list; each list's definition recorded | **S1 P-3 (A, owner 2026-09-27)** |

## X -- version-sensitive behaviour

- clusterProfiler 4.20.0 is the locked release; the book tracks the development versions (it also
  documents packages outside the release, e.g. `enrichit`) -- statements from it are checked against the
  3.23 Rd before use.
- Exemplars span clusterProfiler 3.10 - 4.8; KEGG results from `enrichKEGG` depend on the online KEGG
  release (licence gate: not used by omicstat).

## S1 drafts and pending decisions (the owner decides; no default is fixed yet)

- **P-1 GO ontology.** `enrichGO` defaults to `ont = "MF"`; the book's compareCluster example and the
  exemplars that specify it use BP. Draft: `ont = "BP"` stated in the output; decided together with clusterprofiler-ora.
- **P-2 Universe.** Default = all annotated genes; no exemplar states it. Draft: the expressed genes
  passed from the upstream module, decided together with clusterprofiler-ora.
- **P-3 Lists without a stated definition.** 5 papers name compareCluster without saying what the lists
  are. Draft: the module requires a named list and records how each list was produced.

## S1 审定附录（2026-09-27，所有者批准）

所有者于 2026-09-27 裁决：`docs/build/S1_DECISION_TABLE_M1M2.md`（下称"决策表"）中 A、B 类项目一律按「建议」栏批准（建议含可选项的，默认值与可选项一并冻结），C 类保持待定。上一节 "S1 drafts and pending decisions" 保留为历史；与本附录不一致处以本附录为准。下列参数在调用中一律显式写出，即使等于函数默认值（ENGINEERING_PLAN §3.3）。L1 路径相对于 `L1_bioc3.23/clusterProfiler/`。

| 编号 | 决定 | 类别 | 依据 |
|---|---|---|---|
| P-1 GO 本体与 `fun` | 与 clusterprofiler-ora 同步：`compareCluster(geneClusters, fun = "enrichGO", OrgDb = <registry 中的 OrgDb>, keyType = <与输入一致>, ont = "BP", pool = FALSE, ...)`（`ont`、`pool` 经 `...` 传给 enrichGO，取值同 ORA P-1）。用户改变本体时，连同比较配置一并记录；所有列表使用相同注释版本和检验范围。 | A | 决策表 clusterprofiler-compare P-1；`Rd/compareCluster.Rd`；跨模块 `clusterprofiler-ora/L1_bioc3.23/clusterProfiler/Rd/enrichGO.Rd`；`extraction.jsonl` `gene_set_db`、`fun` |
| P-2 多列表的背景 | 每个列表附候选背景及其来源。各列表确实来自同一可选择总体时，传同一个显式 `universe`（经 `...` 传给 enrichGO）；检测空间不同时分别做富集并注明背景差异；不得拿所有列表的并集充当"共同背景"。"expressed"不自动等于"可被当前规则选中"（规则同 ORA P-2）。比较图不检验"某通路在列表 A 比 B 更富集"的差异显著性，文字不得这样表述。 | A | 决策表 clusterprofiler-compare P-2；`Rd/compareCluster.Rd` Description、`...`；跨模块 ORA `enrichGO.Rd` `universe` |
| P-3 每个列表的定义 | 接收命名列表，或可等价转换且保留原式的公式接口。每个列表必报：研究单位、上游模型/contrast、方向、阈值、top-N（如有）、输入数与 ID 映射后的数量、背景。禁止把同一个体的重复当作独立样本；不把 term 列表误作 gene 列表。 | A | 决策表 clusterprofiler-compare P-3；`Rd/compareCluster.Rd` Arguments、Examples；`extraction.jsonl` `clusters`（PMC11540020 及复算索引） |

对上一节草案原文的更正（草案文本保留不改，更正记在这里）：
- P-1 草案"the book's compareCluster example and the exemplars that specify it use BP"：书中示例未经本地核实（决策表第 13 条）；明确本体的 12 篇中 BP 出现 11/12，另有 CC-only 与三本体/ALL（2026-09-27 更正，决策表第 4 条）。
- P-2 草案"no exemplar states it"：本模块未采 `universe` 字段，可核实的背景记录为 0/26，不能说 26 篇都没有交代（2026-09-27 更正）。
- P-3 草案"5 papers name compareCluster without saying what the lists are"：严格 `not reported` 为 4/26；PMC11540020 另 1/26 只说了功能结果、未命名具体基因列表；合计"定义不足"5/26 是语义合并，两种口径分开（2026-09-27 更正）。

- C 类待定：无。待澄清：无。
- D 表：D-C1、D-C2、D-C4、D-C5 的 Decision 已同步；V 节与 D 表的 `fun`、本体、背景计数按决策表更正；列 (2) 在线书转述标注为未经本地核实（见行内标注）。
