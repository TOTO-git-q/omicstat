# limma-voom 独立 S3 验收

Pinned: `build/m1-limma@874bc949606e9dfa20fd2a0f84074e5de1c0ef88`；ready `e9772bd`；模块 1.0.0。

## 检查表与证据

- [x] 已读 PACK T/W/C、S1 附录、S3_REQUEST、build_worklog。
- [x] 锚点：当前是自选数据/对比的 direct-call replay，不是 PACK 的源工作流回放；缺 printed，见 F1。
- [x] 表：a0 feature_table 有标准十四列、3320 行；limma_full 包含 logFC/AveExpr/t/P.Value/adj.P.Val/B，treat 路径无 B。由 `os_limma_feature` 映射至通用 schema，完整表不被 display-only 截断。fit.rds 为 MArrayLM、elist.rds 为 EList。
- [x] 文字：a0 draft 的 5000 input/3320 tested、17=12+5、5 samples、B 对 A 与 results JSON/表相符；零效应/最小效应/展示筛选三者分开。缺 edgeR 版本和结果参数见 F2。
- [x] 机械：`bash /home/<user>/omic-s3-runs/run_locked.sh limma-voom smoke Rscript skills/limma-voom/tests/run_smoke_test.R`；`_s3/smoke.log` 为 SMOKE PASSED / EXIT 0。calls、drift、defaults、docs、lint、容器 golden PASS 非 SKIP、spec 表/PNG/spec 字节一致、treat/display/legacy flags、from-run 与篡改拒绝、typed unknown flag、无 Rplots.pdf 均通过。
- [x] registry 对 core 全调用逐项核对：filterByExpr 的 min.count/min.total.count/large.n/min.prop；TMM 全参数；新旧 voom 路径；S1 P-2 的 eBayes proportion=.01/stdev.coef.lim/趋势 FALSE/span=NULL/robust FALSE/winsor/legacy=NULL，以及 treat 用户 fc 和 log2(fc)/upshot=FALSE 均显式对应。P-3 默认 sample.weights=FALSE、仅由开关启用。完整参数见 `scripts/limma_voom_core.R:10`–`:60` 与 calls_registry。
- [x] 打开 a0 所有 PNG：volcano/md。文字清楚、无裁切或重叠；caption 给 3320 tested、BH .05、17 significant，volcano 给上下方向计数。PACK F 的 voom 趋势/MDS 未输出（F3）。

## 独立探针与所有者事项

`bash /home/<user>/omic-s3-runs/run_locked.sh limma-voom weights Rscript skills/limma-voom/scripts/run_limma_voom.R --counts /omicstat/_smoke/limma-voom-smoke/fixture/counts.csv --samples /omicstat/_smoke/limma-voom-smoke/fixture/samples.csv --reference A --target B --sample-weights --outdir /omicstat/_s3/weights`：EXIT 0。`_s3/weights_record.log` 独立读 fit$targets，sample.weight 为 `0.7602555,0.7649438,0.1632641,3.4161416,3.0830773`；权重确实存入 fit，未自动启动。EList targets 为 NULL，消费者应读取 fit$targets，不能假定 EList targets 带样本权重。

P-1 的 Rd/formals 已从锁定容器补收并登记，新入口默认方向符合所有者；S3_REQUEST 明确完整集合仍待确认。此审查不代替所有者冻结，也不以缺少确认本身判失败；S5 前须核对 camera/GSVA 下游接口。P-2 的 fc=用户值、lfc=log2(fc) 遵循附录的安全临时建议并已回报。未静默改回旧默认。

## 闭口返修清单

- **F1 — PACK C**：`tests/fixtures/make_gse63310.R:11`–`:24` 选首五个文件/首5000 genes并人为设 A,A,B,B,B；`tests/run_smoke_test.R:33` 起的 oracle 直接重建引擎新路线，未回放 RNAseq123 原始生物学分组/contrast。PACK C 还要求第二个 Yoruba printed anchor；`L1_bioc3.23/limma/vignettes/usersguide.rendered.txt:7393`–`:7428` 打印 correlation .446、genderMale Down27/Up22、TTTY15 logFC6.529 等。应恢复注册工作流的原始设计/contrast，独立回放源代码；增加适用的 printed anchor（不同接口不可强套值，需明确旧路线/阻塞设计的归属）。不能把当前人为子集 direct-call equality 当成完整 PACK C 验收。
- **F2 — PACK W/D-V2/D-V4、S1 P-2/P-3**：`skills/_shared/scripts/limma_io.R:96` 起和 `references/reporting-templates.md` 生成的实际 Methods 只报 limma 版本、接口、TMM 名称；缺 edgeR 版本、filterByExpr 实际阈值、eBayes/treat 的 trend/robust 等冻结结果参数及新入口 span/adaptive.span/权重设置细节。应从实际运行对象/参数生成可复现 Methods，默认、legacy、sample-weights、treat 均据实报告。
- **F3 — PACK F**：`skills/_shared/scripts/limma_io.R:87` 起只输出 volcano/MD；`scripts/limma_voom_core.R:26` 关闭且不保存 voom trend。应按 PACK 增加 voom 均值—方差趋势和样本 MDS 诊断，保存对应数据/图注并目视验证；不能用两个 DE 散点图替代它们。

NEXT STEP: S4 修复上述清单；所有者另确认 pending call set。

VERDICT: FAIL
