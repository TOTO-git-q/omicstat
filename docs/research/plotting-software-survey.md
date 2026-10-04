# 开源生信与细胞生物学作图/统计软件源码调研：omicstat 改进清单

> 2026-09-26。应 medstat 会话转来的调研要求完成。17 个仓库全部 `git clone --depth 1` 只读阅读，未安装、未执行。文中路径均相对各仓库根目录。
> 标 **需要证据** 的建议会改变估计方法或统计默认值，按项目纪律不能直接采纳，必须先有可复现的错误或文献依据。标“推断”的条目是读代码得出、未经运行验证的判断。

## 结论

被调研的 17 个库都把**统计推断的单位**交给用户自己负责。单细胞绘图库（Seurat、SCpubr、scCustomize、CellChat）在图上做的条件间检验都以细胞或细胞组对为单位，并且没有多重校正。细胞生物学作图库里：
- 只有 SuperPlotsOfData 在重复汇总后再做检验；
- 只有 rstatix 要求配对必须按 id 对齐；
- ggpubr 默认显示的是**未校正的 p**。

这说明 omicstat 的“固定引擎 + QC 清单”方向有真实的差异化价值，尤其是伪重复拦截、n 的单位写在图上、校正后 p 为默认。在工程层面，值得直接借鉴的有四类：
- SCpubr / rstatix 的**类型化参数校验**；
- iDEP 的**“图 + 警告”成对返回的 QC 诊断**；
- ComplexHeatmap 的**离群值与叠加一致性检查**；
- scanpy 的**带容差的图像回归测试**。

同时，这些库暴露了一批**反面教材**，其中很多正好是我们应做成自动检查的点：
- 文案与代码默认值不一致：iDEP、ShinyGO、EnhancedVolcano、scCustomize 都有；
- 随机数不设种子：Seurat、dittoSeq、iDEP、SuperPlots；
- 全局吞警告：CellChat、iDEP 的 `options(warn=-1)`；
- 超出坐标范围的点被静默删除：EnhancedVolcano。

图型方面，论文常用而我们缺的主要有：
- 行注释 / 分块热图；
- 堆叠小提琴与 ridge；
- 密度 UMAP；
- 冲积图（注释对应关系）；
- cnet / emap / tree 富集网络；
- 多集 GSEA 曲线；
- SuperPlot 与估计图。

## 一、分问题的发现

### 1. 选项与默认值怎么声明，哪些必须显式选择

| 做法 | 出处 | 对我们的意义 |
|---|---|---|
| 参数按 logical / numeric / character 分组，统一交给类型检查；枚举型参数单独校验；具名颜色必须覆盖全部水平，否则打印 ✓/✗ 对照表后停止 | SCpubr `R/utils.R`（`check_type`、`check_parameters`、`check_consistency_colors_and_names`） | 我们的 `parse_args` + `KNOWN_FLAGS` 只校验参数名，不校验类型和取值，可以照此补上 |
| 配对必须显式给 `id`，并按 id inner-join；同组 id 重复即报错；打乱行顺序后结果不变（有测试） | rstatix `R/utilities_two_sample_test.R::align_paired_by_id`、`tests/testthat/test-paired-id.R` | 反例：ggpubr `ggpaired()` 按行顺序配对；SuperPlots 由“连线样式”决定是否配对（`app.R` 约 1550 行） |
| 数据类型下拉框默认 "..."，不选就不出现上传控件，相当于强制显式选择 | iDEP `R/mod_01_load_data.R`（`data_file_format`） | 与我们“关键选择无默认”的原则一致 |
| 同一参数在不同层有不同默认值：UI 的 FDR 是 0.1，函数默认是 0.05；提示写 `cpm(prior.count=1)`，代码是 `log2(归一化计数+c)` | iDEP `R/mod_05_deg.R` 对 `R/fct_05_deg.R::deg_deseq2`；`R/fct_02_pre_process.R::pre_process` | 反面教材：`--help`、引擎默认值、Methods 文案三者必须由机器比对一致 |
| 文档说 FC 默认 2，代码是 1.0 | EnhancedVolcano `vignettes/EnhancedVolcano.Rmd:122` 对 `R/EnhancedVolcano.R:209` | 同上 |
| 提示写阈值 200,000，实际阈值是 1e5 | scCustomize `R/Plotting_Seurat.R` 约 841–843 行 | 同上：提示文字要从同一常量生成 |
| 默认主题、色板、形状用 YAML 数据驱动；分类数超过 `attr(,"max_n")` 时报错 | ggprism `data-raw/*.yml`、`prism_shape_pal()` | 我们用 `OS_FIG` + 文档 token 表已经做到；可以借鉴其“超出上限即报错、禁止循环复用颜色”的规则（反例：SuperPlots `rep(newColors, …)`） |

### 2. 自动检验与诊断，以及如何呈现给用户

| 诊断 | 出处 | 呈现方式 |
|---|---|---|
| 测序深度与分组的 ANOVA 混杂告警，附 max/min 比 | iDEP `counts_bias_message` | 常驻通知 |
| PC1–5 与设计因子的关联（Bonferroni） | iDEP `R/fct_04_pca.R::pc_factor_correlation` | 表格 |
| GC 偏倚、看家基因、rRNA、染色体计数的组间 ANOVA，只在“组定义良好”（2–20 组、每组 ≥2 个样本）时才做 | iDEP `R/fct_02_pre_process.R`（`gc_bias_ggplot` 等） | 函数统一返回 `list(plot, warning)` |
| counts 与归一化数据误选：看是否整数 + 平均峰度 > 50；比值型数据：负值 < 1% 且偏度 > 1 | iDEP `pre_process`、`R/mod_01_load_data.R` | 弹窗，**并自动修正**（我们应改为报错或警告，不自动修正） |
| 逐样本的过滤报告；ID 转换率 | iDEP `R/mod_02_pre_process.R::counts_table`、`conversion_counts_message` | 表格 / 文字 |
| 默认颜色映射下的离群值提示（|x| > 3×99 分位） | ComplexHeatmap `R/utils.R::default_col` L82-117 | message |
| 叠加的热图行名集合相同但顺序不同时发出警告 | ComplexHeatmap `R/HeatmapList-layout.R` L1130-1170 | warning |
| p=0 时替换为最小非零 p × 0.1 | EnhancedVolcano L320-333 | warning（但改变了显示值） |
| showCategory 超过可用条目数、ID 名全不匹配、集合太小被丢弃：信息里写清数量、原因和修复命令 | enrichplot `R/data_utils.R` L38-56、L233-246，`R/ridgeplot.R` L332-373，`R/emapplot_utilities.R` L53-63 | warning / abort |
| 组数 < 5 时做 z-score 警告；所有细胞取值相同时警告 | Seurat `R/visualization.R`（DotPlot、SingleExIPlot） | warning |
| 样本与分组不是一一对应时直接停止 | dittoSeq `R/dittoFreqPlot.R::.check_1value_per_group` | stop |
| Shapiro / Levene 只作为信息附在结果上；文档明确反对“先检验假设再选检验” | rstatix `R/check_test_assumptions.R` | `attr(res, "assumptions")` |
| 对照组的重复数 n < 3 时直接报错；过半重复不正态时建议改用 median | SuperPlotsOfData `app.R` 1538–1540、724–733 行 | 错误表 / 通知 |
| **吞警告**：`options(warn=-1)` 且不恢复 | CellChat `R/visualization.R`（880、1070 等行）；iDEP `R/app_server.R` | 反面教材：我们的引擎应用 `withCallingHandlers` 把警告全部收进 QC 清单 |

### 3. 图上的统计标注：检验、多重校正、n 的含义

- **校正**：
  - ggsignif 完全不校正。
  - ggpubr `geom_pwc` 默认计算 Holm，但**默认标签显示原始 p**（`R/geom_pwc.R` 657–663 行）。
  - `stat_compare_means(comparisons=)` 显示未校正的 p，每个会话只提醒一次。
  - Seurat、SCpubr、scCustomize、CellChat 的图上检验都不校正。
  - ggprism 猜测标签列时**优先用 p.adj**（`R/utils.R::guess_signif_label_column`），这是唯一默认偏向校正值的实现。
- **星号边界不统一**：
  - rstatix / ggpubr 用 `symnum`，区间右闭，p = 0.05 标 `*`。
  - ggsignif 用严格 `<`，p = 0.05 为 `NS.`。
- **n 的单位**：
  - ggpubr `show.n`、ggsignif、dabestr 的 n 都是**行数**。
  - SCpubr `do_BoxPlot` 的 n 是**细胞数**。
  - dittoSeq `dittoFreqPlot` 和 SuperPlots 的 n 是**样本 / 重复数**（正确单位）。
- **文字标签**：
  - rstatix `get_pwc_label()` 生成 "pwc: T test; p.adjust: Holm"。
  - ggpubr 生成 "Wilcoxon, p = 0.012"，并预置 default / apa / nejm / lancet / graphpad 等 p 格式（`R/p_format_utils.R`）。
  - dabestr 打印 "5000 bootstrap samples… BCa…"，并声明 p "for legacy purposes only"。
- **组学图**：
  - EnhancedVolcano 的 y 轴标签固定写 "-Log10 P"，不管用的是原始 p 还是校正后的 p（L199）；图注只写 "total = N variables"，而且 N 包含 NA 行。
  - enrichplot dotplot 默认按 **GeneRatio** 取前 10（`R/dotplot.R` L390-406），并不是取最显著的；没有显著条目时也不提示。
  - GeneRatio 在 ORA 与 GSEA 中定义不同（`R/method-fortify.R` L327-335）。
  - CellChat 气泡图的 p 来自 nboot=100 的置换检验（分辨率 0.01），没有校正，色条只标 min / max。
- **“平均表达”的定义各不相同**：
  - Seurat：`log1p(mean(expm1(x)))`，z-score 截断到 ±2.5。
  - scanpy 和 SCpubr：log 值的均值。
  - dittoSeq：非零细胞的均值。
  - 我们必须在图注和 Methods 里写明所用的定义。

### 4. 跨图一致的样式系统

- **颜色注册表**：
  - scanpy 用 `adata.uns["{key}_colors"]`，在多张图之间复用。
  - scCustomize 用 `Store_Palette_Seurat`。
  - ComplexHeatmap 用同名离散图例合并 + `col = list(...)` 分发。
  - 我们的 `colour_registry.json` 与之同构，而且能跨模块传递。
  - 反例：ComplexHeatmap 未指定颜色的离散注释调用 `rand_color`（`R/utils.R` L76-81），结果不可复现。
- **分类色板按类数分档**：
  - Seurat：≤26 类用 alphabet，≤32 用 glasbey，否则 polychrome。
  - scanpy：≤20 类用 vega20，≤28 用 zeileis，≤102 用 godsnot，更多全灰。
  - dittoSeq：Okabe-Ito 8 色 + 明暗变体，共 40 色。
  - SCpubr：`colorblind=TRUE` 时按类数选 Wong / Tol / Krzywinski。
- **点大小与栅格化**：
  - Seurat：点大小 `min(1583/n, 1)`，点数 > 1e5 时自动栅格化（scattermore，dpi 512）；需要保留绘制顺序时改用 ggrastr。
  - scanpy：点大小 `120000/n`。
  - scCustomize：细胞数 > 2e5 时栅格化。
  - ComplexHeatmap：行 > 2000 且列 > 10 时栅格化，所用设备取决于环境里是否装了 Cairo / magick（输出因此依赖环境）。
  - 我们的阈值是 50,000 点、ggrastr ragg、600 dpi，设备固定在容器里。
- **绘制顺序**：
  - Seurat 默认不打乱，`shuffle` 的 seed 为 1。
  - scCustomize 默认 `shuffle=TRUE, seed=1`。
  - dittoSeq `randomize` **不设种子**。
  - scanpy 连续变量默认高值画在上层。
  - 我们的做法是无随机数的确定性伪打乱 + 按表达量升序绘制。
- **标签位置**：
  - Seurat、scanpy、dittoSeq 都放在组中位数。
  - SCpubr 先用 kde2d 估计密度，再取每组 33–66% 分位框内细胞的均值，更抗离群点。
  - Seurat 用 `label.size.cutoff` 隐藏小群的标签。
- **截断色条**：SCpubr `compute_scales` 把两端标签写成 "≤ min" / "≥ max"。我们截断到 ±2 的色条目前没有这样标注。
- **抖动的确定性**：
  - ggpubr 固定 `seed=123`，并在函数结束后恢复调用者的 `.Random.seed`。
  - ggprism 的测试用 `position_jitter(seed=1)`。
  - dabestr 用 beeswarm，SuperPlots 用 quasirandom，都是确定性布局。

### 5. 数值与图形正确性测试

| 库 | 方式 | 评价 |
|---|---|---|
| scanpy | `tests/plotting/legacy/conftest.py::plot_cmp`：图像 RMS 容差 15（超过 25 直接报错）；基准图按 matplotlib 版本分目录；失败时输出 diff；另用 `tol=1` 验证两条代码路径产出同一张图 | 最完善，可直接照搬到“Seurat 线与 SCE 线出图一致”的验收 |
| rstatix | 与 `stats::t.test` / effectsize 数值比对（容差 1e-6 ~ 1e-7）；打乱行顺序后结果不变；校正必须基于全精度 p | 数值正确性测试的范本 |
| ggpubr / enrichplot | 用 `ggplot_build()` 取出 layer 数据断言（p.adj、n、刻度函数输出、hit-bin 边界） | 比快照稳定 |
| ComplexHeatmap | `testthat-ColorMapping.R` 断言精确 hex | 可用于我们的色阶测试 |
| ggsignif / ggprism / dabestr | SVG 快照：ggsignif 用 vdiffr；ggprism 用 tinysnapshot 并固定 svglite 与 "Darwin"；dabestr 有 24 张快照但**在 CI 上跳过** | 快照必须固定设备和平台，且不能跳过 |
| Seurat / SCpubr / dittoSeq | 以 `expect_s3_class` / `is_ggplot` 为主；dittoSeq 用 `data.out` 做数据等价测试 | 覆盖弱 |
| EnhancedVolcano / scCustomize / CellChat / ShinyGO / SuperPlots | 基本没有测试 | — |

我们已有的测试：PNG / SVG 逐字节一致、PDF 内容哈希一致、token 与文档一致、错误码、语义（计数、阈值线、标签选择）。**还缺**两类：`ggplot_build` 层级的数值断言，以及“两条前端出同一张图”的验收。

### 6. 我们规划里缺的常见分析与图型

- **热图**：
  - 行注释条、行 / 列分块（split），以及带共识的行 k-means（ComplexHeatmap `row_km`、`km_repeats`）；
  - 只标部分行并画引线（`anno_mark`）；
  - 多热图拼接并共享图例；
  - UpSet。
- **富集**：
  - cnetplot、emapplot、treeplot、ridgeplot、heatplot；
  - 多集 GSEA 曲线；
  - 两组对比的发散点图 dotplot2（enrichplot）；
  - 术语树 / 网络（iDEP、ShinyGO）。
- **单细胞**：
  - 堆叠小提琴（scCustomize `Stacked_VlnPlot`、scanpy `stacked_violin`）；
  - RidgePlot；
  - 密度 UMAP（Nebulosa）；
  - 高亮单个群；
  - 冲积 / 桑基图（SCpubr `do_AlluvialPlot`，用于注释对应和聚类稳定性）；
  - 群聚类树 + dotplot；
  - 双基因 blend；
  - matrixplot、tracksplot。
- **CellChat**：弦图、hierarchy 图、信息流（`rankNet`）、signalingRole 散点 / 热图，以及跨条件时边宽统一尺度（`edge.weight.max`）。
- **细胞生物学实验图**：
  - SuperPlot（细胞层 + 重复均值层）；
  - Gardner-Altman / Cumming 估计图；
  - 配对 slopegraph；
  - repeatability（ICC）。
- **基因层面探索**：基因 k-means + 肘部图（iDEP `R/fct_03_clustering.R`）、染色体位置富集、启动子 motif（iDEP、ShinyGO）。

## 二、改进清单（按优先级）

工作量：S ≈ 1 天以内，M ≈ 2–5 天，L ≈ 1 周以上。

| # | 优先级 | 改进 | 借鉴自 | 工作量 | 风险 / 备注 |
|---|---|---|---|---|---|
| 1 | P1 | **默认值一致性检查**：机器比对 `--help` 默认值、`calls_registry.json`、`references/parameters.md` 与 Methods 模板中的数值，不一致即测试失败 | 反例：iDEP、ShinyGO、EnhancedVolcano、scCustomize | S | 低；扩展现有的 `check_flag_docs.py` 即可 |
| 2 | P1 | **引擎警告全捕获**：`run_*.R` 模板用 `withCallingHandlers` 收集所有 warning / message 写进 QC 清单；禁止 `options(warn=-1)`（lint 检查） | 反例：CellChat、iDEP | S | 低 |
| 3 | P1 | **类型化 flag 校验**：`KNOWN_FLAGS` 扩展为 {名称、类型、枚举、范围、互斥关系}；具名颜色、分组水平必须全覆盖，失败时打印对照表 | SCpubr `R/utils.R` | M | 低；只影响输入校验 |
| 4 | P1 | **n 的单位写上图、写进图注**：凡是涉及组间比较的图，都标注 "n = x samples（y cells）"；比例图用样本数 | dittoSeq、SuperPlots；反例：SCpubr、ggpubr | S | 低；只改渲染 |
| 5 | P1 | **样本与条件一一对应、配对按 id 对齐**：写进 `_shared` 输入校验（`OS_INVALID_DESIGN`）；禁止按行顺序配对 | dittoSeq `.check_1value_per_group`；rstatix `align_paired_by_id` | S | 低 |
| 6 | P1 | **截断与离群值的 QC 与标注**：热图、点图的色条两端写 "≤ −2" / "≥ 2"；QC 清单记录被截断的单元格数和比例，以及 \|x\| > 3×分位数的单元格数 | SCpubr `compute_scales`；ComplexHeatmap `default_col` | S | 低；只改渲染和报告 |
| 7 | P1 | **p 值显示规范写进 token 表**：默认显示校正后 p；统一星号 cut-points 和区间开闭（写进 FIGURE_STYLE）；图注写出 "test; adjustment; family = k" | ggprism（优先 p.adj）、rstatix `get_pwc_label`、ggpubr `.p_format_styles`；反例：ggpubr `geom_pwc` | S | 显示规范低风险；**校正方法和家族的选择：需要证据**（按模块 PACK 裁决） |
| 8 | P1 | **`ggplot_build` 数值断言 + 两条前端出图等价验收**：共享层与每个模块的测试断言 layer 数据（颜色 hex、阈值、点数），Seurat 输入与 SCE 输入出同一张图（PNG 逐字节，或 RMS 容差） | enrichplot / ggpubr 测试；scanpy `plot_cmp`；ComplexHeatmap 颜色测试 | M | 低 |
| 9 | P1 | **富集图的选词规则与定义写明**：图注写 "top-N by padj, ordered by GeneRatio/NES" 以及 GeneRatio 的定义（ORA 为 k/n，GSEA 为 core/setSize）；没有显著条目时给出结构化 QC 结论，而不是空图 | enrichplot `R/dotplot.R` L390-406、`R/method-fortify.R` L327-335 | S | 低；我们本来就按 padj 选，这条是把它写明 |
| 10 | P2 | **deseq2-qc 的诊断规则**：测序深度与分组的混杂（ANOVA + max/min 比）、PC 与设计因子关联、逐样本过滤报告、输入类型判别（整数 / 峰度）；全部采用“图 + 警告”成对输出，并设“组定义良好”门槛 | iDEP `counts_bias_message`、`pc_factor_correlation`、`gc_bias_ggplot` | M | 阈值（p<0.05、峰度 50 等）写进 PACK D 节时**需要证据**；只报告、不自动修正 |
| 11 | P2 | **热图引擎扩展**：行注释条、行 / 列分块、`anno_mark` 式的部分行标注；叠加热图时的行名一致性检查 | ComplexHeatmap | M | 中；布局复杂度增加，需要补测试 |
| 12 | P2 | **单细胞常用图**：堆叠小提琴、ridge、高亮单群、冲积图（注释对应）、群聚类树 + dotplot；小群标签隐藏阈值、图例按类数分列 | scCustomize、scanpy、SCpubr、Seurat | M | 低；纯作图 |
| 13 | P2 | **“平均表达”定义显式化**：marker 点图的图注和 Methods 写明计算方式；组数 < 5 时做 z-score 触发 QC 规则 | Seurat DotPlot 警告；四个库的定义对比 | S | 选择哪种定义作默认：**需要证据**（按 PACK 多数派） |
| 14 | P2 | **富集网络图**：cnet、emap、treeplot、多集 GSEA 曲线；结果附基因集来源、版本、PMID | enrichplot；iDEP `pathway_source_info` | M | 低 |
| 15 | P2 | **CellChat 模块规范**：跨条件边宽统一尺度（`edge.weight.max`）；气泡图色条显示数值；QC 注明 p 来自细胞标签置换、分辨率为 1/nboot、未校正 | CellChat `R/visualization.R` | S | 修改 nboot 或加校正：**需要证据** |
| 16 | P2 | **色盲模拟 lint**：对每张图的离散色做 deutan / protan / tritan 模拟，相邻类别不可区分时给出警告 | SCpubr `do_ColorBlindCheck`；dittoSeq `Simulate` | S | 低 |
| 17 | P3 | **细胞生物学实验图模块**：SuperPlot（统计在重复均值上做）、估计图（均值差 + CI）、配对 slopegraph；确定性布局（beeswarm） | SuperPlotsOfData、dabestr、ggprism | L | 统计单位和推断方法（自助法 / 置换法）：**需要证据**；dabestr 有三处源码疑点需先实测：`equal.var` 参数名写错、配对重抽样不联合、计算路径不按 id 对齐 |
| 18 | P3 | **基因层面探索模块**：基因 k-means + 肘部图、染色体位置富集 | iDEP、ShinyGO | M | 新增模块需走 S0–S5；滑窗“先筛后校正”的做法**需要证据**（ShinyGO 的做法在统计上有问题） |
| 19 | P3 | **密度 UMAP、双基因 blend、六边形分箱汇总** | scCustomize（Nebulosa）、Seurat、dittoSeq `dittoDimHex` | M | 低 |

## 三、不建议采纳的做法

- **自动“先检验假设再选检验”路由**（rstatix `choose_oneway_route`）：rstatix 自己的文档也指出，这样选出来的 p 不再具有名义含义。
- **对输入做静默的自动修正**（iDEP 峰度 > 50 自动取 log，比值数据自动 log2）：应改为类型化报错或警告，由用户显式选择。
- **超出坐标范围的点静默删除**（EnhancedVolcano）：我们现在用三角形标出截断值并在图注计数，更严格。
- **p = 0 替换为最小值 × 0.1**（EnhancedVolcano）：改变了显示值；我们的做法是截断到上限并画三角形。
- **以细胞为单位做条件间检验**（SCpubr、scCustomize、CellChat 的图上检验）：与我们的伪重复 blocker 规则冲突，不提供。
