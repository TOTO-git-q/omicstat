# singler-annotate S4 闭合修复

实际 resolved 参数 → scripts/singler_annotate_core.R:50 将已用于 native call 的 opts_singler/opts_prune 返回；scripts/singler_annotate_report.R:6/:15 从 resolved 参数填 Methods/results，并完整记录 supplementary native 参数；scripts/run_singler_annotate.R:54 provenance 写 resolved_native。references/reporting-templates.md:4 实际 min.diff.med/min.diff.next slots。

共享最小改动：skills/_shared/scripts/fig_mod_sc_backend.R:3/:16 两个 SingleR builder 新增兼容的 optional min.diff.med/min.diff.next，caption/thresholds 用真实值，其他 builder 不改。

证据（scratch run.sh，locked non-root/offline）：
- Rscript skills/singler-annotate/tests/run_smoke_test.R → exit 0；synthetic deterministic replay/typed errors PASS；pancreas 1718 cells、59 pruned、printed labels exact；golden PASS。覆盖 JSON quantile=.5/de.method=wilcox、prune nmads=2/min.diff.med=.01/min.diff.next=.05，与 native SingleR/pruneScores labels/pruning 完全一致；actual Methods/results/captions/provenance PASS。singler_smoke.log。
- bash /scratch/check.sh singler-annotate → calls/default drift/defaults/lint 0 problems；54/54 flags documented；lock/check OK (16 files)，singler_checks.log。
- 全部 12 PNG 在 singler_figures_0.jpg 和 singler_figures_1.jpg 打开，非空、可读、无明显裁切；singler_figures.json。
- golden 未修改；未闭合项：无。
