# build_m1b：limma 三模块 S2 构建报告

工作树 `/home/<user>/omic-build-m1b`，分支 `build/m1-limma`；全部 R 构建、锚点回放、golden 和模块锁使用 `omicstat-r:2026.09.1`（limma 3.68.5、edgeR 4.10.5）。本报告只陈述本构建道的 S2 结果；独立 S3 审核另见各模块的 `S3_REQUEST.md`。

## 需所有者确认的事项

1. **limma-voom 的新调用集。** 已先在 `acceptance/exemplars/limma-voom/L1_bioc3.23/` 导出锁定 edgeR 4.10.5 的 `voomLmFit` Rd、渲染文本、formals 和 sha256 清单，再按冻结 P-1 实现。默认调用的每一个参数值列在 `S3_REQUEST.md` 的「Needs owner confirmation」；请确认该完整调用集，以及下游 camera/GSVA 对 `MArrayLM` 和保存的 `EList` 的契约。`--sample-weights` 默认关闭，启用时将各样本估计权重写入结果 JSON。可选 `treat` 同时显式传线性 `fc` 与 `log2(fc)` 的 P-2 暂定写法，也待确认。
2. **非 Agilent 芯片的预设。** 冻结决定只给 Agilent `trend=TRUE, robust=TRUE`。limma-array 和 limma-dupcor 对其他平台要求用户显式给 `trend`、`robust`，并输出 SA 均值方差诊断；请决定是否登记其他平台预设、背景证据的 0/1 矩阵契约，以及是否要求原生 `plotSA` 图。Illumina 指南锚点回放使用指南的 `trend=TRUE, robust=FALSE`；该设定不影响在 moderation 前求出的相关系数。若 S3 要断言其 DE 表，应先确认回放设定。
3. **Yoruba 印刷锚点差异。** §18.1 印刷第二轮一致性相关为 0.446；本锁定环境按源流程对 F10 直接回放为第一轮 0.4449716、第二轮 0.4454514，后者三位小数为 0.445。请由 S3 独立核查并裁决此印刷精度差异。构建未为匹配印刷值修改估计器或过滤规则。
4. **limma-array 全例锚点范围。** 指南 §17.4 的 27024 探针及 RT1-Bb logFC 9.33 需要 `RnAgilentDesign028282.db` 注释；锁定镜像未提供。当前 10 阵列子集回放不声称复现这些全例印刷值。若 S3 要断言全例值，需先提供锁定注释依赖并确定全例对比。

## 各模块 S2 结果

| 模块 | S2 状态与提交 | 锚点、来源和结果 | 测试及图片 |
|---|---|---|---|
| limma-voom 1.0.1 | 完成；主提交 `e9772bd`，图表与权重报告更新 `ffe1ff3` | F4 `GSE63310_RAW.tar`，sha256 见 ANCHOR_REGISTRY 第 5 行；5000 个输入基因、5 样本，`filterByExpr` 后 3320 个检测基因、BH 0.05 下 17 个发现。所选 2 对 3 测试分组与锁定包直接回放的原始及 BH P 值一致；这是子集回放锚点，并非文献生物对比。 | 容器 smoke/golden 通过；`treat`、显示过滤、旧 `voom`/`lmFit` 复现路线、样本权重效果、typed error、`--from-run` 与篡改拒绝、`--spec` 表格/PNG/图规字节重放均通过。火山图与 MD 图均已打开，文字不裁切，图注含 n 和阈值。 |
| limma-array 1.0.1 | 完成；主提交 `ffa1980`，图表 golden 更新 `ffe1ff3` | F5/F6 `GSE33005_RAW.tar` 与 SDRF，sha256 见 ANCHOR_REGISTRY 第 6 行；按 §17.4 背景校正、分位数标准化后取 5000 探针及 5+5 阵列，控制探针与检测证据过滤后 3867 个检测探针、BH 0.05 下 142 个发现。原始及 BH P 值与锁定 limma 直接回放一致；这是子集值。 | 容器 smoke/golden 通过；Agilent 预设及覆盖、背景 k、经核实技术 ID 的 `avereps`、`treat`、显示过滤、非 Agilent 显式参数、typed error、handoff、重放均通过。火山、MD、非 Agilent SA 图已打开；图注、坐标和标记清晰。 |
| limma-dupcor 1.0.0 | 完成；提交 `dd07c84` | F7-F9 Illumina §17.3：24691 表达探针，12 阵列、3 个 donor 各 4 阵列；估计一致性相关 0.1344848639，对应指南印刷 0.134。F10 Yoruba §18.1：16918 过滤基因、86 测序文库，两轮 0.4449716 / 0.4454514；印刷 0.446 差异已明示。源文件 sha256 与回放脚本见 `S3_REQUEST.md`。 | 容器 smoke/golden 通过；RNA 两轮、估计值显式传入 `lmFit`、block 重复/满秩/可估性拒绝、技术批次理由、`treat`、显示过滤、handoff、篡改拒绝及字节重放均通过。Illumina 火山、MD、SA 及 RNA 火山、MD 图已打开；密集 MD 点已调整为可读尺寸，图注写 n 与适用阈值。 |

三模块 `module_lock.json` 均在锁定容器生成并以 `--check` 验证通过。各模块静态调用注册及锁定默认检查、参数文档检查和 R lint 均通过。运行输出位于 `/home/<user>/omic-build-logs/build_m1b/<module>-smoke/`；各模块 golden、工作日志和 S3 请求在相应 `skills/<module>/`、`acceptance/exemplars/<module>/`。

## 共用代码变更

- 新建 `skills/_shared/scripts/fig_mod_bulk_limma.R`，并在 `fig_all.R` 列表末尾装入；统一三模块火山、MD、SA 图。密集 MD 图改用现有样式令牌的小点大小和红/蓝/灰显著性编码，三模块重跑 golden。补充 `FIGURE_STYLE.md` 说明。
- 新建 `skills/_shared/scripts/limma_io.R`，集中设计矩阵与 block 校验、标准 feature table/QC、图表、Methods/Results、结果 JSON、provenance 和 handoff。为 limma-dupcor 允许多水平条件，并按冻结 P-2 将最小残差自由度设为 2；结果 JSON 保留足够精度记录相关系数。
- 未修改 M1 所属的 `fig_mod_bulk.R`、`bulk_io.R`，未修改 M2/M2b 文件。模块自身的估计器调用留在各自 core 和调用注册表。

## 偏离与未完成事项

相对冻结 S1 决定的实现偏离：**无**。与指南印刷锚点的数值/范围差异是上述 Yoruba 三位小数差异，以及 limma-array 因锁定注释缺失只完成标准化输入子集回放；均已留给独立 S3 核查。

独立 S3 验收、router 行与 `module_rules_v1.json` 安装、SUITE 更新及 S5 安装**未执行**，因为共同任务明确禁止本构建道自验和安装。每个 `S3_REQUEST.md` 已给审核点、锚点来源、输出路径、已知限制和拟议 router/rules 记录。未推送分支。
