# maftools-landscape S4 闭合修复

captureRegions → scripts/run_maftools_landscape.R:26 新增 capture-regions/capture-regions-source，capture-size 改为二选一必填；:35 exclusivity 和 required declaration；core:12 native tmb 转发区域文件，captureSize 保持 native 50 fallback（提供区域时由 native 覆盖）；core:26 记录 region path/source/SHA/实际 size；entry:62 figure 实际 territory/caption，:71 Methods，:75 provenance input hash/actual capture。registry/options/SKILL 同步。

证据（run.sh locked non-root/offline）：
- Rscript skills/maftools-landscape/tests/run_smoke_test.R → exit 0；原 14 checks/golden PASS；本地 chr1 区域捕获 218 variants，TMB 103 rows，原生 tmb 相同输入结果经相同 CSV serialization 后 identical PASS；区域改变 TMB、保留全 variants、source/hash provenance/Methods、二选一/缺失 territory refusal PASS。maf_smoke.log。
- 初始比较失败仅 Tumor_Sample_Barcode native factor 与 CSV character 类型不同，maf_probe.R/log 明确诊断；改为 native CSV roundtrip 且 identical 更严格，不变容差、不改输出。
- bash /scratch/check.sh maftools-landscape → calls/default drift/defaults/lint 0 problems；27/27 flags documented；lock/check OK (9 files)，maf_checks.log。
- 全部 16 PNG 经 maf_figures_0..2.jpg 打开，非空、可读、无明显裁切；maf_figures.json。
- golden 未修改；未闭合项：无。
