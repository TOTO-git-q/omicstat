# seurat-markers S4 闭合修复

1. contrast base → scripts/seurat_markers_core.R:15 转发 --markers-base，默认 2；registry/options/SKILL 同步。精确 CLI 字符串 sprintf("%.17g",exp(1)) 与原生 exp(1) 比较通过，保留原生 avg_logFC 列名。先前探针 as.character 的舍入导致原生列名不同，修正探针，不改容差。
2. mean.fxn → scripts/seurat_markers_core.R:1 package::function 解析，两个路线均转发；NULL 默认。直接 Matrix::rowMeans 对 FindMarkers/FindAllMarkers 比较 PASS。
3. coordinator wording → scripts/seurat_markers_core.R:26 记录实际 base/mean.fxn/test/prefilters；scripts/seurat_markers_report.R:7 和 references/reporting-templates.md 明确 Wilcoxon/presto、Bonferroni over all features，Results 和表 caption 的显著计数明确 Bonferroni-adjusted P (p_val_adj)。

证据：全部命令由 /home/<user>/omic-sol61/fix_r/run.sh 在 locked image、non-root、network none 执行。
- Rscript skills/seurat-markers/tests/run_smoke_test.R → exit 0；原生 all/contrast 和新 base/mean 比较 PASS；两路线实际 Methods 检查 PASS；11648 rows、7023 above log2FC 1；golden PASS，未修改 golden（新增仅绑定和 draft 文本）。日志 markers_smoke.log。
- bash /scratch/check.sh seurat-markers → calls/default drift 0 problems；defaults 0 problems；43/43 flags documented；lint 0 problems；lock/check OK (15 files)。日志 markers_checks.log。
- 全部 10 PNG 已在 markers_figures_0.jpg、markers_figures_1.jpg 打开；非空、可读、无明显裁切；清单 markers_figures.json。
- 未闭合项：无。
