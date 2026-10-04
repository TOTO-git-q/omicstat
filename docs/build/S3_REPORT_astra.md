# M1/M2 独立 S3 验收报告（gpt-6-astra）

已完成全部 **14/14** 模块审查，裁决 **14 FAIL、0 PASS、0 PASS WITH NOTES**。FAIL 表示有下列明确的验收缺口，不表示所有统计计算均错误。锁定容器中的 smoke/golden 通过不能替代独立来源锚点、完整报告与冻结 S1 的验收。

依据 `/home/<user>/omic-tasks/s3_astra.md`、S3_REVIEWER_BRIEF、ENGINEERING_PLAN §3/§7.2、SUITE M1/M2 S1 及各 PACK。只审查，未修改引擎、builder 工作树或分支，未安装、合并、推送。全部 R 在 `omicstat-r:2026.09.1` 运行；探针、日志和图片在 `/home/<user>/omic-s3-runs/<module>/`，入口包装为 `/home/<user>/omic-s3-runs/run_locked.sh`。

按重启任务明确要求，前五份已完成审查保留原 pin，不重做：fgsea-prerank、deseq2-qc、deseq2-wald、limma-voom、limma-array。其余九项固定最终分支 HEAD；两份旧 WIP 无裁决，恢复后重新固定 HEAD。最终 builder 报告的后续修复声明不自动改变旧 pin 裁决。已读取四个 build 报告并裁决其披露的差异。

## 1. 模块、版本与裁决

| module | branch@commit | verdict | anchor type | main findings |
|---|---|---|---|---|
| [deseq2-wald](../../acceptance/exemplars/deseq2-wald/S3_REVIEW_astra.md) | `build/m1m2@212681b331e35ddf2b551cf6ee7b133acd88981d` | FAIL | printed（通过） | 有效低计数输入在 vst 崩溃；非默认 Methods 错报；另有 ranked_list 生产者缺口 |
| [deseq2-qc](../../acceptance/exemplars/deseq2-qc/S3_REVIEW_astra.md) | `build/m1m2@342bcc6e6cc753a7c352cdc591743e6be6c09dcd` | FAIL | printed + replay | 旧 F2–F5 已修复；A2 缺官方 PCA/距离的完整独立断言 |
| [sva-batch](../../acceptance/exemplars/sva-batch/S3_REVIEW_astra.md) | `build/m1m2@2ddf174fb36cbaa3c280af00b52b92fe7f039d04` | FAIL | printed + replay（缺完整链） | SV 入模型 printed 链缺失；联合设计检查漏 covariates；参数与 prior 图不全 |
| [deseq2-lrt](../../acceptance/exemplars/deseq2-lrt/S3_REVIEW_astra.md) | `build/m1m2@2ddf174fb36cbaa3c280af00b52b92fe7f039d04` | FAIL | replay | 完整 P/BH 回放断言不足；变换/图注与 results(name)登记不全 |
| [edger-qlf](../../acceptance/exemplars/edger-qlf/S3_REVIEW_astra.md) | `build/m1m2@2ddf174fb36cbaa3c280af00b52b92fe7f039d04` | FAIL | printed + replay（输入路径差异） | 同镜像原指南能复现 printed；实际差异定位为 AveLogCPM 缓存；QL/MDS 图缺失 |
| [limma-voom](../../acceptance/exemplars/limma-voom/S3_REVIEW_astra.md) | `build/m1-limma@874bc949606e9dfa20fd2a0f84074e5de1c0ef88` | FAIL | replay；缺要求的 printed | 人为子集/分组不是源工作流；Methods 与 voom/MDS 诊断不全 |
| [limma-array](../../acceptance/exemplars/limma-array/S3_REVIEW_astra.md) | `build/m1-limma@874bc949606e9dfa20fd2a0f84074e5de1c0ef88` | FAIL | replay；缺要求的 printed | 原例与注释未完成；Methods、探针映射和辅助输入 hash 缺失 |
| [limma-dupcor](../../acceptance/exemplars/limma-dupcor/S3_REVIEW_astra.md) | `build/m1-limma@fd2b8d714bd581d9de9dcc9d693570b4bad26bda` | FAIL | printed + replay（Yoruba 未过） | 0.4454514 不匹配 printed0.446；RNA 锚点、方法链与 MDS 不全 |
| [clusterprofiler-ora](../../acceptance/exemplars/clusterprofiler-ora/S3_REVIEW_astra.md) | `build/m2@bbbf937c11171049316d453ff215d528ce9eb0f2` | FAIL | replay | ALL/poolFALSE合法选项失败；symbol/simplify关系与版本报告不全 |
| [clusterprofiler-gsea](../../acceptance/exemplars/clusterprofiler-gsea/S3_REVIEW_astra.md) | `build/m2@bbbf937c11171049316d453ff215d528ce9eb0f2` | FAIL | replay | 上游 metric 被错误重命名；同号方向性误判；PACK F 未齐 |
| [clusterprofiler-compare](../../acceptance/exemplars/clusterprofiler-compare/S3_REVIEW_astra.md) | `build/m2@bbbf937c11171049316d453ff215d528ce9eb0f2` | FAIL | 改编 replay；原例未覆盖 | ALL各本体分母被合并为首行；原gcSample被截为外来背景交集 |
| [fgsea-prerank](../../acceptance/exemplars/fgsea-prerank/S3_REVIEW_astra.md) | `build/m2-rank@27fca06bcf33656b67c9bb6839a2e8acfcf53b5a` | FAIL | replay；缺可用 printed | 可用 printed 未验；NES排序不符；图注误称任意score为表达上下调 |
| [gsva-score](../../acceptance/exemplars/gsva-score/S3_REVIEW_astra.md) | `build/m2-rank@e36b77f44ac7e492adacb371c8c6922e7e23a256` | FAIL | 改编 replay；printed/原例未完整覆盖 | 待定 eBayes 被写死并输出推断；源锚点和过滤后集合数量/图形不全 |
| [limma-camera](../../acceptance/exemplars/limma-camera/S3_REVIEW_astra.md) | `build/m2-rank@e36b77f44ac7e492adacb371c8c6922e7e23a256` | FAIL | printed + replay（camera 未过，mroast 通过） | printed camera未过；Methods、图形、registry实值及路由评测资产不全 |

恢复后九个模块另均运行 `tools/make_module_lock.R <module> --check`，各自 `_s3/lock-check.log` 为 OK / EXIT0。未将前五项重新审查或改成最新pin。

## 2. 完整闭合修复清单

以下逐项保留各模块审查的 F 编号、PACK 依据、位置与完成标准。代码路径和行号对应上表固定 checkout；简写 `scripts/`、`tests/`、`references/` 相对于 `skills/<module>/`，L1 相对于该模块 exemplar。每模块审查文件包含运行命令、实际产物、PNG检查与接受的安全 pending 行为。重审应固定修复提交并运行受影响验收，不改科学默认值来追逐打印数值。

### deseq2-wald

- **F1 — PACK D-10/F（热图变换）、机械 typed error**：`skills/deseq2-wald/scripts/deseq2_wald_core.R:134` 仅看 nrow>=1000，未看 vst 所需 normalized mean>5 的 eligible rows；有效低计数输入在 DE 拟合后因出图变换以未类型化错误退出。应按 eligible rows 使用现有直接 VST fallback，并记录实际路径；增加本探针型回归，核对已有 printed anchors/金标准不变。
- **F2 — PACK W、D-03/D-04/D-10**：`references/reporting-templates.md:10` 硬编码 median-of-ratios/parametric，`scripts/deseq2_wald_report.R:90`–`:109` 不提供 fitType/sfType；成功的 mean/poscounts 运行产生错误 Methods。应从实际 resolved 选项填充 size-factor/dispersion 方法，并说明热图的 VST/blind/nsub 或 fallback；显式报告所用收缩包版本和结果相关参数。默认及非默认 draft 都应与 provenance 一致。

证据：[该模块独立审查](../../acceptance/exemplars/deseq2-wald/S3_REVIEW_astra.md)。

### deseq2-qc

- **F1 — PACK C/F**：`tests/run_smoke_test.R:106`–`:128` 的所谓 independent replay 用 apply(var)/radix order/prcomp/手写符号规范化，复刻引擎共享 PCA，而不是 vignette 的 `plotPCA`；仅查两个样本的 PC1/PC2，未断言完整变换矩阵、percentVar、sample distances。应以 vignette 自己的 `plotPCA(...,returnData=TRUE)` 和 `dist(t(assay(vsd)))` 建独立 oracle（只允许明确的整列符号对齐），断言全部样本/矩阵/方差/距离，保留已正确的 printed blind=FALSE 锚点并收紧 method-basis 的“exactly”表述。

证据：[该模块独立审查](../../acceptance/exemplars/deseq2-qc/S3_REVIEW_astra.md)。

### sva-batch

1. **F1 — PACK C / S1 P-4**：`skills/sva-batch/tests/run_smoke_test.R:89`（A2）只断言 SV 数，未验“SV 入模型”链；源 `L1_bioc3.23/sva/vignettes/sva.rendered.txt:203` 有 usable printed topTableF 数值（例如 207783_x_at 的 C1=-13.45607、P=1.207560e-69），未断言。补独立指南原流程的 printed anchor 与 SV 入 full/null 的回放（保留源设计，与套件预设测试分开）；比对 SV/下游结果，版本差异须逐值解释。保护设计的 ComBat replay 可以保留，但不能替代指南原代码回放。
2. **F2 — PACK S1 P-2**：`scripts/sva_batch_core.R:152` 只检查 batch + study，不含 covariates；:165 的 partial 也没有目标 contrast 可估性检查。CLI 用现有 syn_samples 的 cov1（等于 batch）和 `--method combat --batch batch --study-var grp --covariates cov1`，先认为 confounding=ok，再以包原始错误退出（无 OS_*）。在调用前验证含所有保护变量的联合设计，非可估情形类型化拒绝；partial 不得未经验证写“contrast remains estimable”（report:134）。补对应端到端断言。
3. **F3 — PACK T/W / S1 P-2/P-3**：`scripts/sva_batch_report.R:77,109,133` 与 `references/reporting-templates.md` 未输出实际 full/null 公式和 ComBat par.prior/mean.only/ref.batch、ComBat_seq shrink/full_mod、num.sv B/seed/vfilter、sva 迭代与 display removeBatchEffect 参数。按实际路径填入 batch report、JSON 与 Methods，保留版本与用途说明；不能只在源代码/registry 留存。
4. **F4 — PACK F**：`scripts/sva_batch_core.R:197` 固定关闭 prior.plots，且无统一图层的 prior-density diagnostic。S3_REQUEST 的“deferred”属明确披露但不等于满足 PACK。提供合约内的等价诊断及图注，或先取得明确的 PACK 范围修订；补图形检查且无 Rplots.pdf。

证据：[该模块独立审查](../../acceptance/exemplars/sva-batch/S3_REVIEW_astra.md)。

### deseq2-lrt

1. **F1 — PACK C / S1 P-4**：`skills/deseq2-lrt/tests/run_smoke_test.R:61–67,76–84`，补全部 P/调整 P 数值与 NA 对齐断言；pasilla 不能仅以 df/行数/term 名称当 numerical replay。保存并引用 fission 原工作流的完整代码/预过滤来源，与套件过滤的差别明确标注。独立审查探针不能代替已提交的回归门禁。
2. **F2 — PACK W/F**：`scripts/deseq2_lrt_report.R:33–38,64–73`，Methods/图注只称 transformed expression，未写实际 vst/直接 VST、blind=FALSE、fitType、nsub；图注亦未写 LRT padj < alpha 的源集合选择和样本数。按实际运行补齐，保持变换与 inferential LRT 分开；图片本身可读。
3. **F3 — PACK T / S1 P-3（锁3）**：`scripts/deseq2_lrt_core.R:189` 使用 results(name=report_coef)，但 calls_registry 的 results 项不登记 name。补可选单系数选择的来源和值；不能只靠静态“已登记参数均存在”检查证明结果相关参数完备。验证改变 report-coef 只改变展示系数、不改变联合 P/BH。

证据：[该模块独立审查](../../acceptance/exemplars/deseq2-lrt/S3_REVIEW_astra.md)。

### edger-qlf

1. **F1 — PACK C / S1 P-1**：`skills/edger-qlf/tests/run_smoke_test.R:47–69,80` 与 `acceptance/exemplars/edger-qlf/S3_REQUEST.md` 将不一致归为 4.9.9→4.10.5。实测同一 4.10.5、指南完整 `y <- estimateDisp(y,design,robust=TRUE); glmQLFit(y,design,robust=TRUE)` 得 QLF **2607/10546/2816**、Treat **1533/12573/1863**，恰为打印值。当前引擎按 S1 用未运行 estimateDisp 的 y 并显式 dispersion=NULL；这两条路径的 QLF 最大 P 差 0.002497297，Treat 最大 P 差 0.00244725。以未 estimateDisp 输入独立回放则 Treat 最大 P 差 4.999845e-11。故“版本导致”缺乏支持，不能作为 printed anchor 的豁免。保留冻结引擎，在验收中分别跑指南原路径与套件路径，准确标注差别、向所有者报告 PACK C/S1 P-1 的衔接；不要为追打印值擅改估计器。并补 C 指定 dispersion 断言：独立实测 common=0.0134413085635106，首项 QL dispersion=0.0129556217857436，对应打印精度 0.0134/0.013（先明确后者的首项口径）。补充独立 `_s3/cache_probe.R` / `cache-probe.log`：只向未经 estimateDisp 的 y 复制指南对象的 AveLogCPM，QLF P 与完整指南路径最大差 **0**，与原始 suite 路径差 **0.002497297**；AveLogCPM 最大差 **0.2674049**。因此本例差异可定位到 estimateDisp 缓存的 AveLogCPM 经 glmQLFit.DGEList 传入，而非简单“新 QL 使用旧 dispersion”。Builder 坦诚披露差值是正确的，但归因与验收处理不充分。
2. **F2 — PACK F**：`scripts/edger_qlf_report.R:32–54` 只产生 volcano/MD/BCV/heatmap，缺 PACK 指定的 QL dispersion 与 MDS；S3_REQUEST 将其称作范围外不能改写冻结 PACK。补统一图层的 raw/squeezed/trended QL dispersion 与样本 MDS，图注注明参数、n 和适用阈值，检查所有图；或取得明确的 PACK 范围修订。

证据：[该模块独立审查](../../acceptance/exemplars/edger-qlf/S3_REVIEW_astra.md)。

### limma-voom

- **F1 — PACK C**：`tests/fixtures/make_gse63310.R:11`–`:24` 选首五个文件/首5000 genes并人为设 A,A,B,B,B；`tests/run_smoke_test.R:33` 起的 oracle 直接重建引擎新路线，未回放 RNAseq123 原始生物学分组/contrast。PACK C 还要求第二个 Yoruba printed anchor；`L1_bioc3.23/limma/vignettes/usersguide.rendered.txt:7393`–`:7428` 打印 correlation .446、genderMale Down27/Up22、TTTY15 logFC6.529 等。应恢复注册工作流的原始设计/contrast，独立回放源代码；增加适用的 printed anchor（不同接口不可强套值，需明确旧路线/阻塞设计的归属）。不能把当前人为子集 direct-call equality 当成完整 PACK C 验收。
- **F2 — PACK W/D-V2/D-V4、S1 P-2/P-3**：`skills/_shared/scripts/limma_io.R:96` 起和 `references/reporting-templates.md` 生成的实际 Methods 只报 limma 版本、接口、TMM 名称；缺 edgeR 版本、filterByExpr 实际阈值、eBayes/treat 的 trend/robust 等冻结结果参数及新入口 span/adaptive.span/权重设置细节。应从实际运行对象/参数生成可复现 Methods，默认、legacy、sample-weights、treat 均据实报告。
- **F3 — PACK F**：`skills/_shared/scripts/limma_io.R:87` 起只输出 volcano/MD；`scripts/limma_voom_core.R:26` 关闭且不保存 voom trend。应按 PACK 增加 voom 均值—方差趋势和样本 MDS 诊断，保存对应数据/图注并目视验证；不能用两个 DE 散点图替代它们。

证据：[该模块独立审查](../../acceptance/exemplars/limma-voom/S3_REVIEW_astra.md)。

### limma-array

- **F1 — PACK C**：`tests/fixtures/make_gse33005.R:20` 起截前5000探针/10个数组，`tests/run_smoke_test.R:31` 起只在相同子集重建引擎；未断言 PACK 的 27024×19、Down756/NotSig24734/Up1534、RT1-Bb logFC9.33。源指南 `L1_bioc3.23/limma/vignettes/usersguide.rendered.txt:6732`、`:6752`–`:6759` 有这些打印值，`:6681` 还有可用的原始44254×19。应增加可用 printed 断言并回放指南原设计/过滤；注释缺口须通过授权的验收层补齐后完成最终 printed 锚点，或取得明确 PACK 修订。不能用任意子集数值替代。这里判的是必需锚点未完成，不要求本审查安装包。
- **F2 — PACK W、S1 P-2**：`scripts/limma_array_core.R:64` 与共享 `limma_io.R` 的实际 draft 只写“Controls removed or declared removed”“before optional technical-ID averaging”，不写本次 k=4/背景检测规则、实际是否 avereps、输入 normexp+quantile 来源。应据实生成操作/参数及可追踪预处理说明；未提供的预处理信息应明确未知而非臆造，并在 averaging 路径清楚报告映射/数量。
- **F3 — PACK T、S1 P-2**：`skills/_shared/scripts/limma_io.R:43` 起始终把 symbol 设为空，full 表无 symbol/Entrez；无 PACK 的 decideTests 方向汇总。fixture 以 probe_XXXXX 替换原 ProbeName 且没有保留原探针→基因映射。应接受/保存明确的注释映射，在主/补充表保留原 probe ID、symbol、Entrez（缺失明确标记），技术平均保持映射，并产出所审 contrast 的 Down/NotSig/Up 汇总。
- **F4 — PACK S1 P-2（输入身份），ENGINEERING_PLAN §3.2/§3.5**：`scripts/run_limma_array.R:54` 只把 matrix/samples 传入 provenance；实读 a0 provenance.inputs 也仅两项。改变 control-ids、above-background、technical-ids 会改变结果，却没有输入散列。应登记所有实际使用辅助文件的 SHA-256；验证辅助文件变更可由 provenance 检出，重跑相关锁/金标准。

证据：[该模块独立审查](../../acceptance/exemplars/limma-array/S3_REVIEW_astra.md)。

### limma-dupcor

1. **F1 — PACK C / S1 P-1**：`skills/limma-dupcor/tests/run_smoke_test.R:89–94` 对 Yoruba 仅检查 finite，并打印 ANCHOR GAP 后仍 SMOKE PASSED；未让 RNA 引擎运行该锚点并核对结果。Builder 如实报告差异且未改估计器，这点诚实；但不足以满足 printed 验收，也不能以 0.4455 近似掩盖三位打印差异。补源版本/预处理证据解释 0.446，保留严格 printed 检查；若确认源版本差异，则取得锚点修订并登记 locked replay 数值断言。将源回放与引擎的输入/过滤差异明确分开并覆盖 RNA 计算输出，不以 synthetic finite 检查替代。
2. **F2 — PACK W / D-D2 / S1 P-1**：`scripts/limma_dupcor_core.R:74–77` 和 `_shared/scripts/limma_io.R:96–106` 的实际 RNA Methods 不含 edgeR 版本、filterByExpr/TMM/voom，只有“2 estimation round(s)”；trim、voom 设置、moderation 参数也不全。按实际路径报告完整两轮 voom→duplicateCorrelation、模型/相关、过滤/标准化与结果相关参数，保留现有 block 信息。
3. **F3 — PACK F**：`_shared/scripts/limma_io.R:84–89` 只有火山、MD、可选 SA；补 PACK 明列样本 MDS（RNA 同时使 voom 诊断可审查），含输入尺度、n/标记与图注；或先取得 PACK 范围修订。

证据：[该模块独立审查](../../acceptance/exemplars/limma-dupcor/S3_REVIEW_astra.md)。

### clusterprofiler-ora

1. **F1 — PACK S1 P-1/P-2**：`skills/clusterprofiler-ora/scripts/clusterprofiler_ora_core.R:72–75` 强制所有 term 的有效分母相同。合法 `ALL --pool FALSE` 的各本体具有不同背景/输入分母，独立 CLI 实测 `OS_INVALID_RESULT: GO terms disagree on effective background or input denominator` / EXIT 1。按本体保存与报告分母、多重检验范围；增加 ALL pool FALSE/TRUE 成功运行与分母正确性断言。
2. **F2 — PACK T / S1 P-2/P-3**：`scripts/clusterprofiler_ora_core.R:59,65–67` 固定 readable=FALSE，`clusterprofiler_ora_report.R:6–8` 只存简化后表。没有 T 要求的 symbol 映射附表，也没有被冻结 P-3 要求的被合并 term→代表 term 关系。保留原 ID/全表，同时输出可追溯映射、被合并项、代表项与选择规则；实际启用 simplify 验证这些产物。
3. **F3 — PACK W**：`scripts/clusterprofiler_ora_report.R:28–39` / `references/reporting-templates.md`：实际 Methods 只写 clusterProfiler 名称与 org.Hs.eg.db 版本，没有 clusterProfiler 版本、enrichGO 函数和 GO.db release。由实际运行填入这些字段（含影响结果的 enrichit 版本），核对 JSON/provenance；保留现有背景和 cutoffs 的准确说明。

证据：[该模块独立审查](../../acceptance/exemplars/clusterprofiler-ora/S3_REVIEW_astra.md)。

### clusterprofiler-gsea

1. **F1 — PACK T/W、S1 P-1，`skills/clusterprofiler-gsea/scripts/clusterprofiler_gsea_core.R:21–38`；tests:60–66。** ranked_list 的 metric 被按 producer 名称无条件写成 Wald stat / moderated t，不读取或验证实际排名统计量；smoke 把 DOSE 的 log fold changes 包装为 Wald producer，`_smoke/from_run/draft/methods_results.md` 实际写成“DESeq2 Wald stat”。须消费、校验并保留同一 contrast 的显式 metric/LFC 类型及方向；缺少该语义时拒绝或要求补充，不能猜。增加真实 Wald/limma 与显式 LFC 的衔接测试，断言 Methods 和结果元数据。
2. **F2 — S1 P-1，core:11。** 用“必须同时有正负值”代替“带方向的统计量”判定，拒绝有效的全同号单 contrast Wald/t/LFC；独立 `_s3/downstream-probe.log` 对 3,2,1 确认 OS_INVALID_INPUT。须依据统计量与 contrast 元数据判断方向性，对算法不适用情形给出准确说明；不可仅凭数值符号判定为无方向。分别验证单侧带方向数据与真正 LRT/F 的拒绝。
3. **F3 — PACK F，`skills/clusterprofiler-gsea/scripts/clusterprofiler_gsea_report.R:6–16`。** 当前仅单集合 running curve 和单面板 dotplot；补齐冻结的 ridge/core-enrichment 分布与按 sign 展示的 dot 语法，或由 owner 明示缩减 PACK 范围。以包含正负富集的独立 fixture 验证 caption、集合选择和渲染，不将缺失图形默认为已验收。

证据：[该模块独立审查](../../acceptance/exemplars/clusterprofiler-gsea/S3_REVIEW_astra.md)。

### clusterprofiler-compare

1. **F1 — PACK T/W、S1 P-1/P-2/P-3，`skills/clusterprofiler-compare/scripts/clusterprofiler_compare_report.R:12–19`。** ALL/poolFALSE 只取每列表首行的 GeneRatio/BgRatio 分母写为全列表 effective 数。独立运行 `--manifest /omicstat/_smoke/fixture/all_probe_manifest.csv --ontology ALL --pool FALSE --outdir /omicstat/_s3/all-probe` 成功（`_s3/all-probe.log` EXIT0），X1 实际 BP/CC/MF 分母分别为输入198/201/205，背景11525/11914/11822，但 list_definitions 仅写198/11525；X2 输入746/768/758，报告仅746。须按 ontology 分别记录有效数量并说明检验/校正范围，保留每项真实分母；对 ALL/poolFALSE 加数值断言，不能用首行代表所有本体。
2. **F2 — PACK C，`skills/clusterprofiler-compare/tests/fixtures/make_gcsample.R:7–20`、`tests/run_smoke_test.R:24–34`。** 先把原 gcSample 每个列表截成 DOSE geneList 的交集，再以该外来背景 replay；这改变 PACK 指定原例的列表与检验总体。builder 诚实标为 adapted fixture，但此独立数值一致性不足以证明原指南锚点。须另补可追溯原示例代码的未改列表 reference replay（与生产强制背景策略分别说明），以及当前 suite preset 的独立比较；若无法取得原源，提交 owner 明示替代验收依据。不得把任意 package fixture 的背景当成原实验可选择总体。

证据：[该模块独立审查](../../acceptance/exemplars/clusterprofiler-compare/S3_REVIEW_astra.md)。

### fgsea-prerank

- **F1 — PACK C（printed/replay 与独立性）**：`tests/run_smoke_test.R:48`–`:60` 只断言自建 seed 的计数/单行 NES，replay 还调用引擎共享 `os_rank_read`；`L1_bioc3.23/fgsea/vignettes/fgsea-tutorial.rendered.txt:35`–`:56` 已打印 Quick run 的 ES/NES/size/leadingEdge，且独立教程回放复现。应增加带来源行号的 printed anchor（至少确定性的 ES/size；教程 seed=42 的可复现数值亦可），使用教程自己的 fgsea 调用和原始 exampleRanks 回放，保留套件 seed 金标准但不能替代文献锚点。
- **F2 — PACK T**：`scripts/fgsea_prerank_core.R:18` 按 padj、abs(NES)、pathway 排序，PACK 要求显著/非显著分组内按 NES 排序。应按冻结表格顺序输出，添加实际行顺序断言，并重建受影响金标准。
- **F3 — PACK W、S1 P-1**：a1 `figures/nes_bar.figure_spec.json` caption 无条件称正/负端为 up/down-regulated genes，然而入口允许命名的非表达统计量，当前 fixture 自己也说 statistic unspecified。调用点 `scripts/fgsea_prerank_report.R:14` 使用共享 NES 图默认文案。应按明确的 ranking direction 描述正/负端，不把任意 score 解释为表达上/下调，核对自定义 metric 图注。

证据：[该模块独立审查](../../acceptance/exemplars/fgsea-prerank/S3_REVIEW_astra.md)。

### gsva-score

1. **F1 — S1 P-3 待澄清，`skills/gsva-score/scripts/gsva_score_core.R:30–53`、report:50–52、run:27–28。** 只给 reference/target 就以写死的 eBayes FALSE/FALSE 输出 P/BH 和显著集合。PACK 明言确认前不写死；标注 provisional 诚实但不是安全隔离。确认前应只打分/交接，推断请求 typed refusal；或先取得 owner 对入口与 eBayes 设置的明确裁决后实现并登记。不要因缺裁决判失败，失败在主动替 owner 选择后返回推断。
2. **F2 — PACK C，`skills/gsva-score/tests/run_smoke_test.R:47–72`，L1 `GSVA.rendered.txt:683–725`。** 当前重放改用了 maxDiff=TRUE/5–500，并新加非指南 Classical 对 Proneural FALSE/FALSE limma；这验证 suite preset，不是原 vignette 代码。须分开加入原 GBM maxDiff=FALSE workflow 的独立完整 score-matrix 比较和可用 printed 维度/全部分组数/集合大小85、88、98、70断言；另验证冻结 suite preset。若推断例要作为锚点，应回到 FIR/SV/robust/size-trend 原流程及其 printed 值，不把自建比较叫官方数值锚点。
3. **F3 — PACK T/W、S1 P-2，core:12–14,55–57；report:8–23,37。** 仅在原矩阵交集上预数 retained/excluded，GSVA filterRows 后可再移除集合；未输出逐集合的真实过滤后大小。独立 `_s3/filter_probe.R` 在锁定容器给3集合，其中1集合全为常量基因，得到 n_retained=3、n_excluded=0、n_scored=2（`_s3/filter-probe.log` EXIT0）。须从实际 GSVA 过滤后的成员/结果导出每集合大小、保留/排除及原因，使表、JSON、Methods一致；加此边界断言。
4. **F4 — PACK F，`skills/gsva-score/scripts/gsva_score_report.R:18–22` 及 shared score heatmap。** 仅 heatmap，没有 score-by-group 图；max-size60的实际两行热图又缺颜色和分组图例。补齐规定的按组展示（推断尚待批准时不能虚造检验注释），修复少行图例，并验证两行及完整图的图例/caption；或由 owner 明示批准缩减图形范围。

证据：[该模块独立审查](../../acceptance/exemplars/gsva-score/S3_REVIEW_astra.md)。

### limma-camera

1. **F1 — PACK C，`skills/limma-camera/tests/run_smoke_test.R:25–43`；L1 `limma/vignettes/usersguide.rendered.txt:7497–7500`。** 指南 Y P/FDR=2.40e-262/4.80e-262，X P=5.58e-26；当前只断言新 replay 值 Y1.79122449658387e-262/FDR3.58244899316775e-262，X6.02018304198957e-26。独立 `_s3/guide_object_probe.R` 用原式 `camera(v,index,design,2)`（EList+权重）重放，得到相同新值；不是矩阵入口漏权重引起。builder 明说 printed anchor 未过，披露诚实，但不能用 SMOKE PASSED 代替 PACK验收。须追溯指南打印环境/数据/前处理/版本差异并恢复 printed 断言，或由 owner 据证据明示修改锚点；不得无依据放宽有效数字或改冻结 estimator 强行对齐。本次未证明差异根因。
2. **F2 — PACK T/W、S1 P-1/P-2，`skills/limma-camera/scripts/limma_camera_report.R:19–46`、`references/reporting-templates.md`。** 实际 camera/mroast draft 只写 expression_matrix 和 Male vs Female，未写 concentration 设计、voom权重、mroast cellline/correlation；cameraPR draft 更写“not applicable versus not applicable”，不写已提供的 mean_difference/positive means Male higher。须按方法报告真实输入尺度/权重、设计/contrast/重复单位与相关值、实际排名名称及方向、其他影响结果参数，并将真实设计可核查地保存。每条路线分别断言最终稿，不以 JSON/provenance 的局部字段替代 Methods。
3. **F3 — PACK F，`skills/limma-camera/scripts/limma_camera_report.R:8–14` 及 shared set-bar renderer。** 缺指南要求的 barcode/worm、集合高亮 MD；mroast/fry 实际 PNG 丢失轴标题与方向图例。补齐可从相应输入导出的图形、恢复所有路线的图例/轴标签，并逐张目视和 caption 验证；若缩范围需 owner 明示修订 PACK，不能仅把一个 bar图当完整 F验收。
4. **F4 — S1 P-1/P-2、ENGINEERING_PLAN §3.3，`skills/limma-camera/scripts/calls_registry.json:10–63` 及后续 calls。** 多数值登记为字面字符串“explicit”（如 use.ranks/directional/weights/set.statistic/legacy），没有登记冻结值或动态解析规则；function_default 不是实际分析取值。调用点目前对应 preset 正确，但 registry 不具备要求的结果参数审计语义。须写入实际固定值或明确的 flag/输入绑定，保留 defaults单独字段，并在检查中核对两者。
5. **F5 — S1 P-3，`acceptance/exemplars/limma-camera/S3_REQUEST.md` Owner items、`skills/limma-camera/tests/run_smoke_test.R:1–91`。** 显微镜 camera / FRY基因负例与 cameraPR阳性例目前仅文字提议，未找到独立可运行或可消费的评测样例。须把经语境核实的三例及预期路由保存为与频次语料分开的评测资产，交付路由验收；不改变29/30文献计数。

证据：[该模块独立审查](../../acceptance/exemplars/limma-camera/S3_REVIEW_astra.md)。

## 3. 四个指定的 printed/locked 差异裁决

| 项目 | 诚实性与充分性裁决 | 下一步 |
|---|---|---|
| limma-dupcor：0.446 vs 0.4455 | builder 诚实披露，未改 estimator；但 0.4454514 三位小数为0.445，不能算0.446的合法舍入。只测 finite 再打印 ANCHOR GAP 不满足 printed 验收。 | 追溯源/版本/预处理，补原值与真实RNA引擎锚点；若确需换锚点，由 owner 明示修订。 |
| limma-camera：§18.1.10 P值 | builder 明确写 printed anchor 未通过，诚实；当前 replay 与独立原式 EList 调用相符，但不能代替 printed camera 验收。未证明差异根因。mroast P=1e-04已通过。 | 与 Yoruba 前处理共同追溯；保留严格锚点，或提交有证据的锚点修订。 |
| edger-qlf：4.9.9 vs4.10.5 | 差值披露诚实，版本单因解释不成立。同4.10.5按原指南先 estimateDisp 即精确复现 printed 的QLF/Treat方向计数。仅复制其 AveLogCPM 缓存也使QLF P与指南路径最大差为0。 | 分开指南原流程锚点与冻结suite流程；报告缓存输入差异，补dispersion断言，请owner协调PACK C/P-1，不擅改冻结估计器。 |
| limma-array：缺注释包 | 最终builder报告诚实指出镜像缺 `RnAgilentDesign028282.db`，子集不声称全例。此处理避免伪报，但不足以验收必需全例printed；原始44254×19已有可用打印值且独立读入成功，也未纳入断言。 | 从授权验收层补齐锁定注释及原流程，或明示修订PACK；本审查不安装包。旧pin的其他缺口保留。 |

## 4. 所有者事项及已接受的安全处理

- **GSVA P-3**：必须确认接收原始 scores 的 limma 入口，以及 trend/robust（含是否采用集合大小趋势）。在此之前只打分/交接、推断 typed refusal。失败原因是实现已写死待定设置并输出推断，而非缺裁决本身。
- **limma-voom P-1/P-2**：锁定容器已补 voomLmFit Rd/formals；完整调用集、EList/MArrayLM 下游契约、fc与log2(fc)同传的临时方案仍需确认。当前按附录临时规则实现，不因待确认本身单独判失败。
- **deseq2-qc P-2**：离群统计量、阈值、人工标记范围仍待定；当前只有描述性PCA，已去除未经批准centroid/flag，安全。旧F2–F5已独立复核修复。
- **deseq2-lrt 模式聚类**：缺DEGreport时 OS_UNAVAILABLE_DEPENDENCY 拒绝，安全；不替owner选择聚类输入规则。
- **sva-batch**：ComBat_seq连续研究变量未支持时明确拒绝，安全；SV去除仅作展示，原始数据+协变量进入推断的界限须保留。
- **非Agilent array/dupcor**：要求显式trend/robust并提供SA诊断，安全；其他平台预设、0/1背景证据契约由owner决定。不得自动继承Agilent设置。
- **离线参考数据**：Hallmark及未登记数据库仍应 OS_REFDATA_MISSING；GO/orgdb/hash/许可、enrichit进入pkg_lock等基础设施事项按M1-3/M2-2处理。GSVAdata本次可从锁定acceptance层读取；缺引用数据或许可裁决本身不是统计失败。
- **ORA全表1/1 cutoffs**：实现透明，保留全检验表后单独BH标记；D-O5与跨模块全表政策的文字衔接仍由owner确认，不据此单独判失败。
- **无方向统计量**：LRT和QL F不能直接生成方向性GSEA排名；edgeR未输出尚未冻结公式的ranked_list是安全处理。Wald单contrast的已冻结排名契约则仍需真正实现。
- **锚点与图形范围**：指南不一致必须有可追溯证据或明确PACK修订；“deferred/out of scope”披露不是既有PACK的豁免。不得仅为放行而放宽数值有效位数、替换对比或删减图形要求。

## 5. 跨模块问题与合并证据

1. **真实排名生产链尚未闭合。** 指定Wald及最终m1分支的Wald没有ranked_list。fgsea/cameraPR依赖该类型，合成或自身handoff回放不等于真实Wald→消费者测试。limma共享 `limma_io.R:115–123` 也输出feature_table/MArrayLM/可选EList，未输出ranked_list。clusterprofiler-gsea能回退feature_table.stat，但其producer推断metric会错误重命名LFC；三模块须统一contrast、metric、LFC类型、ID、direction与输入全体语义。
2. **limma→camera/GSVA 对象不兼容。** m1b真实handoff是MArrayLM/EList；camera的 `run_limma_camera.R:67` 只挑expression_matrix/ranked_list/batch_corrected_matrix，GSVA `run_gsva_score.R:60` 只挑expression_matrix/batch_corrected_matrix。当前模拟CSV producer跑通不能证明voom的precision/sample weights、样本表、原design/contrast在生产链保留。需明确接收EList还是导出带权重/设计的矩阵契约并做真实跨分支集成验收；避免静默重建不同设计或丢权重。
3. **校正状态应跨score交接保留。** GSVA入口拒绝对batch_corrected_matrix直接推断，但输出scores统一标expression_matrix，原校正状态只在state.corrected_input。后续camera等主要看对象type；合并时必须验证该状态不能在中间步骤丢失。这是静态契约风险，未声称本次已成功构造下游违规统计运行。
4. **ORA/compare共有ALL分母假设错误。** 同一个GO ALL/poolFALSE实际包含不同本体检验总体：ORA拒绝合法结果，compare错误合并为首行分母。修复须同步effective input/background、校正范围和报告语义；不改成列表并集背景。
5. **共享报告与图层缺口。** m1b共享limma_io的Methods缺参数、缺诊断和注释映射影响三模块；M2-rank图层的少行/不同方法图例缺失须覆盖GSVA与camera。golden可以稳定锁定错误版式，不能替代目视验收。共享层修复需对受影响模块重跑锁和golden。
6. **确认存在的文本合并冲突。** 对最终四个branch头做六组只读 `git merge-tree <merge-base> <A> <B>`，日志保存在 `/home/<user>/omic-s3-runs/integration/*.merge-tree.txt`。每对分支均在 `skills/_shared/docs/FIGURE_STYLE.md` 出现冲突标记；`build/m1-limma` 与 `build/m2-rank` 还在 `skills/_shared/scripts/fig_all.R` 冲突。必须合并各新增图层注册与规则，不能整文件取一侧。该检查未改分支、未实际合并；两两检查不能保证最终顺序合并无其他冲突。
7. **无文本冲突不代表兼容。** m1的module_kit、feature_table、bulk图层改动，m1b的limma_io，m2的enrich_io，m2b的enrich_rank_io/refdata注册最终会共存。应在实际整合提交核验对象命名、非Ensembl带点ID、参考数据身份、默认值登记、figure加载顺序及真实上游衔接。不能只复用各分支孤立golden宣称合并版通过。

## 6. 尚未审查模块

无。全部14个模块有固定commit、完整检查记录、闭合修复清单和末行VERDICT。每模块已按规定单独提交；旧暂停记录保留为历史。审查完成不等于批准S5安装：全部FAIL须由S4处理各自清单并重新提交独立验收。
