# port_pub 发布检查移植报告

当前状态：已按协调者 2026-10-04 02:40 的范围授权原样应用两文件兼容性补丁；全部规定验收通过，lane 已完成；最终计数与协议结果见文末。

## 移植与组学适配

阅读了 scratch 中的 medstat 当前实现，移植了 `text_coverage` 和 `case_flow` 的值映射记录、PUB-U-003 / PUB-U-001 审阅发现及结果提纲提示。组学适配没有复制临床病例流假设。

- 特征结果按 `(contrast, feature_id)` 建键；汇总行按表路径命名空间及自然键建键，避免将 normalized counts 与 VST 等不同测量误判成同一个数值。既有 effect-table 比较逻辑保留。feature/native summary 表的发现独立于 R effect-table validator，不修改 server 或模块。
- 数值覆盖读取 `draft/*.md`、caption/legend 文本侧文件，以及实际模块生成的 `.figure_spec.json` 的 caption 字段。来源包括 canonical 表、results JSON 数值标量、QC evidence/observed/threshold/value 列。整数精确匹配，小数与科学记数按显示精度匹配；百分数可匹配比例。排除版本、年份、路径和带数字的标识符。未覆盖条目记录原始句子与文件。
- 可选 `draft/number_sources.json` 用带 `value` 与可追溯 `source` 的短列表声明非表格数字，格式已写入 `mcp/README.md`；无文件正常，错误声明保留诊断。
- feature ledger 记录 `filtered_reason` 分类，比较拟合行数、n_group1/n_group2 与结果分母；可用时再核对输入特征数 = 表中拟合特征数 + prefiltered-out。独立 padj filtering 不等于拟合前过滤。
- single-cell 支持 Seurat/scater 的 input/retained 汇总、Scanpy stage/n_cells 流、cell audit 的 pass/retained/discard，以及可用的生物学 sample/proportion 表。逐 sample/batch 的审计可防止相反方向错误被总数抵消；缺少独立匹配分母时标记 `not_present`，不产生自动 ledger pass/fail 发现。既有 PUB-U-001 通用人工审阅占位仍保留，以遵守原有 release-gate 断言。
- 两个自动门均为 warning、非 blocking、需要 human review；既有跨表数值冲突依然可阻断。universal catalogue 版本升至 1.1.0，在既有两条规则内列出新增自动检查记录，不更改规则类别及原本 requirement 的含义。

## 验证与证据

所有日志与真实运行输出位于 `/home/<user>/omic-sol61/port_pub/`，没有手写或重建 golden/lock，没有尝试 git commit；提交由外部 helper 按 lane worklog 执行。

- `omicstat-r:2026.10.1` 内执行 DESeq2 Wald 和 Seurat QC 原有 smoke，均退出 0，输出完整保留于 `smoke/`。未下载重复 anchor 数据。已打开 smoke 产生的全部 38 张 PNG，通过 10 张带路径标签的 contact sheet 检视；图形内容正常，部分 bulk 密集标签较拥挤，保留为人工视觉审阅事项。
- `mcp/test_publication.py` 新增 13 个测试，涵盖完整覆盖、未覆盖句子、caption JSON、precision/科学记数/百分数/区间、版本年份排除、allow-list/QC evidence、feature ledger 匹配/不匹配/缺证据、contrast 隔离、native measurement 隔离、prefilter 核对、Seurat/Scanpy 流及 sample 总数/分组核对。
- 最终主机通过项目 `.venv/bin/python -m unittest mcp.test_publication` 运行 73 个测试：零 failure/error，5 个 native 环境 skip。容器 `/opt/omicstat/venv/bin/python` 同命令运行 73 个测试：零 failure/error，2 个 skip。为避免已安装 MCP SDK 与仓库同名目录的 import 冲突，仅使用 scratch 的 `bootstrap/sitecustomize.py` 扩展 SDK package search path，不修改 SDK 或仓库 package 配置。日志：`unit_host_final.log`、`unit_container_final.log`。
- catalogue 最终验证通过：21 modules、28 unique rule IDs；universal 精确要求 1.1.0，module 精确要求 1.0.0。日志：`catalogue_final.log`。
- 客户端对实际磁盘 manifest/review schema 和 clean-run publication status 的断言已补充；compact envelope 自身缺少磁盘专属必需字段，因此不当作完整 PublicationManifest 校验。最终协议结果见文末。

## 两个真实运行的覆盖示例

| 项目 | bulk：DESeq2 Wald `smoke/deseq2-wald-smoke/a2` | single-cell：Seurat QC `smoke/qc_anchor` |
|---|---|---|
| 数值出现次数 | 45 | 58 |
| 被覆盖次数 / share | 39 / 0.8666666666666667 | 53 / 0.9137931034482759 |
| 未覆盖次数 | 6 | 5 |
| canonical 来源 | feature_table、size_factors | cell_qc、filter_flow |
| 分母独立比较 | 4 次，0 mismatch | 3 次，0 mismatch |
| 核心分母 | 8,148 tested；target 3、reference 4；prefilter accounting 一致 | 2,700 input；2,638 retained，results JSON 与逐细胞审计一致 |

bulk 未覆盖例为灰色非显著点数 7,295、heatmap top 50、z-score clip ±2，分别在草稿和 sidecar 重复出现；这些派生或绘图常数尚未作为单独数值来源写出。single-cell 未覆盖的 5 次均为 “Mitochondrial-pattern features present=13”，来自草稿及 caption；结果 JSON 只在 details 字符串内记录该值，并无独立数值标量。本 lane 不允许改写模块，因此如实提示人工审阅，未增补模块来源文件。完整值映射分别在 scratch 的 `bulk_value_map.json`、`single_cell_value_map.json`。

## 局限与兼容性处理

数值与某处来源相等只证明可追踪，不证明描述对象、方向、因果措辞或统计解释正确；还需人工核对。DOCX 不扫描。未识别的 ledger 布局、缺失结果分母或缺少 sample 身份证据时不推算分母。cell 数不能代替生物学重复数。年份与版本的排除是词法规则；标准数值未单独输出时可能出现合理的 warning。

协调者在任务文件中明确批准原样应用 `/home/<user>/omic-sol61/port_pub/compatibility.patch`，已完成两项修改：

1. `skills/_shared/schemas/publication_review.v1.schema.json` 的 finding check_status 枚举加入 `pass`，保留其他验证约束。
2. `skills/_shared/publication/test_publication_rules.py` 将 universal 的精确版本期望改为 1.1.0，module 仍为 1.0.0。

未修改其他范围外文件，没有放松断言或数值容差。

## 最终协议验收

`mcp/test_client.py` 与 `env/py/test_e2e.sh` 最终均退出 0：各 98 assertions、98 passed、0 failed、3 skipped。skip 原因是主机没有 Rscript/native 环境；两条 pinned-container 路线均实际运行。完整磁盘 manifest/review schema 通过，R 与 Python clean run 的 publication status 均为 `needs_input`。日志分别为 `client_final.log`、`e2e_final.log`，输出保留于 `client_final/`、`e2e_final/`。

首次最终客户端调用误将 RUNS_ROOT 设为输出目录的子目录，产生路径策略拒绝；修正 scratch/run-root 配置后完整复验通过，没有修改路径策略。已打开最后两轮产生的全部 6 张 PNG（带路径标签的 `client_final_sheet.png`、`e2e_final_sheet.png`），volcano 与 UMAP 可读、非空且没有裁切。自动生成的 `env/py/e2e_report.txt` 已恢复为原始内容，未将范围外测试产物纳入改动。

所有要求已完成，lane worklog 最后一行为 `DONE`；未尝试手工 git commit，仍由外部 helper 提交。
