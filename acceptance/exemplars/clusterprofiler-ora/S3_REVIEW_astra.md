# clusterprofiler-ora 独立 S3 验收

Pinned: `build/m2@bbbf937c11171049316d453ff215d528ce9eb0f2`。恢复旧无裁决 WIP 后按任务更新 pin 最终 HEAD。

- [x] PACK C / L1：DOSE geneList 选择为 abs(score)>2，背景为完整 geneList；测试独立调用 enrichGO（tests/run_smoke_test.R:35），没有调用引擎 compute。BP/显式背景是冻结预设的回放；不是书中 CC/默认背景数值。逐读锁定 clusterProfiler/DOSE rendered text：仅概览与在线书链接，无可用打印数值，故此处不追加“缺 printed”发现。应保留原书章节/原代码溯源限制说明。
- [x] PACK T：实读 enrichment_full.csv，ID/Description/GeneRatio/BgRatio/P/BH/qvalue/geneID/Count 及 canonical 列齐全，原始 ID 保留；symbol 映射与 simplify 合并关系欠缺，见 F2。
- [x] PACK W：实际 anchor draft 与 JSON 的 207 输入、12495 候选背景、194 有效输入、11525 有效背景、2588 term、154 BH 命中一致；全表 cutoffs=1/1、零重叠未检验明确。软件版本/函数不全见 F3。
- [x] Mechanical/S1：enrichGO 与 simplify 注册参数对照调用和附录；BP、背景资格、默认不简化符合；静态 checks、缺背景/缺 KEGG/ALL 缺 pool 类型拒绝、from-run 有限 padj 背景、篡改拒绝、spec 表和 PNG 字节一致、golden PASS、无 Rplots.pdf，SMOKE PASSED / EXIT 0。额外 ALL 合法选项失败，见 F1。
- [x] Figures：打开 anchor/figures/ora_dotplot.png，全部 term、图例、轴可读无遮挡；spec 写明 15 展示/154 显著、BH 0.05、GeneRatio 与排列规则。

证据目录 `/home/<user>/omic-s3-runs/clusterprofiler-ora/`。命令：`/home/<user>/omic-s3-runs/run_locked.sh clusterprofiler-ora review-final Rscript skills/clusterprofiler-ora/tests/run_smoke_test.R`；日志 `_s3/review-final.log`。额外 CLI `--input /omicstat/_smoke/selected.csv --universe /omicstat/_smoke/eligible.csv --selection-rule dose --ontology ALL --pool FALSE --outdir /omicstat/_s3/all-probe`，日志 `_s3/all-probe.log`。

## 闭口返修清单

1. **F1 — PACK S1 P-1/P-2**：`skills/clusterprofiler-ora/scripts/clusterprofiler_ora_core.R:72–75` 强制所有 term 的有效分母相同。合法 `ALL --pool FALSE` 的各本体具有不同背景/输入分母，独立 CLI 实测 `OS_INVALID_RESULT: GO terms disagree on effective background or input denominator` / EXIT 1。按本体保存与报告分母、多重检验范围；增加 ALL pool FALSE/TRUE 成功运行与分母正确性断言。
2. **F2 — PACK T / S1 P-2/P-3**：`scripts/clusterprofiler_ora_core.R:59,65–67` 固定 readable=FALSE，`clusterprofiler_ora_report.R:6–8` 只存简化后表。没有 T 要求的 symbol 映射附表，也没有被冻结 P-3 要求的被合并 term→代表 term 关系。保留原 ID/全表，同时输出可追溯映射、被合并项、代表项与选择规则；实际启用 simplify 验证这些产物。
3. **F3 — PACK W**：`scripts/clusterprofiler_ora_report.R:28–39` / `references/reporting-templates.md`：实际 Methods 只写 clusterProfiler 名称与 org.Hs.eg.db 版本，没有 clusterProfiler 版本、enrichGO 函数和 GO.db release。由实际运行填入这些字段（含影响结果的 enrichit 版本），核对 JSON/provenance；保留现有背景和 cutoffs 的准确说明。

所有者事项：1/1 为保存全表的透明实现，符合跨模块全表说明，已回报 D-O5 衔接，不因该待确认项判失败。未登记离线集合 OS_REFDATA_MISSING 安全；GO 资产散列/许可仍归 M1-3，不在此私自批准。

NEXT STEP: S4 按闭口清单修复；未修改引擎。
VERDICT: FAIL
