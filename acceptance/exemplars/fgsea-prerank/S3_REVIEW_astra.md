# fgsea-prerank 独立 S3 验收

Pinned: `build/m2-rank@27fca06bcf33656b67c9bb6839a2e8acfcf53b5a`，ready commit `60a86c5`。审查对象 1.0.0；未修改引擎。

## 检查表与证据

- [x] 阅读 PACK T/W/C、S1 附录、S3_REQUEST 和 build_worklog。
- [x] 锚点：**不合格**。测试使用 replay；L1 实际有可用 printed anchor，见 F1。
- [x] 表：完整 enrichment_table 包含 term_id/term_name/database/set_size/es/nes/pvalue/padj/log2err/leading_edge；无需 DE feature_table。排序违反 PACK T，见 F2。
- [x] 文字：实际 `_smoke/fgsea-prerank-smoke/a1/draft/methods_results.md` 列出 fgsea 1.38.0、fgseaMultilevel、metric、方向、物种、版本/hash、15–500、权重、sampleSize、nPermSimple、nproc、seed、eps 和 BH；12000 genes、1457 input sets、586 retained、871 excluded、124 significant 与 results JSON/表相符。不声称因果或 eps 容差。
- [x] 机械：`bash /home/<user>/omic-s3-runs/run_locked.sh fgsea-prerank smoke Rscript skills/fgsea-prerank/tests/run_smoke_test.R`；`_s3/smoke.log` 为 SMOKE PASSED / EXIT 0，calls、drift、defaults、flag docs、lint、golden PASS（非 SKIP）、spec 字节一致、from-run、tamper/invalid-input、Hallmark 缺失拒绝、无 Rplots.pdf 均通过。
- [x] S1 P-1/P-3 参数逐项对应：`scripts/fgsea_prerank_core.R:12` 显式 sampleSize=101、min/max、eps=1e-50、scoreType=std、nproc=1、gseaParam=1、BPPARAM=NULL、nPermSimple=1000、absEps=NULL，调用前 set.seed；registry 全登记。`_shared/scripts/enrich_rank_io.R:3` 检查有限/唯一/降序并计 ties；`:18`、`:40` 校验版本、物种、散列并拒绝未就绪/KEGG。P-2 的 Hallmark 待定安全且已记录，不因缺少所有者决定而判失败。
- [x] 亲眼打开 a1 全部 PNG：nes_bar、gsea_curve。标签可读、无重叠或裁切；长名称用省略号；caption 给出 BH 0.05、124 个显著集合及图中正负集合数，曲线说明 317/12000、NES/padj。NES caption 将正/负排名泛称 up/down-regulated，对自定义非表达统计量应改成方向中性措辞（F3）。

## 独立探针

`bash /home/<user>/omic-s3-runs/run_locked.sh fgsea-prerank probe Rscript _s3/probe.R`，脚本/输出保存在同一 checkout 的 `_s3/`。直接执行教程 `data(examplePathways); data(exampleRanks); set.seed(42); fgsea(..., minSize=15,maxSize=500)`，不使用引擎/共享读入函数。Cell Cycle、Cell Cycle Mitotic、Mitotic Prometaphase 的 ES/NES/size 输出依次为 `0.5388497/2.705894/369`、`0.5594755/2.769070/317`、`0.7253270/2.972690/82`，正是 rendered 教程打印值。主运行改用套件 seed，ES/size 仍一致。`NES descending within significant: FALSE`。

## 闭口返修清单

- **F1 — PACK C（printed/replay 与独立性）**：`tests/run_smoke_test.R:48`–`:60` 只断言自建 seed 的计数/单行 NES，replay 还调用引擎共享 `os_rank_read`；`L1_bioc3.23/fgsea/vignettes/fgsea-tutorial.rendered.txt:35`–`:56` 已打印 Quick run 的 ES/NES/size/leadingEdge，且独立教程回放复现。应增加带来源行号的 printed anchor（至少确定性的 ES/size；教程 seed=42 的可复现数值亦可），使用教程自己的 fgsea 调用和原始 exampleRanks 回放，保留套件 seed 金标准但不能替代文献锚点。
- **F2 — PACK T**：`scripts/fgsea_prerank_core.R:18` 按 padj、abs(NES)、pathway 排序，PACK 要求显著/非显著分组内按 NES 排序。应按冻结表格顺序输出，添加实际行顺序断言，并重建受影响金标准。
- **F3 — PACK W、S1 P-1**：a1 `figures/nes_bar.figure_spec.json` caption 无条件称正/负端为 up/down-regulated genes，然而入口允许命名的非表达统计量，当前 fixture 自己也说 statistic unspecified。调用点 `scripts/fgsea_prerank_report.R:14` 使用共享 NES 图默认文案。应按明确的 ranking direction 描述正/负端，不把任意 score 解释为表达上/下调，核对自定义 metric 图注。

## 集成/所有者事项

Hallmark 依赖 M1-3，维持 OS_REFDATA_MISSING。此 pin 的 deseq2-wald 无 ranked_list producer；本模块 smoke 的 from-run 为自身 handoff 回放，不能宣称真实 Wald→fgsea 已验收。合并时统一 M2 两支的 ranked_list/refdata/共享图层契约。

NEXT STEP: S4 仅修复上述闭口清单后重跑相关验收。

VERDICT: FAIL
