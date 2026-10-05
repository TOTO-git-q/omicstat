# 所有者裁决实施报告（owner_items，2026-10-05）

分支 `fix/owner-items`（基于 `integrate/final` @ 54a9a70）。前半程由 Codex sol lane 完成（两项裁决实施、CellChat 验收、第一次重签）；该 lane 停止后由 Claude 接手，解决 WGCNA golden 冲突、重签、跑全套测试并完成本报告。所有运行均为离线（`--network none`）、非 root 的锁定镜像 `omicstat-r:2026.10.1` / `omicstat-py:2026.09.1`。未合并到 `integrate/final`。

## 一、WGCNA：仅 plain Pearson 给出模块—性状 P 值

### 改动（file:line）

- `skills/wgcna-network/scripts/wgcna_network_core.R:139`：`pair_n <- crossprod(!is.na(MEs), !is.na(traits))`，即每个模块—性状组合的成对完整观测数。
- `wgcna_network_core.R:140`：`infer` 仅当 `cor-method` = pearson、`cor-cosine` / `cor-cosine-x` / `cor-cosine-y` 全为 FALSE、`cor-weights-x` / `cor-weights-y` 均为 NULL 时为 TRUE。此时 `corPvalueStudent(cor = r, nSamples = pair_n)`，否则 P 矩阵全 NA，`p_adjusted` 随之为 NA。
- `wgcna_network_core.R:150`：`n_unweighted` 写成对完整数。无缺失时等于 `nrow(datExpr)`，与原值逐字节相同。
- `wgcna_network_core.R:154`：新增 `inference_table`（sidecar 数据），`module_traits` 表本身**不再加列**（见第三节）。
- `skills/wgcna-network/scripts/run_wgcna_network.R:84-86`：允许性状缺失值；仍拒绝非数值、无限值、常量及有效观测少于 3 个的性状（`OS_INVALID_DESIGN: traits must be numeric and nonconstant with at least three observed finite values.`）。
- `skills/wgcna-network/scripts/wgcna_network_report.R:11`（`wgcna_cor_setting`）：为描述性设置生成可读标签，如 `Spearman`、`Pearson with cosine (uncentred) option`、`... observation weights`。
- `wgcna_network_report.R:25`（`wgcna_trait_text`）：按三条路径生成 Methods / Results / 图注文本（见下）。
- `wgcna_network_report.R:40`（`wgcna_trait`）：描述性路径去掉 BH 调整句，在图注中写明相关设置和不给 P 的原因；Pearson 有缺失时在图注补一句成对 n。
- `wgcna_network_report.R:60-61`：effect table 描述性路径 `test_name` = `none (descriptive correlation)`，`p_adj_method` = NA（之前即使没有调整也会写 BH）。
- `wgcna_network_report.R:62`：写出 `tables/module_traits_inference.csv`。
- `wgcna_network_report.R:86`：模板槽 `{trait_inference}`、`{results_inference}`、`{assoc_noun}`；`wgcna_results.json` 另记 `inference` 与 `n_pairwise_complete`。
- `skills/_shared/scripts/fig_network.R:16,19,22`：P 为 NA 的单元格只显示 r（不出现 `(NA)`）；全部为 NA 时图例标题为 `r`，图注为 `Each cell gives the descriptive correlation coefficient only and no P values are shown; colour encodes r ...`。P 存在时标签、图例、图注与原来完全一致。
- `skills/wgcna-network/references/reporting-templates.md:3,6,9`、`SKILL.md:15,43`、`references/options.md:77`、`scripts/calls_registry.json`（`nSamples` = `pair_n`）同步更新。

### 文本前后对比

| 路径 | Methods 中的推断句 |
|---|---|
| 修改前（所有设置） | `{cor_method} module-trait correlations used corPvalueStudent with n={n}; {adjustment} adjustment covered all {tests} module-trait tests.`（Spearman / cosine 也这样写，是错误陈述） |
| 修改后：plain Pearson，无缺失（锚点） | 与修改前**逐字相同**：`Pearson module-trait correlations used corPvalueStudent with n=134; BH adjustment covered all 19 module-trait tests.` |
| 修改后：plain Pearson，有缺失 | `Pearson module-trait correlations used corPvalueStudent with the pairwise complete sample count of each module-trait pair (n=133 of 134 samples, because trait values were missing); BH adjustment covered all 1 module-trait tests.` |
| 修改后：描述性（Spearman/Kendall/cosine/weights） | `Module-trait correlations (Spearman) were computed as descriptive coefficients. No P values were computed because a Student-t P value is not valid for this correlation setting (corPvalueStudent applies to plain Pearson correlation only); the correlations are descriptive and no BH adjustment was applied.` |

Results：锚点路径与原文逐字相同（`... all 19 module-trait tests are retained. These associations ...`）。描述性路径改为 `all N module-trait correlations are retained. No P values were computed because a Student-t P value is not valid for this correlation setting; the correlations are descriptive.`；Pearson 有缺失时追加 `Trait values were missing for some samples, so each Student-t P value used the pairwise complete sample count of its module-trait pair (n=133 of 134).`

图注（描述性）：`Each cell gives the descriptive correlation coefficient (Spearman) only and no P values are shown; colour encodes r from −1 (blue) to 1 (red). n = 134 biological samples; no display significance filter. No P values were computed because a Student-t P value is not valid for this correlation setting; the correlations are descriptive.`

### bicor

性状相关路径不提供 bicor，本 lane 也没有新增。**bicor inference is not exposed**：`--network-cor-type bicor` 只作用于网络构建，与模块—性状推断无关。

## 二、CellChat：沿用 marker 模块的分组规则（前 lane 实施，已验收）

- `skills/cellchat-communication/scripts/run_cellchat_communication.R:19`：新增 `--sample-col`（默认 `samples`），并把输入层的可信 state 传入计算层（`:29`）。SKILL.md、`references/options.md`、`calls_registry.json` 同步。
- `skills/cellchat-communication/scripts/cellchat_communication_core.R:2-19`（`cellchat_communication_group_guard`）：样本列存在时，`--cluster-col` 等于样本列或在每个样本内只取一个值即拒绝；样本列不存在时，只接受可信上游 / 嵌入 state 记录的聚类列（`cluster_col`、Bioconductor `clusters`、Seurat `cluster`）。原 Astra 对 `group.dataset` / 替代 `group.by` 的拒绝（`:24`）保留。
- `skills/cellchat-communication/tests/fixtures/make_skin.R:5`：人皮肤锚点的 `samples` 取自数据自带的 `patient.id`（探测确认存在），缺失时才回退为 `sample1`。
- `skills/cellchat-communication/tests/run_smoke_test.R:37-72`：条件列、样本列本身、无样本列且非链聚类列三种拒绝；有样本列时第二个细胞层标签（聚类列副本）允许且通信结果相同。

拒绝信息：

```text
OS_PSEUDOREPLICATION: Grouping column 'condition' is sample-level; use muscat-pseudobulk for expression or speckle-propeller for proportions, where samples are replicates. CellChat compares communication between cell groups, not conditions.
OS_PSEUDOREPLICATION: Grouping column 'labels' needs a sample column to verify that the grouping is cell-level; use muscat-pseudobulk for expression or speckle-propeller for proportions, where samples are replicates. CellChat compares communication between cell groups, not conditions.
```

验收：以 `patient.id` 为样本列的聚焦 smoke exit 0；默认 presto 与显式 Wilcoxon 两条 sealed golden 均逐字节不变，SHA256 `56f455639c3498fe53c4b0abd81c04d35984f28cb552e81e10fba992341f4ddd`。

## 三、WGCNA golden 冲突的解决

**冲突**：原规格要求 `module_traits.csv` 加 `inference` 列、Methods 加 `{inference_note}` 句，同时要求锚点 golden 七项逐字节不变。前 lane 的实现使 `module_traits.csv` 与 `draft/methods_results.md` 两项 hash 改变（数值本身未变），golden FAIL。

**解决（未改动、未重生成任何 golden，未放宽任何断言或容差）**：

1. `tables/module_traits.csv` 在所有路径上保持原 schema：`module, trait, estimate, p_value, p_adjusted, n_unweighted`。描述性路径 `p_value` / `p_adjusted` 为 NA。
2. 推断模式与成对 n 写入新的 sidecar `tables/module_traits_inference.csv`：`module, trait, inference (pearson_student_t | descriptive_no_p), n_pairwise_complete, n_samples, p_value_source`。`os_golden_check` 只比对 `tests/golden_manifest.csv` 中列出的路径，新文件不在清单中，因此不影响检查；检查逻辑与清单均未改动。
3. 原 Methods 句本来就写明 Pearson 用 `corPvalueStudent with n=…`，已是 Student-t P 的完整说明，因此 plain Pearson 无缺失路径不加任何句子。模板把这一句改为槽 `{trait_inference}`，该路径下填入与原文逐字相同的句子；Results 用 `{results_inference}`（该路径为空串）和 `{assoc_noun}`（`tests`）。只有描述性设置和 Pearson 有缺失两种情况才会追加句子，因为只有这两种情况内容不同。
4. 前 lane 添加的 `tests/fixtures/original_golden_manifest.csv` 及「去掉新列后再比 hash」的替代断言已不再被测试引用：真实 golden 检查现在直接 PASS，比替代断言更严格。该文件仍留在仓库中（未被任何 lock 绑定），留给协调者决定是否删除。

**Golden 逐项状态（锚点：默认 Pearson，FemaleLiver 3600 探针 × 134 样本）**：

| golden 条目 | 状态 |
|---|---|
| tables/gene_modules.csv | 逐字节相同 |
| tables/module_sizes.csv | 逐字节相同 |
| tables/module_traits.csv | 逐字节相同（`c6a183c8ea7d586aa01a2520af5bac8cc0baaca3dc76cfc3613e3d559a20a5e0`） |
| tables/soft_threshold.csv | 逐字节相同 |
| draft/methods_results.md | 逐字节相同（`29f32f1920d7a54ab23be1c68931dc7c5fd90e54fb40ba57d62316bbc40ea5a2`） |
| figures/soft_threshold.figure_spec.json | 逐字节相同 |
| figures/module_traits.figure_spec.json | 逐字节相同 |

smoke 中 `container golden` 为 PASS（不是 SKIP）。

### WGCNA 回归（`skills/wgcna-network/tests/run_smoke_test.R`）

聚焦 smoke（最终代码）：**59 项检查全部 PASS**，exit 0。在原有断言全部保留的基础上：

- 锚点：P 值与教程 part 3 直接回放差值 < 1e-12；`module_traits.csv` 列名等于原 schema；sidecar 全为 `pearson_student_t`、`n_pairwise_complete` = 134（`:35-38`）。
- Spearman 与 cosine 的 CLI 运行：原 schema、P 与调整 P 全 NA；sidecar 全为 `descriptive_no_p`；effect table `test_name` = `none (descriptive correlation)` 且 P、`p_adj_method` 为 NA；Methods/Results 描述性措辞；图注原因；实际绘图标签只有 r、无括号/NA（`:66-81`）。
- 一个性状缺失的 Pearson 运行：`n_unweighted` 与 sidecar `n_pairwise_complete` 均为 133，等于直接 `crossprod` 计算；Methods 与图注写明 n=133 of 134；P 值与直接 `corPvalueStudent(nSamples = pair_n)` 回放差值 < 1e-12（`:85-101`）。
- 锚点 golden：PASS（`:132`）。

## 四、锁与 seal

`mcp/module_seal.py` 显示本轮改动使 6 个 seal 失效：`wgcna-network`（模块自身文件）以及绑定 `skills/_shared/scripts/fig_network.R` 的 5 个 Python 模块 `scanpy-cluster`、`scanpy-markers`、`scanpy-qc`、`scanvi-annotate`、`scvi-integrate`。

- R：`tools/make_module_lock.R wgcna-network`（显式 `OMICSTAT_IMAGE_ID` = 锁定镜像 ID），`--check` → `module_lock wgcna-network 1.0.0: OK (16 files)`。
- Python：`tools/make_module_lock.py` 在 `omicstat-py:2026.09.1` 中逐个生成，`--check` 全部 OK（68/68/66/66/67 files）。
- `cellchat-communication` 本轮未改，沿用前 lane 的重签。
- 全部 seal：**39/39 verify OK**（`~/omic-sol61/owner_items/all-seals-v2.json`）。

## 五、全套测试

在最终代码与最终 lock 上依次运行（`~/omic-sol61/owner_items/run_full_v2.sh`，2026-10-05 09:15–11:30）：

| 测试 | 结果 |
|---|---|
| `bash env/test.sh`（omicstat-r 容器，非 root，离线） | exit 0，`== done: ALL PASSED (0 skipped for missing packages)`，共 189 条命令。唯一失败为 sva-batch 已登记的 2 条 A6a `KNOWN-FAILING ANCHOR`（`SMOKE PASSED (with 2 documented KNOWN-FAILING anchor(s))`）。wgcna-network smoke `SMOKE PASSED: 59 checks`；cellchat-communication smoke 通过（含替代标签与 presto 锚点逐字节相同）。 |
| `bash env/py/test.sh`（即在 omicstat-py 镜像中执行 `tools/run_tests_py.sh`，非 root，离线） | exit 0，`== done: ALL PASSED (31 commands)`。`env/py/test.sh` 就是 `tools/run_tests_py.sh` 在 Python 镜像内的官方包装，未另行重复运行。 |
| `bash env/py/test_e2e.sh`（`OMICSTAT_E2E_PYTHON=$HOME/omic-venv/bin/python`） | exit 0，99 assertions，99 passed，0 failed，3 skipped（3 项均为 native 引擎在宿主机不可用：无 Rscript / 无 native 环境文件）。 |

报告文件：`env/test_report.txt`、`env/py/e2e_report.txt`（已随提交更新）；控制台日志在 scratch `full-r-v2-console.log`、`full-py-v2-console.log`、`e2e-v2-console.log`。

## 六、图像检查

逐张打开：WGCNA 锚点 Pearson `module_traits.png`（19 模块，r 与括号内 P，图例 `Pearson r`）；全锚点 Spearman 复核运行 `module_traits.png`（scratch `review-spearman-full`，19 模块，只有 r，图例 `r`）；smoke 中 cosine / Spearman 小子集（1 个模块，只有 r，图例 `r`）及缺失性状 Pearson（r 与 P，图例 `Pearson r`）；CellChat 锚点（patient.id 样本列）`network_circle.png` 与 `network_weight.png`。未见空白面板、标签重叠或被截断；图例与推断模式一致。前 lane 已记录的 WGCNA 样本树纵轴标题贴左边缘属原有布局，本轮未改动。

## 七、遗留事项

- `skills/wgcna-network/tests/fixtures/original_golden_manifest.csv` 已无引用，可由协调者删除。
- 描述性路径的 `module_traits.png` 只在 Spearman 全锚点复核中看过多模块版本；smoke 中的描述性运行用的是 200 探针子集，只有 grey 一个模块，属测试设计如此。
