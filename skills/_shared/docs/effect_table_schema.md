# effect_table.R 表结构 —— 全套件契约

> **出处说明**：本文件描述的脚本是从 medstat 继承的通用 `_shared` 组件（omicstat 在自己的 R 环境中独立运行它们，不依赖 medstat）。文中出现的 `research/phase2/...`、medstat 模块名与 survey 相关内容是原始设计出处与历史用例，保留作参考。

`skills/_shared/scripts/effect_table.R` 定义了全套件每个 skill 产出效应量估计时
共用的唯一 tidy 表结构，也是 `render_md.R`/`render_docx.R` 唯一认识、能排成期刊
三线表的表结构。新建一个 skill 的效应量表之前先读这份文档；想给它加一列之前
再读一遍——在这里加列是全套件级别的决定，不是某个 skill 局部的事。

## 与 P0-baseline-table.md §8.4 的关系（2026-08-14 裁决）

`research/phase2/P0-baseline-table.md` §8.4 曾经给这个文件另开过一份定义：`build_effect_table(
data, vars, strata, factor_vars, exact_vars, weights, svy_strata, svy_psu, smd, journal)`，
列名是 `variable, group1_stat, group2_stat, ..., smd, smd_type, test_name, test_statistic,
p_value, p_value_adj, missing_n, missing_pct, weighted` —— 一张**按分组展开的 Table 1 宽表**，
和 `research/phase2/P0-assoc-workflow.md` §7（本文件实际遵循的定义）描述的**长表**在结构上
根本不是同一种东西：宽表一行是"一个变量在两组各自的统计量+组间比较结果"，长表一行是"一个
term 在一个 analysis_id 下的一个效应量估计"。两份 P0 报告各自忠实解读了自己负责的模块需求，
分歧在集成阶段才浮出水面。

**裁决**：`EFFECT_TABLE_SCHEMA`（本文件描述的对象）**只**服务 P0-assoc-workflow.md §7 定义的
长表场景（关联分析/剂量反应/亚组森林图的效应量表），不吸收 baseline-table 的 Table 1 宽表需求。
理由是长表和宽表本质上是两种不同的数据形状，硬塞进同一个 schema 只会让两边都变形。
`baseline-table` 模块（尚未开发）真正落地时应该：

- 走独立的 `BASELINE_TABLE_SCHEMA`（宽表，字段参照 P0-baseline-table.md §8.4 的列表，但把
  `p_value_adj` 改名为 `p_adjusted`，与本文件的命名习惯对齐，避免同一套件里出现两种大小写/
  下划线风格的"校正后 P 值"列名）；
  由该模块自己的脚本（例如未来的 `baseline_table.R`）定义，不寄生在 `effect_table.R` 里；
- 排版仍然复用 `render_md.R` 的通用层 `render_md_table()`（"任意 data.frame 都能排成三线表"
  的那一半，见该文件顶部的两层结构说明），不需要复用 `format_effect_table_for_display()`
  （那是专门解析 `EFFECT_TABLE_SCHEMA` 长表结构的，宽表用不上）。

`scripts/effect_table.R` 里一处过时的内部注释（曾提到一个从未真正存在过的 `build_effect_table()`
函数）已一并清理，避免误导以为这两个 schema 曾经合并过。

本文档是 `effect_table.R` 里 `EFFECT_TABLE_SCHEMA` 对象的手写转录；随时可以调用
`effect_table_schema()` 拿到同样信息的 data.frame。两者若有出入，以 R 对象为准
（`tests/test_effect_table.R` 会核对列数与任务原始指令里点名的列表，列**数量**
漂移会导致测试失败；列的**文字说明**漂移不会，所以改了 schema 之后要回来对一眼
这份文档）。

## 设计原则

1. **一行 = 一个估计值。** Model 1/2/3 递进表是每个暴露 term 三行（每个模型一行），
   不是一行塞三组数字。一个四水平的分类变量是（最多）三或四行（每个非参照水平一行，
   或想把所有水平都列出来就每个水平一行），不是把四个数字挤进一个单元格。宽表、
   给人看的排版是 `render_md.R`/`render_docx.R` 最后一步才做的事；在那之前全程保持
   tidy/long 形态。
2. **排版与计算解耦。** 这个文件里没有任何四舍五入、没有 P 值阈值格式化、没有三线表
   逻辑。期刊排版规则（见 `docs/render_conventions.md`）变了，这里的数字不受影响；
   数字变了（重跑模型），排版代码不受影响。如果发现自己想在 `effect_table.R` 里写
   `sprintf("%.2f", ...)`，那行代码该搬去 `render_md.R`。
3. **绝不悄悄丢弃一个本该存在的数字。** 模型没收敛的那一行、或加权设计下算不出来的
   P 值，依然占着这行，该单元格是 `NA`，`notes` 里写明原因——绝不整行删除；`p_adj`
   在没做多重比较校正时是 `NA`（而不是整列缺失），这样读者才能分清"没校正"和
   "校正了但这行没填上"。
4. **数字必须自洽。** `validate_effect_table()` 会机械检查 `lower <= estimate <= upper`
   （留一点浮点容差）、`p`/`p_adj` 落在 `[0,1]`、`n_event <= n` 等等——见下面"校验规则"。
   这是整个项目唯一不可让步的底线：一张表不满足这些，无论怎么产出的，都是错的。

## 列参考表

| 列名 | 类型 | 必填 | 语义 |
|---|---|---|---|
| `term` | character | 是 | 变量或对比名，如 `"bmi"`、`"Q4_vs_Q1"`、`"sexFemale"`。 |
| `level` | character | 否 | 分类/分组对比中 `term` 内部的具体水平；连续变量的单个每单位 term 为 `NA`。 |
| `analysis_id` | character | 是 | 产出这行的模型/分析标签，如 `"crude"`、`"model1"`、`"model3"`、`"rcs_threshold"`、`"subgroup_male"`。这是 P0-assoc-workflow.md §7 原名的 `analysis_id` 列，同时承担该报告 §1 的 Model 1/2/3 标签角色——一列干两件事的活。 |
| `effect_type` | character | 是 | 效应量的量纲：期望是 `EFFECT_TYPE_VOCAB`（`OR`/`HR`/`RR`/`IRR`/`beta`/`mean_diff`/`median_diff`/`SMD`/`prop_diff`/`c_index`/`cal_slope`/`cal_intercept`/`net_benefit`/`brier`/`risk`/`prevalence`/`entropy`/`sensitivity`/`specificity`/`ppv`/`npv`/`lr_pos`/`lr_neg`/`dor`/`other`）之一。`OR`/`HR`/`RR`/`IRR` 和新增的 `lr_pos`/`lr_neg`/`dor`（诊断准确性的阳性/阴性似然比、诊断比值比）是比值尺度（零假设值为 1，log 轴）；`beta`/`mean_diff`/`median_diff`/`SMD`/`prop_diff`、`c_index`/`cal_slope`/`cal_intercept`/`net_benefit`/`brier`/`risk`/`prevalence`/`entropy` 及新增的 `sensitivity`/`specificity`/`ppv`/`npv`（诊断准确性的有界 [0,1] 比率）是差值/绝对尺度（线性轴）——但后一组多数是有界汇总统计量（判别力、校准、效用指标、诊断准确性指标），不是"对照参照值的对比"，所以除 `cal_slope`（完美校准=1）外通常没有"零假设参考线"这个概念。出现清单外的值只**警告**，不拒绝——未来某个 skill 可能需要这里没预料到的量纲。 |
| `estimate` | numeric | 是 | 点估计，量纲由 `effect_type` 决定。允许 `NA`（不可估计），但应在 `notes` 里说明原因。 |
| `ci_low` | numeric | 否 | `ci_level` 置信水平下的下界；未计算则为 `NA`。 |
| `ci_high` | numeric | 否 | 同上，上界。 |
| `ci_level` | numeric | 否（默认 `0.95`） | `ci_low`/`ci_high` 对应的置信水平（比例形式）。读别人产出的表**永远不要默认是 0.95**——先看这一列。 |
| `p_value` | numeric | 否 | 该 term 的原始双侧 P 值。 |
| `p_adjusted` | numeric | 否 | 多重比较校正后的 P 值；没做校正时是 `NA`——不是不出现这一列。项目惯例（P0-baseline-table.md / 项目总纲）：FDR/Bonferroni 默认关；开启时 `p_value` 和 `p_adjusted` 都要报，绝不能只报 `p_adjusted`。 |
| `p_adj_method` | character | 否 | 产出 `p_adjusted` 用的校正方法，如 `"BH"`、`"bonferroni"`；`p_adjusted` 为 `NA` 时此列也是 `NA`。 |
| `n_unweighted` | integer | 是 | 该估计值背后的未加权分析样本量。永远是未加权数，哪怕这一行来自加权设计——见 P0-baseline-table.md §3.1 的 NHANES 惯例。 |
| `n_events` | integer | 否 | 事件/病例数，用于生存或二分类结局；不适用时为 `NA`。 |
| `design_df` | numeric | 否 | 复杂抽样设计自由度（`degf(design)`）；非 survey 模型为 `NA`。 |
| `weighted` | logical | 是（默认 `FALSE`） | 该估计是否来自 survey 加权模型/设计。 |
| `stratum_var` | character | 否 | 定义分层/亚组切分的变量名，如 `"sex"`；非亚组分析为 `NA`。 |
| `stratum` | character | 否 | 该行所属的分层水平，如 `"Male"`；非亚组分析为 `NA`。 |
| `test_name` | character | 否 | 实际使用的 R 检验/模型函数，如 `"svycoxph"`、`"wilcox.test"`、`"chisq.test"`。自由文本，用于溯源和 Methods 起草（`var_typing.R` 的 `recommend_test()` 输出的 `test_name` 就是打算填进这里的）。 |
| `model_spec_hash` | character | 否 | 该估计背后的协变量集+complete-case 集的哈希，用来让图和表自动校验"是否来自同一个模型规格"（把 P0-assoc-workflow.md §7 那条"图和表绝不能来自不同规格的模型"的规则做成机器可查）。 |
| `notes` | character | 否 | 呈现给渲染层/Methods 草稿的自由文本说明，如 `"Fisher exact, expected count <5"`。 |
| `row_role` | character | 否（**可以整列不存在**，见下方"两个 OPT-IN 列"一节） | 只在列存在时校验：`"study"`（单个纳入研究自身的估计值）/`"pooled"`（meta 合并估计值）/`"subgroup_pooled"`（某个亚组内部的合并估计值）/`"sensitivity"`（敏感性分析/leave-one-out 重跑的合并估计值）之一，出现清单外的值是**错误**（不是警告，和 `effect_type` 不同——见该列在 `scripts/effect_table.R` 里 `ROW_ROLE_VOCAB` 常量旁的注释）。给聚合数据（meta 分析类）效应量表区分"这一行是某篇原始研究自己的估计"还是"这一行是合并出来的汇总估计"用的。 |
| `contrast` | character | 否（**可以整列不存在**，同上） | 自由文本，说明这一行的估计值是"对比什么"得到的，如 `"per_unit"`、`"vs_reference"`、`"highest_vs_lowest"`。和 `row_role` 不同，这一列**没有**封闭词表，只在列存在时做类型检查，不检查取值。 |

`term`、`analysis_id`、`effect_type`、`estimate`、`n_unweighted`、`weighted` 是**必填**：这几列
在任意一行是 `NA` 或空字符串，`validate_effect_table()` 都会拒绝。其余列在任意一行都可以是 `NA`。

### 两个 OPT-IN 列：`row_role` / `contrast`（2026-08-14 新增）

这两列和上面其它所有"非必填"列不是同一类"非必填"。上面列出的其它非必填列（`level`、
`ci_level`、`stratum` 等等）**必须作为列存在**，只是每一行的取值可以是 `NA`——`new_effect_table()`
产出的空表本来就带着这些列，`validate_effect_table()` 看到表里根本没有这一列会直接判为坏表
（`missing_cols` 检查）。`row_role`/`contrast` 反过来：**整列可以完全不存在**，`validate_effect_table()`
对此没有任何意见，行为和这两列从未被加进 schema 之前一模一样。这个区别在
`EFFECT_TABLE_SCHEMA`（`scripts/effect_table.R`）里落地成一个新增的 `core` 字段（逻辑值）——
原有 20 列 `core = TRUE`（必须作为列存在，这是没变过的老规矩），`row_role`/`contrast`
`core = FALSE`（可以整列缺失）。

这个设计不只是校验层面的宽松，构造层面也是**真正的 opt-in**：

- `new_effect_table()` 产出的空表**仍然只有 20 列**，和这两列加进来之前完全一样——不会自动带上
  两列全 `NA` 的 `row_role`/`contrast`。
- `add_effect_rows(..., row_role = NULL, contrast = NULL)`：这两个参数默认 `NULL`，**不是**
  `NA_character_`（和这个函数其它所有可选参数都不同）——`NULL` 才能让函数分清"调用方压根没提这个
  参数"和"调用方明确要记一个缺失值"，只有调用方**这一次调用**真的传了非 `NULL` 值，这一列才会
  出现在产出的表里。一条从未用过 `row_role`/`contrast` 的调用链，产出的表列结构和这两列存在之前
  逐字节一致。
- 为什么要做到这么严格：`competing-risks`/`diagnostic-accuracy`/`longitudinal-change`/
  `missing-data` 这几个 skill 会把效应量表的原始列 `utils::write.csv()` 直接导出成 `.csv`
  产出物——如果这两列被无条件加进每一张表（哪怕全是 `NA`），这些模块的导出 `.csv`
  会平白无故多出两个空列，即使那个模块从来没打算用 `row_role`/`contrast`。三线表渲染层
  （`render_md.R` 的 `format_effect_table_for_display()`）不受影响，因为它本来就是按列名白名单
  取数（`Term`/`Model`/`effect_label`/`N`/`Events`/`P`/`P`-adjusted/`Stratum`/`Notes`），从不
  透传 `et` 的原始列，但 `.csv` 直出路径没有这层保护，所以选择在构造层面就把这两列做成真正的
  opt-in，而不是只在校验层面放行。
- `combine_effect_tables()` 同理修正过：只有参与合并的表里**至少有一张**真的带了 `row_role`/
  `contrast`，合并结果才会带上这一列（沿用它本来就有的"额外列取并集、缺的一方补 `NA`"逻辑）；
  没有任何一张表用到这两列时，合并结果仍然只有 20 列。
- 一条效应量表的构建链里可以中途开始用 `row_role`（前几行没传，后面某一行传了，前面的行自动
  回填为 `NA`），也可以中途停止传（后面的行 `row_role` 落 `NA`）——这和 `combine_effect_tables()`
  本来就有的"某张输入表没有的额外列自动补 `NA`"是同一套机制，`add_effect_rows()` 现在也用同一套
  机制处理它自己的 `et`/`new_rows` 两边列不对齐的情况。

## 一个命名上的说明：这份 schema 和 P0-assoc-workflow.md §7 / forest.R 的关系

本文件的列名（`analysis_id`/`ci_low`/`ci_high`/`p_value`/`p_adjusted`/`n_unweighted`/`n_events`）
就是 `research/phase2/P0-assoc-workflow.md` §7 逐字点名的那套正典命名，也正是 `scripts/forest.R`
（本套件共用的森林图渲染器）硬编码期望的列名——两者现在是同一套名字，不需要改名桥接就能
`forest_plot(et, ...)` 直接消费 `effect_table.R` 的产出（完整规则见
`skills/_shared/docs/CONVENTIONS.md`）。

**历史备注**：这份 schema 早期版本曾用一套不同的字面列名（`model`/`lower`/`upper`/`p`/`p_adj`/
`n`/`n_event`），和 `forest.R` 独立依据同一份需求文档取的不同措辞并存，靠一个改名桥接函数
`as_forest_input(et)` 弥合。这次全套件列名对齐已经消除了这个分歧——schema 直接采用了 P0 §7/
forest.R 的名字，`as_forest_input()` 因此降级为一个**不做任何事的透传函数**（仅保留向后兼容，
标记为 deprecated），新代码应该跳过它，直接把 `add_effect_rows()` 的产出传给 `forest_plot()`。

## 公开函数

| 函数 | 作用 |
|---|---|
| `effect_table_schema()` | 以 data.frame 形式返回 `EFFECT_TABLE_SCHEMA`（列名/类型/是否必填/说明）。 |
| `new_effect_table()` | 一张空的（0 行）、每列类型都正确、按 schema 顺序排列的表。 |
| `add_effect_rows(et, term, analysis_id, effect_type, estimate, ..., row_role = NULL, contrast = NULL)` | 追加一行或多行（各参数互相 recycle，所以一个分类变量的多个水平可以一次调用加完）。`et = NULL` 表示新建一张表。`validate = TRUE`（默认）在结果不通过校验时只发**警告**、不报错，不阻断增量构建。`row_role`/`contrast` 默认 `NULL`（不是 `NA_character_`）——只有这次调用真的传了非 `NULL` 值，产出的表才会带上这一列；见上面"两个 OPT-IN 列"一节。 |
| `validate_effect_table(et)` | 从不抛错，返回 `list(ok, errors, warnings)`。`errors` 是让表结构性损坏或内部自相矛盾的问题（缺必填列、`estimate` 落在 `[ci_low, ci_high]` 外、`p_value` 落在 `[0,1]` 外、`n_events > n_unweighted` 等）。`warnings` 是值得留意但不致命的问题（`effect_type` 不在清单内、给了 `p_adjusted` 没给 `p_adj_method`、整张表 0 行）。 |
| `assert_effect_table(et, label = "effect table")` | `validate_effect_table()` 的抛错版本。失败时把所有累积的错误一次性抛出（不是只报第一条）；成功时原样隐式返回 `et`。 |
| `combine_effect_tables(...)` | 把两张或更多效应量表按行合并（可传 `...` 或一个 list）。逐个校验每个输入以及合并结果。超出固定 schema 的额外列会取并集，某个输入表没有的列自动补 `NA`，所以某个 skill 专属的扩展列不会挡住合并。 |
| `as_forest_input(et)` | **Deprecated**，不做任何事的透传函数（先校验 `et`，原样返回，附带一条弃用警告）。历史上曾把本 schema 的列名改成 `scripts/forest.R` 期望的名字；现在两者列名本就一致，保留只为了不破坏旧调用点（见上面命名说明）。新代码直接跳过它。 |

## 校验规则（什么样的表算"坏表"）

`validate_effect_table()` 按以下顺序检查（后面的检查假设前面的都通过了，
这样同一列上的类型错误会先于范围错误被报出来，不至于互相掩盖）：

1. 输入是 `data.frame`。
2. 20 个 **core** schema 列全部存在（`row_role`/`contrast` 不算在内，这两列可以整列不存在；
   多出来的列没问题；少了任何一个 core 列不行）。
3. 每一列的类型和 schema 声明的一致（`character` 保持 character，`numeric`/`integer`
   保持数值型，`logical` 保持逻辑型）——这一步排在最前面，因为后面每一项检查都假设
   这列已经是声明的类型才能索引进去；`row_role`/`contrast` 不存在时直接跳过，不报错。
4. 每一个**必填**列（`term`、`analysis_id`、`effect_type`、`estimate`、`n_unweighted`、`weighted`）
   在每一行都不是 `NA`（字符列还要求非空字符串）。
5. `effect_type` 在 `EFFECT_TYPE_VOCAB` 里——只**警告**。
6. `row_role` 这一列**存在时**，取值在 `ROW_ROLE_VOCAB`（`study`/`pooled`/`subgroup_pooled`/
   `sensitivity`）里——**错误**（注意和第 5 条的 `effect_type` 不同，这里是错误不是警告）；
   列不存在则完全跳过这条检查。`contrast` 不做取值检查（自由文本）。
7. `p_value` 和 `p_adjusted` 非 `NA` 时落在 `[0, 1]`——**错误**。
8. `ci_level` 非 `NA` 时落在 `(0, 1]`——**错误**。
9. `ci_low` 和 `ci_high` 同时存在时 `ci_low <= ci_high`——**错误**。
10. `ci_low`、`estimate`、`ci_high` 三者都存在时 `ci_low <= estimate <= ci_high`（留一点相对
   容差）——**错误**。这就是项目总纲那条"数字必须自洽"规则的机械化实现。
11. 给了 `p_adjusted` 却没给 `p_adj_method`——**警告**。
12. `n_unweighted >= 0`——**错误**。
13. `n_events` 和 `n_unweighted` 同时存在时 `n_events` 落在 `[0, n_unweighted]`——**错误**。

0 行的空表是合法的（里面没有东西能自相矛盾），但会带一条警告说明这一点——一张空表
流到渲染层，几乎总意味着上游哪里没产出东西。

## 一个完整示例

```r
source(file.path(shared_dir, "effect_table.R"))

et <- new_effect_table()
et <- add_effect_rows(et,
  term = "bmi", analysis_id = "model3", effect_type = "HR",
  estimate = 1.52, ci_low = 1.21, ci_high = 1.91, p_value = 0.00034,
  n_unweighted = 1000L, n_events = 120L, weighted = FALSE)
et <- add_effect_rows(et,
  term = "race", analysis_id = "model3", effect_type = "OR",
  level = c("Black", "Other"), estimate = c(1.1, 0.9),
  ci_low = c(0.8, 0.6), ci_high = c(1.5, 1.3), p_value = c(0.5, 0.6),
  n_unweighted = c(1000L, 1000L))

assert_effect_table(et)   # 只要违反上面任何一条就在这里抛错

source(file.path(shared_dir, "render_md.R"))
render_effect_table_md(et, title = "Table 2. Model 3 estimates", style = "ama")
```

完整的构造/校验/合并行为清单见 `tests/test_effect_table.R`（都写成可执行的检查）；
`tests/test_render.R` 里有一个真实模型（拟合在 `survival::nafld1` 上）从
`effect_table.R` 一路走到两个 renderer 的端到端例子。
