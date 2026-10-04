# edger-qlf 独立 S3 验收

Pinned: `build/m1m2@2ddf174fb36cbaa3c280af00b52b92fe7f039d04`。

- [x] PACK C/L1：核读 User's Guide §4.4（rendered:2639,2679,2696–2728），printed 15969、0.0134、0.013、QLF 2607/10546/2816、Treat 1533/12573/1863。当前引擎为 2608/10546/2815 与 1535/12570/1864，区别确实存在，但“仅版本差异”的解释被独立探针否定，见 F1。
- [x] PACK T：全表 15969 行，QLF 的 logFC/logCPM/F/PValue/FDR 与 Treat 的 unshrunk.logFC 均保留；canonical schema 和 Down/NotSig/Up 齐全，展示筛选不改全表。
- [x] PACK W：读 a1/treat 草稿与 JSON，版本、设计、TMM、过滤、robust/new QL、BH、最小效应与展示筛选分开且数目一致。
- [x] Mechanical/S1：core:42–67 的 DGEList/filterByExpr/normLibSizes/estimateDisp/glmQLFit/glmQLFTest/glmTreat/topTags/cpm 与 registry、附录逐项核对；默认 dispersion=NULL、legacy=FALSE、robust=TRUE、winsor、poisson.bound/null 均显式。静态检查、legacy/display 参数效果、spec 表/PNG/spec 字节回放、handoff/篡改/校正输入拒绝、golden PASS、无 Rplots.pdf；SMOKE PASSED / EXIT 0。
- [x] Figures：逐张打开 a1 与 treat 的 volcano、md、bcv、top_heatmap 共八张 PNG，轴、标签、图例可读；图注含 n 与阈值。PACK 指定诊断未齐，见 F2。

证据目录 `/home/<user>/omic-s3-runs/edger-qlf/`。`run_locked.sh edger-qlf review-final Rscript skills/edger-qlf/tests/run_smoke_test.R`；首次缺 fixture 的 SKIP 不算验收，复制任务指定锚点后重跑，最终 golden PASS。额外 `_s3/dispersion_probe.R` / `dispersion-probe.log` 按指南原代码先 estimateDisp 再 glmQLFit，完全不调用引擎；`method_probe.R` 打印锁定 glmQLFit.DGEList 的参数转交源码。

## 闭口返修清单

1. **F1 — PACK C / S1 P-1**：`skills/edger-qlf/tests/run_smoke_test.R:47–69,80` 与 `acceptance/exemplars/edger-qlf/S3_REQUEST.md` 将不一致归为 4.9.9→4.10.5。实测同一 4.10.5、指南完整 `y <- estimateDisp(y,design,robust=TRUE); glmQLFit(y,design,robust=TRUE)` 得 QLF **2607/10546/2816**、Treat **1533/12573/1863**，恰为打印值。当前引擎按 S1 用未运行 estimateDisp 的 y 并显式 dispersion=NULL；这两条路径的 QLF 最大 P 差 0.002497297，Treat 最大 P 差 0.00244725。以未 estimateDisp 输入独立回放则 Treat 最大 P 差 4.999845e-11。故“版本导致”缺乏支持，不能作为 printed anchor 的豁免。保留冻结引擎，在验收中分别跑指南原路径与套件路径，准确标注差别、向所有者报告 PACK C/S1 P-1 的衔接；不要为追打印值擅改估计器。并补 C 指定 dispersion 断言：独立实测 common=0.0134413085635106，首项 QL dispersion=0.0129556217857436，对应打印精度 0.0134/0.013（先明确后者的首项口径）。补充独立 `_s3/cache_probe.R` / `cache-probe.log`：只向未经 estimateDisp 的 y 复制指南对象的 AveLogCPM，QLF P 与完整指南路径最大差 **0**，与原始 suite 路径差 **0.002497297**；AveLogCPM 最大差 **0.2674049**。因此本例差异可定位到 estimateDisp 缓存的 AveLogCPM 经 glmQLFit.DGEList 传入，而非简单“新 QL 使用旧 dispersion”。Builder 坦诚披露差值是正确的，但归因与验收处理不充分。
2. **F2 — PACK F**：`scripts/edger_qlf_report.R:32–54` 只产生 volcano/MD/BCV/heatmap，缺 PACK 指定的 QL dispersion 与 MDS；S3_REQUEST 将其称作范围外不能改写冻结 PACK。补统一图层的 raw/squeezed/trended QL dispersion 与样本 MDS，图注注明参数、n 和适用阈值，检查所有图；或取得明确的 PACK 范围修订。

所有者项：不交接无方向 QL F 的 ranked_list 属安全行为；其排名公式未冻结，不因缺该未定 producer 单独判失败。cpm 的 formals 来自锁定容器，来源说明诚实。

NEXT STEP: S4 按闭口清单修复。
VERDICT: FAIL
