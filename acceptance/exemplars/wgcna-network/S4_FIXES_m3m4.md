# wgcna-network S4 闭合修复

1. native controls → scripts/run_wgcna_network.R:9 每个 review 参数新增独立 CLI；scripts/wgcna_network_core.R:2 JSON / RDS wrapper 和 package::function 解析，goodSamplesGenes:37、pickSoftThreshold:56、blockwiseModules:69、moduleEigengenes:121、cor:18 实际转发；:155 resolved controls；registry/options/SKILL 同步。cosineX/Y 按 locked formals 继承 cosine。默认延续 locked formals / 原有 tutorial 值（cor use=p）。所有实际值写 provenance 和 draft/native_parameters.md 补充 Methods。
2. p.adjust → core:142 trait-p-adjust（默认 BH），保留 p_value，family=全部 module-trait tests；report:6 effect metadata/:19 caption/:32 main Methods 填实际 correlation/adjustment。默认主 draft/spec 文本保持原样，以免改原 golden。

证据：run.sh locked non-root/offline。
- Rscript skills/wgcna-network/tests/run_smoke_test.R → exit 0；原 26 checks PASS，3600 genes/134 samples、18 assigned modules/grey99，printed 19 sizes exact；unchanged container golden PASS。新增 Pearson/bicor + TOMDenom mean 的原生 module labels/eigengenes replay PASS，BH/none 对保存 native P 的 stats::p.adjust exact PASS；Pearson/Spearman correlation forwarding PASS；alternative CLI 的 actual Methods/adjustment caption PASS。wgcna_smoke.log。
- 200-probe diagnostic subset 的 native mean-TOM alternative 保留 all-grey，原生 mergeCloseModules 警告记录在日志，两边均相同；不放宽断言，不当作生物模块证据。
- bash /scratch/check.sh wgcna-network → calls/default drift/defaults/lint 0 problems，65/65 flags documented；lock/check OK (16 files)，wgcna_checks.log。
- 全部 24 PNG 经 wgcna_figures_0..3.jpg 打开；非空、可读、无明显裁切，密集全基因 dendrogram 与原 anchor 保持一致；wgcna_figures.json。
- golden 未修改；未闭合项：无。
