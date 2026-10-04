# seurat-cluster S4 闭合修复

1. FindClusters initial.membership / node.sizes → `scripts/run_seurat_cluster.R:8` 的 JSON CLI；`scripts/seurat_cluster_core.R:14` 显式绑定；默认仍为 NULL。
2. HVG mean.function / dispersion.function，SCT reference.SCT.model / residual.features → `scripts/seurat_cluster_core.R:2` 命名函数解析、`:10` 原生调用；参考模型采用用户离线 RDS。options.md、SKILL.md、calls_registry.json 同步，S0 keys 为 none。实际值进入 chain_state.native_controls 和 Methods；参考模型记录路径、类和文件 SHA256。

验证（锁定容器、非 root、network none；运行器 `/home/<user>/omic-sol61/fix_r/run.sh`）：
- `Rscript skills/seurat-cluster/tests/run_smoke_test.R` → exit 0；2638 cells / nine communities / 95927 edges；native PCA/labels replay PASS；main tables golden PASS；新增 `tests/run_binding_test.R:1` 对有效 Leiden 初始分类/节点权重、mean.var.plot 函数配置及 SCT 参考/残差特征的直接原生比较均 PASS。日志：`/home/<user>/omic-sol61/fix_r/cluster_smoke.log`。
- `bash /scratch/check.sh seurat-cluster` → check_calls 0 registry/default drift problems；check_defaults 0 problems；87/87 flags documented；lint 0 problems；`make_module_lock.R` 及 `--check` OK (16 files)。日志：`cluster_checks.log`。
- 六个 smoke PNG（cluster_qc 三个、cluster_anchor 三个）均在 `cluster_figures.jpg` 打开；图非空、文字可读、未见裁切。
- golden 无修改。初次 Leiden 探针使用无效的 0 起始 membership 导致 native leidenbase 崩溃，改用有效的 1 起始 membership 后原生与包装调用均通过；未修改容器或原生包。SCT 参考由原生 poisson vst 拟合，绕开该镜像未安装的 glmGamPoi；没有安装包或放宽断言。

未闭合项：无。
