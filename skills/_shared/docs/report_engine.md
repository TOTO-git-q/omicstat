# report_engine.R —— 模板注册规范

> **出处说明**：本文件描述的脚本是从 medstat 继承的通用 `_shared` 组件（omicstat 在自己的 R 环境中独立运行它们，不依赖 medstat）。文中出现的 `research/phase2/...`、medstat 模块名与 survey 相关内容是原始设计出处与历史用例，保留作参考。

`_shared/scripts/report_engine.R` 是全套件共用的"数字驱动文字"生成器，把
`rcs-analysis/scripts/rcs_report.R` 已经验证过的防错原语和写法泛化成每个
skill 都能复用的库。本文档写给要在它之上注册**新** skill 句式模板的人。

在你的 skill 的 report 脚本里靠近开头处 source 一次：

```r
source(file.path(here, "..", "..", "_shared", "scripts", "report_engine.R"))
```

它不依赖任何 R 包（纯 base R），所以 source 它不会因为缺包而失败。

## 两层结构

1. **原语（primitives）**——一批可以直接塞进 `sprintf()` 里用的普通函数，
   用法和今天的 `rcs_report.R`完全一样。手写一段文字、只是想套用某条格式
   规则时用它们。
2. **模板（templates）**——`declare_template()` + `fill()`。句子的措辞固定、
   只有数字每次调用会变时用它们；好处是能在编译期（也就是 `fill()` 调用时）
   保证每个槽位都被喂进了正确形状的值——P 值槽不可能悄悄收到一个已经格式化
   好的字符串，方向词槽也不可能被手填一个和旁边数字不一致的词。

两层都不是强制的。`rcs_report.R` 自己的段落函数（`methods_en`、`results_en`
……）就是用普通 `sprintf()` 加条件性的 `character(0)` 累加拼出来的——这个写法
依然有效，而且对"有很多可选从句"的段落（阈值分析可能没跑、Davies 检验可能
在 survey 设计下不适用）往往就是更合适的选择。`declare_template()` 更适合
"每次形状都一样、只是换数字"的句子。

## 原语一览

| 函数 | 对应 rcs_report.R 中的私有函数 | 作用 |
|---|---|---|
| `fmt_p(p, style, prefix, eps, journal)` | `.peq`/`.pfmt`/`.pbare` | `style="full"` -> `"P = 0.032"` / `"P < 0.001"`；`"eq"` -> `"= 0.032"`；`"bare"` -> `"0.032"`（表格单元格用） |

**`fmt_p()` 默认小数位数和 `render_md.R::format_p()` 不是同一条规则，这是故意的**：`fmt_p()`
不传 `journal=` 时固定按 `eps`（默认 0.001）推出的位数四舍五入（对拍 `rcs_report.R` 的
`.peq`/`.pfmt`/`.pbare`，见 `tests/test_primitives.R` §1），`render_md.R::format_p()` 按期刊
风格分段舍入（>0.01 用 2 位小数，见 `docs/render_conventions.md`）——同一个 P 值（比如
0.046）默认情况下 Methods 正文可能写成 `"P = 0.046"`（`fmt_p()`，3 位固定小数）而表格里是
`"0.05"`（`format_p()`，AMA 风格 2 位小数），这不是缺陷，是两条**故意不同**的舍入规则（正文
习惯给更多有效数字，表格习惯紧凑）。如果某次写作确实需要正文和表格用**完全一致**的舍入规则，
给 `fmt_p()` 传 `journal=`（取值同 `render_md.R` 的 `THREE_LINE_STYLES`：
`generic`/`ama`/`jama`/`nejm`/`lancet`），这时数字部分会走和 `format_p()` 完全相同的舍入规则
（`tests/test_primitives.R` §5 逐一核对过两者在这个模式下的输出完全一致），只是 `P`/`p` 前缀、
`=`/`<` 运算符的拼法仍由 `fmt_p()` 自己的 `style`/`prefix` 参数控制。`report_engine.R`
本身不 `source()` `render_md.R`（保持零依赖），`journal=` 模式的数字舍入规则是在
`report_engine.R` 内部重新实现的一份（`.ms_fmt_p_journal()`），不是转发调用。
| `fmt_ci(lo, hi, digits)` | `.ci` | 两端都非负时用连字符 `"1.12-1.62"`，否则拼成 `"-2.80 to -1.32"` |
| `fmt_pct_direction(ratio_est)` | `pct_phrase` | `"35% lower"` / `"35% higher"`，方向由估计值本身推导 |
| `fmt_direction_word(estimate, null_value, higher, lower)` | （新增；把 pct 版本的"仅限比值尺度"推广成任意尺度的纯方向词） | `"higher"` / `"lower"` |
| `smart_round(v, x)` | `.smart_round` | 按原始变量 `x` 的取值范围决定 `v` 该保留几位小数再四舍五入 |
| `an(word)` | `.an` | 按发音而非拼写选冠词（`"a U-shaped"` 而不是 `"an U-shaped"`） |
| `ucfirst(s)` | `.ucfirst` | 只把首字母大写 |
| `oxford(v)` | `.oxford` | `"a"`、`"a and b"`、`"a, b, and c"` |
| `ordinal(p)` | `.ordinal` | `"5th"`、`"97.5th"`、`"22nd"` |
| `effect_label(model)` | `.effect_word`/`.effect_abbr`/`.null_value` 三个合并 | 对 `cox`/`logistic`/`poisson`/`linear` 返回 `list(word=, abbr=, null=, ratio=)` |

`tests/test_primitives.R` 会把以上每一个都和 `rcs-analysis/scripts/rcs_report.R`
的参考实现（只读方式 source 进来对拍）逐一对比，日后如果哪次改动破坏了一致性，
测试会直接报错。

## 注册一个模板

```r
declare_template(
  id    = "myskill.methods.core",
  text  = "The {{term}} between {{exposure}} and {{outcome}} was {{effect}} ({{p}}).",
  slots = list(
    term     = "text",
    exposure = "text",
    outcome  = "text",
    effect   = list(type = "effect_ci", label = "HR", digits = 2),
    p        = list(type = "p", prefix = "P")
  )
)
```

以下规则在**注册时**就会检查，而不是等到第一次 `fill()` 才暴露：

- `text` 里出现的每个 `{{name}}` 都必须在 `slots` 里有对应声明。
- `slots` 里声明的每个槽位都必须在 `text` 里至少用到一次——一个没被用到的
  槽位通常意味着死参数或者占位符写错了名字，会被立刻拒绝而不是悄悄忽略。
- `id` 必须形如 `skill.section.name`（字母、数字、`.`/`_`），例如
  `rcs.methods.knots`、`assoc.results.point_estimate`。请在自己 skill 的
  前缀下注册模板；`ms.` 前缀留给下面的共用骨架使用。
- 用同一个 `id` 调用 `declare_template()` 两次，且没传 `overwrite = TRUE`，
  会报 `OS_TEMPLATE_ALREADY_EXISTS`。开发调试时应该重启 R 会话或显式传
  `overwrite = TRUE`，而不是绕开这道检查。

### 槽位类型

| 类型 | `fill()` 期望的值 | 渲染成 |
|---|---|---|
| `text` | 单个字符串 | 原样插入（空字符串会被拒绝，除非设置 `allow_empty = TRUE`） |
| `list` | 字符向量 | 用 `oxford()` 拼接；可配置 `empty_text` 作为长度为 0 时的兜底（例如 `"no additional covariates"`） |
| `number` | 单个数值 | `sprintf(fmt, value)`，`fmt` 默认 `"%.4g"`；也可以传 `round_to = <原始变量向量>`，改用 `smart_round()` 而不是固定格式 |
| `p` | 单个数值 P 值（也接受 `NA`/`NULL`） | 完整句式 `"P = 0.032"` / `"P < 0.001"` / `"P not estimable"`；`prefix`、`eps` 可配置 |
| `p_bare` | 同 `p` | 裸格式 `"0.032"` / `"<0.001"` / `"NA"`，给表格单元格用 |
| `ci` | `c(lower, upper)` | 走 `fmt_ci()`；`digits` 可配置 |
| `effect_ci` | `c(estimate, lower, upper)` | `"HR 1.35 (95% CI 1.12-1.62)"`；`label`、`digits` 可配置；`conf_level`（2026-08-14 新增，百分数形式，如 `90`、`99`，不是 0-1 比例）可改写 `"95% CI"` 里的置信水平——不传时默认 `95`，产出和加这个功能之前逐字节一致 |
| `direction` | **单个数值估计量** | `"higher"` / `"lower"`（或自定义 `words = c(hi, lo)`），由 `estimate` 相对 `null_value` 的大小推导（默认 1，即比值尺度；差值尺度传 `scale = "diff"`，或直接指定 `null_value`） |
| `pct_direction` | **单个数值比值估计量** | `"35% lower"` / `"35% higher"`，走 `fmt_pct_direction()` |

`direction` 和 `pct_direction` 即使在只跑 `validate = TRUE` 这一层检查时也会
拒绝字符串值——这正是"方向词不能被手填、从而和旁边的数字对不上"这条硬性
要求的实现机制。如果你发现自己想传一个已经算好的方向字符串进去，那多半说明
这个字符串该走 `text` 槽位、出于别的理由存在（比如调用方自己选定的形态标签
`"U-shaped"`），而不是说明这里的类型检查应该放松。

## 填充一个模板

```r
fill("myskill.methods.core", list(
  term = "hazard ratio", exposure = "BMI", outcome = "all-cause mortality",
  effect = c(1.35, 1.12, 1.62), p = 0.003
))
```

- `fill()` 要求每个声明过的槽位都必须给值（否则 `OS_SLOT_MISSING`），也拒绝
  给从未声明过的槽位赋值（`OS_SLOT_UNKNOWN`）——这两种情况几乎总是调用方
  手误，而不是合法的"可选槽位"用法。可选从句请像 `rcs_report.R` 自己的段落
  函数那样在 R 里拼（分别生成几段文字，再用 `paste()` 挑选适用的部分）。
- `validate = TRUE`（默认）会对每个槽位做类型检查，不匹配时报
  `OS_SLOT_TYPE_MISMATCH` / `OS_SLOT_INVALID_VALUE`。`validate = FALSE`
  是一个刻意留的逃生舱——即便类型检查失败也不会硬停，而是退化成
  `paste(format(value))` 这种粗糙渲染——呼应本套件的原则："读者期待一个
  数字的地方绝不能得到『无法计算』"。只有在真的遇到无法归入现有槽位类型
  的奇怪形状时才用它（P 值本来就估计不出来这种情况，`p`/`p_bare` 槽位已经
  原生支持 `NA`，不需要 `validate = FALSE`）。

## 内置的共用句式骨架（`ms.*`）

有四个模板是预先注册好的，覆盖"不管哪个分析产出的数字，Methods 里都会原样
出现"的那几句话。优先用对应的便捷包装函数而不是直接调 `fill()`：

| 模板 id | 包装函数 | 覆盖的句子 |
|---|---|---|
| `ms.methods.software` | `software_statement(packages, alpha, r_version = NULL)` | "Analyses were performed in R 4.x.x using the X, Y, and Z packages; a two-sided P < 0.05 was considered statistically significant." |
| `ms.methods.alpha` | `alpha_statement(alpha)` | 只有 alpha 那句话，给自己组装软件声明句的模块用 |
| `ms.methods.missing_data_cc` | `missing_data_statement(variables, n_excluded, n_total)` | "Participants with missing data on ... were excluded under a complete-case approach (n of N excluded, X.X%)."——百分比永远由 `n_excluded`/`n_total` 现算，不允许手填 |
| `ms.methods.survey_weighting` | `survey_weighting_statement(artifacts, scope = "")` | "All estimates[, including ...,] incorporate the complex survey design ..., so that ... come from the same weighted model." |

这四个模板刻意做得很窄。像 `rcs_report.R` 里那种更完整的 survey 设计
Methods 措辞（LRT 还是基于设计的 Wald 检验、Davies 检验、拐点置信区间走
bootstrap 还是 segmented）应该留在各模块自己的 report 脚本里，就像
`rcs_report.R` 现在做的那样；只有"这些数字是加权的"这句通用声明才该复用
`ms.methods.survey_weighting`。

这里只登记英文句式。`lang` 不是引擎本身的参数：每个 skill 自己的 report
脚本决定要不要出中文稿（参见 `rcs_report.R` 的 `methods_cn`/`results_cn`——
它们是手写的，没有走模板，因为中文流行病学论文有自己固定的措辞习惯，
拆不进和英文相同的槽位结构）。如果你的 skill 需要中文稿，请照这个先例
写一个专门的函数，而不是把中文塞进和英文共用的同一套槽位里再复制一份。

## 内省（introspection）

- `list_templates(prefix = NULL)`——列出已注册的模板 id，可按前缀过滤
  （如 `list_templates("rcs.")`）。
- `get_template(id)`——取出存好的 `list(id, text, slots)`，方便 skill 自己
  生成文档。
- `clear_templates(ids = NULL)`——移除模板；主要用于测试隔离（在测试的
  setup/teardown 里调用，避免一个测试文件里的 `declare_template()` 和
  另一个测试文件冲突）。

## 错误码

本文件里的错误一律使用 `MS_` 前缀（全套件统一约定；`rcs-analysis` 自己的
CLI/引擎错误用 `RCS_` 前缀）。

| 错误码 | 触发时机 |
|---|---|
| `OS_INVALID_PARAMETER` | 模板 id/text/槽位声明格式不对，或槽位类型未知 |
| `OS_TEMPLATE_ALREADY_EXISTS` | `declare_template()` 用了已注册的 id，且没传 `overwrite = TRUE` |
| `OS_TEMPLATE_NOT_FOUND` | `fill()`/`get_template()` 用了未注册的 id |
| `OS_TEMPLATE_UNFILLED_SLOT` | `text` 里的 `{{name}}` 没有对应的槽位声明（在 `declare_template()` 时就会拦下）；或者作为最后一道保险，`fill()` 之后仍残留占位符 |
| `OS_SLOT_UNKNOWN` | `fill()` 给了一个模板从未声明过的槽位赋值 |
| `OS_SLOT_MISSING` | `fill()` 缺了某个已声明槽位的值 |
| `OS_SLOT_TYPE_MISMATCH` | 槽位的值类型/形状不对（包括给 `direction`/`pct_direction` 槽位传了字符串） |
| `OS_SLOT_INVALID_VALUE` | 类型对但值不合法（`text` 槽位给了空字符串却没设 `allow_empty`；`list` 槽位给了空向量却没设 `empty_text`） |
