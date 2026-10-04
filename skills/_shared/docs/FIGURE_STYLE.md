# omicstat 图形规范 v1.3.0（FIGURE_STYLE）

> 本文件是 omicstat 全部分析模块出图样式的**唯一规范**。它与 `scripts/fig_style.R` 是一对孪生文件：代码是执行者，本文件是人读版。§14 的机器校验表由 `tests/test_figures.R` 逐项与代码比对，两者不一致时测试直接 FAIL，所以文档不可能悄悄过时。
> 适用范围：所有 `skills/<module>/` 的作图，一律通过 `_shared/scripts/fig_*.R` 完成。**模块代码里不允许出现任何颜色值、字号、线宽、点形状或文字位置的字面量。**需要新图型时先扩展 `_shared`，再由模块调用。

> **v1.3.0 变更（只改标签排布，2026-09-27 锁定容器验收）**：火山图与 MA 图的基因标签改用确定性排布 `os_label_place()`（§7.3）；两图不再用固定 `aspect.ratio`，面板形状由图高决定（火山图默认高 92 mm）。原因：锁定容器（ggrepel 0.9.8）中 pasilla 锚点的火山图 / MA 图出现标签互压——ggrepel 的斥力在消除全部重叠前就衰减停止（1,000 次与 100,000 次迭代布局完全相同），固定 aspect.ratio 使其更严重。
>
> **v1.2.0 变更（只改标签排布）**：ggrepel 改为固定迭代 100,000 次、不设实际生效的时间上限（§7.3）——旧设置（20,000 次或 5 秒）在约 8,000 个点的火山图上会让标签互相压住，且时间上限使布局随机器快慢而变。
>
> **v1.1.0 变更（只改显示与报告，不改任何统计量、阈值默认值或选择规则）**：n 与单位上图（§16.3）；marker 点图截断色条与截断计数（§8.11）；P 值显示规范写进 token（§16）；`ggplot_build` 数值断言（§13 T8）；富集图写明选择规则与定义（§8.5–8.8）；marker 点图必须声明“平均表达”定义（§8.11）；色觉缺陷 lint `FIG-03`（§17）。

---

## 0. 稳定性靠什么保证（五道机制）

| 机制 | 做法 | 在哪里 |
|---|---|---|
| ① 单一 token 源 | 所有视觉常量集中在 `OS_FIG` 与 `OS_PAL_*`，图函数只读不写 | `fig_style.R` §3–4 |
| ② 语义配色角色 | 颜色按“含义”分配（上调/下调/参照组/不显著/细胞类型……），而不是按“第几个系列” | 本文 §6 |
| ③ 跨图颜色登记表 | 同一个细胞类型、簇、条件在整条 `--from-run` 分析链的所有图中颜色恒定 | `os_colours_for()` + `objects/colour_registry.json` |
| ④ 确定性渲染 | 行序、标签选择、绘制层序、ggrepel 种子、PCA 符号、PDF 时间戳全部固定；同一输入重跑，PNG/PDF/SVG/figure_spec 逐字节相同 | `tests/test_figures.R` T1 |
| ⑤ 机械质检 + 自动图注 | 字号下限、语义色数、非拉丁字符、画布高度、标签拥挤度在保存前检查；图注由画图时的同一份数据生成，不可能与图不符 | `os_fig_lint()`、`os_save_figure()` |

变更规则（对应 ENGINEERING_PLAN 锁 7）：改动任何 token → 升级 `OS_FIG_STYLE_VERSION`、同步改本文件 §14、重跑 `make_figure_gallery.R` 并人工逐张看图、重新登记金标准中的图形哈希。**数值结果表必须保持逐字节不变。**

---

## 1. 用法（模块作者只需要这些）

```r
source(file.path(shared_dir, "scripts", "fig_all.R"))       # 一次载入全部作图层
reg <- os_colour_registry_read(file.path(from_run, "objects", "colour_registry.json"))

p <- os_volcano(feature_table, padj_threshold = 0.05, lfc_threshold = 1,
                contrast_label = "Treated vs control",
                method_label = "DESeq2 Wald test, apeglm shrinkage, Benjamini-Hochberg")
os_finalize_figure(p, file.path(out_dir, "figures", "volcano"), width = "single", root = out_dir)
# -> volcano.pdf（矢量，字体内嵌） volcano.png（600 dpi） volcano.figure_spec.json
```

多面板：`os_compose(list(p1, p2, p3), ncol = 3)` 后同样 `os_finalize_figure(..., width = "double")`。期刊切换：`options(omicstat.journal = "cell")` 或各函数的 `journal =` 参数。

---

## 2. 尺寸：期刊预设

| 预设 | 单栏 mm | 1.5 栏 mm | 双栏 mm | 最大高 mm | 面板字母 | 最小字号 |
|---|---|---|---|---|---|---|
| `nature`（默认） | 89 | 120 | 183 | 170 | 小写粗体 a b c | 5 pt |
| `cell` | 85 | 114 | 174 | 225 | 大写粗体 A B C | 6 pt |
| `science` | 57 | 121 | 184 | 220 | 大写粗体 A B C | 5 pt |
| `generic` | 85 | 120 | 180 | 220 | 大写粗体 A B C | 5 pt |

- 数值是各刊作者指南中常见的公开值，**不在运行时联网核对**。投稿前请以目标期刊当期指南为准，必要时新增一个预设（只改 `OS_JOURNAL_PRESETS`，不改图函数）。
- 出图以**最终印刷尺寸**绘制（不缩放），所以 7 pt 就是印出来的 7 pt。宽度用 `"single" / "onehalf" / "double"` 或具体毫米数。
- 超过预设最大高度直接报错 `OS_FIG_TOO_TALL`，提示拆图。
- 每种图有默认高度（见 §8 各节），可用 `height_mm` 覆盖。

---

## 3. 字体与字号层级

- 字体族优先级：`Liberation Sans` → `Arial` → `Helvetica` → `sans`。Liberation Sans 与 Arial **字宽逐字符一致**（metric-compatible）且可自由分发，因此容器内固定用它，跨机器排版不变；实际使用的字体写进 `figure_spec.json` 的 `font_family`。需要强制 Arial 时 `options(omicstat.font = "Arial")`。
- PDF 用 cairo 输出，字体**子集内嵌**，Illustrator 可直接编辑文字；PNG 用 ragg 600 dpi；可选 SVG（文字保持为文字）。

| 元素 | 字号 | 字重/字形 | 位置 |
|---|---|---|---|
| 面板字母 | 8 pt | 粗体；Nature 小写，Cell/Science 大写 | 面板左上角**外侧**，同一行字母顶端对齐 |
| 面板标题（可选） | 7 pt | 常规 | 面板上方居中 |
| 坐标轴标题 | 7 pt | 常规 | x 在轴下方居中；y 在轴左侧、逆时针旋转 90°居中；与刻度标签间距 1.5 mm |
| 刻度标签 | 6 pt | 常规 | 距刻度线 0.8 mm |
| 图例标题 / 图例文字 | 7 pt / 6 pt | 常规 | 图例在面板右侧、顶端对齐；标题在图例键上方左对齐 |
| 分面条带文字 | 7 pt | 常规 | 条带无底色、无边框 |
| 图内注释（计数、NES、P 值） | 6 pt | 常规 | 见各图型 |
| 数据标签（基因名、样本名） | 5.5 pt | 基因名**斜体**，其余常规 | ggrepel 排布，见 §7.3 |
| 任何文字的下限 | 5 pt（Cell 为 6 pt） | — | `FIG-01` blocker |

- **图内文字一律英文**（含希腊字母、±、×、−）。中文等非拉丁字符在期刊字体里会变成空框，`os_assert_latin()` 直接拒绝（`OS_FIG_NON_LATIN_TEXT`）。
- 所有文字纯黑 `#000000`，**不使用彩色文字**。

---

## 4. 线条

| 元素 | 线宽 | 线型 | 颜色 |
|---|---|---|---|
| 坐标轴线、刻度线 | 0.5 pt | 实线；刻度朝外，长 1.0 mm | 黑 |
| 数据线（曲线、running ES） | 0.75 pt | 实线 | 按语义色 |
| 参照/阈值线 | 0.5 pt | 虚线 `22`（2 单位实 2 单位空） | 中灰 `#7F7F7F`，**画在数据层之下** |
| 零线（MA 图 y=0、NES=0、GSEA ES=0） | 0.5 pt | 实线 | 中灰 |
| 标签引线、热图格线、GSEA 命中竖线、树状图 | 0.25 pt | 实线 | 引线 `#4D4D4D`；其余黑或白 |
| 可填充点的描边 | 0.25 pt | — | 样本点白色、被标注特征点黑色 |

- 坐标轴为 L 形（左 + 下），**不画网格线、不加背景色、不加阴影**。点阵类（marker 点图、富集比较图）用细框（box），热图与嵌入图无坐标轴。
- 阈值线的具体数值一定写进 `figure_spec.json → thresholds` 与自动图注（“Dashed lines mark these thresholds”）。

---

## 5. 点与形状

| 数据层级 | 形状 | 大小（直径 mm） | 描边 |
|---|---|---|---|
| 每个特征（火山、MA） | 16 实心圆 | 0.6 | 无 |
| 每个细胞（UMAP/t-SNE） | 16 实心圆 | 按细胞数：≤2 000 为 0.8；≤10 000 为 0.5；≤50 000 为 0.3；更多为 0.15（且点层栅格化，见 §15.1） | 无 |
| 每个样本（PCA 等） | 21 可填充圆 | 2.2 | 白色 0.25 pt |
| 第二分组变量（如批次） | 依次 21 圆、24 上三角、22 方、23 菱、25 下三角（最多 5 级） | 2.2 | 白色 0.25 pt |
| 被标注的特征 | 21 可填充圆（颜色同类别） | 0.9 | 黑色 0.25 pt |
| 超出坐标范围、被截断的值 | 17 实心三角（被标注时为 24 可填充三角） | 0.78 | — |

- **不用透明度（alpha）表达密度**：半透明会改变颜色、打破“同一实体同一颜色”；稠密时靠绘制顺序与点大小控制。
- 绘制顺序（z-order）固定：不显著点在最底层；显著点按显著性从弱到强（最显著在最上）；单细胞按确定性伪随机顺序（Knuth 乘法散列，不用随机数），避免最后画的簇把别人盖住；表达量图按表达从低到高（表达细胞在上层）。
- 截断值用三角形画在边界上，数量写进图注（“n features beyond the axis limits are drawn as triangles at the limit”）。

---

## 6. 配色系统（按语义角色）

### 6.1 固定语义色（全系统所有图一致）

| 角色 | 颜色 | 用在 |
|---|---|---|
| 上调 / 正 NES / 正相关 | `#B2182B` 深红 | 火山、MA、NES 柱、GSEA 曲线（NES>0）、发散色阶高端 |
| 下调 / 负 NES / 负相关 | `#2166AC` 深蓝 | 同上的负向 |
| 不显著 / 背景特征 | `#BDBDBD` 浅灰 | 火山、MA 的 NS 点，QC 小提琴默认填充 |
| 缺失 / 未分配 | `#D9D9D9` | 未知突变类型、未注释细胞 |
| 参照组（对照） | `#666666` 深灰 | 条件变量的参照水平永远是灰色 |
| 参照线 | `#7F7F7F` | 所有阈值线、零线 |

红-蓝而非红-绿：对红绿色觉缺陷友好，且与发散色阶 RdBu 的两端**完全相同**（测试 T2 检查），所以“火山图里的蓝色基因”和“热图里的蓝色格子”是同一种蓝。

### 6.2 调色板

| 调色板 | 用途 | 规则 |
|---|---|---|
| `OS_PAL_GROUP`（Okabe–Ito 7 色） | 实验条件、处理组（≤8 组） | 参照组固定灰；其余按水平顺序取 `#D55E00 #0072B2 #009E73 #E69F00 #CC79A7 #56B4E9 #F0E442`。超过则 `OS_TOO_MANY_CATEGORIES`，改用分面 |
| `OS_PAL_CATEGORY`（23 色） | 簇、细胞类型、WGCNA 模块等“多类别实体” | 前 6 色为 Okabe–Ito，其后接 Paul Tol muted 与 Kelly 高对比色；**排除全部灰色**（灰色留给 NS/NA）；>23 类报错，请合并小类 |
| `OS_PAL_DIVERGING`（RdBu 9 阶） | z-score 热图、相关系数、带符号的打分 | 蓝=低/负、白 `#F7F7F7`=0、红=高/正；**范围对称**；z 在 ±2 截断（图注说明截断数目） |
| `OS_PAL_SEQUENTIAL`（viridis 10 阶） | −log10 调整 P、AUC、密度等“单向大小” | 感知均匀、色盲友好、灰度可读；以十六进制字面量存储，不随 viridisLite 版本漂移 |
| `OS_PAL_EXPRESSION`（灰→紫 6 阶） | 基因在 UMAP 上的表达、未缩放的平均表达 | 零表达为浅灰 `#E5E5E5` 自然退为背景 |
| `OS_PAL_DISTANCE`（Blues 9 阶反向） | 样本距离热图 | 深蓝=相似（DESeq2 vignette 惯例） |
| `OS_PAL_MUTATION` | oncoplot 变异类型 | 固定映射（见 §14）；Multi_Hit 为黑 |

色觉缺陷检查：`OS_PAL_GROUP` 前 4 色（及参照灰）、上/下调/NS 三色在正常视觉与 deutan/protan/tritan 模拟下两两 CIEDE2000 ≥ 10，测试 T9 保证；`OS_PAL_CATEGORY` 有若干对在模拟下接近（T9 逐对报告，不判失败），所以类别图必须直接写类别名（UMAP）或按固定顺序配图例，单细胞之外的图尽量少用类别色。详见 §17。

**禁止**：jet/rainbow、红-绿对比、同一图中用颜色区分超过 6 个非类别语义（`FIG-02` 警告）、仅靠颜色区分（样本图同时用形状编码第二变量；UMAP 在类别上直接写名字）。

### 6.3 颜色登记表（跨图一致的关键）

- `os_colours_for(values, family, registry)`：`family` 如 `"celltype"`、`"cluster"`、`"group"`。已登记的实体颜色**永不改变**；新实体按字母序（C locale）依次取调色板中下一个未用颜色。
- 模块把登记表写到 `objects/colour_registry.json`，下游模块经 `--from-run` 读入。于是 UMAP 里的 “B” 是 `#0072B2`，比例图、marker 点图、pseudobulk 热图注释条里的 “B” 也一定是 `#0072B2`。
- JSON 键排序固定，重复写出逐字节一致（测试 T3）。

---

## 7. 文字与元素的位置

### 7.1 面板与图例
- 面板字母：左上角，**在面板绘图区与轴标题之外**（`plot.tag.position = c(0, 1)`，左对齐顶对齐），一行中的字母自动对齐。
- 图例：默认在面板**右侧、顶端对齐**，无边框无底色；连续色标竖放，宽 2.4 mm、高 15 mm，带黑色细框与刻度；图例标题在键的上方、左对齐。
- 能直接标注就不用图例：火山图的上/下调计数写在面板顶角；UMAP 把类别名写在该类细胞的中位位置并去掉图例；oncoplot 把突变频率写在每行右端。
- 多面板共用同一编码时用 `os_compose(..., collect_guides = TRUE)` 合并图例到右侧。

### 7.2 坐标轴标题（统一措辞，模块不得自拟）
| 量 | 标题 |
|---|---|
| log2FC | log<sub>2</sub> fold change |
| −log10 调整 P | −log<sub>10</sub>(adjusted *P*) |
| MA 图 x | Mean of normalized counts（log10 轴，刻度写成 10<sup>n</sup>） |
| PCA | PC1 (42.3% variance)（一位小数） |
| 富集 | Gene ratio / Normalized enrichment score / Enrichment score / Ranked list metric |
| 单细胞 | UMAP 1、UMAP 2（左下角 L 形箭头，无刻度无数字）；Proportion of cells (%) |
| 热图 | Row z-score / Euclidean distance / Pearson r |

- 负数一律用**真正的减号 U+2212（−）**，不用连字符；千分位用逗号（1,000）；小数去掉无意义的尾零（0.5 而非 0.50），但同一轴内精度一致。
- *P* 斜体；基因名斜体（HGNC 惯例）；蛋白、通路、细胞类型名正体。

### 7.3 数据标签（基因名等）
- **火山图、MA 图**用 `os_label_place()`（v1.3.0）：绘制时在真实面板的毫米坐标里、用设备给出的真实文字宽度，按优先级（火山图 -log10 调整 P 从大到小，MA 图调整 P 从小到大）逐个放置；候选位置为以点为中心、每 0.6 mm 一圈、16 个方向（从该点指向面板外侧的方向优先）。**硬约束**：标签之间留 0.7 mm、不压其他被标注的点、引线不穿过已放置的标签或其他被标注的点、标签不压已有引线；**软约束**：尽量少压其余着色点（最多取 300 个最显著的作障碍），引线尽量短（超过 12 mm 就取当前最优）。无随机、无迭代上限，同一输入在任何设备上布局相同；找不到完全空位时取违约最少的位置，标签从不丢弃。引线 0.25 pt 深灰，标签离点不足 1 mm 时不画引线；白色光晕同下。
- 其余图（PCA 样本名、网络图、热图行标注等）仍用 `os_label_repel()`：5.5 pt、ggrepel 固定种子 `20260925`、固定迭代次数 100,000（`max.time` 设为 3600 秒，实际永远用不到，所以布局只由迭代次数决定，与机器快慢无关）、引线 0.25 pt 深灰且**总是**从点出发（`min.segment.length = 0`）、文字带 0.12 行高的白色描边光晕，压在密集点上仍可读。
- 标注哪些基因（确定性规则）：默认每个方向取调整 P 最小的 10 个；并列时按 |log2FC| 大者优先，再按 `feature_id` 字母序。用户给出 `label_genes` 时只标这些，图注写 “Labelled features were pre-specified”。
- 火山图顶部 12% 是“计数带”，标签被限制在它下方，永远不会与计数文字相撞。

### 7.4 长文字
- 通路/GO 名称在 40 字符处按词换行，保留原始大小写（GO 术语本身是小写）。
- 热图行标签只在行高 ≥ 标签字高时显示：`os_save_figure()` 计算每行可用毫米数，不足时给出 `OS_FIG_ROW_LABELS_CROWDED` 警告；列标签同理（`OS_FIG_COL_LABELS_CROWDED`）。默认 ≤60 行显示行名，≤24 列显示列名。

---

## 8. 各图型规范

> 每个函数返回带 `os_meta` 的 ggplot/patchwork 对象；`os_finalize_figure()` 负责质检与保存。下表“默认尺寸”指宽度预设 × 默认高度。

### 8.1 火山图 `os_volcano()`（单栏 × 80 mm，正方形绘图区）
- x = log2FC，范围关于 0 对称并取整（≤2 按 0.5、≤5 按 1、≤12 按 2、以上按 5 取整）；y = −log10(padj)，从 0 起。
- 分类规则：padj < 阈值 且 log2FC > 阈值 → 上调（红）；< −阈值 → 下调（蓝）；其余 NS（灰）；padj 为 NA（独立过滤）的特征**不画**，数量写入图注。
- 虚线：y = −log10(padj 阈值)；x = ±log2FC 阈值（阈值为 0 时不画竖线）。
- padj = 0 的点截断在 y 上限并画成三角。左上角 “● Down: n”，右上角 “Up: n ●”。
- 自动图注示例：*Volcano plot (Treated vs control). Each point is one feature; 3,361 features with an adjusted P value are shown (639 … not shown). Red, up-regulated (n = 184); blue, down-regulated (n = 178); grey, not significant … adjusted P < 0.05 and |log2 fold change| > 1 (DESeq2 Wald test, …). Dashed lines mark these thresholds. The 10 most significant features per direction are labelled.*

### 8.2 MA 图 `os_ma()`（单栏 × 70 mm，绘图区宽高比 4:3）
- 按 DESeq2 `plotMA` 惯例：x 为归一化均值（log10 轴，刻度 10<sup>0</sup>、10<sup>1</sup>…），y 为 log2FC（对称），y=0 实线，可选 ±阈值虚线；超出 y 范围的点画成边界三角。颜色规则同火山图。

### 8.3 样本 PCA `os_pca_scores()` + `os_pca_plot()`（单栏 × 70 mm）
- 计算与 DESeq2 `plotPCA` 等价：方差最大的 500 个特征、中心化、不标准化；**符号规范化**（每个主成分中载荷绝对值最大者取正），跨平台不镜像。
- 两轴同比例（coord_fixed）；若两轴数据范围之比超出 [0.4, 2.5]，改为自由比例 0.75 并在图注写明 “axes NOT on a common scale”。
- 颜色 = 条件（参照组灰），形状 = 第二变量；样本名默认不标（>12 个样本时标签只会造成拥挤），需要时 `label_samples = TRUE`。

### 8.4 热图引擎 `os_heatmap()`（样本距离、Top 基因、模块–性状等共用）
版式固定为：
```
            [ 列树状图           ]                 （仅列聚类时）
            [ 注释条 1          ] 注释名（右侧）
   [行树]   [ 热图主体          ] 行名（右侧，基因斜体）
            [ 列名（下方，竖排 90°） ]              图例统一收在最右
```
- 聚类：欧氏距离 + complete linkage（pheatmap/ComplexHeatmap 默认），写进图注与 figure_spec。
- 格线：≤40×40 时白色 0.25 pt 分隔，更大时不画。
- 单元格内文字（模块–性状）：按底色亮度自动选黑/白字（亮度 < 0.45 用白）。
- Top 基因热图 `os_top_heatmap()`：取 padj 最小的 n 个特征，行 z-score、±2 截断；列先按条件（参照组在前）再按样本名排序、不聚类；行聚类并显示左侧树；默认高 = 30 + 2.2 mm × 行数。
- 样本距离热图 `os_sample_distance()`：Blues 反向，对称聚类，只显示列树与行名。

### 8.5 富集点图 `os_enrich_dotplot()`（单栏 × (22 + 5.2 mm × 条数)）
- 只画 padj < 阈值的集合，按 padj（ORA）或 |NES|（GSEA）取前 15；y 轴按 x 值排列（最大在最上），并列按 padj、再按 term_id。
- x = Gene ratio（从 0 起，约 4 个刻度）或 NES（对称，0 处实线）；颜色 = −log10 padj（viridis）；大小 = 基因数或集合大小，直径 1.0–3.6 mm 固定范围，跨面板可比。
- **选择规则与定义写进图注（v1.1.0）**：图注逐字写出实际执行的规则，例如 ORA：“Selection: the 15 gene sets with the smallest adjusted P among the 20 with adjusted P < 0.05 (ties broken by larger gene ratio, then term ID); ordered by gene ratio, largest at the top (ties by adjusted P, then term ID).”；GSEA 版写 “largest |NES| … (ties broken by smaller adjusted P, then term ID); ordered by NES”。随后写定义：ORA 为 “Gene ratio = input genes in the set / input genes annotated in the database”（clusterProfiler 的 GeneRatio k/n，**不是** GSEA 的 core/setSize）；NES 版为 “NES from preranked GSEA (…)”。同样的文字进 `figure_spec.json → definition`（`selection`、`ordering`、`gene_ratio` 或 `nes`）。
- **没有集合过阈值时**：仍抛出 `OS_EMPTY_DATA`（调用方可捕获），但信息是一句完整的结论：“No gene set reached adjusted P < 0.05 (20 gene sets tested; smallest adjusted P = 0.20).”。同一句话由 `os_enrich_empty_note(et, padj_threshold)` 单独返回，供 QC 清单与 Methods 使用，而不是画一张空图。

### 8.6 NES 条形图 `os_nes_bar()`：每个方向最多 10 条，正红负蓝，0 处黑色实线，y 轴不画轴线与刻度。图注写明选择规则（每个方向按 |NES| 取前 N，并列按 padj、再按 term ID；正负各几条）、排序（按 NES，最大在最上）与 “NES from preranked GSEA”；`definition` 字段同 §8.5；无显著集合时同 §8.5 的 `OS_EMPTY_DATA` 信息。

### 8.7 GSEA 曲线 `os_gsea_curve()`（单栏 × 62 mm，三轨高度比 3 : 0.45 : 1.3）
- 上：running ES（加权 KS，权重 1，与 clusterProfiler/fgsea 默认一致；并列按基因名打破），颜色按方向（正红负蓝），y=0 灰实线，最大偏离位置灰虚线；NES 与 adj. *P*（“3.2 × 10<sup>−6</sup>” 格式）写在峰值一侧的角落。
- 中：命中位置，0.25 pt 黑竖线，外框 0.5 pt。
- 下：排序指标，灰色面积，过零处虚线；x 标题 “Rank in ordered gene list”。

### 8.8 多组富集比较 `os_enrich_compare()`：x = 组、y = 集合（按首次 padj < 阈值的组分块，块内按各组中最小 padj，并列按 term ID），点大小 = gene ratio，颜色 = −log10 padj；x 标签 45°。图注写明：每组按 padj 取前 N（并列按较大 gene ratio、再按 term ID），取并集；行的分块与排序规则；gene ratio 定义。

### 8.9 UMAP / t-SNE `os_embedding()`（单栏 × 80 mm）
- 无坐标轴与刻度，左下角 L 形箭头（长为数据范围 18%）+ “UMAP 1/UMAP 2”（6 pt）。坐标比例固定为数据范围比（不拉伸）。
- 颜色来自登记表；默认把类别名（6 pt、白色光晕）放在各类细胞坐标的中位点并去掉图例；`label = FALSE` 时图例放右侧（>12 类分两列）。

### 8.10 表达 UMAP `os_feature_embedding()`：灰→紫色阶，从 0 到最大值；按表达从低到高绘制；标题为基因名斜体。

### 8.11 Marker 点图 `os_marker_dotplot()`（1.5 栏）
- x = 基因（斜体、竖排 90°、保持调用者给的顺序，通常按簇分块），y = 簇（第一个在最上）；点大小 = 表达细胞百分比（0–100 固定，图例 25/50/75/100）；颜色 = 簇间缩放表达（RdBu，±2 截断）或原始均值（灰→紫）。表达比例为 0 的格子不画点。
- 图注自动加一句：“Markers describe clusters and are not tests of differences between conditions.”（对应 QC 推断类规则）。
- **“平均表达”的定义必须声明（v1.1.0）**：`mean_definition` 是**必填参数、没有默认值**，缺省时报 `OS_MISSING_PARAMETER`，取值不在下表时报 `OS_INVALID_PARAMETER`。函数不计算平均值，只如实声明调用方算的是哪一种；图注逐字写出 “Mean expression definition: …”，`figure_spec.json → definition.mean_expression` 记录代码。

  | `mean_definition` | 图注文字 | 惯用工具 |
  |---|---|---|
  | `log_mean` | mean of log-normalised values | scanpy、SCpubr |
  | `log1p_mean_expm1` | log1p(mean(expm1(x))), the log of the mean of back-transformed values (Seurat convention) | Seurat `DotPlot` |
  | `nonzero_mean` | mean over expressing cells only (cells with non-zero expression) | dittoSeq |

  选哪一种作为模块默认值属于统计选择，由各模块 PACK 裁决，共享层不替模块选。
- **截断色条**：缩放表达在 ±clip（默认 2）截断，色条两端写 “≤−2” / “≥2”（`os_clipped_labels()`，刻度固定为 −clip、−clip/2、0、clip/2、clip）；被截断的点数写进 `counts.clipped_cells`（与热图同名），画出的点数写进 `counts.dots_drawn`；图注写 “values beyond ±2 shown at the limit (k of N dots)”（`os_clip_note()`）。
- **n**：簇的细胞数由 `cluster_n`（命名向量）或 `md$n_cells` 列提供，图注写 “n = 120–1,440 cells per cluster”（§16.3），计数进 `counts.cells_per_cluster`。
- **少于 5 组做 z-score**：`scaled = TRUE` 且簇数 < 5 时，图注加一句 QC：“z-scores are computed across only k clusters; scaling across fewer than 5 groups exaggerates differences.”，`notes.qc_scaled_few_groups` 同步记录（参考 Seurat DotPlot 的同类警告）。
- 默认高度不小于 55 mm，保证簇很少时图例（点大小 + 色条）不被裁掉。

### 8.12 细胞比例堆叠图 `os_proportion_bar()`：每个样本一根柱（宽 0.8），按条件分面（面板宽度随样本数），类别之间白色 0.25 pt 分隔；第一个类别在最上，图例顺序与堆叠顺序一致；y 为 0–100%，刻度 25 一档，从 0 严格起。图注声明“比例是描述性的，组间检验在样本层面另行完成”。**n 上图（v1.1.0）**：分面条带写条件名与样本数——任一条件样本数 < 5 时分三行（“control / n = 3 / samples”，保证窄面板里也不溢出），否则两行（“control / (n = 12 samples)”）；图注写各条件的样本数与 “n = 966–1,068 cells per sample”，并说明每根柱是一个样本（重复单位）；计数进 `counts.samples_per_condition`、`counts.cells_per_sample`。

### 8.13 QC 小提琴 `os_qc_violin()`：每个指标一个面板纵向堆叠、各自坐标轴；计数类指标用 log10 轴但**刻度写真实数值**（300、1,000、3,000）；小提琴等宽、内画中位数横线、阈值虚线；只在最底面板显示样本名。x 轴标签保持样本 ID；图注写样本数与 “n = 477–518 cells per sample”（有分组时再写各组样本数），计数进 `counts.cells_per_sample`。

### 8.14 打分小提琴 `os_score_violin()`：按簇/细胞类型，颜色来自登记表，中位数横线。图注写 “n = 126–1,429 cells per group”，并声明细胞不是独立重复：“Cells are not independent replicates: … differences between groups must be tested at the sample level, not across cells.”；计数进 `counts.cells_per_group`。

### 8.15 模块–性状热图 `os_module_trait()`：r ∈ [−1, 1] 的 RdBu，格内两行 “r / (P)”；P < 0.001 写成 `2e-04` 科学计数；图注注明 P 未校正。

### 8.16 软阈值诊断 `os_soft_threshold()`：左右两面板（R² 与平均连通度），R² 阈值虚线（默认 0.85），选定幂次画红色描边点。

### 8.17 Oncoplot `os_oncoplot()`（双栏）：顶部为每样本变异数堆叠柱；主体灰底 `#EFEFEF`、变异类型固定配色；基因按突变频率排序（斜体、左侧），右侧写百分比；样本按突变模式“瀑布”排序；同一基因多个变异记为 Multi_Hit（黑）；图例在底部左对齐两行。

### 8.18 诊断曲线 `os_diag_xy()`：肘部图、BCV、mean-variance 等通用 x–y 图，黑色线点、可选红色高亮点、参照虚线。

---

## 9. 多面板组合 `os_compose()`

- 一张图一个论断：面板建议 3–5 个；超过 6 个给出 `OS_FIG_TOO_MANY_PANELS` 警告（该领域正文图面板数中位数约 3，>6 通常意味着应拆图或移到补充材料）。
- 单一阅读方向：按行从左到右填充。子图若本身是拼装的（热图、GSEA 曲线），整体只占一个字母。
- 组合图的图注自动拼成 “**a**, <a 的图注> **b**, …”（Nature）或 “(A) … (B) …”（Cell/Science），每段都来自该面板自己的数据，**图注与图不可能不一致**。

---

## 10. 数字与文字格式小结

| 项 | 规则 |
|---|---|
| 负号 | U+2212 “−”（需要 UTF-8 locale；`fig_style.R` 载入时自动切换 LC_CTYPE） |
| 千分位 | 逗号：12,345 |
| P 值（图内） | ≥0.001 两位有效数字（0.012）；<0.001 写成 3.2 × 10<sup>−6</sup>；<10<sup>−300</sup> 写 “<10<sup>−300</sup>” |
| 百分比 | PCA 方差一位小数；比例轴取整 |
| 斜体 | 基因名、*P*、*R*² |
| 语言 | 图内只用英文 |

---

## 11. 每张图附带的 `figure_spec.json`

字段：`schema`、`style_version`、`figure_type`、`journal`、`width_mm`、`height_mm`、`font_family`、`png_dpi`、`files`（相对路径 + sha256）、`caption`（自动图注）、`encodings`（实际用到的每个颜色映射）、`thresholds`、`counts`（上/下调数、截断数、被过滤数、每组 n……）、`data`（被标注的特征 ID、行列顺序、聚类方法……）、`lint`，以及可选的 `definition`（v1.1.0：图上量的书面定义与选择规则，如富集图的 `selection` / `ordering` / `gene_ratio`、marker 点图的 `mean_expression`；构建函数没有设置时该字段不出现）。
- **不含时间戳与绝对路径**，键排序固定 → 逐字节可复现，可直接进入金标准 `golden_manifest.csv`（字节档）。
- 审稿/复核时，这个文件回答了“图上每个颜色是什么意思、阈值是多少、标的是哪些基因、有多少点被截断”。

---

## 12. 质检与错误码

| 代码 | 级别 | 判据 | 处置 |
|---|---|---|---|
| `FIG-01` | blocker | 任何图内文字 < 期刊最小字号 | 拒绝保存（`OS_FIG_LINT_BLOCKER`） |
| `FIG-02` | warning | 单面板离散语义色 > 6（不计灰色、不计连续色阶；UMAP/比例图/oncoplot 等类别图除外） | 拆面板或合并类别 |
| `FIG-03` | warning | 同一面板中由离散色阶映射到**不同类别**的两种颜色，在正常视觉或 deutan/protan/tritan 模拟下 CIEDE2000 < 10（§17） | 换色、直接标注类别名、用形状做冗余编码 |
| `FIG-03` | info | 同上，但只在灰度下接近（< 10） | 只报告；需要黑白印刷时改用明度不同的颜色 |
| `OS_FIG_NON_LATIN_TEXT` | error | 图内出现 CJK 等字体无法渲染的字符 | 改用英文 |
| `OS_TOO_MANY_CATEGORIES` | error | 条件 > 8 或类别 > 23 或形状 > 5 | 分面 / 合并小类 |
| `OS_FIG_TOO_TALL` | error | 高度超期刊最大值 | 拆图 |
| `OS_FIG_ROW_LABELS_CROWDED` / `…COL…` | warning | 标签行高/列宽不足 | 增高、减行或隐藏标签 |
| `OS_FIG_TOO_MANY_PANELS` | warning | 组合图 > 6 面板 | 拆图 |
| `OS_MISSING_COLUMNS` / `OS_EMPTY_DATA` | error | 输入缺列 / 没有可画的行（富集图的信息写明阈值、检验的集合数与最小 padj，见 §8.5） | 检查上游；富集为空时把 `os_enrich_empty_note()` 的句子写进 QC/Methods |
| `OS_MISSING_PARAMETER` | error | 必须显式声明的参数未给（marker 点图的 `mean_definition`；校正后 P 的方法与家族大小） | 显式传入 |
| `OS_INVALID_PARAMETER` | error | 参数值不在允许集合（n 的单位、`mean_definition`、P 不在 [0, 1] …） | 按提示修正 |

---

## 13. 测试与示例画廊

- `Rscript skills/_shared/tests/test_figures.R`：T1 逐字节确定性（13 种图 × PDF/PNG/SVG/spec）、T2 本文件 §14 与代码一致、T3 颜色登记表、T4 错误码、T5 语义（计数、阈值线、标签选择、PCA 符号、减号、面板字母）、T6 卫生（无绝对路径/时间戳、无 Rplots.pdf、.R 文件纯 ASCII）、T7 栅格化、**T8 `ggplot_build` 数值断言**（画出来的数据而不是函数自报的元数据：火山图每个点的颜色等于其类别的 token、阈值线位置/颜色/线型、标注点数、MA 图 y 范围对称、UMAP 每个细胞颜色等于登记表颜色、marker 点图大小映射 0–100% → 0.3–3.2 mm 与截断色条端点标签、NES 柱按符号填色、oncoplot 每个格子颜色等于 `OS_PAL_MUTATION`；热图由热图测试负责）、**T9 色觉**（CIEDE2000 对 Sharma 2005 测试对、模拟函数性质、`FIG-03`、调色板碰撞报告）、**T10 显示契约**（星号边界、P 标签措辞、n 单位、marker 点图定义/截断/少组 QC、富集图选择规则与空结果信息、`definition` 字段）。
- `Rscript skills/_shared/tests/make_figure_gallery.R`：用合成数据渲染全部 31 种单图 + 2 张组合图到 `docs/figure-gallery/`。**任何 token 改动后都必须重新生成并逐张目视检查**（ENGINEERING_PLAN S3：图形审必须亲眼看图）。
- 逐字节一致只在相同“环境签名”（字体文件、cairo/ragg/freetype 版本）下成立；跨环境比较时按 §3.5 显式 SKIP 字节档，不判 FAIL。

---

## 14. 机器校验 token 表（T2 逐行比对 `fig_style.R`，请勿手改为与代码不同的值）

| token | 值 | 含义 |
|---|---|---|
| `font_family_preference` | `Liberation Sans,Arial,Helvetica,sans` | 字体族优先级 |
| `size_tag` | `8` | 面板字母 pt |
| `size_title` | `7` | 面板标题 pt |
| `size_axis_title` | `7` | 轴标题 pt |
| `size_axis_text` | `6` | 刻度标签 pt |
| `size_legend_title` | `7` | 图例标题 pt |
| `size_legend_text` | `6` | 图例文字 pt |
| `size_strip` | `7` | 分面条带 pt |
| `size_annot` | `6` | 图内注释 pt |
| `size_label` | `5.5` | 数据标签 pt |
| `size_min` | `5` | 全局最小字号 pt |
| `lw_axis` | `0.5` | 轴线/刻度 pt |
| `lw_data` | `0.75` | 数据线 pt |
| `lw_ref` | `0.5` | 参照线 pt |
| `lw_segment` | `0.25` | 引线/格线 pt |
| `lw_point_edge` | `0.25` | 点描边 pt |
| `lw_box` | `0.5` | 箱/小提琴外框 pt |
| `ref_linetype` | `22` | 虚线样式 |
| `tick_len_mm` | `1` | 刻度长 mm |
| `pt_dense_mm` | `0.6` | 特征点直径 |
| `pt_cell_mm` | `0.3` | 细胞点直径（1–5 万细胞） |
| `pt_sample_mm` | `2.2` | 样本点直径 |
| `pt_highlight_mm` | `0.9` | 被标注点直径 |
| `shape_dense` | `16` | 特征/细胞点形状 |
| `shape_sample_sequence` | `21,24,22,23,25` | 第二变量形状序列 |
| `shape_capped` | `17` | 截断值形状 |
| `col_ink` | `#000000` | 文字与轴 |
| `col_ref` | `#7F7F7F` | 参照线 |
| `col_ns` | `#BDBDBD` | 不显著 |
| `col_na` | `#D9D9D9` | 缺失/未分配 |
| `col_reference_group` | `#666666` | 参照组 |
| `col_point_edge` | `#FFFFFF` | 样本点描边 |
| `col_segment` | `#4D4D4D` | 标签引线 |
| `col_bg` | `#FFFFFF` | 背景 |
| `col_up` | `#B2182B` | 上调/正 |
| `col_down` | `#2166AC` | 下调/负 |
| `legend_key_mm` | `3` | 图例键尺寸 |
| `plot_margin_mm` | `2,2,2,2` | 面板外边距 上右下左 |
| `label_wrap_chars` | `40` | 长名称换行字符数 |
| `max_categories` | `23` | 类别色上限 |
| `max_semantic_colours_panel` | `6` | FIG-02 阈值 |
| `png_dpi` | `600` | PNG 分辨率 |
| `raster_threshold_points` | `50000` | 超过该点数，点图层栅格化 |
| `raster_dpi` | `600` | 栅格化点图层的分辨率 |
| `p_star_cutpoints` | `0.05,0.01,0.001,0.0001` | 星号分界（§16.1） |
| `p_star_symbols` | `*,**,***,****` | 依次对应 p < 0.05、< 0.01、< 0.001、< 0.0001 |
| `p_star_ns` | `ns` | 不低于 0.05 时的符号 |
| `p_star_rule` | `p < cutpoint` | 区间规则：严格小于（p = 0.05 为 ns） |
| `p_display_default` | `adjusted` | 图上默认显示多重校正后的 P |
| `n_units` | `samples,cells,features,gene sets` | n 允许的单位词（§16.3） |
| `cvd_simulations` | `deutan,protan,tritan` | FIG-03 使用的色觉缺陷模拟（Machado 2009） |
| `cvd_severity` | `1` | 模拟严重度（完全二色视） |
| `cvd_delta_e_metric` | `CIEDE2000` | 色差公式 |
| `cvd_delta_e_min` | `10` | FIG-03 阈值：不同类别两色的最小色差 |
| `os_pal_group` | `#D55E00,#0072B2,#009E73,#E69F00,#CC79A7,#56B4E9,#F0E442` | 条件色（参照组除外） |
| `os_pal_category` | `#0072B2,#D55E00,#009E73,#CC79A7,#E69F00,#56B4E9,#882255,#44AA99,#332288,#999933,#AA4499,#117733,#CC6677,#DDCC77,#88CCEE,#BE0032,#8DB600,#654522,#F99379,#604E97,#C2B280,#2B3D26,#F0E442` | 类别色 |
| `os_pal_diverging` | `#2166AC,#4393C3,#92C5DE,#D1E5F0,#F7F7F7,#FDDBC7,#F4A582,#D6604D,#B2182B` | 发散色阶 |
| `os_pal_sequential` | `#440154,#482878,#3E4A89,#31688E,#26828E,#1F9E89,#35B779,#6DCD59,#B4DE2C,#FDE725` | 顺序色阶（viridis） |
| `os_pal_expression` | `#E5E5E5,#CBC9E2,#9E9AC8,#756BB1,#54278F,#3F007D` | 表达色阶 |
| `os_pal_distance` | `#08306B,#08519C,#2171B5,#4292C6,#6BAED6,#9ECAE1,#C6DBEF,#DEEBF7,#F7FBFF` | 距离色阶 |

变异类型固定色（`OS_PAL_MUTATION`）：Missense `#1B9E77`、Nonsense `#D95F02`、Frame_Shift_Del `#7570B3`、Frame_Shift_Ins `#E7298A`、In_Frame_Del `#66A61E`、In_Frame_Ins `#E6AB02`、Splice_Site `#A6761D`、Translation_Start_Site `#666666`、Nonstop `#1F78B4`、Multi_Hit `#000000`。

---

## 15. 已知限制与待裁决

1. **超大单细胞数据的矢量 PDF（2026-09-26 已裁决）**：点数 > 50,000 时，`os_points_layer()` 用 ggrastr（环境 L7 层）把**仅点图层**渲染为 600 dpi 位图嵌入 PDF，文字、坐标轴、图例、标签仍是可编辑矢量；图注自动加一句 “Cells are rendered as a 600 dpi bitmap layer; text and axes are vector.”，`figure_spec.json → notes.rasterised_points = true`。缺少 ggrastr 时保持矢量并给出 `OS_FIG_RASTER_UNAVAILABLE` 警告。测试 T7 覆盖。
2. **期刊尺寸**为常见公开值，未在运行时核对；投稿前核对并按需新增预设。
3. **热图**用 ggplot2 自建引擎，而不是 ComplexHeatmap：优点是与其余图共用同一主题与 token、可逐字节复现；代价是暂不支持行注释条与切分（split）。若 PACK F 节显示某模块的范本普遍需要这些功能，再在 `_shared` 扩展。
4. **字节级一致**依赖字体与图形库版本：在 omicstat-r 容器（`env/omicstat-env.json` 锁定的镜像，含 fonts-liberation、ragg、cairo）内保证；`env/native/` 的原生隔离环境与容器之间只保证“视觉一致”，字节档按 §13 显式 SKIP。
5. 各模块的 PACK **F 节（图形语法）**完成后，若范本多数派与本规范冲突（例如某领域惯用 t-SNE 而非 UMAP、火山图 y 用原始 P），以 S1 裁决为准：优先通过参数实现（如 `os_volcano(y = "pvalue")` 类选项），并在图注中自动披露，而不是在模块里另写一套样式。

---

## 16. 统计标注：P 值与 n（v1.1.0，共享契约）

> 这一节只规定**怎么显示**。用哪种检验、校正方法和家族如何划定是统计选择，由各模块按 PACK 证据裁决；共享层只保证：无论模块选了什么，图上与图注都用同一种写法、并且不可能省略校正状态。

### 16.1 星号

| P 值 | 符号 |
|---|---|
| p < 0.0001 | `****` |
| 0.0001 ≤ p < 0.001 | `***` |
| 0.001 ≤ p < 0.01 | `**` |
| 0.01 ≤ p < 0.05 | `*` |
| p ≥ 0.05 | `ns` |

- **区间开闭**：一律“严格小于”（token `p_star_rule = p < cutpoint`）。p 恰好等于 0.05 标 `ns`，0.0499 标 `*`；每个分界点同理。这与 ggsignif 一致，而与 rstatix/ggpubr 的 `symnum`（右闭，p = 0.05 标 `*`）不同——我们选择严格规则，是因为“显著”在全系统的定义就是 padj **<** 阈值（§8.1 的分类规则）。
- `os_p_stars(p)`：向量化；NA 输入返回 NA（调用方不画任何符号）；P 不在 [0, 1] 报 `OS_INVALID_PARAMETER`。
- 图注必须说明星号对应哪一种 P（校正后或未校正）以及上表的分界（可直接引用本节）。

### 16.2 文字标签 `os_p_label()`

- 默认显示**校正后**的 P（token `p_display_default = adjusted`，对应 ggprism 优先 p.adj 的做法；反例是 ggpubr `geom_pwc` 计算了 Holm 却默认显示原始 P）。
- 图注形式（`form = "caption"`）：`检验; 校正方法-adjusted P = 值 (family of k comparisons)`，例如 “Wilcoxon rank-sum test; Holm-adjusted P = 0.012 (family of 6 comparisons)”。
- 图内短形式（`form = "short"`）：“adj. P = 0.012”。
- `adjusted = FALSE` 时文字**必须**含 “unadjusted”：图注 “Wilcoxon rank-sum test; unadjusted P = 0.012 (family of 6 comparisons; no multiplicity adjustment)”，短形式 “unadjusted P = 0.012”。
- 校正后的 P 缺少校正方法或家族大小时报 `OS_MISSING_PARAMETER`（不允许“校正了但不说怎么校正”）。方法代码 `holm`、`bonferroni`、`hochberg`、`hommel`、`BH`/`fdr`、`BY`、`tukey`、`dunnett` 会写成全名（Benjamini–Hochberg 等），其余按原文输出。
- 数值格式同 §10：≥ 0.001 两位有效数字；< 0.001 写 “3.2 × 10^−6”；< 10^−300 写 “P < 10^−300”；NA 写 “P = NA”。

### 16.3 n 与它的单位

- 凡是比较组的图，图注都写 n **和单位**；空间允许时轴标签或分面条带也写。单细胞图里 “n” 可能是细胞也可能是样本，而只有样本是独立重复，所以单位不能省。
- `os_n_label(n, unit, per = NULL)`：单位必须是 `samples`、`cells`、`features`、`gene sets` 之一（token `n_units`），否则 `OS_INVALID_PARAMETER`；n = 1 时用单数（“n = 1 sample”）；向量给出范围（“n = 120–2,400 cells per sample”，en dash，千分位逗号）。
- 当前落实：比例图条带 “control / n = 3 / samples”（§8.12）；QC 小提琴图注每样本细胞数范围（§8.13）；PCA 图注样本数（§8.3）；marker 点图图注每簇细胞数范围（§8.11）；打分小提琴图注每组细胞数范围 + “细胞不是独立重复”（§8.14）。

## 17. 色觉缺陷 lint（`FIG-03`）

- **模拟**：Machado, Oliveira & Fernandes (2009, IEEE TVCG 15:1291–1298) 的严重度 1.0 矩阵（deuteranopia、protanopia、tritanopia；与 colorspace::simulate_cvd 所用数值相同），在**线性** sRGB 上相乘、截断到 [0, 1] 再做 gamma 编码。矩阵直接写在 `fig_style.R` §17，不依赖外部包。灰度用 Rec. 709 相对亮度 Y = 0.2126 R + 0.7152 G + 0.0722 B（线性 RGB）。
- **色差**：CIEDE2000（Sharma, Wu & Dalal 2005），在 CIE L\*a\*b\*（D65）上计算，**不是** ΔE76；实现与 Sharma 等人的测试数据一致（T9）。
- **规则**：lint 取每个面板中由**离散**颜色/填充色阶映射到类别的颜色（注释文字、参照线这类常量颜色不算），两两比较：
  - 正常视觉或任一模拟下 ΔE00 < 10 → `FIG-03` warning，信息列出最接近的 5 对（颜色、模拟类型、ΔE）；
  - 只在灰度下 ΔE00 < 10 → `FIG-03` info（只报告）。
- **阈值 10 的依据**：这是一个筛查用的设计阈值，不是心理物理学标准。大色块的最小可觉差约为 ΔE 1–2，而数据图里的点、细柱很小，小尺寸标记需要数倍的色差才能可靠区分（Stone, Szafir & Setlur 2014, “An engineering model for color difference as a function of size”）。取 10 能让 Okabe–Ito 条件色前 4 色在三种模拟下全部通过（最接近的一对是 tritan 下蓝/蓝绿 12.1、deutan 下朱红/橙 12.5），同时抓住类别调色板中真正难分的颜色对。修改阈值属于 token 变更，按 §0 的变更规则处理。
- **测试中的调色板结论（T9）**：
  - 判 FAIL 的：`OS_PAL_GROUP` 前 4 色、参照灰与这 4 色、上调/下调/NS 三色，在正常视觉与三种模拟下必须两两 ≥ 10——当前全部通过。
  - 只报告的：`OS_PAL_CATEGORY` 23 色在模拟下有若干对 < 10（例如 `#E69F00`/`#8DB600` protan 2.1、`#F99379`/`#C2B280` deutan 2.5），所以类别图依赖直接标注与固定图例顺序，类别数多时 `FIG-03` warning 属于预期。
  - 上调红 `#B2182B` 与下调蓝 `#2166AC` 的明度几乎相同（灰度 ΔE00 ≈ 3.7），黑白印刷时无法靠颜色区分；火山图、MA 图、NES 柱中方向同时由位置（x 或 y 的符号）编码，所以只作 info 报告。

## 18. 扩展图型

> 本节是对 §8 的扩展，覆盖 `plotting-software-survey.md` 改进清单第 11、12、14、19 项：热图的注释条、分块与部分行标注，单细胞的堆叠小提琴、ridge、高亮单群、冲积图、群聚类树 + 点图、密度 UMAP，以及富集网络（cnet、emap、术语树、多集 GSEA 曲线）。代码在 `fig_heatmap.R`、`fig_sc_extra.R`、`fig_enrich_network.R`，经 `fig_all.R` 一次载入；测试为 `tests/test_figures_ext.R`（确定性、lint、编码断言、错误码、向后兼容）。
> 所有扩展图型沿用 §3–§7 的 token（`OS_FIG`、`OS_PAL_*`）、颜色登记表、`os_label_repel()` 与自动图注；只用 ggplot2 / grid / patchwork / stats / MASS 实现（不依赖 ggalluvial、ggridges、igraph、ggraph、Nebulosa）。**不使用随机数**：所有布局都是闭式构造或固定迭代次数的确定性算法，同一输入重跑时 PNG/SVG/figure_spec 逐字节相同。
> 扩展图型自己的视觉常量放在 `OS_FIG_EXT`（见 16.4），**不进入 §14 的机器校验表**；测试 E6 检查 `OS_FIG_EXT` 的每个键都在本节出现。

### 18.1 热图引擎扩展 `os_heatmap()`（新增参数全部默认关闭，旧调用行为不变）

版式（在 §8.4 的基础上）：
```
                     [ 列分块标题（条带，上方）            ]
                     [ 列树状图（每个列分块各自一棵）       ]
                     [ 列注释条 1..k                     ] 注释名（右侧）
   [行分块标题][行树] [行注释1][行注释k] [ 热图主体（分块之间 1 mm 间隔） ] 行名 或 mark_rows 标签 + 引线
    （左侧竖排）       注释名（下方，竖排 90°）[ 列名（下方，竖排 90°） ]          图例统一收在最右
```
- **行注释条** `row_annot`：data.frame（行名 = 矩阵行名，每列一条），画在行树与主体之间，每条宽 `annot_track_mm`（2.5 mm）；注释名写在条的**下方**、竖排 90°，与列名同一基线。颜色优先用 `annot_colours[[名]]`，否则取颜色登记表（family = 注释名，可传 `colour_registry`），图例顺序为因子水平或 C-locale 字母序（不是出现顺序）；缺失值为 `col_na`。列注释条同样可以回落到登记表。
- **分块** `row_split` / `col_split`：可给按行（列）名命名的向量，或按矩阵顺序的无名向量；因子水平即分块顺序，否则按字母序。分块之间留 `split_gap_mm`（1 mm）空隙；**聚类在每个分块内部分别进行**（欧氏距离 + complete，每块少于 3 行则保持输入顺序），各块树状图共用同一高度刻度。分块标题用 7 pt 条带文字：列块标题在最上方（列树之上），行块标题在最左侧、逆时针竖排。figure_spec 记录 `row_slices` / `col_slices`（各块大小），`clustering` 写为 “euclidean/complete within slices”。
- **部分行标注** `mark_rows`（ComplexHeatmap `anno_mark` 式）：行太多、无法全部标名时，只在右侧标出给定的行，标签由 `os_label_repel()` 沿纵向排开（固定种子），0.25 pt 深灰引线从热图右缘出发；此时不再画整列行名（`show_row_labels` 被忽略），列注释名移到标签列顶部，使引线紧贴热图。标签列宽度 = `mark_lead_mm`（引线区 3.5 mm）+ 标签字宽。figure_spec 记录 `marked_rows`（按显示顺序）。
- **截断色条**：`scale_type = "diverging"` 且给了 `clip`（色阶范围即 ±clip）时，色条两端刻度写成 “≤−2”“≥2”（`os_clipped_labels()`），`encodings.fill.clipped_end_labels = true`；未截断的色条保持普通刻度。
- **行树方向修正**：行树的叶子自上而下与热图行一一对应（此前行树在竖直方向是镜像的；只影响画法，不影响聚类结果与行序）。拼图用的空白格不再带默认 5.5 pt 边距，因此行树与热图之间不再有约 2 mm 的空隙。
- **叠加热图的行一致性** `os_heatmap_check_rows(list(expr = m1, score = m2))`：多张热图左右拼接、共享行轴之前调用；行集合不同或行序不同都会报 `OS_FIG_ROW_MISMATCH`（信息中给出第一处差异），全部一致时返回共享的行 ID。
- 图注：沿用各调用者（如 `os_top_heatmap()`）的图注；分块与标注信息写入 figure_spec。

### 18.2 单细胞扩展图型（`fig_sc_extra.R`）

输入均为普通 data.frame / 矩阵（与 Seurat、SCE 无关）；群的颜色一律来自颜色登记表（与 UMAP、比例图相同）。

**堆叠小提琴 `os_stacked_violin(expr, groups, genes)`**（1.5 栏 × (18 + 6.5 mm × 基因数)）
- 每行一个基因（顺序同调用者，斜体基因名在左侧，水平书写），每列一个群（x 轴下方，竖排 90°），所有行共用 x；每个“基因 × 群”格一个小提琴，`scale = "width"`（各小提琴等宽，形状只表示分布），0.25 pt 黑色轮廓。
- 每行有自己的 y 轴（右侧，5 pt、Cell 预设 6 pt），只标一个刻度：≤ 该行最大值 85% 的最大“整齐”数值，以免读成相邻行的刻度；行与行之间无空隙，外加 0.25 pt 细框。
- **填充默认 `fill = "median"`**：每个小提琴按该基因在该群的中位表达着色（灰→紫 `OS_PAL_EXPRESSION`，全图统一 0..最大值）——群身份已由 x 轴给出，颜色用于表达量级（scanpy `stacked_violin` 惯例），也不会触发 FIG-02。`fill = "group"` 时用登记表中的群颜色（与 UMAP 一致；> 6 群时会得到 FIG-02 颜色数警告）。
- 图注写明基因数、群数、细胞数、小提琴等宽与填充含义；figure_spec 记录每格中位数。

**Ridge 图 `os_ridge(values, groups, feature)`**（单栏 × (22 + 7 mm × 组数)）
- 自行计算密度（不用 ggridges）：高斯核 `stats::density`，**所有组共用一个带宽 = 合并数据的 `bw.nrd0`（Silverman 经验法则）**，在覆盖数据范围的公共网格（`ridge_grid_n` = 512 点）上求值，因此各组形状可比；所有 ridge 共用一个高度刻度，最高的 ridge 为 `ridge_height`（1.6 行，允许轻微重叠）。
- 第一组在最上；自上而下逐个绘制，下方的 ridge 盖住上方的尾部；每条 ridge 有 0.25 pt 基线和中位数竖线；组名在 y 轴、贴基线。填充 = 登记表颜色（`fill = "none"` 时为 `col_ns`）。少于 2 个细胞的组不画，图注列出。图注给出带宽数值与规则。

**高亮单群 `os_highlight_embedding(emb, group_col, target)`**（单栏 × 80 mm）
- 目标群（可多个）用登记表颜色、**画在上层**；其余细胞一律 `col_ns` 灰、画在下层；坐标轴、点大小、栅格化规则同 §8.9。目标群名写在其细胞中位点（6 pt，白色光晕）。图注给出每个目标群的细胞数与百分比。

**冲积 / 桑基图 `os_alluvial(df, axes = c("cluster", "celltype"))`**（单栏 × 80 mm；≥ 3 个轴时建议 1.5 栏）
- 每个轴一列方框（宽 `alluvial_box_width` = 轴间距的 8%），方框高 = 细胞数，方框之间留 `alluvial_gap_frac`（细胞总数的 3%）空隙，各轴纵向居中。轴名在上方（7 pt）。
- 方框顺序：第一个轴按因子水平 / 字母序；之后的轴若是因子则按水平，否则按**重心**（其细胞在前一轴上位置的均值，自上而下降序，并列按名称）排序，以减少不必要的交叉，图注注明。缺失注释记为 “Unassigned”（灰，放最后）。
- 连接带：每个（第一轴类别，左类别，右类别）组合一条多边形，宽 = 细胞数，上下边为 smoothstep 曲线（3t² − 2t³，`alluvial_curve_n` 点）；**颜色 = 第一轴（源）类别的登记表颜色，并贯穿后续所有轴**；第一轴方框同色，其余轴方框为白底黑框（两个登记表家族的颜色不会在同一面板里混用）。不透明、无 alpha、无白边；按细胞数从大到小绘制，小流在上层保持可见。
- 标签 “名称 (n)”（6 pt，千分位）：第一轴在左、最后一轴在右（各自独立的标签列，`os_label_repel()` 纵向排开，短引线指向方框），中间轴居中压在方框上（白色光晕）；占比 < `label_min_frac`（默认 1%）的类别不标，数目写入图注。figure_spec 记录各轴方框顺序、计数和每条流（源、左、右、n）。

**群聚类树 + 点图 `os_cluster_tree_dotplot(md, gene_order, profiles = NULL, mean_definition)`**（1.5 栏；高度同 §8.11；`mean_definition` 必填，原样传给 marker 点图并写进图注，见 §16）
- 群的平均表达谱（默认取 `md` 的 avg_exp 矩阵，即所画基因；也可传入群 × 特征矩阵，如高变基因均值）做欧氏距离 + complete 层次聚类；点图的群顺序 = 叶序（第一个叶在最上）。
- 右侧点图就是 `os_marker_dotplot()` 的原样输出（`fig_sc.R` 未改动）；树状图（0.25 pt 黑线，宽 `tree_width_mm` = 10 mm）用 patchwork 放在群名左侧，叶子与点图各行精确对齐。图注 = 聚类说明 + 点图原图注（含 “Markers describe clusters…”）。

**密度 UMAP `os_density_embedding(emb, values, feature)`**（单栏 × 70 mm）
- 二维高斯核密度，公式与 `MASS::kde2d` 完全相同（每轴带宽 `MASS::bandwidth.nrd`，核标准差 = 带宽/4，网格 `kde_grid_n` × `kde_grid_n` = 100 × 100、覆盖数据范围），但**每个细胞按表达量加权**（负值按 0）；`values = NULL` 时权重全为 1，结果与 `MASS::kde2d` 逐元素相等（测试 E3）。
- 每个细胞的密度由网格双线性插值得到，显示为相对密度（最大 = 1，viridis `OS_PAL_SEQUENTIAL`）；按密度从低到高绘制。标题为基因名斜体；图注写出两个带宽数值与非零表达细胞数。
- 双基因 blend 暂未实现。

### 18.3 富集网络（`fig_enrich_network.R`）

输入：富集表 `et`（§8.5 的列）+ `gene_sets`（命名 list：term_id → 基因；ORA 为输入基因中属于该集合者，GSEA 为 core enrichment 基因）。选词规则统一：padj < 阈值且有基因集的条目，按 padj、再按 term_id 排序，取前 `top_n`。

**基因–概念网络 `os_cnet(et, gene_sets, fc, top_n = 5)`**（1.5 栏 × 89 mm）
- 闭式布局：选中的集合放在内圆（半径 1，第一个在 12 点方向，按 padj 顺时针；只有一个集合时放圆心）；每个基因的目标角度 = 其所属集合角度的圆均值；基因按目标角度排序（并列：所属集合多者在前，再按名称）后**等角距**放在外环（半径 = `cnet_ring_ratio` × 内圆），整体旋转到与目标角度的圆均值偏差最小——同一集合的基因聚成一段弧、共享基因落在两集合之间，节点永不重叠。
- 基因节点：21 号可填充圆（直径 `cnet_gene_mm`），填充 = log2FC（RdBu，范围关于 0 对称，`os_sym_limit`），无 FC 时为 `col_ns`；集合节点：白底黑框空心圆，直径随集合内基因数在 `cnet_set_mm` 范围内变化；连线 0.25 pt `col_ns`，画在最下层。
- 标签：基因名斜体 5.5 pt，沿径向向外偏移后用 `os_label_repel()` 排开；基因多于 `cnet_max_labels`（40）时优先标共享基因，再按 |log2FC|、名称；集合名（6 pt，`net_term_wrap` = 24 字符换行）向圆心方向偏移。图注写明集合数、基因数、标注规则。

**富集图 `os_emap(et, gene_sets, top_n = 30)`**（1.5 栏；默认高度随布局纵横比在 70–170 mm 之间取值）
- 相似度 = Jaccard 指数（共享基因 / 两集合并集，`os_jaccard()`）；J ≥ `emap_jaccard_cutoff`（0.2，enrichplot 默认）时连边，边宽随 J 在 `emap_edge_pt`（0.25–1.5 pt）内变化，颜色 `col_ns`。
- 布局：对 1 − J 做经典多维标度（`stats::cmdscale`，k = 2），**符号规范化**（每一维中绝对值最大的坐标取正，`os_mds_signed()`），再做确定性去重叠（`layout_sweeps` = 200 次固定扫描，距离小于 `emap_min_dist`（图宽的 20%）的节点对沿连线对称推开，重合点按下标给定方向）。坐标无单位，不画坐标轴，图注说明。
- 节点：填充 = −log10 padj（viridis），直径随基因数在 `emap_node_mm` 内变化，0.25 pt 黑边；术语名 5.5 pt 正体、24 字符换行，`os_label_repel()` 排布。figure_spec 记录每个节点坐标、边数与孤立节点数。

**术语树 `os_term_tree(et, gene_sets, top_n = 30, n_clusters = 4)`**（1.5 栏 × (18 + 4.4 mm × 条目数)）
- 1 − Jaccard 距离、`ward.D` 连接（enrichplot treeplot 默认）的层次聚类，切成 `n_clusters` 簇；簇**按叶序编号**（最上面的叶属于 Cluster 1），颜色依次取 `OS_PAL_CATEGORY`；某分支下所有叶属于同一簇时该分支取簇色（0.75 pt），跨簇分支为黑色。
- 根在左、叶在右；每个叶处一个点（填充 −log10 padj，直径随基因数在 `tree_leaf_mm` 内变化），术语名在右侧（6 pt、40 字符换行）。图例：显著性色条、基因数、簇颜色。

**多集 GSEA 曲线 `os_gsea_multi(stats, sets, nes, padj)`**（单栏 × (72 + 6 mm × 集合数)）
- 每个集合的 running ES 直接来自 `os_gsea_running_score()`（加权 KS，权重 1，并列按基因名），与 §8.7 单集曲线数值一致；一集一线（0.75 pt），颜色取登记表（family `gene_set`）；最多 `gsea_multi_max`（6）个集合，超过报 `OS_TOO_MANY_CATEGORIES`（颜色数上限，拆面板）。
- 三轨：上为 running ES（y = 0 灰实线）；中为命中位置，每集一行、自上而下与图例同序、同色；下为排序指标灰色面积与过零虚线。
- 图例放在**底部左对齐、每集一行**（与 §7.1 的“右侧”不同，因为每项都带统计量）：“集合名 (NES = 2.61, adj. *P* = 3.2 × 10<sup>−6</sup>)”。图注逐集列出列表中命中基因数、NES 与校正 P。

### 18.4 扩展常量 `OS_FIG_EXT`（不属于 §14 机器校验表）

| 常量 | 值 | 含义 |
|---|---|---|
| `split_gap_mm` | 1 | 热图分块间隔 mm |
| `annot_track_mm` | 2.5 | 行注释条宽 mm |
| `mark_lead_mm` | 3.5 | mark_rows 引线区宽 mm |
| `violin_width` | 0.85 | 堆叠小提琴宽（占一个群位的比例） |
| `ridge_height` | 1.6 | 最高 ridge 的高度（行单位） |
| `ridge_grid_n` | 512 | ridge 密度求值点数 |
| `alluvial_gap_frac` | 0.03 | 冲积图方框间隔（占细胞总数比例） |
| `alluvial_box_width` | 0.08 | 冲积图方框宽（轴间距 = 1） |
| `alluvial_curve_n` | 48 | 每条流边缘曲线的点数 |
| `tree_width_mm` | 10 | 群聚类树宽 mm |
| `kde_grid_n` | 100 | 密度 UMAP 网格边长 |
| `net_term_wrap` | 24 | 网络图中术语名换行字符数 |
| `cnet_set_mm` | 2.4–5.2 | cnet 集合节点直径范围 mm |
| `cnet_gene_mm` | 1.6 | cnet 基因节点直径 mm |
| `cnet_ring_ratio` | 2.1 | cnet 基因外环半径 / 集合内圆半径 |
| `cnet_max_labels` | 40 | cnet 最多标注基因数 |
| `emap_node_mm` | 1.6–5.0 | emap 节点直径范围 mm |
| `emap_edge_pt` | 0.25–1.5 | emap 边宽范围 pt |
| `emap_jaccard_cutoff` | 0.2 | emap 连边阈值（Jaccard） |
| `emap_min_dist` | 0.2 | emap 去重叠后的最小节点间距（图宽 = 1） |
| `layout_sweeps` | 200 | 去重叠的固定扫描次数 |
| `tree_leaf_mm` | 1.0–3.6 | 术语树叶点直径范围 mm |
| `gsea_multi_max` | 6 | 多集 GSEA 单面板最多集合数 |

- 新图型的 `figure_type`：`stacked_violin`、`ridge`、`highlight_embedding`、`alluvial`、`cluster_tree_dotplot`、`density_embedding`、`cnet`、`emap`、`term_tree`、`gsea_multi`（热图扩展仍为 `heatmap` 或调用者的类型）。
- 新错误码：`OS_FIG_ROW_MISMATCH`（叠加热图行集合或行序不一致）；其余沿用 §12（`OS_INVALID_PARAMETER`、`OS_MISSING_COLUMNS`、`OS_EMPTY_DATA`、`OS_TOO_MANY_CATEGORIES`、`OS_FIG_NON_LATIN_TEXT`）。
- lint：扩展图型在 nature 与 cell 预设下均无任何 lint 发现（测试 E2）；`os_stacked_violin(fill = "group")`、`os_ridge()`、`os_alluvial()` 在类别 > 6 时会按 §12 得到 FIG-02 警告（这是提示，不阻止保存）。
- 测试：`Rscript skills/_shared/tests/test_figures_ext.R`（E1 确定性、E2 lint、E3 编码断言、E4 错误码、E5 旧调用兼容、E6 卫生）。

## 19. 模块自建图型（`fig_mod_*.R`，MODULE_BUILD_BRIEF 第 4 节）

> M1/M2 各模块新增的图型，按模块分节；代码在 `fig_mod_bulk.R`（bulk）/ `fig_mod_enrich.R`（enrichment），`fig_all.R` 最后加载，因此可以调用 `fig_bulk.R` / `fig_compose.R` 等已有 builder。同样只用 §3-§7 的 token，不新增视觉常量。

### 19.1 sva-batch

**Before/after PCA 对比 `os_batch_pca_pair(mat_before, mat_after, coldata, colour_col, shape_col, ntop, colour_registry, journal)`**（PACK F 第一行；SUITE 批次跨模块规则 7）
- 复用 `os_pca_scores()` + `os_pca_plot()` 各画一次（原始矩阵 / 校正后展示矩阵），用 `os_compose(ncol = 2)` 拼成一张两联图；`colour_col` 编码已知 `--batch`（combat / combat_seq）或（无已知 batch 时）保护的研究变量，`shape_col` 编码另一个可用的分类分组；两者都必须是模块层已经离散化好的分类列（连续研究变量的分桶发生在 `sva_batch_report.R`，不在共享图形层，避免共享 builder 悄悄发明新的统计口径）。
- 每个面板标题为 “Before correction (display only)” / “After correction (display only)”；整体标题与 `os_compose()` 的自动图例强调“展示用途、不用于组间检验”（SUITE 规则 7：批次校正 scores 只作展示）。`figure_type` 沿用 `os_compose()` 的 `"composite"`（每个子面板仍各自携带 `"pca"`）。
- **未实现**：PACK F 第二行的 ComBat prior 密度图（`ComBat(prior.plots = TRUE)`，核密度 vs 参数估计的批次效应）——该图由 `ComBat()` 自身用 base R 图形绘制，与本仓库“图只能通过 `fig_*.R`/ggplot 生成”的规范冲突，重新实现其密度估计超出 S2 范围；已记入 sva-batch 的已知限制，留待需要时再扩展 `fig_mod_bulk.R`。

## 19.2 deseq2-lrt trajectory

`os_lrt_trajectory()` in `fig_mod_bulk.R` displays normalized count + 0.5 on a log10 axis for the top LRT-significant genes, faceted by gene. Points are samples and lines are means at each time value within the supplied group. The figure is exploratory: joint significance comes from the LRT, and each facet has its own y scale. Colours, point size, line width and journal layout use shared style tokens. Its caption names the number of genes, time and group fields, and the normalization/pseudocount.

## 19.3 edger-qlf MD plot

`os_md_edger()` in `fig_mod_bulk.R` uses average log2 counts per million (`topTags` `logCPM`) directly on the x axis and contrast log2 fold change on y. Colours encode BH significance and direction; the caption records the selected QLF/glmTreat method, FDR and any prespecified minimum-effect threshold. The shared `log2cpm` axis token and other style tokens control the appearance. The BCV diagnostic uses the existing `os_diag_xy()` builder with tagwise BCV points and the common-BCV reference line.

## 19.4 Limma differential expression (M1b)

`fig_mod_bulk_limma.R` supplies the three limma modules with a volcano plot and a mean-difference plot. The former uses the shared volcano builder with BH threshold and no post hoc fold-change gate; the latter places log2 fold change against average log2 expression. Both captions state the contrast, method, number of features and adjusted-P threshold. Publication constants and journal presets come from `fig_style.R`.

The MD builder draws all features at the shared dense-point size, with significant up/down points in the shared red/blue palette. It avoids enlarged highlights when thousands of features are significant; the caption reports each count and BH cutoff.

## 19.5 clusterprofiler-ora

`os_cp_ora_dotplot()` delegates to the shared enrichment dot plot. The caption records the GO ontology, BH threshold, number of significant and displayed terms, gene-ratio definition, ordering and encodings. No figure is emitted when there are no terms below the requested threshold.

## 19.6 clusterprofiler-gsea

The M2 wrapper delegates to `os_enrich_dotplot(x = "nes")` and `os_gsea_curve`. Both use the shared palette and caption machinery; the dot plot reports the BH threshold, the number significant and the number shown. The curve identifies the leading GO set, its NES, adjusted P, ranked genes and hit count.

## 19.7 clusterprofiler-compare

For identical eligible universes, `os_cp_compare_dotplot()` uses the shared comparison dot plot. Its caption states BH 0.05, the number of lists, the selected-term count and that no between-list enrichment test was performed. When backgrounds differ, the module writes separate ORA tables and no comparison figure.

## 19.8 fgsea-prerank (M2b)

`fig_mod_enrich_rank.R` 调用既有 `os_nes_bar`（每方向前 5 个显著集合）与 `os_gsea_curve`（BH 排序第一的显著集合）；图形仅使用共享样式 token。显示名去掉演示数据数字前缀、下划线换空格，长名截短；完整 ID 与名称保留在主表和 figure_spec。NES 图 caption 标出 BH 阈值、显著集合数与展示数；曲线 caption 标出排名基因数、集合交集大小、BH 阈值。两张图由 `os_finalize_figure` 执行 lint。无显著集合时只输出全表和 QC，不制造图。

## 19.9 gsva-score (M2b)

`fig_mod_enrich_rank.R` 的 `os_gsva_score_heatmap()` 调用共享 `os_heatmap()`。展示方差最高的至多 20 个集合和每组按样本 ID 排序的前 6 个样本（总数最多 24）；原始全分数矩阵另存，不以展示选择做推断。图中每行在展示样本上 z 标准化；样本组别为注释条。caption 写清展示数、全数、ID 交集后的集合大小范围，并说明热图没有显著性阈值。`os_finalize_figure` 执行 lint。

## 19.10 S4 shared additions (bulk diagnostics, gene-set displays)

Added in the S4 concentrated fix (`docs/build/S4_REPORT.md`). Each builder draws numbers the module computed with the package's own function; the only computation inside the figure layer is a display kernel density.

- `os_sample_mds()` (`fig_mod_bulk.R`): limma `plotMDS(plot = FALSE)` coordinates drawn through `os_pca_plot()`; axis titles name the distance ("leading log2 fold change" / "log2 fold change") and the variance explained; the caption states n samples, `top`, the input scale and the colour/shape columns. Used by edger-qlf, limma-voom, limma-dupcor.
- `os_ql_dispersion()` (`fig_mod_bulk.R`): edgeR `plotQLDisp` content — raw and squeezed quarter-root QL dispersions as points, the trend as a line, against average log2 CPM; the caption states prior df, robust and the number of robust outliers.
- `os_voom_trend()` (`fig_mod_bulk.R`): voom `save.plot` points (sqrt residual SD vs log2 count size) and the lowess line; the caption states the span.
- `os_prior_density()` (`fig_mod_bulk.R`): ComBat empirical-Bayes prior check (the `prior.plots` content without base graphics), one row per batch, additive (normal prior) and multiplicative (inverse-gamma prior) panels; empirical kernel density in ink, fitted prior in the up colour; display only.
- `os_barcode()` (`fig_mod_enrich_rank.R`): limma `barcodeplot` display — ranked statistic (most negative left) as a grey area, set members as bars, optional enrichment worm supplied by the module (`limma::tricubeMovingAverage`).
- `os_md_set_highlight()` (`fig_mod_enrich_rank.R`): MD plot with up to two gene sets highlighted (User's Guide 18.1.10); display only.
- `os_score_by_group()` (`fig_mod_enrich_rank.R`): GSVA scores by group (box + points, one panel per set, at most 12 highest-variance sets); never carries a test annotation.
- `os_nes_bar(positive_end, negative_end)`: the caption names what the two ends of the ranking mean instead of assuming up/down-regulated expression; `os_camera_set_bar()` now always shows the axis titles and a legend of the directions present.

## 19.4 M4 lane figures

`fig_mod_m4.R` wraps existing soft-threshold, module-trait, oncoplot and heatmap builders with sample counts, declared scales and selection/adjustment captions. Dendrograms convert hclust merges to segments and use shared line/colour/point tokens. Module colours travel in colour_registry handoffs; crowded gene trees omit leaf labels and preserve full assignment tables. No global tokens are changed.
