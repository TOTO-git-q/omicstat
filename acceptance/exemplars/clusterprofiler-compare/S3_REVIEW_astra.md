# clusterprofiler-compare — S3 独立验收

固定版本：`build/m2@bbbf937c11171049316d453ff215d528ce9eb0f2`。运行目录 `/home/<user>/omic-s3-runs/clusterprofiler-compare`；代码行号相对此 checkout。仅审查，未改引擎。

- [x] 阅读 PACK T/W/C/F、S1 P-1–P-3、S3_REQUEST、build_worklog、BUILD_REPORT。
- [x] 锁定容器 `bash /home/<user>/omic-s3-runs/run_locked.sh clusterprofiler-compare review-final Rscript skills/clusterprofiler-compare/tests/run_smoke_test.R`：`_s3/review-final.log` SMOKE PASSED / EXIT 0；calls、drift、defaults、flags、lint、golden **PASS**，同 spec 主表与 PNG 字节一致，无 Rplots.pdf。
- [x] 锚点：独立直接 compareCluster 调用，不调用引擎；29874 list-term 行、247 BH<0.05、8列表，candidate universe12495 / effective BP11525，4列表至少一个显著项。L1 overview 无 printed 数值，本地在线书正文未收录。当前是改编 fixture replay，非 PACK C 原始 gcSample replay，见 F2。
- [x] T/W：全表保留 P/BH/q、列表/总体/selection rule；每列表另表记录研究单位、模型/contrast、方向、阈值、topN、输入/映射/背景数。读取实际 draft，明确不做列表间富集差异显著性检验。ALL 的报告数量错误见 F1。
- [x] S1/mechanics：相同 population 且相同背景才走 compareCluster；异总体/背景走分别 enrichGO，不做误导的比较图；禁止列表本身充背景。BP/poolFALSE/fun=enrichGO 和所有内层计算参数有登记并显式传入。ALL 缺 pool、未锁定 KEGG 安全拒绝。入口是显式 manifest 而非 `--from-run`，输入列表及各自背景有哈希；不把模拟 manifest 当真实上游衔接证据。
- [x] PNG：打开 `_smoke/anchor/figures/compare_dotplot.png`，8列表标签可读，空列保留，无裁切/重叠。caption 明示每组最多5、联合20集合、BH0.05、8列表/4有显著项以及不检验组间差异。

## 闭合修复清单

1. **F1 — PACK T/W、S1 P-1/P-2/P-3，`skills/clusterprofiler-compare/scripts/clusterprofiler_compare_report.R:12–19`。** ALL/poolFALSE 只取每列表首行的 GeneRatio/BgRatio 分母写为全列表 effective 数。独立运行 `--manifest /omicstat/_smoke/fixture/all_probe_manifest.csv --ontology ALL --pool FALSE --outdir /omicstat/_s3/all-probe` 成功（`_s3/all-probe.log` EXIT0），X1 实际 BP/CC/MF 分母分别为输入198/201/205，背景11525/11914/11822，但 list_definitions 仅写198/11525；X2 输入746/768/758，报告仅746。须按 ontology 分别记录有效数量并说明检验/校正范围，保留每项真实分母；对 ALL/poolFALSE 加数值断言，不能用首行代表所有本体。
2. **F2 — PACK C，`skills/clusterprofiler-compare/tests/fixtures/make_gcsample.R:7–20`、`tests/run_smoke_test.R:24–34`。** 先把原 gcSample 每个列表截成 DOSE geneList 的交集，再以该外来背景 replay；这改变 PACK 指定原例的列表与检验总体。builder 诚实标为 adapted fixture，但此独立数值一致性不足以证明原指南锚点。须另补可追溯原示例代码的未改列表 reference replay（与生产强制背景策略分别说明），以及当前 suite preset 的独立比较；若无法取得原源，提交 owner 明示替代验收依据。不得把任意 package fixture 的背景当成原实验可选择总体。

Owner：无新增科学默认裁决；无离线引用数据时的拒绝是安全行为，不因缺数据本身判失败。

NEXT STEP: 无；等待闭合修复后重审。
VERDICT: FAIL
