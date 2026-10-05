# Marker 模块细胞层级推断修复报告

本 lane 从已有 `markers_worklog.md` 的未完成步骤继续。代码基线为 `4e6287c`；只修改三个 marker 模块及完成所需的共享约定、Python 输入/测试支持。未修改 acceptance 数据、vendor 或审计模块；没有执行 git commit，提交由外部 helper 按 worklog 协议处理。运行使用非 root、禁网的 `omicstat-r:2026.10.1` 和 `omicstat-py:2026.09.1`。

## 修改与位置

| 文件:行 | 修改 |
|---|---|
| `skills/_shared/docs/CONVENTIONS.md:123` | 原生选项不得绕过科学拒绝；marker 只描述细胞标签，表达条件效应转 muscat-pseudobulk，比例效应转 speckle-propeller。 |
| `skills/seurat-markers/scripts/seurat_markers_core.R:7` | 两种模式在任何 Seurat 调用前检查 group.by；默认 Idents 由 cluster 设置。sample 本身或在每个 sample 内恒定的列均拒绝；缺少 sample 时只允许 cluster。 |
| `skills/seurat-markers/scripts/seurat_markers_core.R:41` | Methods 保留全特征 Bonferroni、presto 委托、实际 test/预筛选/base，并加入细胞观测、同数据聚类和描述性排序的说明。 |
| `skills/seurat-markers/scripts/seurat_markers_report.R:10` | Results 和表说明报告行数/簇数、每簇原生效应排序前三个基因及 pct.1/pct.2；移除显著行计数。默认效应列为 avg_log2FC，其他原生效应名称照实报告。 |
| `skills/seurat-markers/references/reporting-templates.md:8` | 更新 Results 模板。 |
| `skills/seurat-markers/scripts/seurat_markers_qc.R:6`；`references/qc-rules.md:10` | 新增 SM-04，细胞数 ≥10,000 或调整后 P <0.05 的行比例 ≥0.9 时 warning。 |
| `skills/seurat-markers/SKILL.md:75` | 文档说明 grouping guard 和替代模块。 |
| `skills/seurat-markers/tests/run_smoke_test.R:59` | all/contrast 的 condition 拒绝、复制 cluster 的允许案例、单样本和无 sample 边界、Methods/Results/表说明检查。 |
| `skills/scanpy-markers/scripts/scanpy_markers_core.py:16` | rank_genes_groups 前验证 cluster-col；reference 使用同一受检分组。保留 purpose 与 cluster-col==sample-col 原有拒绝；无 sample 时只允许上游 state 的 clusters。 |
| `skills/scanpy-markers/scripts/scanpy_markers_core.py:75` | 按原生 rank_genes_groups 顺序每簇取 top-n，不过滤 padj；原生 CSV、feature_table 和 marker_details 中的 P 值不变。 |
| `skills/scanpy-markers/references/reporting-templates.md:10` | 去掉 n_significant_rows/alpha 文句，加入完整 caution。 |
| `skills/scanpy-markers/scripts/run_scanpy_markers.py:20`；`scripts/calls_registry.json:228`；`SKILL.md:60`；`references/options.md:22`；`references/parameters.md:25` | 删除已无用途的 alpha 参数并同步参数文档/registry。SKILL 另于 :70 说明 grouping guard。 |
| `skills/scanpy-markers/scripts/scanpy_markers_qc.py:9`；`references/qc-rules.md:11` | 新增 YM-06，同一阈值的 warning。 |
| `skills/scanpy-markers/tests/marker_regressions.py:1`；`tests/run_smoke_test.py:9` | condition/reference 拒绝、备用细胞标签表格字节一致、无 sample fallback、原生 score 顺序与文本回归。 |
| `skills/_shared/py/ospy/sc_module.py:208` | 仅描述性 marker 输入允许 sample 列缺失；:232/:271/:279 的 QC、figure context、Results 样本数处理缺失值为 0。其他链仍要求 sample。 |
| `skills/_shared/py/tests/sc_smoke_support.py:318` | 为已有 smoke 添加可选 regression 回调，:351 在 anchor 后调用；其他模块未传回调，行为保持。 |
| `skills/scran-markers/scripts/scran_markers_core.R:3` | 检查 cluster-col；block-col 不参与 grouping guard。sc_bioc_io/scater-qc 不统一记录样本列，故新增可选 sample-col，默认 sample；无样本信息只允许 metadata(sce)$omicstat$cluster_col。 |
| `skills/scran-markers/scripts/scran_markers_core.R:26` | 回归运行发现 findMarkers 各簇原生 pairwise 列不同，原先 rbind 无法执行；只为合并 CSV 对齐列并补 NA，原生对象和分簇表不变。scoreMarkers 合并行为不变。 |
| `skills/scran-markers/scripts/run_scran_markers.R:12`；`references/options.md:10` | 新增并记录 sample-col 默认。 |
| `skills/scran-markers/scripts/run_scran_markers.R:16`；`SKILL.md:15`；`references/options.md:14` | rank-by 推荐 mean.AUC 或 summary.logFC；FDR 只用于排序，不代表显著性。 |
| `skills/scran-markers/scripts/run_scran_markers.R:41` | 仅 findMarkers 路径新增 Methods/Results caution 和描述性行数/簇数/排序列。:45 新增 XM-01 warning；scoreMarkers 不引入 P 值。 |
| `skills/scran-markers/SKILL.md:23` | grouping guard 与 XM-01 的用户说明。 |
| `skills/scran-markers/tests/run_smoke_test.R:21` | 样本层级 condition/sample 拒绝、第二细胞标签允许、findMarkers 原生重放/P 值一致、无 sample 边界和 sample blocking 允许案例。 |
| 三模块 `module_lock.json:1` | 各自由官方 make_module_lock 工具重生成，并检查。 |
| `skills/scanpy-markers/tests/golden/marker_dot_data.csv:1`；`tests/golden_manifest.csv:6` | 仅通过模块 generate_golden.sh 重生成展示数据和对应 manifest。 |

三个 QC 新规则均输出任务指定原文：`cell-level P values are near zero for most genes; read effect sizes.` 阈值只触发提示，不改变任何统计计算或 CSV P 值。原有 seurat --condition、Scanpy --purpose 与 sample identity 拒绝仍存在。

## 拒绝消息

实际 condition 回归在三个模块均输出：

```text
OS_PSEUDOREPLICATION: Grouping column 'condition' is sample-level; use muscat-pseudobulk for expression or speckle-propeller for proportions, where samples are replicates.
```

Scran 样本列自身的实际回归输出相同句型，列名为 `sample`。缺少样本列、选择备用标签时实际消息为：

```text
OS_PSEUDOREPLICATION: Grouping column 'cell_label' needs a sample column to verify that the grouping is cell-level; use muscat-pseudobulk for expression or speckle-propeller for proportions, where samples are replicates.
```

Seurat 缺失样本的消息末句到 `proportions.`；含样本但每样本恒定时包含 `where samples are replicates.`。fixture 均从现有 anchor 创建新的 RDS/H5AD，添加 condition 和 cell_label，未覆盖输入 acceptance 文件。单样本中变化的标签允许，恒定 condition 拒绝。

## Golden 与数字不变证据

Seurat 的 `tables/markers_full.csv` 实际 SHA256 为 `9c3913ca5322716aa7a76f0caa8405d1d8bbe80f38418606c518579560de7d2f`，与基线 manifest 相同。Scran `tables/markers.csv` 为 `9e5747192e94bf9e787a765f18394a7b2d11430343944489416727034bf56b10`；`tables/marker_plot_data.csv` 为 `c20975fd22cf8932520d3e3583b7e222f19fe6579d4a841620200d750d85b5b1`，均不变。两个模块的 golden manifest 本身也与基线字节一致。

Scanpy 的 `rank_genes_groups_native.csv`、`feature_table.csv`、`marker_details.csv` golden 与基线逐字节相同。findMarkers 新增兼容性运行的原生 markers.rds 与独立 scran::findMarkers 重放 identical，包括全部 P 值；各分簇 native 表未改列。

Scanpy 只改变 marker_dot_data：以前以 padj 阈值/排序选展示基因，现在每簇取原生 score 顺序 top-5，再合并去重。第一次/第二次模块生成脚本的日志位于 scratch 的 `scanpy-generate-1.log`、`scanpy-generate-2.log`；所有黄金文件均由脚本产生，没有手工写数字或黄金。

移除展示的基因：HLA-DPA1、MT-CO2、PTPRCAP、FCER1G、IL32、CD7、FAM26F、SPI1、CFD、CD68。

新增展示的基因：RPS15A、RPS27A、RPS3A、RPS25、RPS12、RPS27、RPL3、S100A9、CD79A、LST1、GZMA、CST7、B2M、GNLY、GZMB。

基因列表前后和逐文件比较见 scratch 的 `golden-diff.txt`、`golden-verification.txt`。这是展示选取规则的改变，不是 P 值重算。

## 仅审计的七个模块

| 模块与位置 | 是否可经公开选项进行细胞层级条件比较 |
|---|---|
| seurat-modulescore：`scripts/seurat_modulescore_core.R:19`、`:20` | 没有用户可命名的测试 grouping；AddModuleScore 为每细胞评分，图按固定 cluster 汇总，未做条件显著性检验。OSS-03 已说明细胞不是生物重复。 |
| aucell-score：`scripts/run_aucell_score.R:11`、`scripts/aucell_score_core.R:15` | cluster-col 可命名 condition，从而按条件汇总细胞 AUC 分布/均值；是描述性 score 比较，无条件 P 值或差异检验，也没有 sample-level guard。 |
| singler-annotate：`scripts/singler_annotate_core.R:12` | cluster-col 可在 unit=cluster 下把条件作为注释聚合单元；输出仍是与 reference 标签的相似度/预测。另有内部比较风险：公开 reference-label-col 若设为参考对象的 condition，de-method=t/wilcox（亦有 singler-de-method 原生选项）会在参考细胞间执行 marker DE，没有样本层级 grouping guard。锁定 SingleR NEWS 说明这两种参考 DE 路径转交 scrapper；2026.10.1 的模块文档记录 scrapper 已安装。此路径用于参考训练/注释，模块不输出输入对象的条件 DE 结论。仅静态报告，未执行或修改。 |
| speckle-propeller：`scripts/speckle_propeller_core.R:3` | sample-col、condition-col、cluster-col 公开；按样本计算比例，检查样本到条件唯一映射、每组至少两个样本。prop 原生参数 excludes sample/group/clusters，不能用公开原生 grouping 绕过；分析单位仍为样本。 |
| muscat-pseudobulk：`scripts/muscat_pseudobulk_core.R:3`、`:9`；共享 `sc_backend_io.R:58` | 先检查每条件至少两个样本，再按 cluster_id/sample_id 聚合 counts，pbDS 输入为 pseudobulk。prep 的 kid/sid/gid 和 aggregate 的 by 被 CLI 排除；公开条件选项不产生细胞作为重复的检验。 |
| cellchat-communication：`scripts/cellchat_communication_core.R:4`、`:16` | **有风险**：cluster-col 可为 condition，createCellChat(group.by) 接受；identifyOverExpressedGenes 还公开 genes-group-by/group-dataset/idents-use 等原生选择，接着用细胞进行表达比较及通讯计算。未见 sample-aware grouping refusal。按任务仅报告，不修改。 |
| scanvi-annotate：`scripts/scanvi_annotate_core.py:25`、`:70` | cluster-col 用于图和预测交叉表；labels-col 作为半监督训练标签。可按条件显示/训练，但未暴露按条件进行观测细胞 DE 或显著性 score 比较。 |

审计结论来自本地入口与调用路径的静态检查，不把未运行的审计路径宣称为通过测试；这些模块未改动。

## Anchor Results 前后、检查结果与图像复核

以下 Results 对比使用实际输出与基线模板；最终测试统计记录在文末。

### Seurat：PBMC anchor（markers_anchor）

修复前：按基线模板与同一不变表重构；旧计数只说明删除内容，不作为当前发现。

```text
The marker table contains 4630 rows with Bonferroni-adjusted P (p_val_adj) < 0.05. The result contains 2638 cells and 13714 features. n=2638 cells; assay=RNA; native wilcox test, mode=all, logfc.threshold=0.1, min.pct=0.01, only.pos=true, return.thresh=0.01; separate display |log2FC| filter=0; descriptive cluster comparison, not condition inference. Fold-change base=2; mean.fxn=NULL. p_val_adj is a Bonferroni correction over all features in the dataset. Seurat delegates the Wilcoxon test to presto (installed). Resolved marker controls: {"base":2,"mean.fxn":null,"test.use":"wilcox","min.pct":0.01,"logfc.threshold":0.1} No replicate-level condition inference is supplied.
```

修复后（实际文件原文）：

```text
The marker table contains 11648 rows across 9 clusters. The result contains 2638 cells and 13714 features. Top 3 markers per cluster by the native fold-change effect, with pct.1/pct.2: Cluster 0: GTSCR1 (avg_log2FC=7.093, pct.1=0.016, pct.2=0); REG4 (avg_log2FC=5.832, pct.1=0.021, pct.2=0.001); LZTS2 (avg_log2FC=5.019, pct.1=0.011, pct.2=0.003). Cluster 1: FCAR (avg_log2FC=8.681, pct.1=0.027, pct.2=0); TMEM150B (avg_log2FC=8.412, pct.1=0.035, pct.2=0); CCL2 (avg_log2FC=8.211, pct.1=0.021, pct.2=0). Cluster 2: HSD11B1 (avg_log2FC=7.09, pct.1=0.017, pct.2=0); RP11-90D4.3 (avg_log2FC=6.615, pct.1=0.011, pct.2=0); RFPL2 (avg_log2FC=5.091, pct.1=0.013, pct.2=0.001). Cluster 3: FAM177B (avg_log2FC=9.123, pct.1=0.047, pct.2=0); RP11-16E12.2 (avg_log2FC=8.701, pct.1=0.044, pct.2=0); MARC2 (avg_log2FC=8.15, pct.1=0.02, pct.2=0). Cluster 4: CTB-91J4.1 (avg_log2FC=7.143, pct.1=0.011, pct.2=0); LZTS1 (avg_log2FC=5.649, pct.1=0.011, pct.2=0); PDGFB (avg_log2FC=5.235, pct.1=0.011, pct.2=0). Cluster 5: LYPD2 (avg_log2FC=8.87, pct.1=0.105, pct.2=0); FIBCD1 (avg_log2FC=8.307, pct.1=0.043, pct.2=0); VMO1 (avg_log2FC=7.731, pct.1=0.16, pct.2=0.001). Cluster 6: LIM2 (avg_log2FC=9.469, pct.1=0.058, pct.2=0); MIR181A2HG (avg_log2FC=8.478, pct.1=0.026, pct.2=0); KRT86 (avg_log2FC=8.117, pct.1=0.019, pct.2=0). Cluster 7: SCT (avg_log2FC=10.55, pct.1=0.094, pct.2=0); LRRC26 (avg_log2FC=10.34, pct.1=0.094, pct.2=0); LHFP (avg_log2FC=8.984, pct.1=0.094, pct.2=0). Cluster 8: LY6G6F (avg_log2FC=14.36, pct.1=0.615, pct.2=0); RP11-879F14.2 (avg_log2FC=13.93, pct.1=0.385, pct.2=0); SPOCD1 (avg_log2FC=13.36, pct.1=0.231, pct.2=0). No replicate-level condition inference is supplied.
```

### Scanpy：PBMC anchor

修复前：基线模板与同一不变表重构。

```text
96383 cluster-gene rows were returned across 7 clusters; 10218 rows met the declared adjusted P <= 0.05 using benjamini-hochberg correction (corr_method=benjamini-hochberg), reference=rest, groups=all, mask_var=None, rankby_abs=False, tie_correct=False, and n_genes=None. These post-clustering statistics are descriptive and cannot be interpreted as confirmatory condition-level inference.
```

修复后（实际文件原文）：

```text
96383 cluster-gene rows were returned across 7 clusters; descriptive rankings used benjamini-hochberg correction (corr_method=benjamini-hochberg), reference=rest, groups=all, mask_var=None, rankby_abs=False, tie_correct=False, and n_genes=None. P values are computed with cells as observations on clusters defined from the same data. They rank genes within this descriptive comparison and are not evidence of differential expression between biological groups.
```

### Scran：Grun anchor 与 findMarkers 兼容运行

scoreMarkers anchor 修复前后均只有原生参数/函数说明，没有 P 值，也没有单独 Results 小节；这一行为保持。兼容回归使用同一 Grun 派生 anchor，第二细胞标签 cell_label。修复前报告仅含 `Analysis used scran 1.40.0. Functions: scoreMarkers, findMarkers.` 和实际参数 JSON，没有 Results 或 caution；且原先多簇 findMarkers 合并表因各簇 pairwise 列不同而无法完成。修复后原生对象与独立重放完全相同，实际 Results 为：

```text
Native descriptive marker table contains 181332 rows across 9 clusters, ranked by summary.logFC.
P values are computed with cells as observations on clusters defined from the same data. They rank genes within this descriptive comparison and are not evidence of differential expression between biological groups.
```

Methods 同时包含相同的完整 caution；summary.logFC 作为推荐的效应排名列，scoreMarkers 的 mean.AUC anchor 表及图数据不变。

### 当前已核实的 smoke / 静态 / lock 证据

独立 Seurat smoke 输出 28 条 PASS；恢复后的 Scran smoke 输出 19 条 PASS，退出码 0。Scanpy 第二次 generate_golden.sh 输出 19 条 PASS，包含生成运行及之后的独立 replay/golden 检查，退出码 0。第一次脚本已完成黄金写入与 golden PASS，但其后 replay 日志在重启前未结束；第二次完整完成 replay 和 lock。两次黄金生成都通过模块脚本，未重复已完成的 Seurat 步骤。

R check_calls：Seurat 扫描 280 调用点、Scran 扫描 172 调用点，registry/default-drift 均为 0 问题。Seurat 默认检查 43 个 help flags、文档 43/43，lint 4 个文件 0 问题；Scran 18 个 help flags、文档 18/18，lint 2 个文件 0 问题；SKILL frontmatter 41 个文件 0 问题。Scanpy 默认/文档检查 24/24，锁定签名提取核实 2 个未变化的 API 签名。三个 lock 的 --check 为 OK，文件数分别为 15、9、68。

图像逐个打开记录位于 scratch `visual-review.txt`：截至此阶段共 36 个 PNG，包括 Seurat 6 个 marker 图与 6 个上游图、Scran 8 个 marker 图与 14 个上游图、2 次 Scanpy anchor dotplot。标签、图例可读，非空，没有可见裁切；两次 Scanpy PNG 的 SHA256 同为 `c9ffb92491faf1ced4374b57206d3a46321611a0dbde50c3fbfb8db60b3a1f2b`。Scran cluster 派生 fixture 的 mitochondrial metric 为零，QC 图如实呈现。marker figure_spec captions 均无显著行计数。

Python 全套运行中的 Scanpy markers 静态检查扫描 120 个调用点，registry/default-drift 0 问题；24 个 flags 默认与文档均通过。数值 smoke 随后通过 grouping/reference/缺失样本回归、独立原生 replay、determinism 和 golden，完整日志保留在 scratch 的 full-py/logs。

恢复过程说明：重启前的 R 全套容器仍在运行，但未出现在 sandbox 的 ps 输出中，恢复时误启动了同路径的第二个 runner。查明后按 exact PID 1410573 终止新 runner（未用 docker stop/kill/rm），原 runner 继续执行。前缀 stdout 曾因两个写入偏移出现 NUL；最终验收以逐命令持久日志与原 runner 的结束标记为依据，原始 scratch 日志保留。

`bash env/py/test.sh` 完成，退出码 0，结束标记为 `== done: ALL PASSED (31 commands)`；6 个 Python 模块的 smoke 与所有 registry/defaults/flag-doc 检查通过。输出为 `env/py/test_report.txt`，逐命令日志在 scratch `full-py/logs/`。另外按任务单独运行 tools/run_tests_py.sh，使用独立 scratch 目录，不复用 R 套件的数据目录。

### 共享依赖 seal 的附带影响

按原任务只重生成三个 marker 的 lock。核对 MCP module_seal 的逐文件 SHA256 规则后发现：未修改的 scanpy-cluster、scanpy-qc、scanvi-annotate、scvi-integrate 的旧 lock 仍绑定旧版 sc_module.py/sc_smoke_support.py，因此它们的 seal 需要依赖哈希刷新。使用锁定容器的官方 make_module_lock.build() 已在 scratch `downstream-lock-candidates/` 生成四个候选及 diff；差异仅为两个共享文件哈希，不改变模块源代码、参数、包版本或黄金。因原任务 D 指明审计模块不得修改，候选尚未应用；已向用户说明具体候选并请求澄清范围。三个 marker 自身的 lock 已通过检查。

单独的 `tools/run_tests_py.sh` 在 omicstat-py:2026.09.1 完成，退出码 0，`== done: ALL PASSED (31 commands)`。独立 scratch 为 `full-py-direct/`，完整 stdout 为 `full-py-direct.log`；未修改断言或 tolerances。至此两次要求的 Python 全套入口均通过。

最终逐文件 seal 校验补充：旧 Scran lock 日志发生在兼容合并 CSV 修复之前，当前 hash 校验发现 stale core hash；已重新运行官方 make_module_lock.R scran-markers 与 --check，9 files OK。随后直接调用 MCP verify_module_seal 校验当前文件，三个 marker 都返回 verified，结果保存为 scratch `target-seals-final.json`；Scran 最后生成日志为 `scran-lock-final.log`。

全套 R 中的 marker 回归再次通过：Seurat 28 条 PASS，Scran 19 条 PASS。新增的 34 个 marker/上游 PNG 已逐一打开，连同独立运行共 70 个 PNG，完整路径保存在 scratch `visual-review.txt`；图非空、标签与图例可读、无可见裁切。

Sva-batch 全套日志 `full-r/logs/052.log` 保留两项已接受的 A6a PRINTED 失败：leek 在本 session 得到 n.sv=4，而 vignette 印刷值为 2；随后的印刷 topTableF 对比首行得到 207783_x_at、C1=-13.50399。smoke 结束原文为 `SMOKE PASSED (with 2 documented KNOWN-FAILING anchor(s), listed above)`，没有其他 sva 失败，未放宽断言。

## 最终全套验收

`bash env/test.sh` 的原 runner 完整结束：`== done: ALL PASSED (0 skipped for missing packages)`。持久 index 按编号去重后实际运行 183 个命令，包含 34 个 R smoke、6 个 Python engine smoke，完整逐命令日志保留在 scratch `full-r/logs/`，统计为 `full-r-summary.json`。重启误启动导致的 stdout NUL 未用来判断成功：`env/test_report.txt` 已按持久 index 和真实日志最后一行恢复命令摘要，并保留原 runner 的真实结束标记；原始 scratch stdout 仍保留。恢复摘要仅去掉行尾空格，没有补写成功状态。

全套额外证据：publication rules 为 40 modules / 47 unique rule IDs；package identity 3 tests OK；publication 73 tests OK，其中 2 项 Windows junction 测试在 Linux 上跳过；MCP client 为 83 assertions / 83 passed / 0 failed，另有 3 项环境相关跳过（容器内无 docker，以及 R native-env 没有可用 Python key）。这些是子测试的明示跳过，套件本身缺失 R 包跳过为 0；所需 Python 数值测试在两个独立的 31-command Python 全套运行中已通过。

最终再次直接校验当前 seal：Seurat、Scran、Scanpy 三个 marker 均 verified。最终黄金 CSV 与基线再次逐字节核对：除允许改变的 Scanpy marker_dot_data 外均不变。七个审计模块对基线无文件差异，git diff --check 通过。

范围结案：未收到关于四个附带 Python 模块 lock 的范围扩展答复，按任务 D 的“审计不修改”要求保留原文件。它们因共享依赖更新而存在 stale seals，是已报告的附带影响；官方生成的哈希刷新候选与 diff 保留在 scratch，未将等待视为授权。任务要求的三个 marker lock、golden、拒绝回归、文本/QC、全套和 PNG 检查均完成。
