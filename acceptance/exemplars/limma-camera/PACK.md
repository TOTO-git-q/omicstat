# PACK -- limma-camera

Evidence pack of module `limma-camera` (ENGINEERING_PLAN 2.3). Status: **S0 complete (L1 locked release,
L3/L4 collected and independently verified, 2026-09-27); S1 drafted -- the pending decisions at the
end are the owner's. S2 (engine) not started** (built locally).

| Layer | Status | Where |
|---|---|---|
| L1 | limma 3.68.5 (Bioconductor 3.23, git.bioconductor.org RELEASE_3_23): limma User's Guide (release PDF, text), Rd of `camera` (incl. `cameraPR`), `fry`, `roast`, `mroast`, `ids2indices`, `barcodeplot`, NEWS, `defaults.tsv` | `L1_bioc3.23/` (manifest with sha256 and git commit) |
| L2 | limma User's Guide 18.1.10 (Yoruba RNA-seq: `mroast` and `camera` on the male-specific Y and X-escape gene sets, `barcodeplot`) | cited below |
| L3 | 10 open-access full texts (tier-A journals), close-read notes | `literature/l3_notes.md` |
| L4 | 30 open-access articles 2020-2026 (whitelisted journals, CC BY / CC BY-NC, PubMed-echoed); **29 of 30 apply** (1: "FRY" is a gene symbol) | `literature/corpus.jsonl`, `extraction.jsonl`, `efetch/` |
| Verification | 6 of 30 articles, 48 records: 48 pass (100.0 %), PMID echo 6/6 -> **pass**; note: one paper runs cameraPR through TMSig (`cameraPR.matrix`, depends on limma), counted as applicable | `literature/verification.json` |

Collection history: the first corpus (11 of 30 applicable) came from a signal whose alternative
`camera (` matched microscope cameras ("Leica camera (Wetzlar)"). The signal was tightened (the test name
in one sentence with limma, or cameraPR / mroast / "camera function|test|method") and the corpus
re-collected: 10 applicable articles carried over, 20 new. Lines of dropped round-1 articles stay in
`extraction.jsonl` and are not counted.

## T -- table skeleton

- Gene-set table per contrast (as `camera()`): set, NGenes, Direction, PValue, FDR; `fry` / `mroast` add
  PropDown, PropUp, PValue.Mixed, FDR.Mixed. Header: test, contrast, inter-gene correlation (preset value
  or estimated), collection and release, input object (voom EList / logCPM / array matrix).

## F -- figure grammar

| Figure | Grammar | Source |
|---|---|---|
| Barcode plot | moderated t of all genes, set members as bars, running enrichment worm | `barcodeplot(fit$t[,2], Ymale, Xescape)` (User's Guide 18.1.10) |
| MD plot with highlighted sets | logFC vs average expression, set members coloured | User's Guide 18.1.10 `plotMD(status = ...)` |
| Set bar / dot plot | -log10 FDR per set, direction coloured | exemplars |

## W -- wording

Exemplar structure (L3): "competitive gene set testing was performed with camera (limma) using
<collection>"; the inter-gene correlation, the adjustment and the set cutoff are rarely stated; several
papers run camera and fry / roast side by side for different purposes. Template to write at S2: limma
version, test (camera: competitive; fry / roast: self-contained) and why, inter-gene correlation (preset
0.01 or estimated), collection and release, input object and contrast, BH FDR.

## V -- variant frequencies (L4: 29 applicable papers)

Source: `collect.py summarize limma-camera`.

| Parameter (PACK) | Reported values | n.r. | Majority among reporting papers |
|---|---|---|---|
| Test (D-CM1) | camera in 14 papers (alone 10); fry 8 (alone 5); cameraPR 7 (alone 5); roast 6 (alone 3); 6 papers combine tests | 0 | most common: **camera** (14 of 29) （2026-09-27 更正：14/29 未过半，只是最常见；多方法可重叠；recount 2026-09-27） |
| Inter-gene correlation (D-CM2) | preset 0.01 ("default" / "standard") 2 | 27 | preset 0.01 (2 of 2) |
| Collection (D-CM3) | MSigDB Hallmark most often; MSigDB C2 / C5 / GO BP; KEGG, Reactome via MSigDB; SMPDB 2 (metabolomics); custom signatures frequent | 6 | Hallmark / MSigDB |
| Input (D-CM4) | voom EList / logCPM with weights 5; moderated t or ranked statistics (cameraPR) 6; array matrices 2; other omics 3 | 8 | voom object (camera) / t statistic (cameraPR) |
| Adjustment (D-CM5) | BH 5; q-value 1 | 23 | BH |
| Set cutoff (D-CM6) | FDR / q < 0.05: 4 | 25 | 0.05 |
| limma version (X) | 3.42.0 - 3.50.3 (9 papers; one written "3.1.6.8") | 20 | -- |

## C -- anchors

`acceptance/data/ANCHOR_REGISTRY.md` row 14: Yoruba HapMap (`limma_Yoruba.RData`, F10) + GenderGenes
(`msYgenes`, `XiEgenes`, F11), User's Guide 18.1.10. Printed values in the locked release's guide:
`camera(v, index, design, 2)`: **Y 13 genes Up, PValue 2.40e-262, FDR 4.80e-262; X 54 genes Down, PValue
5.58e-26**; `mroast(..., nrot = 9999)`: Y 13 Up, X 54 Down, both PValue 1e-04. Printed-value anchor
(camera is deterministic; mroast depends on the seed). Row 14b (GSE63310 + msigdbr) is the alternative.

## D -- defaults: function default / User's Guide / exemplar majority

Function defaults from `L1_bioc3.23/limma/defaults.tsv` (limma 3.68.5).

| Id | Parameter | (1) function default | (2) User's Guide / Rd | (3) exemplar majority (V) | Draft | Decision |
|---|---|---|---|---|---|---|
| D-CM1 | test | -- | camera "even more convincing" than mroast for the Yoruba sets （2026-09-27 限定：这是 Yoruba 示例的结果，不代表 camera 普遍更优；Rd 把 camera 定为竞争性问题、fry/roast 为自包含问题） | camera 14/29, most common but not a majority (2026-09-27 更正) | `camera` default; `fry` for self-contained questions; `cameraPR` for a ranked statistic | **S1 P-1 (B, owner 2026-09-27)**: route by the scientific question; camera preset for the standard competitive entry |
| D-CM2 | `inter.gene.cor` | 0.01 (preset; "usually works best with a small value"); NA = estimate per set （2026-09-27 补注：锁定版 `camera.Rd` 的 Details 有一段仍写默认估计相关，与 Usage 及后文默认 0.01 冲突；以 Usage/NEWS 为准，冲突须如实报告。决策表第 14 条） | default in the guide's call | preset 0.01 (2 of 2 reporting) | 0.01, printed | default + majority agree |
| D-CM3 | `use.ranks`, `directional`, `allow.neg.cor` | FALSE, TRUE, FALSE | defaults | n.r. | defaults | function default |
| D-CM4 | input | voom EList / log-expression + design + contrast | `camera(v, index, design, 2)` on the voom object | voom object | the voom / array object from limma-voom or limma-array with the same design | consistency with the DE module |
| D-CM5 | `roast` / `mroast` rotations | `nrot = 1999` | `nrot = 9999` in the guide's mroast call | n.r. (no rotations field in the extraction; n/N not applicable) | 9999 with a fixed seed when roast is chosen | **S1 P-2 (A, owner 2026-09-27)**: `nrot = 9999` publication preset (roast Rd: "at least nrot=9999 or higher is recommended"), seed/RNG fixed and recorded, `midp` recorded |
| D-CM6 | collection | -- (index list) | user gene sets (`ids2indices`) | Hallmark / MSigDB | Hallmark via msigdbr (registry release); KEGG excluded (licence gate) | registry rule |
| D-08 | adjustment, cutoff | FDR (BH) column in the output | -- | BH; 0.05 | BH, 0.05 | same as the DE modules |

## X -- version-sensitive behaviour (L1 NEWS, limma 3.68.5)

- 3.30.0: `camera()` defaults changed to a preset inter-gene correlation (0.01) -- results differ from older
  analyses that estimated the correlation; tends to rank co-regulated, interpretable sets higher.
- 3.32.0: `cameraPR()` added (pre-ranked camera).
- 3.42.0: `roast()` / `mroast()` default `nrot` raised from 999 to 1999, less memory; `legacy` restores the
  old numerical results.
- 3.64.0: new argument `directional` for `camera()` / `cameraPR()` (default TRUE = previous behaviour).

## S1 drafts and pending decisions (the owner decides; no default is fixed yet)

- **P-1 Which test by default.** camera (competitive) is the majority and the guide's preferred example;
  fry / roast answer a different (self-contained) question. Draft: `camera` default with the question
  stated in the output; `fry` and `cameraPR` as options; never several tests picked after the fact.
- **P-2 Rotations for roast / mroast.** Function default 1999, guide example 9999. Draft: 9999 with a fixed
  seed (the P-value floor is 1/(nrot+1)); the owner decides because it departs from the function default.
- **P-3 Negative controls.** After the re-collection all 10 L3 articles apply (round 1 had microscope-camera
  false positives); the router's evaluation set should keep a "camera = microscope" confusable example.

## S1 审定附录（2026-09-27，所有者批准）

所有者于 2026-09-27 裁决：`docs/build/S1_DECISION_TABLE_M1M2.md`（下称"决策表"）中 A、B 类项目一律按「建议」栏批准（建议含可选项的，默认值与可选项一并冻结），C 类保持待定。上一节 "S1 drafts and pending decisions" 保留为历史；与本附录不一致处以本附录为准。下列参数在调用中一律显式写出，即使等于函数默认值（ENGINEERING_PLAN §3.3）。L1 路径相对于 `L1_bioc3.23/limma/`。

| 编号 | 决定 | 类别 | 依据 |
|---|---|---|---|
| P-1 默认竞争性还是自包含检验 | 先按科学问题路由，不运行多种检验后挑显著者。标准竞争性入口预设 `camera(y, index, design, contrast = <contrast>, weights = <NULL 或 voom 权重>, use.ranks = FALSE, allow.neg.cor = FALSE, inter.gene.cor = 0.01, trend.var = FALSE, directional = TRUE)`；只有排序统计量时用 `cameraPR(statistic, index, use.ranks = FALSE, inter.gene.cor = 0.01, directional = TRUE)`；自包含问题用 `fry`/`roast`（参数见 P-2）。`inter.gene.cor = 0.01` 是预设值，报告时不得写成估计的相关；固定 0.01 与逐集合估计之间的误差控制/排名解释取舍须在输出中说明。 | B | 决策表 limma-camera P-1；`Rd/camera.Rd` Usage、Details；`Rd/roast.Rd` Details；`vignettes/usersguide.rendered.txt` §18.1.10；`extraction.jsonl` `test`、`inter_gene_cor` |
| P-2 roast/mroast 旋转次数 | 发表预设显式 `nrot = 9999`：`roast(y, index, design, contrast, set.statistic = "mean", nrot = 9999, approx.zscore = TRUE, legacy = FALSE)`、`mroast(..., nrot = 9999, approx.zscore = TRUE, legacy = FALSE, adjust.method = "BH", midp = TRUE)`，固定并记录 seed/RNG（`set.seed(<套件 seed>)`）；小规模开发可显式 `nrot = 1999`，但须另设签名，不作发表结果。记录 `midp`。大量集合需要更高分辨率时，按问题改用 `fry` 或提高 `nrot`。P 值下限：普通 mixed/双侧原始 P 为 `1/(nrot+1)`，单侧 Up/Down 为 `1/(2*nrot+1)`；`mroast(midp = TRUE)` 的 BH 使用 mid-p，不能把双侧原始 P 的下限当作全部 FDR 的下限。 | A | 决策表 limma-camera P-2；`Rd/roast.Rd` Arguments `nrot`、Details；`Rd/mroast.Rd`；User's Guide §18.1.10 |
| P-3 显微镜 camera 负例 | 保留一例经语境核实的"camera = 显微镜相机"和一例"FRY = 基因"作为路由评测的独立负例，另保留 cameraPR/limma 阳性例；与分析频次语料分开标注。当前适用 29/30（不适用的一例是 FRY 基因）；extraction 另保留的 20 篇旧语料不计入当前 N。 | A | 决策表 limma-camera P-3；`literature/corpus.jsonl`、`extraction.jsonl` `_applies`；本 PACK "Collection history"；`SUITE.md` M2-S0 偏离之处第 1 项；ENGINEERING_PLAN G5 |

说明：`set.statistic = "mean"` 是锁定版 `roast`/`mroast` 的函数默认，按 §3.3 写出，决策表未另作取舍。

对上一节草案原文的更正（草案文本保留不改，更正记在这里）：
- P-1 草案"camera (competitive) is the majority"：14/29 未过半，只是最常见（2026-09-27 更正，决策表第 5 条）。
- P-2 草案"(the P-value floor is 1/(nrot+1))"：只适用于普通 mixed/双侧原始 P；单侧为 `1/(2*nrot+1)`，mroast 的 FDR 另用 mid-p；9999 也不只是指南示例，`roast.Rd` 明确建议发表用途至少 9999（2026-09-27 更正，决策表第 12 条）。
- P-3 草案只提到保留"camera = microscope"混淆例；按决策还要保留"FRY = 基因"负例（当前 L4 语料中唯一的不适用例，适用 29/30），并与频次语料分开标注（2026-09-27 补充）。

- C 类待定：无。待澄清：无。
- D 表：D-CM1、D-CM5 的 Decision 已同步；V 节与 D-CM1 的"多数"表述按决策表更正，D-CM2 补注 `camera.Rd` 内部冲突（见行内标注）。
