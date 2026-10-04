# deseq2-qc 独立 S3 验收

Pinned: `build/m1m2@342bcc6e6cc753a7c352cdc591743e6be6c09dcd`；ready `5a0fd30`；模块 1.0.1。先读旧 Opus `S3_REVIEW.md`，以下为独立复核。

## 检查表与证据

- [x] PACK T/W/C、S1、S3_REQUEST、build_worklog 已读。
- [x] 锚点：A1 printed 正确，A2 replay 不充分（F1）。`L1_bioc3.23/DESeq2/vignettes/DESeq2.rendered.txt:925`–`:936` 的 blind=FALSE 三行、全部七列与测试 `:66`–`:71` 一致；容器断言通过。blind=TRUE 的 PCA 没有对应 printed 值，不能把 blind=FALSE 数字套用为默认 QA。
- [x] 表格：a2 `tables/sample_qc_descriptive.csv` 为 sample,condition,size_factor,PC1,PC2，七个样本；a1 另有 type。无 centroid distance、outlier/flag/reason。遵循 S1 P-2 暂缓，优先于旧 PACK T；不需要 DE feature_table。
- [x] 文字：实际 a1 draft 写 DESeq2 1.52.0/R 4.6.1、estimateSizeFactors ratio、vst TRUE/nsub=1000/parametric、补充 FALSE、500 genes PCA、Euclidean distance；8148/14599、7 samples、57.3%/30.0% 与 results JSON 相符。实际 f5 draft 写 1200 rows、200 eligible、varianceStabilizingTransformation fallback，无自动剔除主张。
- [x] 机械：`bash /home/<user>/omic-s3-runs/run_locked.sh deseq2-qc smoke Rscript skills/deseq2-qc/tests/run_smoke_test.R`，`_s3/smoke.log` 为 SMOKE PASSED / EXIT 0；calls/drift/defaults/docs/lint、golden PASS 非 SKIP、字节确定性、QC→Wald 真正 forward handoff、篡改拒绝、typed blockers、flag effectiveness、无 Rplots.pdf 全通过。
- [x] S1 P-1/P-3：`scripts/deseq2_qc_core.R:82`–`:119` 显式 blind/nsub/fitType，主 QA TRUE、补充 FALSE、按 eligible rows 回退；批次校正在该模块默认不存在，由 sva 模块负责。P-2 保持描述性 PCA、无数值离群规则。
- [x] 打开 a1 全部四张 PNG（pca、pca_blind_false、sample_distance、size_factor）：无文字重叠/裁切，图例、轴读得清；caption 写样本 n、ntop、blind、距离和补充用途；不适用显著性阈值。PCA 相近样本点部分重合是数据分布，不是标签布局错误。

## 对旧 F2–F5 的复核

- F2 已修复：`deseq2_qc_core.R:122`–`:133` 与实际表/文字均去除 centroid statistic；C 类仍待所有者。
- F3 已修复：`deseq2_qc_report.R:95`–`:108` 以及 a1/f5 实际 draft 均明确参数、补充图和 fallback。
- F4 已修复：`calls_registry.json:56` 起登记 `method=estimateSizeFactors.DESeqDataSet`、type、locfunc、quiet；调用 `core.R:108` 显式。独立 `_s3/probe.R` 打印锁定容器 formals，type 为 ratio/poscounts/iterate、locfunc=stats::median；geoMeans/controlGenes/normMatrix 确为缺失实参，不能用 NULL 替代。该例外在 core 注释和 build_worklog 记录，接受安全的 omission 语义，不要求改变估计器。
- F5 已修复：`core.R:87` 按 normalized mean >5 的 eligible rows 选路径；smoke F5 和实际 f5 draft 确认。该修复尚未覆盖指定 Wald pin，见其独立审查。

## 独立教程探针

`bash /home/<user>/omic-s3-runs/run_locked.sh deseq2-qc probe Rscript _s3/probe.R`（脚本/日志均在该 checkout `_s3/`）直接 `DESeqDataSetFromMatrix`→`vst(blind=TRUE)`→`plotPCA(...,returnData=TRUE)`，未 source 引擎。全部样本 PC1/PC2 经整列符号对齐最大误差 `3.581693e-09` / `1.504645e-09`；完整 VST matrix 最大误差 `4.998785e-09`；由两份矩阵算出的 sample distances 最大误差 `5.67379e-09`；percentVar 两边为 `57.30592 29.95391`（输出精度）。因此当前示例计算正确，但不能用本次一次性探针代替提交中的回归锚点。

## 闭口返修清单

- **F1 — PACK C/F**：`tests/run_smoke_test.R:106`–`:128` 的所谓 independent replay 用 apply(var)/radix order/prcomp/手写符号规范化，复刻引擎共享 PCA，而不是 vignette 的 `plotPCA`；仅查两个样本的 PC1/PC2，未断言完整变换矩阵、percentVar、sample distances。应以 vignette 自己的 `plotPCA(...,returnData=TRUE)` 和 `dist(t(assay(vsd)))` 建独立 oracle（只允许明确的整列符号对齐），断言全部样本/矩阵/方差/距离，保留已正确的 printed blind=FALSE 锚点并收紧 method-basis 的“exactly”表述。

## 所有者事项

P-2 离群统计量/阈值和人工标记范围仍待定；当前安全且已记录，不把缺少所有者决定本身作为失败。复杂设计要求显式 min-samples 是保守继承，建议在 PACK D-11 中补充清晰文字（文档备注）。

NEXT STEP: S4 修复 F1 后复跑。

VERDICT: FAIL
