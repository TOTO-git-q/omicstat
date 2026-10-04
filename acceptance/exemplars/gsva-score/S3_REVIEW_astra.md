# gsva-score — S3 独立验收

固定版本：`build/m2-rank@e36b77f44ac7e492adacb371c8c6922e7e23a256`。运行目录 `/home/<user>/omic-s3-runs/gsva-score`；代码行号相对此 checkout。仅审查，未改引擎。

- [x] 阅读 PACK T/W/C/F 和 S1 P-1–P-3、S3_REQUEST、build_worklog、BUILD_REPORT。
- [x] 锁定容器 `bash /home/<user>/omic-s3-runs/run_locked.sh gsva-score review-final Rscript skills/gsva-score/tests/run_smoke_test.R`：`_s3/review-final.log` SMOKE PASSED / EXIT0；calls/default drift/defaults/flags/lint、golden **PASS**；same-signature hashes 和 spec replay scores/PNG 一致，无 Rplots.pdf。另 `_s3/lock-check.log` 为 module_lock OK(14 files)。
- [x] 锚点/原文：GBM 11861 features、173 samples、4集合、auto Gaussian；Classical38 / Proneural53，4个 BH<0.05，oligodendrocytic_up logFC -0.522609890627989。tests:55–72 独立参数对象打分/limma 调用，但仅比较一个 score 和一个 padj；不是完整指南 workflow。`L1_bioc3.23/GSVA/vignettes/GSVA.rendered.txt:683–725` 有可用 printed 维度/分组/集合大小，并明确原例 maxDiff=FALSE；另 :1006–1066 有 FIR 的 printed 推断结果，不能说本地完全无 printed anchors。见 F2。
- [x] T/W：scores 保留全部样本，推断分表和设计另写，参数对象保存。实际 draft 报告 GSVA2.6.6、输入尺度/存储、集合版本/hash、参数/seed/实际 kernel、显示与推断分开。post-filter 集合大小与数量不完整见 F3。
- [x] S1/mechanics：gsvaParam 新 API 各结果参数显式且 registry 覆盖；173连续样本 Gaussian 与显式 Gaussian 完全一致，200样本 none、显式 counts Poisson 测试通过。默认 counts、未锁定 Hallmark、篡改上游、校正矩阵上的推断有 typed 拒绝；sample 对齐正确。未重复 log VST。P-3 未批准的推断仍实际运行见 F1。
- [x] PNG：打开 `_smoke/gsva-score-smoke/{a1,a4,no_kernel,poisson}/figures/score_heatmap.png` 四个不同图；a1/a2/a3/a5 由字节验证相同。主锚点标签、树、分组与 row-z 图例清楚，caption 明示4/4集合、24/173样本、5–500及无显著性筛选。a4 两行图丢失 Group/row-z 图例；PACK F score-by-group 图也未实现，见 F4。

## 闭合修复清单

1. **F1 — S1 P-3 待澄清，`skills/gsva-score/scripts/gsva_score_core.R:30–53`、report:50–52、run:27–28。** 只给 reference/target 就以写死的 eBayes FALSE/FALSE 输出 P/BH 和显著集合。PACK 明言确认前不写死；标注 provisional 诚实但不是安全隔离。确认前应只打分/交接，推断请求 typed refusal；或先取得 owner 对入口与 eBayes 设置的明确裁决后实现并登记。不要因缺裁决判失败，失败在主动替 owner 选择后返回推断。
2. **F2 — PACK C，`skills/gsva-score/tests/run_smoke_test.R:47–72`，L1 `GSVA.rendered.txt:683–725`。** 当前重放改用了 maxDiff=TRUE/5–500，并新加非指南 Classical 对 Proneural FALSE/FALSE limma；这验证 suite preset，不是原 vignette 代码。须分开加入原 GBM maxDiff=FALSE workflow 的独立完整 score-matrix 比较和可用 printed 维度/全部分组数/集合大小85、88、98、70断言；另验证冻结 suite preset。若推断例要作为锚点，应回到 FIR/SV/robust/size-trend 原流程及其 printed 值，不把自建比较叫官方数值锚点。
3. **F3 — PACK T/W、S1 P-2，core:12–14,55–57；report:8–23,37。** 仅在原矩阵交集上预数 retained/excluded，GSVA filterRows 后可再移除集合；未输出逐集合的真实过滤后大小。独立 `_s3/filter_probe.R` 在锁定容器给3集合，其中1集合全为常量基因，得到 n_retained=3、n_excluded=0、n_scored=2（`_s3/filter-probe.log` EXIT0）。须从实际 GSVA 过滤后的成员/结果导出每集合大小、保留/排除及原因，使表、JSON、Methods一致；加此边界断言。
4. **F4 — PACK F，`skills/gsva-score/scripts/gsva_score_report.R:18–22` 及 shared score heatmap。** 仅 heatmap，没有 score-by-group 图；max-size60的实际两行热图又缺颜色和分组图例。补齐规定的按组展示（推断尚待批准时不能虚造检验注释），修复少行图例，并验证两行及完整图的图例/caption；或由 owner 明示批准缩减图形范围。

Owner：必须裁决接收原始 score 的 limma 入口及 trend/robust；重复单位走相关设计，当前拒绝是安全的。Hallmark 无离线 hash 的拒绝可保留。GSVAdata 已能从锁定 acceptance 层读到，不再是本次运行阻塞。

NEXT STEP: 无；等待闭合修复后重审。
VERDICT: FAIL
