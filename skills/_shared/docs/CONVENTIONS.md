# `_shared` 层项目约定（omicstat）

新建模块或往 `_shared` 加代码前先读一遍。发现代码与这里写的不一致时，先改到一致，再继续手头的活。

## 1. 两张正典结果表

| 表 | 定义 | 用途 |
|---|---|---|
| **feature table** | `scripts/feature_table.R` 的 `FEATURE_TABLE_SCHEMA`（14 列：`feature_id`、`symbol`、`contrast`、`base_mean`、`log2fc`、`log2fc_se`、`stat`、`pvalue`、`padj`、`method`、`shrinkage`、`n_group1`、`n_group2`、`filtered_reason`） | 一切“每个特征一行”的组学结果（差异表达、pseudobulk、marker 等）；MCP 按列头识别为主载荷 |
| **effect table** | `scripts/effect_table.R` 的 `EFFECT_TABLE_SCHEMA`（`analysis_id`、`term`、`estimate`、`ci_low`、`ci_high`、`p_value`、`p_adjusted`、`n_unweighted`、…；细节见 `docs/effect_table_schema.md`） | “一个效应量 + 置信区间”一行的结果（细胞比例检验、模块–性状关联等） |

模块不得另起列名（例如 `lfc`、`FDR`、`p_adj`）；展示用的列名在渲染层转换，结果表本身保持正典名。持久化一律走 `write_feature_table()` / 对应 validator CLI，保证字节可复现。

## 2. `.R` 源码只用 ASCII

Windows 上 GBK locale 会把 UTF-8 源码里的中文、弯引号、长破折号读坏。所有 `.R` 文件（含注释）只用 ASCII；图中需要的 −、×、± 在字符串里写成 `−` 这类转义。Markdown 文档不受此限。`tests/test_figures.R` 的 T6 检查全部 `_shared` 下 `.R` 文件为纯 ASCII。

## 3. 错误码：`OS_*`

所有给调用方做程序化判断的错误/警告码以 `OS_` 开头、全大写下划线分隔，后接一句人类可读的说明。先复用已有家族：`OS_SCHEMA_*`（表结构）、`OS_MISSING_*`（依赖/文件/列缺失）、`OS_INVALID_*`（输入不合法）、`OS_HANDOFF_*` / `OS_ECOSYSTEM_MIXED` / `OS_CONTRACT_MISMATCH`（`--from-run` 链）、`OS_FIG_*`（图形质检）、`OS_ENV_*`（R 环境）、`OS_DEGENERATE`（数值退化）、`OS_UNKNOWN_FLAG` / `OS_CONFLICTING_PARAMETERS`（命令行，§14）、`OS_ENGINE_WARNING`（阶段内警告，§15）、`OS_INVALID_DESIGN`（实验设计，§16）。

转换错误码：`OS_CONVERT_LAYER_MISSING`（命名 assay/layer 缺失）、
`OS_CONVERT_LAYER_ROLE`（原始计数/归一化角色不符）、
`OS_CONVERT_UNSUPPORTED`（无法无损表示）、`OS_CONVERT_MISMATCH`（转换后核对失败）。
协调员可逆决定 4：Python→R 中立后端保留 upstream `front_end_ecosystem`，
记录 `backend_ecosystem: neutral`，以 `OS_ECOSYSTEM_CROSSING` 信息级 QC 提示跨生态，
不拒绝、不创造新标签；前段切换生态仍以 `OS_ECOSYSTEM_MIXED` 拒绝。


## 4. 共享小工具 `%||%`

每个 `_shared` 脚本都**无条件**定义自己的 `%||%`（“NULL、零长度或单个 NA 时取默认值”），**不要**加 `exists()` 守卫：R ≥ 4.4 自带语义更窄的 `base::%||%`，守卫会让行为随 source 顺序改变。需要第二个跨脚本 helper 时，再统一建 `scripts/utils.R`。

## 5. 图形设备卫生

1. 图构建函数一律返回对象（`invisible()` 或赋值），不在顶层自动 print；保存只走 `os_save_figure()` / `os_finalize_figure()`，它们打开、关闭设备，并在绘制失败时删掉半成品文件。
2. 每个模块的 `run_smoke_test.R` 必须能从任意工作目录运行，并在末尾断言没有产生 `Rplots.pdf`。

## 6. 图形：唯一规范是 `docs/FIGURE_STYLE.md`

- 所有模块的图只能通过 `scripts/fig_*.R`（`fig_all.R` 一次载入）生成；模块代码中**不得出现**颜色十六进制值、字号、线宽、点形状或文字位置的字面量。缺图型就先扩展 `_shared`。
- 保存一律走 `os_finalize_figure()`（先 lint，再写 PDF + PNG + `figure_spec.json`）。
- 簇、细胞类型、条件的颜色经 `objects/colour_registry.json` 随 `--from-run` 链传递，下游必须读入并沿用。
- 修改任何 token：升级 `OS_FIG_STYLE_VERSION`、同步 `FIGURE_STYLE.md` §14、跑 `tests/test_figures.R`、重新生成并目视检查 `docs/figure-gallery/`。

## 7. UTF-8 字符 locale

渲染 −、× 等字符需要 UTF-8 的 `LC_CTYPE`。容器里设置了 `LANG=C.UTF-8`；原生环境下 `fig_style.R` 载入时若 locale 不是 UTF-8，只切换 `LC_CTYPE`（不动排序与数字格式）。

## 8. 基因 ID

- 内部键一律为**不带版本号**的 Ensembl ID（`ENSG00000141510`，不是 `ENSG00000141510.17`）；`as_feature_table()` 自动去版本号，`validate_feature_table()` 拒绝带版本号的 ID。
- symbol 只用于显示，不作连接键；symbol 缺失时显示 feature_id。
- 一对多 / 多对一映射与丢失率的处理规则由各模块 PACK 裁决后补入本节；映射丢失率 > 5% 为 QC 警告。

## 9. `--from-run` 交接

`scripts/handoff.R`：上游 `write_handoff()` 写 `objects/handoff.json`（对象类型 + sha256 + 生态 + 合同哈希 + `upstream_runs` 链）；下游 `read_handoff()` 先校验再读对象。类型化拒绝：`OS_HANDOFF_MISSING`、`OS_HANDOFF_MISMATCH`、`OS_ECOSYSTEM_MIXED`、`OS_CONTRACT_MISMATCH`。MCP manifest 的 `upstream_runs` 字段直接读这个键。

## 10. 同一产出物内部格式自洽

散文里的 P 值（`report_engine.R::fmt_p`）与表格单元格里的 P 值（`render_md.R::format_p`）舍入规则可以不同，但**同一张表、同一段文字内部**必须只用一套规则。图内 P 值统一用 `fig_style.R::os_p_plotmath` / `os_p_text`。

## 11. R 环境

引擎只在 omicstat 自己的 R 环境中运行（`env/omicstat-env.json`）：容器 `omicstat-r:<env_version>`（金标准所在环境），或 `env/native/setup_native.R` 建的隔离库（`Rprofile.omicstat` 保证搜索路径只有 omicstat 库 + R 基础库）。模块代码不得假设任何其他 R 安装、用户库或站点库存在。新增 R 包 = 改 `env/layers/*.txt` + 升级 `env_version` + 重建镜像 + 重跑金标准。

## 12. 并行 agent 的临时文件带模块名前缀

多个 agent 同时往 scratchpad 写临时文件时，文件名必须带自己负责的模块/任务前缀（如 `deseq2-wald-probe1.R`），避免同名覆盖。只管临时文件；正式产物有各自固定的位置与命名。

## 13. `docs/` 文件名避开 “report”

部分编辑工具会拦截文件名含 `report` 的写入；新文档优先用 `*-summary.md`、`*-findings.md` 之类的名字。

## 14. 命令行 flag：一份 spec（`scripts/args.R`）

- 入口脚本用 `os_arg_spec()` + `os_flag(name, type, required, default, help, values, range, requires, must_exist)` 声明全部 flag；类型 `int` / `num` / `string` / `path` / `enum`（需 `values`）/ `bool`（裸开关，不带值）；`exclusive = list(c("a", "b"))` 声明互斥组。**同一份 spec** 负责解析（`os_parse_args()`）、默认值与 `--help`（`os_print_help()`），不再手写 `KNOWN_FLAGS` 和帮助文本。
- 类型化错误：`OS_UNKNOWN_FLAG`（未声明的 flag 或游离值）、`OS_MISSING_PARAMETER`（必需 flag 缺失、flag 缺值、`requires` 未满足）、`OS_INVALID_PARAMETER`（类型 / 枚举 / 范围 / 路径不存在，消息写 “expected …, got '…'”）、`OS_CONFLICTING_PARAMETERS`（互斥组同时出现、同一 flag 出现两次）。spec 本身写错（默认值不过校验等）报 `OS_INVALID_ARG_SPEC`。`--help` 优先于一切校验。
- `--help` 行格式（机器可读，`tools/check_defaults.py` 与 MCP 白名单都读它）：`  --<flag> <TYPE>  required|default: <value>  <说明>`；TYPE 为 `int`、`num`、`string`、`path`、`switch` 或枚举值用 `|` 连接，范围写成 `<num in [0, 1]>`；默认值：整数原样、开关 `off`、无默认 `none`；列之间至少两个空格，所以默认值里不能有连续两个空格。说明文字里只出现真实存在的 `--flag`（MCP 用正则 `--[A-Za-z0-9][A-Za-z0-9-]*` 从整段帮助里取白名单）。
- 具名颜色 / 标签映射用 `os_check_named_values(values, levels, what)` 检查是否覆盖每个水平；不全时以 `OS_INVALID_PARAMETER` 停止并打印 `[x]` / `[ ]` 对照表（ASCII）。

## 15. 引擎警告全捕获（`scripts/engine_run.R`）

- `elog <- os_engine_log_new(outdir)`；compute / render / qc 等阶段一律写成 `os_engine_capture(<阶段表达式>, "<stage>", elog)`。
- 每条 warning 和 message 连同阶段名写入 `qc/engine_warnings.csv`（列 `stage, type, message`；无条件时只有表头；每个阶段结束和出错时都重写，所以运行中断也留得下）。warning 同时以 `OS_ENGINE_WARNING: [<stage>] <msg>` 打到 stderr，供 MCP manifest 的 `engine_warnings` 控制台扫描读取；message 照常打印、不压制。
- error **从不**被压制或改写：记录一行 `error` 后原样向上抛。`options(warn >= 2)` 时 warning 仍按调用方意愿变成 error。
- 捕获期间临时调高 `warning.length`（C 层引擎警告否则截断到 1000 字节）并钉住 `warn`；两者在退出时（包括出错、阶段自己改过）恢复。
- QC 层可以用 `os_engine_counts(elog)` 把警告数变成规则；阈值属于模块 PACK。

## 16. 设计校验（`scripts/design_check.R`）

- `os_check_sample_condition(sample_table, sample_col, condition_col)`：每个样本只能属于一个条件，否则 `OS_INVALID_DESIGN` 并列出违规样本及其条件；条件缺失也是 `OS_INVALID_DESIGN`；缺列为 `OS_MISSING_COLUMN`。
- `os_align_pairs(df, id_col, group_col, groups)`：配对**只按 id 内连接**，结果按 id 排序（与行顺序无关）；同组内 id 重复 → `OS_INVALID_DESIGN`；id 为 NA 的行丢弃并计数（`n_na_id_dropped`，警告 `OS_DESIGN_NA_ID_DROPPED`）；没配上的 id 放在 `unpaired`。**禁止按行顺序配对。**
- `os_replicate_counts(sample_table, condition_col, sample_col)` 返回每组生物学重复数；`os_classify_replicates(counts, blocker_below, warning_below)` 按传入的阈值分 blocker / warning / ok。阈值（例如 < 2 blocker、< 3 warning）由模块 QC 层按 PACK 传入，`_shared` 里不写死。

## 17. 默认值一致性（`tools/check_defaults.py`）

- `python tools/check_defaults.py skills/<module>` 比对同一 flag 在以下各处的默认值，不一致即失败：`--help`（§14 行格式）；`scripts/calls_registry.json` 顶层 `"flag_defaults": {"--seed": 20260925}` 与已登记参数上的 `"flag": "--alpha"`（其 `value` 即 flag 缺省时引擎收到的值）；`SKILL.md` 与 `references/*.md` 里表头含 `Flag` 和 `Default` 两列的表格；正文中的标记 `<!-- default --alpha -->0.05<!-- /default -->`（Methods / 报告模板里把数值写进散文时用；代码块和行内代码中的标记视为示例、不读）。
- 比较前规范化：去掉反引号、引号和结尾的 “(说明)”；`off/false/absent` → `off`；`none/-/--/n/a` → `none`；`(required)` → `required`；数值按数值比较（`20260925` = `20260925L`）。文档里出现 `--help` 没有的 flag、或 `--help` 的 flag 行不符合格式，也算失败。
- 由 `tools/run_tests.sh`（每个有 `scripts/run_*.R` 的模块）和模块 `run_smoke_test.R` 调用。

## 18. 引擎卫生 lint（`tools/lint_r.py`）

扫描 `skills/*/scripts/*.R` 与 `templates/module/scripts/*.R.tmpl`（`tests/`、`fixtures/` 目录豁免），在去掉注释和字符串内容后做简单文本匹配：

| 规则 | 拦截 |
|---|---|
| LR01 | `options(warn = <负数>)` |
| LR02 | `suppressWarnings()` 包住整个阶段：参数是 `{ }` 块、跨行，或调用 `*_compute/_render/_qc/_report/_draft`、`os_engine_capture`、`source`；单行类型转换如 `suppressWarnings(as.numeric(x))` 允许 |
| LR03 | `set.seed()` 的第一个参数不是变量（`seed`、`args$seed`、`args[["seed"]]`），即字面量或表达式 |
| LR04 | `sample()`、`sample.int()`、`rnorm()`、`runif()` 不在已设种子的作用域内：所在函数（或外层函数、文件顶层）在调用之前没有 `set.seed()` 或同文件定义的播种 helper，也不在 `with_seed()` / `withr::with_seed()` / `os_with_seed()` 内 |

确需例外时在该行末尾写 `# lint-ok LR0x: <理由>`。

## Accepted Methods reference layouts (S5, 2026-10-04)

M1/M2 use `references/reporting-templates.md` with fenced `template` blocks;
slim back-end/M4 modules may use `references/methods-template.md`. Both are
accepted without renaming. `check_flag_docs.py` reads SKILL.md and every
references/*.md file; `check_defaults.py` reads Flag/Default tables and inline
default markers in those files, not unrestricted template prose.

## Marker grouping and scientific refusals

An exposed native option must never bypass a scientific refusal. Marker modules describe cell-level labels, which must vary within at least one sample; sample identity and variables constant within every sample are refused. Without sample information, only the chain’s own cluster column is allowed. Condition effects belong to muscat-pseudobulk (expression) and speckle-propeller (proportions), where samples are the replicates. Cell-level marker P values rank descriptive comparisons and are not evidence of differential expression between biological groups.
