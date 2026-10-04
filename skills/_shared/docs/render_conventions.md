# 表格渲染惯例：var_typing.R、render_md.R、render_docx.R

> **出处说明**：本文件描述的脚本是从 medstat 继承的通用 `_shared` 组件（omicstat 在自己的 R 环境中独立运行它们，不依赖 medstat）。文中出现的 `research/phase2/...`、medstat 模块名与 survey 相关内容是原始设计出处与历史用例，保留作参考。

`docs/effect_table_schema.md`（数据契约）的姊妹篇。这份文档讲契约两侧的事：
`var_typing.R` 怎么判定一个变量"是什么"、该拿它怎么办；`render_md.R`/
`render_docx.R` 怎么把数字排成期刊要的三线表。

## var_typing.R：变量分型与检验路由

`classify_variable(x, var_name, force_type)` 回答"这个变量是什么"
（`continuous`/`binary`/`categorical`/`ordinal`/`constant`），以及对连续变量
额外回答"它正态吗"。`recommend_test(var_type, n_groups, paired, normal, trend,
expected_min)` 在此基础上回答"该用什么描述统计、该用什么检验"。两个函数都
只处理自己该管的那一个决策，不碰数据本身，也不跑检验、不产出比较结果——
那是下游 `effect_table.R` 的事。

### 正态性路由：`|skewness| > 1`，不是显著性检验

主判据是 `|skewness| > 1`（Fisher-Pearson g1，不做小样本偏差校正）。
Shapiro-Wilk 和 Q-Q 相关系数（`filliben_r`）总是会被算出来并返回，供参考/
报告用，但**两者都从不参与路由判断**。完整实证依据见
`research/phase2/P0-baseline-table.md` §1.2，简述如下：

- 在 Table 1 常见的样本量（n>300 量级）下，Shapiro 的检验功效趋近 1，会拒绝
  肉眼看起来明显正态的数据。`nafld1$age`（n=17,549）是标准演示案例：偏度
  只有 0.07（远低于 1.0 阈值），Shapiro P 却是 6e-12。`classify_variable()`
  依然判定它 `normal = TRUE`，路由到 mean(SD)。这个具体案例是
  `tests/test_var_typing.R` 第 4 节的回归测试。
- n<20 时 Shapiro 反过来功效不足（P0 报告里对数正态分布在 n=20 时 500 次
  重复只有 83.6% 检出率），所以 `classify_variable()` 在这个区间不信任任何
  一个检验：默认 `normal = FALSE`（保守分支），并在 `notes` 里说明，而不是
  在证据不足时随便选一边。
- 二者之间，`|skewness| > 1` 就是全部规则。表格脚注或 Methods 里可以报
  `shapiro_p` 和 `filliben_r`（返回对象上随时可取），回应"你们做没做正态性
  检验"这类审稿问题——但不能让它们推翻 skewness 给出的结论。

### 类型判定绝不会从"取值种类少"猜出分类变量

一个数值型向量只要非缺失取值种类数大于二，默认判定为 `"continuous"`，除非
调用方传了 `force_type`。这是有意为之：经典的 `unique_count<=5` 启发式会
把小样本连续变量误判（`research/phase2/P0-baseline-table.md` §8.3 的 NEVER
条目之一）。恰好两个不同取值（不论是数值、字符、因子还是逻辑型）无歧义地
判为 `"binary"`——这一条不是猜测。如果一个数值列其实是分类编码（比如
`race` 编成 `1..4`），调用方必须显式声明 `force_type = "categorical"`（或
`"ordinal"`）——这正是为什么一个 skill 的 CLI 层应该暴露类似 `--factor-vars`
的参数，而不是尝试自动侦测。

### 描述统计/检验映射表

`recommend_test()` 把 P0-baseline-table.md §1.1/1.3 的决策树编码了一次，
让每个 skill 走同一条路由：

| 变量类型 | 组数 | 配对 | 正态 | -> 描述统计 | -> 检验 |
|---|---|---|---|---|---|
| 连续 | 1 | -- | 是 | mean (SD) | 单样本 t 检验 |
| 连续 | 1 | -- | 否 | median [IQR] | Wilcoxon 符号秩检验 |
| 连续 | 2 | 否 | 是 | mean (SD) | 独立样本 t 检验 |
| 连续 | 2 | 否 | 否 | median [IQR] | Mann-Whitney U |
| 连续 | 2 | 是 | 是 | mean (SD) | 配对 t 检验 |
| 连续 | 2 | 是 | 否 | median [IQR] | Wilcoxon 符号秩检验 |
| 连续 | 3+ | 否 | 是 | mean (SD) | ANOVA |
| 连续 | 3+ | 否 | 否 | median [IQR] | Kruskal-Wallis |
| 连续 | 3+ | 是 | 是 | mean (SD) | RM-ANOVA |
| 连续 | 3+ | 是 | 否 | median [IQR] | Friedman |
| 二分/分类 | 1 | -- | -- | n (%) | 二项检验/z 检验 |
| 二分/分类 | 2+ | 否 | -- | n (%) | 卡方检验（期望频数>=5）或 Fisher 精确检验（期望频数<5；超出 2x2 之后精确 Fisher 计算上不现实） |
| 二分 | 2 | 是 | -- | n (%) | McNemar 检验 |
| 分类 | 3+ | 是 | -- | n (%) | Cochran's Q（无原生 base R 实现——用之前先确认有对应包） |
| 有序变量，或组本身有序 | 任意 | -- | -- | n (%) | 卡方趋势检验（Cochran-Armitage） |

`expected_min`（最小期望频数）决定卡方/Fisher 的分支；用
`expected_cell_min(table(x, group))` 算——和 `chisq.test()` 内部用的算法
（`outer(rowSums, colSums)/n`）完全一样，单独暴露出来是为了让调用方不用
重复写这段算式，也不会误把观测频数当期望频数传进去。

`recommend_test()` 还会返回 `test_r_call`，一段用于溯源/文档的 R 调用签名
字符串（例如 `"stats::chisq.test(tab)  # base R defaults to Yates' continuity
correction..."`）——读一下，它标出了本套件已知的两个常用包默认行为不一致的
唯一一处：base R 的 `chisq.test()` 在 2x2 表上默认做 Yates 连续性校正
（`correct=TRUE`），而 gtsummary 2.5.1 默认不做（P0-baseline-table.md §4.2）。
用了哪一种，务必在 Methods 里写清楚。

## render_md.R / render_docx.R：三线表

两个文件都分两层，刻意分开：

1. **纯排版层** —— `render_md_table(df, title, footnote, path)` /
   `render_docx_table(df, title, footnote, path)`。接受**任意**列已经是
   可直接显示的字符串（或 `format()` 能合理打印的东西）的 data.frame，
   照原样排版。不做任何四舍五入，不重新解读 P 值。这是手搓的、从未经过
   `effect_table.R` 的汇总表该走的路径。
2. **schema 感知的格式化层** —— `format_effect_table_for_display(et, style,
   digits, effect_label)`，以及一步到位的封装函数
   `render_effect_table_md()` / `render_effect_table_docx()`（先调它，再把
   结果交给第 1 层）。这是 `effect_table.R` schema 表该走的路径：把
   `estimate`/`ci_low`/`ci_high` 拼成 `"1.52 (1.21 to 1.91)"`，把 `p_value` 格式化成
   `"<0.001"` 或 `".03"`（取决于 `style`），并配上对应的 P 值列表头
   （`"P"`、`"*P*"` 或 `"p"`）。

`render_docx.R` 会 source `render_md.R` 来拿第 2 层的格式化函数
（`format_p`、`format_ci`、`p_label`、`ci_separator`、
`format_effect_table_for_display`），而不是自己重写一遍，这样一个数字在
`.md` 预览里和最终 `.docx` 里绝不会长得不一样——判定 `0.032` 该显示成什么
样子的地方只有一处。使用顺序要先 source `render_md.R` 再 source
`render_docx.R`；后者会检查这一点，顺序反了会以 `OS_MISSING_DEPENDENCY`
报错。

### Reader-facing column names

`format_effect_table_for_display()` defaults to its legacy, machine-oriented
headers so existing callers receive byte-identical output. For a table meant
for readers, set `reader_facing = TRUE`. This applies the exported
`EFFECT_TABLE_DISPLAY_NAMES` map from `effect_table.R`: for example, `term`
becomes `Variable`, `n_unweighted` becomes `No. of participants`, and
provenance fields such as `analysis_id` and `model_spec_hash` are omitted.

Use `display_names` for a named character-vector override. `NA_character_`
suppresses a source column. When `reader_facing = TRUE`, supplied entries
override the suite map, so a Mendelian-randomization table can use
`c(n_unweighted = "No. of SNPs")` while retaining every other reader-facing
default. The one-call `render_effect_table_md()` and
`render_effect_table_docx()` helpers accept the same two parameters.

Reader-facing effect tables MUST use `reader_facing = TRUE` or an explicit
`display_names` map. Machine identifiers belong only in `qc/` and
`provenance/` artifacts, not reader-facing tables or footnotes.

### docx 引擎选型：`gt::gtsave()`，不是 flextable

`render_docx_table()` 用 `gt::gt()` 搭表，用 `gt::gtsave(g, "*.docx")` 写出。
`research/phase2/P0-baseline-table.md` §4/5.2 在本机把这条路线和更常被引用的
`gtsummary -> as_flex_table() -> flextable::save_as_docx()` 路线都实测过：
gt 1.3.0 能直接写出合法 docx，gt 本来就是本套件的硬依赖，走这条路不用再引入
flextable/officer 这第二套表格写出栈。万一 gt 的 docx 导出以后出问题，
`flextable::flextable(df) |> flextable::save_as_docx()` 是文档记录过的备选
方案（同一份报告 §4）——只需要在 `render_docx_table()` 内部换掉引擎，调用
这个函数的代码完全不用知道底下换了什么。

### 恰好三条横线，没有竖线

`render_docx_table()` 恰好画三条横线——表头上方一条、表头下方一条、
最后一行数据下方一条——不画任何竖线，对齐 AMA/NEJM/Lancet 三家共有的惯例
（P0-baseline-table.md §5.1 的"8 条通用规则"：全表不用竖线，只用横线）。
`render_md_table()` 产出标准的 GitHub-flavored-markdown 管道表，而不是
硬凑字符画出三条线——markdown 本来就没有真三线表的语法；markdown 路线
（P0-baseline-table.md §5.2 的 route C）存在的意义是快速、可 diff 的预览，
不是投稿终稿，投稿用 docx 路线。

### `style` 同时控制 P 值格式和 CI 分隔符

| `style` | P 标签 | 前导 0 | 小数位规则 | `<` 阈值 | CI 分隔符 |
|---|---|---|---|---|---|
| `"generic"`（默认） | `P` | 有 | 2 位小数（低于 0.01 时 3 位） | `<0.001` | `", "` |
| `"ama"` / `"jama"` | `*P*`（斜体） | 无 | 大于 0.01 时 2 位小数，0.01-0.001 之间 3 位 | `<.001` | `", "` |
| `"nejm"` | `P` | 无（数值规则同 AMA） | 同 AMA | `<.001`（数值同 AMA） | `" to "` |
| `"lancet"` | `p`（小写） | 有 | 2 位**有效数字**，不是固定小数位 | `<0.0001` | `" to "` |

`"nejm"` 的数值格式和 `"ama"` 完全一致——两家期刊的区别只在标签是否斜体、
CI 两端用什么词分隔，这两点 `format_effect_table_for_display()` 和
`render_docx_table()` 都会从同一个 `style` 参数一致地套用。

`format_p()` 从不返回 `"NS"`，也从不拒绝给一个落在合法范围内的 P 值输出
数字——按项目总纲的房规，读者期待一个数字的地方就该拿到一个数字；路由逻辑
拿不准的值也会在上游 `effect_table.R` 里给出数字加 `notes` 说明，而不是在
这一层留空。

### `na_string` 与缺失单元格

两个 renderer 默认都用 `"--"` 替换缺失值（`na_string` 参数），而不是留空
单元格或字面量字符串 `"NA"`——`"--"` 是投稿 Table 1 里表示"不适用"或
"未计算"更常见的惯例，也能和真实的 0 一眼区分开。

## 完整示例（对应 `tests/test_render.R`）

```r
source(file.path(shared_dir, "effect_table.R"))
source(file.path(shared_dir, "render_md.R"))
source(file.path(shared_dir, "render_docx.R"))

fit <- glm(dead5 ~ age + male + bmi, data = d, family = binomial())
cf <- coef(fit); ci <- confint(fit)

et <- new_effect_table()
for (term in c("age", "male", "bmi")) {
  et <- add_effect_rows(et, term = term, analysis_id = "logistic_dead5", effect_type = "OR",
                        estimate = exp(cf[[term]]), ci_low = exp(ci[term, 1]), ci_high = exp(ci[term, 2]),
                        p_value = summary(fit)$coefficients[term, "Pr(>|z|)"],
                        n_unweighted = length(fit$fitted.values), n_events = sum(d$dead5))
}

render_effect_table_md(et, title = "Table 1. Odds of 5-year mortality",
                        style = "ama", path = "table1.md")
render_effect_table_docx(et, path = "table1.docx",
                          title = "Table 1. Odds of 5-year mortality", style = "ama")
```
