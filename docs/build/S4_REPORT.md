# M1/M2 S4 集中修复报告（integrate/m1m2）

执行：Claude Opus 5.5（S4 协调者）+ opus 助手（每模块独立分支 `s4/<name>`，只在本地，合并进 `integrate/m1m2`）。
依据：`docs/build/S3_REPORT_astra.md` 与 14 份 `acceptance/exemplars/<module>/S3_REVIEW_astra.md` 的闭合清单；
`docs/handoff/ENGINEERING_PLAN.md` v1.2；各 PACK 的 `## S1 审定附录`；SUITE `M1/M2 S1 审定`。
全部 R 运行在 GT103 的锁定容器 `omicstat-r:2026.09.1`。本报告只陈述修了什么、证据在哪、还剩什么；**不代替终验**。
每模块的逐项对照（F 项 → 改动 file:line → 证据）在 `acceptance/exemplars/<module>/S4_FIXES.md`。
过程记录：`docs/build/s4_worklog.md`。

## 0. 结论摘要

- **14/14 模块的 S3 闭合修复清单已逐项处理**，全部升版本（deseq2-wald 1.2.0，其余 1.1.0）。
- **最终运行**（`integrate/m1m2` @e0a2865（之后的提交只改文档），GT103 `~/omic-integrate` 重置到 origin 后，容器 `omicstat-r:2026.09.1`）：
  `bash env/test.sh` → **ALL PASSED，0 SKIP**（14 个模块冒烟 + selftest + 共享/工具/MCP 测试）；
  14 个模块 `make_module_lock.R --check` 全部 OK（各 14 文件）。日志：GT103 `~/omic-build-logs/s4/final-test.log`、
  `final-lockcheck.log`。金标准均为容器签名、逐字节 PASS。
- **已知失败锚点仅 1 处**：sva-batch A6a（vignette 原样 `num.sv(leek)` 给 4，打印 2；已溯源为数值噪声，严格断言保留并在冒烟输出中显示；
  另 1 行同源的下游表断言一并标出，共 2 行 `KNOWN-FAILING ANCHOR:`）。其余打印锚点全部严格复现。
- 跨模块契约 (a)–(d) 已实现并有真实生产者→消费者链式测试；共享层缺口已补（§2、§3）。
- 所有者待定事项未替所有者决定（§6），新增一项：voom `adaptive.span`（§4、§6.7）。
- 这是修复方报告，不是验收；终验须独立复核（§7）。


## 1. 整合

- `integrate/m1m2` 以 `build/m1m2@2ddf174` 为底，依次合并 `build/m1-limma@fd2b8d7`、`build/m2@bbbf937`、
  `build/m2-rank@e36b77f`、`s3/review@feef4e6`。文本冲突只在 `_shared/docs/FIGURE_STYLE.md`（各线的 §19.x
  全部保留，重编号 19.2–19.9）与 `_shared/scripts/fig_all.R`（`fig_mod_bulk_limma.R` 与 `fig_mod_enrich_rank.R`
  都加载）。四条线之外没有其他文件被两条线同时修改。
- 基线（整合后、任何修复前，@b9a26b9，容器内 `env/test.sh`）：ALL PASSED，但有 3 个 SKIP——三个
  clusterProfiler 模块的冒烟测试从未被 `tools/run_tests.sh` 真正运行（`# requires:` 行用逗号分隔，包名带逗号被判缺包）。
  已修 `tools/run_tests.sh`（逗号当空格）；这三个测试单独运行为 PASS。日志：GT103
  `~/omic-build-logs/s4/baseline-b9a26b9.log`、`baseline-cp.log`。
- GT103 运行镜像 `~/omic-integrate`：验收数据层现为独立拷贝（最初按指令建的软链接在容器挂载内解析不到）。

## 2. 跨模块契约（S3_REPORT §5）

| 契约 | 实现 | 证据 |
|---|---|---|
| (a) 真实 ranked_list 生产者 | 新增 `_shared/scripts/ranked_list.R`：文件仍是冻结的 `feature_id,symbol,score`（降序、平分按 ID），语义随 handoff state `ranked_list` 与旁车 `.meta.json` 传递（metric、statistic、test_statistic/effect_size、LFC 类型、directional、contrast、正/负端含义、零效应或最小效应检验、排名全体、排除与并列计数、生产者/版本）。生产者：deseq2-wald（未收缩 Wald stat）；limma 三模块经 `limma_io.R`（单系数 moderated t；treat 时注明 treat t）。edgeR QL-F 不生产（契约未冻结，按指令保持）。消费者 fgsea-prerank、clusterprofiler-gsea（及 limma-camera 的 cameraPR）从元数据读取，缺元数据或无方向统计量一律类型化拒绝，不按生产者名字猜。 | deseq2-wald 冒烟 R1–R3（含 vignette `results()` 独立回放）；fgsea R0–R6、cp-gsea 的真实 Wald→、limma-voom→ 链式测试 |
| (b) limma → camera / GSVA | `limma_io.R::os_limma_write` 交接真实对象：`EList`（含 voom 精度权重）、`MArrayLM`（含 design）、显式无权重的 `expression_matrix`（state 写明尺度与“权重未随矩阵传递”）、`sample_table`、被检系数、权重说明、block/相关。消费端统一读取器 `os_limma_handoff_read()`。 | 见 gsva-score / limma-camera 的 S4_FIXES |
| (c) 批次校正状态跨 GSVA 保留 | `handoff.R`：state `batch_corrected_lineage = TRUE` 时，`read_handoff(expect=)` 对该 run 的数据对象一律 `OS_BATCH_CORRECTED_INPUT`；`os_handoff_assert_uncorrected()` 供自行挑选对象的模块使用。GSVA 对校正输入的 scores 类型为 `batch_corrected_matrix` 并置 lineage。 | 见 gsva-score S4_FIXES |
| (d) GO ALL + pool=FALSE | ORA 与 compare 按“检验族”（ORA：本体；compare：列表×本体）分别保存与报告有效输入/背景分母和 BH 范围；在锁定源码中核实 enrichGO(ALL, pool=FALSE) 逐本体调用、BH 在本体内，pool=TRUE 为单一 BH 族。不用并集背景。 | ORA：BP/CC/MF 输入 194/201/193、背景 11525/11914/11822；compare：X1 198/201/205、X2 746/768/758（与 Astra 实测一致），均与直接调用一致 |
| (e) 共享报告与图层缺口 | 见第 3 节 | — |

## 3. 共享层改动（协调者；助手不改 `_shared`）

- `limma_io.R`：交接对象（上）；Methods 模板槽由模块按实际运行填充（`res$template_values`）；`direction_summary.csv`
  （Down/NotSig/Up，treat 时记录 lfc）；可选注释映射（`feature_annotation.csv`、特征表 symbol）；MDS 与 voom 趋势图；
  草稿附图注；修正 `res$expr` 与 `res$expr_scale` 的 R 部分匹配隐患（助手发现）。
- `handoff.R`：校正谱系规则（契约 c）。
- 新图形构件（FIGURE_STYLE §19.10）：`os_sample_mds`、`os_ql_dispersion`、`os_voom_trend`、`os_prior_density`
  （ComBat 先验诊断，不用 base 图形）、`os_barcode`（含 worm）、`os_md_set_highlight`、`os_score_by_group`（纯描述、
  不画检验）、`os_cp_gsea_dotplot_signed`、`os_cp_gsea_ridge`；`os_nes_bar` 可按排名两端含义写图注（不再默认
  “上调/下调基因”）；`os_camera_set_bar` 保留轴标题与方向图例。每个构件都在容器出图并目视检查。
- `tools/run_tests.sh`：`# requires:` 逗号问题（见 §1）。
- 验收数据层：按 limma-array 助手的精确请求加入 `RnAgilentDesign028282.db 3.2.3` 与 `org.Rn.eg.db 3.23.0`
  （Bioconductor 3.23 annotation 仓库，Artistic-2.0，sha256 写入 `acceptance/data/acceptance_lib_lock.csv`）；
  安装脚本改为按依赖顺序安装、依赖可来自层内已装包。已在 GT103 `~/omic-integrate/.omicstat-acceptance` 安装。

## 4. 锚点溯源结论

- **limma User's Guide §18.1（Yoruba）与 §18.1.10 camera**：指南是静态 PDF，最后一次重跑约在 limma 3.42；
  limma 3.66.0 把 `voom(adaptive.span)` 默认改为 TRUE。用指南原代码并写出当时默认 `adaptive.span = FALSE`，
  锁定容器逐值复现全部打印值（相关 0.446/0.446、decideTests 27/16869/22、TTTY15 等、camera Y 2.40e-262 / FDR 4.80e-262、
  X 5.58e-26）。证据：`docs/build/S4_ANCHOR_TRACE.md`，探针 `acceptance/exemplars/limma-dupcor/_s4/yoruba_span_probe.*`。
  按所有者指示：**指南路径锚点**用 `adaptive.span = FALSE` 严格断言；**冻结的套件默认路线不变**（TRUE），另以锁定回放断言。
- **edger-qlf**：按 Astra 裁决实现。指南原路径（先 `estimateDisp`）在锁定容器严格复现打印的 QLF 2607/10546/2816、
  glmTreat 1533/12573/1863、common dispersion 0.0134、`fit$dispersion` 0.013（源码确认它是 NB 离散度而非 QL）；
  冻结套件路线不变并单独回放；差异定位为 `estimateDisp` 缓存的 AveLogCPM（仅替换它即 P 差 0）。原“4.9.9→4.10.5 版本导致”的归因已更正。
- **limma-array**：`RnAgilentDesign028282.db` 缺失已溯源并补入验收层（§3），指南 17.4 全链打印值（27024×19、
  756/24734/1534、RT1-Bb logFC 9.33 等）在容器内全部复现。
- **sva-batch A6a**：vignette 原样 `num.sv(edata, mod, method = "leek")` 在容器给 4（打印 2）；同版本，原因是 leek 阈值从 0
  起比较、理论为零的特征值出现 ±1e-16 舍入噪声（输入扰动 1e-12 即得 2/4/5）。作为 KNOWN-FAILING 锚点保留严格断言并在冒烟输出显示；
  以打印的 n.sv = 2 继续的下游链（A6b）逐值复现全部 70 个打印值。
- **fgsea-prerank**：教程 Quick run 的打印表（6 行 pathway/pval/padj/log2err/ES/NES/size/leadingEdge）用教程自身调用严格复现。
- **clusterprofiler-compare**：原例来源为 YuLab 书 `comparecluster-analysis.qmd`（L2 manifest sha256 一致），无打印值；
  以原代码+未改动 gcSample 列表回放，并与现有预设测试分列。

## 5. 逐模块状态

“已修”指 S3 闭合清单中的全部 F 项都有改动与回归断言、版本已升（锁 7）、容器内冒烟通过（含金标准）、
`module_lock.json` 重建。证据与 file:line 见各 `S4_FIXES.md`。**这是修复方的自述，不是验收。**

| 模块 | 版本 | F 项 | 状态 | 已知失败/未运行锚点 | 修复者 |
|---|---|---|---|---|---|
| deseq2-wald | 1.1.0→1.2.0 | F1 vst 按可入选行回退；F2 Methods 按实际 sfType/fitType/变换/收缩包版本；契约 a 生产者 | 已修 | 无 | 协调者 |
| deseq2-qc | 1.0.1→1.1.0 | F1 vignette 自身 `plotPCA(returnData)`/`dist` 独立 oracle，全矩阵/PC/percentVar/距离断言 | 已修 | 无 | 助手 |
| deseq2-lrt | 1.0.0→1.1.0 | F1 全表 P/padj（含 NA 对齐）+ fission 工作流原码与打印锚点 A0；F2 变换与选择规则写入 Methods/图注；F3 `results(name)` 登记、换 report-coef 不动联合 P/BH | 已修 | 无 | 助手 |
| edger-qlf | 1.0.0→1.1.0 | F1 指南路径打印锚点（QLF/Treat 计数、0.0134、0.013 等）与冻结套件路线分列，差异定位 AveLogCPM 缓存；F2 QL 离散度图 + MDS | 已修 | 无 | 助手 |
| sva-batch | 1.0.0→1.1.0 | F1 vignette 原码 SV 入模型链（A6b 70 个打印值）；F2 含全部保护变量的联合设计检查与类型化拒绝；F3 实际公式/参数入报告；F4 ComBat 先验诊断图（与 ComBat 内部值差 0） | 已修（1 个已知失败锚点） | A6a：原样 `num.sv(leek)` 给 4≠打印 2（数值噪声，见 §4） | 助手 |
| limma-voom | 1.0.1→1.1.0 | F1 恢复 RNAseq123 原设计（9 样本、group+lane、Basal vs LP），工作流原码逐值复现打印值，Yoruba 打印锚点；F2 Methods 按实际运行；F3 voom 趋势 + MDS | 已修 | 无 | 助手（续跑） |
| limma-array | 1.0.1→1.1.0 | F1 指南 17.4 全例（44254×19 起）原码回放 + 引擎回放；F2 实际操作/参数的 Methods；F3 注释映射、symbol/Entrez、方向汇总；F4 辅助输入全部哈希 | 已修 | 无（注释包已入验收层，GT103 镜像内全链 PASS） | 助手 |
| limma-dupcor | 1.0.0→1.1.0 | F1 Yoruba 打印锚点（指南时代 span）+ RNA 引擎在该数据上的锁定回放（0.4449716/0.4454514、全表）；F2 两轮 voom→dupCor 等参数；F3 MDS + voom 趋势 | 已修 | 无 | 助手（续跑） |
| clusterprofiler-ora | 1.0.0→1.1.0 | F1 契约 d（按本体检验族）；F2 symbol 映射表、simplify 合并关系表；F3 版本/函数/GO release 来自运行 | 已修 | 无 | 助手 |
| clusterprofiler-gsea | 1.0.0→1.1.0 | F1 消费排名元数据（不按生产者命名）、效应量须给 LFC 类型；F2 单侧带方向排名合法；F3 ridge + 按符号分块点图 | 已修 | 无 | 协调者 |
| clusterprofiler-compare | 1.0.0→1.1.0 | F1 列表×本体检验族分母；F2 书中原例在未改动 gcSample 列表上的原码回放（与预设测试分列） | 已修 | 无（原例无打印值） | 助手 |
| fgsea-prerank | 1.0.0→1.1.0 | F1 教程 Quick run 打印表严格断言；F2 PACK T 排序；F3 图注按排名两端含义；契约 a 消费者 | 已修 | 无 | 协调者 |
| gsva-score | 1.0.0→1.1.0 | F1 删除写死的 eBayes 推断，推断请求 `OS_OWNER_DECISION_PENDING`；F2 vignette 原流程与套件预设分列回放、打印维度/集合大小 85/88/98/70；F3 GSVA 过滤后的逐集合真实大小；F4 按组图 + 少行热图图例；契约 b/c | 已修 | 无 | 助手（续跑） |
| limma-camera | 1.0.0→1.1.0 | F1 camera 打印行（指南时代 span）严格断言 + 套件路线回放；F2 各路线 Methods；F3 barcode(worm)、集合高亮 MD、图例/轴标题；F4 registry 实值/绑定；F5 路由评测资产；契约 b | 已修 | 无 | 助手（续跑） |

契约 (a)–(d) 见 §2；共享层见 §3。


## 6. 所有者待定事项（本轮均未替所有者决定，均采用 S3 接受的安全处理）

1. **GSVA 下游 limma 入口与 eBayes trend/robust**（gsva-score S1 P-3）：未决。安全处理：只打分/交接，推断请求 `OS_OWNER_DECISION_PENDING`。
2. **limma-voom `voomLmFit` 调用集合**（P-1）与 treat 的 `fc` 登记方式（P-2）：未决；沿用附录临时实现，未冻结。
3. **deseq2-qc 离群统计量与阈值**（P-2）：未决；保持纯描述。
4. **DEGreport 进镜像**（deseq2-lrt 模式聚类）：未决；缺依赖时 `OS_UNAVAILABLE_DEPENDENCY`。
5. **非 Agilent 芯片预设**（limma-array P-1 / dupcor）：未决；非 Agilent 须显式 `--trend/--robust`，否则类型化拒绝。
6. **ORA/compare 全表 1/1 cutoff**（对 PACK D-O5/D-C3 的 0.05/0.2）：未决；保持透明全表 + 单独 BH 标记。
7. **锚点修订（均附证据，未擅改）**：
   - **新：voom `adaptive.span`**。limma 3.66.0 起默认 TRUE；指南 §18.1 的打印值只在 `adaptive.span = FALSE` 下复现（`docs/build/S4_ANCHOR_TRACE.md`）。
     现做法：指南路径锚点写出 FALSE；套件默认路线保持 TRUE（未改）。**套件是否也改用 FALSE（或在 Methods/参数中固定 span）由所有者决定。**
     影响 limma-voom、limma-dupcor、limma-camera。
   - edger-qlf：PACK C 的打印计数只在指南路径（先 estimateDisp）成立；冻结 S1 路线给 2608/10546/2815、1535/12570/1864。
     套件是否改用 estimateDisp 缓存的 AveLogCPM，或 PACK C 改记套件路线值。
   - sva-batch A6a：是否把 vignette 打印的 n.sv = 2 视为中间量（A6b 已由它逐值复现下游全部打印值）。
   - clusterprofiler-compare：原例无打印值，“原码回放 + 预设测试”是否作为 PACK C 依据。
8. **其他新确认事项（非失败）**：
   - sva-batch：P-2 “部分混杂”的新读法（bladderbatch 现报告为 partial，8 个空格，全部 cancer 对比可估）；
     计数法（combat_seq/svaseq）的展示 PCA 在原始计数尺度上（PC1 94%），是否先变换；
     sva-batch 未置 `batch_corrected_lineage`（`sv_table` 来自未校正输入，须能进入 DE 设计），请确认。
   - deseq2-lrt：因子水平按 radix 排序，默认展示系数与工作流不同（联合 P/padj 不受影响），是否尊重样本表水平顺序或加参考水平参数。
   - limma-voom：接受两种 RNAseq123 接口差异（按设计过滤 17062 vs 按组 16624；直接检验系数 vs `contrasts.fit`），且现在允许多于两水平（其余水平留在模型中）。
   - limma-array：`--keep-other-levels` 是否默认；是否给引擎加“无 symbol 探针”过滤（S1 P-2 未覆盖，目前在上游声明）。
   - limma-dupcor：Illumina 17.3.7 若把 PACK C 行 7 扩展到 DE 输出，第 9 行 P 值 4.2369e-11 vs 打印 4.23e-11 会成为已知失败值。
   - clusterprofiler-ora：包自身的 simplify 循环会删掉后来组里的代表项（CC 中 63/210 行），表中如实报告。
9. **参考数据**：Hallmark/MSigDB 仍 `OS_REFDATA_MISSING`；GO 资产哈希与许可（M1-3）、enrichit 进 pkg_lock（M2-2）未变；无 KEGG。
   新加入验收层的两个大鼠注释包（Artistic-2.0）只用于验收测试。


## 7. 给终验者的提示

- 分支 `integrate/m1m2` 之外的 `s4/*` 分支只在本地，未推送；其全部内容已合并。GT103 各模块运行目录：`~/omic-build-logs/s4/<module>/`，
  协调者运行：`~/omic-build-logs/s4/coord/`，最终运行：`~/omic-build-logs/s4/final*.log`。
- 验收数据层：`acceptance/data/acceptance_lib_lock.csv` 新增两行；在新检出上须重跑
  `bash bin/omicstat-r-route.sh Rscript acceptance/data/install_acceptance_lib.R`（可联网一次）。GT103 镜像已安装。
  没有该层时 limma-array 的全链打印锚点打印 `NOT-RUN ANCHOR:` 行（不算通过）。
- 冒烟输出中的锚点分类标注：PRINTED（打印值、用指南/教程自身代码）、REPLAY（同一会话内原码与引擎逐值相等）、
  suite-route locked replay、KNOWN-FAILING（仅 sva-batch A6a）。请逐一核对“原码路径”是否真的没有调用引擎或共享函数。
- 指南时代 `adaptive.span = FALSE` 只出现在锚点代码里；请核对引擎调用仍为 TRUE（calls_registry 与 core）。
- 契约 (a)(b)(c) 的真实链式测试：deseq2-wald→fgsea/cp-gsea、limma-voom→cp-gsea/GSVA/camera、limma-dupcor→camera（需确认块被忽略时的显式确认旗标）、
  GSVA(校正输入)→下游拒绝。建议终验另起一条完整链复核。
- 已知未改的共享外观问题（不影响数值）：`os_enrich_compare` 多行换行标签在极长术语时会挤（只见于测试用原例图）；
  `os_prior_density` 每批次高度固定、>3 批次由模块分页；`os_limma_sa` 无趋势线；`formatC(..., format="g")` 按列宽补空格（文件可正常解析）。
- 助手曾因速率限制中断（约 04:30）；中断时未提交的改动以 WIP 提交保存在各自分支，续跑助手逐项重跑核验后才完成（见各模块 `s4_worklog.md`）。

