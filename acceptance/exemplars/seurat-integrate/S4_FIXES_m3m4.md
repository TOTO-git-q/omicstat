# seurat-integrate S4 闭合修复

project.dim → `scripts/run_seurat_integrate.R:8` 新增 --harmony-project-dim TRUE|FALSE，locked TRUE；`scripts/seurat_integrate_core.R:9` 实际转发，`:25` chain state / Methods 记录实际值。registry、options.md (none)、SKILL reference-service guidance 同步。

命令均经 `/home/<user>/omic-sol61/fix_r/run.sh`（锁定镜像、非 root、network none）：
- `Rscript skills/seurat-integrate/tests/run_smoke_test.R` → exit 0；2000 graph nodes；原生 embeddings replay PASS；project.dim TRUE/FALSE loading 比较 PASS，FALSE 无 loadings、TRUE 有 loadings；FALSE Methods 检查 PASS；HarmonyIntegration route PASS；golden PASS；no device leak PASS。日志 `integrate_smoke.log`。
- `bash /scratch/check.sh seurat-integrate` → calls/default drift 0 problems，defaults 0 problems，69/69 flags documented，lint 0 problems，lock 写入并 check OK (15 files)。日志 `integrate_checks.log`。
- 打开全部 18 PNG，见 scratch `integrate_figures.json` 及三个 `integrate_figures_*.jpg`；非空、文字可读，未见裁切。
- golden 无修改；未闭合项：无。
