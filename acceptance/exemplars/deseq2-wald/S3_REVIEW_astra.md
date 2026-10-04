# deseq2-wald 独立 S3 验收

Pinned: `build/m1m2@212681b331e35ddf2b551cf6ee7b133acd88981d`（任务指定 1.1.0，未随分支更新）。此 pin 没有模块 S3_REQUEST.md/build_worklog.md；已读 PACK、SUITE 的 1.1.0 变更记录及测试/代码，不把文件缺失本身当统计缺陷。

## 检查表与证据

- [x] PACK C printed anchors：`L1_bioc3.23/DESeq2/vignettes/DESeq2.rendered.txt:531`–`:572`、`:607`–`:632`、`:869`–`:873` 与测试 A1/A2/A3 逐项相符。实测 8148；A1 1069=533+536；A2 416/437；FBgn0000017、0000008 的 MLE/apeglm 与多因素 0000017/0000037 LFC/padj 均通过。
- [x] PACK T：实读 a1 feature_table，8148 行，列为 feature_id,symbol,contrast,base_mean,log2fc,log2fc_se,stat,pvalue,padj,method,shrinkage,n_group1,n_group2,filtered_reason，按 padj 后 feature_id 排序；full 表有 MLE/shrunken LFC/SE、stat/pvalue/padj/max_cooks。`core.R:153`–`:184` 保留未收缩统计量。主表通用 log2fc 别名与明确命名 full 表并存；SUITE 已把主表命名口径交所有者，审查不擅自改变共享 schema。
- [x] PACK W：a1 实际 draft 数字和 JSON 一致，清楚分离 Wald P 值/收缩 LFC、display-only 无额外 FDR 保证。非默认选项下错误方法陈述见 F2。
- [x] 机械：容器内 `Rscript skills/deseq2-wald/tests/run_smoke_test.R`，日志 `/home/<user>/omic-s3-runs/deseq2-wald/_s3/smoke.log` 末尾 SMOKE PASSED；calls、drift、defaults、flag docs、lint、golden PASS 非 SKIP、spec/table/PNG 确定性、from-run、批次校正矩阵/篡改拒绝、typed errors、FC flags、无 Rplots.pdf 均通过。容器/mount/user/env 模式同 `run_locked.sh`。
- [x] S1 附录逐项：P-1 coef/res/apeglm/lfcThreshold=0/svalue=FALSE/apeAdapt/apeMethod 在 `core.R:131`，ashr 可选；P-2 results alpha/BH/greaterAbs/minimum-effect 在 `:124`，display-only 默认关闭在 `:71`；P-3 复杂设计显式 min-samples 在 `:53`。registry 对应取值与调用一致。
- [x] 亲眼打开 a1/a2/a3 的全部 volcano、ma、top_heatmap PNG。主标签基本可读；volcano 最低的 FBgn0001224（a1/a2）及 FBgn0031150（a3）贴住 x 轴，建议增下侧留白（排版备注）。热图标签/组别清晰。volcano/MA caption 有 cutoff/计数；热图给出 50 行、z-score clip ±2，但未说明 VST/blind，纳入 F2。

## 独立探针

- `bash /home/<user>/omic-s3-runs/run_locked.sh deseq2-wald probe Rscript _s3/probe.R`：种子 42，1200×6 整数矩阵（100 行高均值，其余低计数），`--min-count 0 --sf-type poscounts --fit-type mean --shrinkage none`。输出 `less than 'nsub' rows with mean normalized count > 5`，`LOW_COUNT_EXIT 1`，无 OS 类型；脚本包装本身 EXIT 0，不能误写引擎成功。
- `bash /home/<user>/omic-s3-runs/run_locked.sh deseq2-wald wording Rscript skills/deseq2-wald/scripts/run_deseq2_wald.R --counts /omicstat/_smoke/deseq2-wald-smoke/pasilla/counts.tsv --samples /omicstat/_smoke/deseq2-wald-smoke/pasilla/samples.csv --reference untreated --target treated --fit-type mean --sf-type poscounts --shrinkage none --outdir /omicstat/_s3/wording_run` 成功；实际 draft 仍写 median-of-ratios / parametric trend，805=406+399。resolved_spec/调用确为 mean/poscounts。

## 闭口返修清单

- **F1 — PACK D-10/F（热图变换）、机械 typed error**：`skills/deseq2-wald/scripts/deseq2_wald_core.R:134` 仅看 nrow>=1000，未看 vst 所需 normalized mean>5 的 eligible rows；有效低计数输入在 DE 拟合后因出图变换以未类型化错误退出。应按 eligible rows 使用现有直接 VST fallback，并记录实际路径；增加本探针型回归，核对已有 printed anchors/金标准不变。
- **F2 — PACK W、D-03/D-04/D-10**：`references/reporting-templates.md:10` 硬编码 median-of-ratios/parametric，`scripts/deseq2_wald_report.R:90`–`:109` 不提供 fitType/sfType；成功的 mean/poscounts 运行产生错误 Methods。应从实际 resolved 选项填充 size-factor/dispersion 方法，并说明热图的 VST/blind/nsub 或 fallback；显式报告所用收缩包版本和结果相关参数。默认及非默认 draft 都应与 provenance 一致。

NEXT STEP: S4 修复 F1/F2，重跑受影响检查。

VERDICT: FAIL
