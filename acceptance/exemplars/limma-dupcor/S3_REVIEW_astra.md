# limma-dupcor 独立 S3 验收

Pinned: `build/m1-limma@fd2b8d714bd581d9de9dcc9d693570b4bad26bda`。

- [x] PACK C/L1：Illumina F7–F9 read.ilmn→neqc→Detection<0.05/至少3阵列是指南源流程，24691 探针、consensus=0.1344848639，三位小数匹配 printed 0.134（L1 usersguide.rendered.txt:6526）。Yoruba F10 replay 也直接调用源 voom/duplicateCorrelation 两轮，非引擎函数；源 :6963 确实把 concentration 转成 factor，:7402/7410 打印 0.446。独立运行现有源回放实际为 0.4449716 / 0.4454514；后者四位小数 0.4455，但三位小数为 0.445，并非 0.446 的合法舍入。
- [x] PACK T：canonical feature table 与 limma_full 含 logFC/AveExpr/t/P/BH/B，排序与 schema 合理；JSON/草稿含 block 定义、数目、大小、相关和轮次。
- [x] PACK W：实读 a0/rna0 草稿，limma 版本、design、contrast、BH、block 和估计相关正确；RNA 方法链与参数缺失见 F2。
- [x] Mechanical/S1：逐行核 core:18–71 与 registry。相关是估计值而非示例常数，显式传 lmFit；RNA 两轮；Agilent trend/robust TRUE，其他平台须显式参数；重复单位、spanned block、rank、残差df与 technical rationale 检查合理。静态登记/漂移/defaults/docs/lint、treat/display、spec 字节回放、handoff/篡改、golden PASS、无 Rplots.pdf，SMOKE PASSED / EXIT 0。
- [x] Figures：亲眼打开 a0 volcano/MD/SA 与 rna0 volcano/MD，标签/轴无遮挡裁切。全部 spec 含数量，推断图含 BH 阈值。PACK 的 MDS 缺失见 F3。

证据目录 `/home/<user>/omic-s3-runs/limma-dupcor/`。`run_locked.sh limma-dupcor review-final Rscript skills/limma-dupcor/tests/run_smoke_test.R`；日志 `_s3/review-final.log` 保留 printed gap 原值。另有 numeric concentration 探针，但源明写 factor，数值型不是可替代指南流程。

## 闭口返修清单

1. **F1 — PACK C / S1 P-1**：`skills/limma-dupcor/tests/run_smoke_test.R:89–94` 对 Yoruba 仅检查 finite，并打印 ANCHOR GAP 后仍 SMOKE PASSED；未让 RNA 引擎运行该锚点并核对结果。Builder 如实报告差异且未改估计器，这点诚实；但不足以满足 printed 验收，也不能以 0.4455 近似掩盖三位打印差异。补源版本/预处理证据解释 0.446，保留严格 printed 检查；若确认源版本差异，则取得锚点修订并登记 locked replay 数值断言。将源回放与引擎的输入/过滤差异明确分开并覆盖 RNA 计算输出，不以 synthetic finite 检查替代。
2. **F2 — PACK W / D-D2 / S1 P-1**：`scripts/limma_dupcor_core.R:74–77` 和 `_shared/scripts/limma_io.R:96–106` 的实际 RNA Methods 不含 edgeR 版本、filterByExpr/TMM/voom，只有“2 estimation round(s)”；trim、voom 设置、moderation 参数也不全。按实际路径报告完整两轮 voom→duplicateCorrelation、模型/相关、过滤/标准化与结果相关参数，保留现有 block 信息。
3. **F3 — PACK F**：`_shared/scripts/limma_io.R:84–89` 只有火山、MD、可选 SA；补 PACK 明列样本 MDS（RNA 同时使 voom 诊断可审查），含输入尺度、n/标记与图注；或先取得 PACK 范围修订。

所有者项：非 Agilent/Illumina moderation 待定已安全要求显式 trend/robust；现有 Illumina correlation 的 printed 判断不依赖其 eBayes 选择，不因此判失败。

NEXT STEP: S4 按闭口清单修复。
VERDICT: FAIL
