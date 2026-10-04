# PACK -- clusterprofiler-ora

Evidence pack of module `clusterprofiler-ora` (ENGINEERING_PLAN 2.3). Status: **S0 complete (L1 locked
release, L3/L4 collected and independently verified, 2026-09-27); S1 drafted -- the pending decisions
at the end are the owner's. S2 (engine) not started** (built locally).

| Layer | Status | Where |
|---|---|---|
| L1 | clusterProfiler 4.20.0, enrichplot 1.32.1, DOSE 4.6.0 (Bioconductor 3.23, git.bioconductor.org RELEASE_3_23): Rd of `enrichGO`, `enricher`, `enrichKEGG`, `simplify`, `setReadable`, `dotplot`, `cnetplot`, current NEWS (`NEWS.md`), `defaults.tsv`; **enrichit 0.2.1** (CRAN snapshot 2026-09-15 of the locked image), which now carries the ORA computation (`ora`, `ora_gson`) | `L1_bioc3.23/`, `L1_cran2026-09-15/` (manifests with sha256) |
| L2 | clusterProfiler book chapters (`enrichment-foundations`, `enrichment-overview`, `go-enrichment`, `universal-enrichment`, `reactome-enrichment`, `semantic-similarity`, `enrichplot-summary`, `data-contract`), pinned by commit 5496131 + sha256, not copied (no licence file) | `L2/manifest.tsv`, `L2/README.md` |
| L3 | 10 open-access full texts (tier-A journals), close-read notes | `literature/l3_notes.md` |
| L4 | 30 open-access articles 2020-2026 (whitelisted journals, CC BY / CC BY-NC, PubMed-echoed); **30 of 30 apply** | `literature/corpus.jsonl`, `extraction.jsonl`, `efetch/` |
| Verification | 6 of 30 articles, 54 records: 54 pass (100.0 %), PMID echo 6/6 -> **pass** | `literature/verification.json` |

## T -- table skeleton

- Enrichment table: ID, Description, GeneRatio, BgRatio, pvalue, p.adjust, qvalue, geneID (symbols via
  `setReadable`), Count; header: input list size, universe size, ontology, cutoffs, database release.

## F -- figure grammar

| Figure | Grammar | Source |
|---|---|---|
| Dot plot | y = term, x = GeneRatio, size = Count, colour = p.adjust | `enrichplot::dotplot`; `_shared` gallery 06 |
| Gene-concept network | terms and genes, gene colour = logFC | `cnetplot`; `_shared` gallery 28 (known label issue, SUITE M0.3) |
| Bar plot | Count or -log10 p.adjust per term | exemplars |

## W -- wording

Exemplar structure (L3): "GO (and KEGG) enrichment of <DE genes / cluster markers> was performed with
clusterProfiler (enrichGO)"; the input list is usually defined (with its DE cutoffs), the universe and the
term cutoff usually not. Template to write at S2: clusterProfiler version, input list and its source
module + cutoffs, universe, ontology, database / annotation release (org.Hs.eg.db / GO.db / msigdbr),
BH, p / q cutoffs, size limits, redundancy reduction if used.

## V -- variant frequencies (L4: 30 applicable papers)

Source: `collect.py summarize clusterprofiler-ora`.

| Parameter (PACK) | Reported values | n.r. | Majority among reporting papers |
|---|---|---|---|
| Input list (D-O1) | DE genes with a padj cutoff; cluster markers; ChIP-peak genes; modules; others | 3 | DE genes (study-specific cutoffs) |
| Database (D-O2) | GO in 28 papers ("GO" alone 13; BP 5 + more within multi-database lines); KEGG 7; Reactome 2; MSigDB Hallmark 2; custom 1 | 0 | **GO** (BP where specified) （2026-09-27 更正：明确涉及 BP 的 8/30——BP 单本体 7/30，BP/CC/MF 同时 1/30（PMC8617197）；明确本体者 BP 8/8。不能写成全部 30 篇都选 BP；BP 是预设建议，不是文献一致；recount 2026-09-27） |
| Universe (D-O3) | expressed / detected genes of the experiment 6 (worded differently) | 24 | expressed genes (6 of 6) （2026-09-27 限定：6/30，其中含"检测集与注释的交集"等写法，不全是同一个"DE tested"定义） |
| Adjustment (D-O4) | BH 5; "fdr" argument 1 | 24 | **BH** |
| Term cutoff (D-O5) | adjusted P / q < 0.05: 9; 0.1: 1; pvalueCutoff 0.05 + qvalueCutoff 0.2 (function defaults) 1 | 19 | **0.05 adjusted** (9 of 11) |
| Size limits (D-O6) | minGSSize 10, maxGSSize 500 (the defaults) 1 | 29 | -- |
| Redundancy (D-O7) | `simplify()` 2 (one with cutoff 0.7 / 0.8); REVIGO 1 | 27 | -- |
| clusterProfiler version (X) | 3.2.14 - 4.18.4 (16 papers) | 14 | -- |

## C -- anchors

`acceptance/data/ANCHOR_REGISTRY.md` row 9: DOSE `geneList` (12495 ranked Entrez ids; the ORA list is a
cut of it, `names(geneList)[abs(geneList) > 2]` in the book), GO from the refdata registry
(org.Hs.eg.db / GO.db). The book is not a release document -> replay anchor.

## D -- defaults: function default / book / exemplar majority

Function defaults from `L1_bioc3.23/clusterProfiler/defaults.tsv` (clusterProfiler 4.20.0).

（2026-09-27 更正/限定：列 (2) 的"book"内容是在线书的转述。本地 vignette 只有外链，`L2/` 只存 manifest 与散列、没有章节正文，所以这些转述**未经独立核实**，不能写成已从正文重导的官方推荐；补证须按 manifest 的 commit 收集允许存档的段落，或在获准联网的取证任务中核验。决策表第 13 条。）

| Id | Parameter | (1) function default | (2) book | (3) exemplar majority (V) | Draft | Decision |
|---|---|---|---|---|---|---|
| D-O2 | `ont` | "MF" | examples use "CC" (`go-enrichment`), "BP" in compareCluster (book, not locally verified); Rd Examples use `ont = "BP"` (an example, not a rule) | GO BP where specified: BP 8/30 (BP-only 7, BP/CC/MF 1), BP 8/8 of papers naming an ontology (recount 2026-09-27) | **disagreement** function default vs practice | **S1 P-1 (A, owner 2026-09-27)**: `ont = "BP"` preset; CC/MF/ALL by explicit choice |
| D-O3 | `universe` | all annotated genes of the OrgDb | `data-contract`: "the set of genes that could have been selected in the experiment", "not every gene in the annotation database" | expressed genes 6/6 reporting (6/30; not all the same "tested" definition) | expressed / tested genes passed from the upstream module | **S1 P-2 (A, owner 2026-09-27)**: universe required or traced upstream = genes eligible under the actual selection rule; no silent fallback to all annotated genes |
| D-O4 | `pAdjustMethod` | "BH" | BH | BH | BH | default + majority agree |
| D-O5 | `pvalueCutoff`, `qvalueCutoff` | 0.05, 0.2 | defaults | adjusted 0.05 | function defaults (p.adjust < 0.05 and q < 0.2) | function default |
| D-O6 | `minGSSize`, `maxGSSize` | 10, 500 | defaults | defaults (1 paper) | 10, 500 | function default |
| D-O7 | `simplify(cutoff, by, measure)` | 0.7, "p.adjust", "Wang" | redundancy reduction chapter | 2 papers (simplify 2/30; REVIGO 1/30 counted separately) | optional, off by default | **S1 P-3 (A, owner 2026-09-27)**: off by default; when chosen `cutoff = 0.7, by = "p.adjust", select_fun = min, measure = "Wang", semData = NULL` |
| D-O8 | database | -- | GO, KEGG (online), Reactome, MSigDB | GO | GO (refdata registry); KEGG excluded (licence gate); Reactome / MSigDB via registry | licence rule |

## X -- version-sensitive behaviour

- **DOSE 4.5.1 (-> 4.6.0 in Bioconductor 3.23)**: enrichment functions now use the CRAN package
  **enrichit**; `enricher_internal` / `GSEA_internal` moved there (`ora_gson` / `gsea_gson`). The dev tier
  (Bioconductor 3.22: clusterProfiler 4.18.4, DOSE 4.4.0) has no enrichit. enrichit 0.2.0 (in the
  container's 0.2.1): "exclude zero-overlap gene sets from `ora_gson()` before multiple-testing
  correction" -> p.adjust can differ from the dev tier. Goldens are container-only (signature SKIP).
- clusterProfiler NEWS (release branch `NEWS.md`, newest heading 4.19.8): "fix: map non-ENTREZID universe
  in enrichGO" (2026-04-22) -- universes given as symbols behaved differently before 4.20.
- The release branch still carries a frozen 2017 `NEWS` file next to `NEWS.md`; `collect_l1_release.py`
  now picks the NEWS file with the newest version heading and records the choice (`NEWS.source`).

## S1 drafts and pending decisions (the owner decides; no default is fixed yet)

- **P-1 GO ontology.** Function default "MF"; exemplars that specify it use BP. Draft: `ont = "BP"` by
  default, stated in the output (shared with clusterprofiler-compare).
- **P-2 Universe.** Function default = all annotated genes; the book and all 6 reporting exemplars use the
  genes that could have been selected (expressed / tested). Draft: universe = the tested genes from the
  upstream DE module, required when the list comes from a DE module; the owner decides because it departs
  from the function default.
- **P-3 Redundancy reduction.** `simplify()` in 2 papers. Draft: off by default, `--simplify 0.7` option,
  the raw table always kept.

## S1 审定附录（2026-09-27，所有者批准）

所有者于 2026-09-27 裁决：`docs/build/S1_DECISION_TABLE_M1M2.md`（下称"决策表"）中 A、B 类项目一律按「建议」栏批准（建议含可选项的，默认值与可选项一并冻结），C 类保持待定。上一节 "S1 drafts and pending decisions" 保留为历史；与本附录不一致处以本附录为准。下列参数在调用中一律显式写出，即使等于函数默认值（ENGINEERING_PLAN §3.3）。L1 路径相对于 `L1_bioc3.23/clusterProfiler/`。

| 编号 | 决定 | 类别 | 依据 |
|---|---|---|---|
| P-1 GO 本体 | 默认预设 `enrichGO(gene, OrgDb = <registry 中的 OrgDb>, keyType = <与输入一致>, ont = "BP", pool = FALSE, ...)`；用户可显式改为 `"CC"`、`"MF"` 或 `"ALL"`，并在 Methods 记录。改为 `"ALL"` 时必须同时显式给出 `pool` 取值并说明多重检验的范围；不得把一次 BP 的结果当作完整 GO 结论。与 clusterprofiler-compare 同步。 | A | 决策表 clusterprofiler-ora P-1；`Rd/enrichGO.Rd` Usage、Arguments、Examples；`literature/extraction.jsonl` `gene_set_db` |
| P-2 ORA 背景基因集 | `universe` 必填，或从上游模块追溯得到：取该次列表选择流程中**有资格被选中**的基因（与实际筛选规则一致：按 padj 选时，不混入没有 padj、不可能被选中的行；非 DE 输入按其检测/筛选范围定背景），并使用与 `gene` 相同的 ID 映射（`enrichGO(..., universe = <背景>)`、`enricher(gene, TERM2GENE = <集合>, universe = <背景>)`）。报告候选背景数、映射后背景数、输入列表数与有效交集数。任意外来列表也不得静默回退到全注释基因（`enrichGO` 缺省 `universe` 的语义）。显著基因自身不能充当背景。 | A | 决策表 clusterprofiler-ora P-2；`Rd/enrichGO.Rd`、`Rd/enricher.Rd` `universe`；`extraction.jsonl` `universe`（6 篇） |
| P-3 `simplify` | 默认关闭。用户显式选择时：`simplify(x, cutoff = 0.7, by = "p.adjust", select_fun = min, measure = "Wang", semData = NULL)`；保留原始全表、被合并的 term 与代表 term 的选择规则。0.7 来自锁定版函数默认，不是文献多数；简化是展示/归纳步骤，不重新解释为更强的显著性。 | A | 决策表 clusterprofiler-ora P-3；`Rd/simplify.Rd` Usage、Arguments；`extraction.jsonl` `simplify` |

说明（跨模块，非本模块 A/B 项）：决策表「跨模块一致性」第 4 行要求——若 ORA 要求保存全表，计算阶段须同时处理 `pvalueCutoff` 与 `qvalueCutoff`（建议计算阶段取 1），并如实说明零重叠/无有效映射的集合未被检验（enrichit 0.2.0/0.2.1 NEWS）。D-O5 目前仍为函数默认 0.05 / 0.2；两者如何衔接在 S2 实现时回报所有者。

对上一节草案原文的更正（草案文本保留不改，更正记在这里）：
- P-1 草案"exemplars that specify it use BP"：明确本体者 BP 8/8，但其中 1 篇同时用 BP/CC/MF（PMC8617197）（2026-09-27 更正，决策表第 4 条）。
- P-2 草案"the book and all 6 reporting exemplars use the genes that could have been selected"：书中该句未经本地独立核实（决策表第 13 条）；6 篇的背景写法也不全是同一"tested"定义（2026-09-27 更正）。

- C 类待定：无。待澄清：无。
- D 表：D-O2、D-O3、D-O7 的 Decision 已同步；V 节与 D 表的 GO 本体、背景计数按决策表更正，列 (2) 的在线书转述标注为未经本地核实（见行内标注）。
