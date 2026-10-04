# clusterprofiler-gsea — S3 独立验收

固定版本：`build/m2@bbbf937c11171049316d453ff215d528ce9eb0f2`。运行目录 `/home/<user>/omic-s3-runs/clusterprofiler-gsea`；以下代码行号均相对此 checkout。仅审查，未改引擎。

- [x] 阅读 PACK T/W/C/F 和 S1 P-1–P-3、S3_REQUEST、build_worklog 与分支 BUILD_REPORT。
- [x] 锁定容器 smoke：`bash /home/<user>/omic-s3-runs/run_locked.sh clusterprofiler-gsea review-final Rscript skills/clusterprofiler-gsea/tests/run_smoke_test.R`；`_s3/review-final.log` 为 SMOKE PASSED / EXIT 0，registry、formals、defaults、flag docs、lint、golden **PASS**，同 spec 主表及两个 PNG 逐字节一致，无 Rplots.pdf。
- [x] 锚点：DOSE geneList 的独立 `clusterProfiler::gseGO` 调用（tests:22–34，非引擎函数）得到 5299 集合，715 个 BH<0.05，首项 GO:0000819 NES 2.89486744、padj 8.02878788e-09。此为锁定包 preset replay；本地 L1 clusterProfiler/DOSE vignette 只有概览和在线书外链，无可用 printed 表，不能把未收录的在线书内容说成已核对的原文。builder 对此有披露。
- [x] T/W：完整检验表保留 ES/NES/P/BH/q/rank/leading_edge/core_enrichment，未按显著性裁剪；实际 draft 包含版本、数据库、method、seed、size、BH 及 eps 的计算下限含义。from-run 排名名称错误见 F1。
- [x] S1/mechanics：wrapper 明示 P-2 参数、P-3 全表 cutoff=1；探索 BH0.25 单独标记。`_s3/downstream-probe.log` 独立打印锁定 gseGO 函数及 enrichit formals：wrapper 不传 `...`，下游 seed=FALSE 通过 R `sample.int` 取种子；因此 builder 的 set.seed 与同环境逐字节实测相互支持。登记的 eps/sampleSize/nPermSimple/scoreType/weight 与实测默认值一致；不要求虚构一个不会被转发的 seed 参数。缺 KEGG/Hallmark 安全拒绝；LRT/F 输入、篡改 handoff 安全拒绝。
- [x] PNG：打开 `_smoke/anchor/figures/gsea_dotplot.png`、`gsea_curve.png`；字与轴未见重叠或裁切。dot caption 明示显示15/显著715及 BH0.05；curve 明示196成员/12495排名基因、NES/BH。PACK F 的 ridge/多集合展示尚未完整实现，不能以这两个图代表全部图形语法已完成。

## 闭合修复清单

1. **F1 — PACK T/W、S1 P-1，`skills/clusterprofiler-gsea/scripts/clusterprofiler_gsea_core.R:21–38`；tests:60–66。** ranked_list 的 metric 被按 producer 名称无条件写成 Wald stat / moderated t，不读取或验证实际排名统计量；smoke 把 DOSE 的 log fold changes 包装为 Wald producer，`_smoke/from_run/draft/methods_results.md` 实际写成“DESeq2 Wald stat”。须消费、校验并保留同一 contrast 的显式 metric/LFC 类型及方向；缺少该语义时拒绝或要求补充，不能猜。增加真实 Wald/limma 与显式 LFC 的衔接测试，断言 Methods 和结果元数据。
2. **F2 — S1 P-1，core:11。** 用“必须同时有正负值”代替“带方向的统计量”判定，拒绝有效的全同号单 contrast Wald/t/LFC；独立 `_s3/downstream-probe.log` 对 3,2,1 确认 OS_INVALID_INPUT。须依据统计量与 contrast 元数据判断方向性，对算法不适用情形给出准确说明；不可仅凭数值符号判定为无方向。分别验证单侧带方向数据与真正 LRT/F 的拒绝。
3. **F3 — PACK F，`skills/clusterprofiler-gsea/scripts/clusterprofiler_gsea_report.R:6–16`。** 当前仅单集合 running curve 和单面板 dotplot；补齐冻结的 ridge/core-enrichment 分布与按 sign 展示的 dot 语法，或由 owner 明示缩减 PACK 范围。以包含正负富集的独立 fixture 验证 caption、集合选择和渲染，不将缺失图形默认为已验收。

Owner / 跨模块：Wald 当前无 ranked_list；本模块 feature_table stat fallback 能避开对象缺失，但不替代排名语义契约验收。enrichit/pkg_lock 基础设施待定如实保留；未把缺失裁决本身判为失败。

NEXT STEP: 无；等待 builder 按闭合清单修复后重审。
VERDICT: FAIL
