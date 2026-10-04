# M1 / M2 S1 参数裁决建议

> 由 gpt-6-astra（effort high，codex exec）于 2026-09-27 生成，只读仓库证据，未联网。本机主会话抽查了 7 条关键论断，全部与原文件一致（CONFIRMED）：
> - edgeR `glmQLFit(robust=FALSE)`，而用户指南写的是 "Setting robust=TRUE in glmQLFit is strongly recommended"；
> - limma 用户指南 §15.7 推荐 `voomLmFit` 作为首选接口；
> - limma `roast.Rd` 写明发表用途至少 `nrot=9999`；
> - fgsea 教程的 Reactome 调用只设了 `maxSize=500`；
> - GSVA 教程中同时有 5–500 和 5–300 两种示例；
> - `enrichGO` 默认 `ont="MF"`，Rd 示例用的是 BP；
> - sva-batch 中校正矩阵进入检验的是 11/17（逐条复算：7 篇 DESeq2/limma，另有 4 篇为其他检验），PACK 写的 10/17 漏计。
>
> 本表只是建议稿，最终裁决由所有者做出。

共审查 **50 项**：14 个模块的 44 个 P 项、1 个 edgeR 核查 Note，以及 SUITE 的 5 个基础设施事项；其中 **A 可直接采纳 24 项、B 需要所有者判断 21 项、C 证据不足 5 项**。最重要的建议是：① DE 使用合法未校正输入并将 batch/SV 放入设计，ORA 使用与选择过程匹配的背景；② FC 阈值检验与展示筛选分开，LRT 不套单系数 FC 门槛；③ 两个预排序 GSEA 模块统一上游排名契约；④ limma-voom 的方法方向遵循锁定指南的 `voomLmFit` 推荐，但补齐其 Rd/formals 后才能冻结完整调用；⑤ 权威金标准由锁定容器产生，`eps` 不能当作数值容差。逐项依据及取舍见下表与跨模块部分。本文只提供建议，未修改任何既有文件、模块默认值、实现或分析输出，也未运行包安装、容器构建或联网取证。

## 口径与证据索引

只使用本仓库文件。依据 `docs/handoff/ENGINEERING_PLAN.md` §2.3、§3.3，三列分别核对锁定版 Rd、官方指南正文、论文摘录；不把 PACK 的转述作为指南原文。文内“建议”是本次裁决建议，不表示官方强制要求。A＝可直接采纳；B＝需要所有者判断（有实际取舍）；C＝证据不足（补证办法列在行内）。A 也只供所有者批量批准。

每个模块的证据根目录为 `acceptance/exemplars/<模块>/`。表中 `R:包/文件` 指该根目录的 `L1_bioc3.23/包/Rd/文件.Rd`；`V:包/文件` 指 `L1_bioc3.23/包/vignettes/文件`；`E:参数` 指 `literature/extraction.jsonl` 中相应参数的记录，记录键为 `(pmid, parameter)`，PMCID 见文末复算索引。`PACK` 指本模块 `PACK.md`；跨模块来源写明模块名。`NEWS:包` 指 `L1_bioc3.23/包/NEWS.txt`。这些缩写是文件路径映射，不是外部引用。

频次按当前 `literature/corpus.jsonl` 中的论文与 `_applies=yes` 交集计算，参数行同时须 `applies=true`；不把换批次前留下的摘录计入。以适用论文数 N 为主分母，另列“已报告者 n/R”。`not reported` 不能解释为 FALSE、没有使用或接受默认值；“最常见”也不等于超过半数。相同论文使用多种方法可出现在多个非互斥类别中，但每类别最多计一次。核查报告的补充与原始摘录计数分列，不偷偷修订原始摘录。

## 按模块裁决

### deseq2-wald（3 项；N=29）

| 编号 | 问题 | 函数默认 | 官方推荐 | 范本多数 (n/N) | 建议 | 理由 | 依据 | 类别 |
|---|---|---|---|---|---|---|---|---|
| P-1 | LFC 收缩估计器 | `lfcShrink(type=c("apeglm","ashr","normal"))` 首选 `apeglm`；`lfcThreshold=0,svalue=FALSE,apeAdapt=TRUE,apeMethod="nbinomCR"` | “Log fold change shrinkage for visualization and ranking”“Alternative shrinkage estimators”：示例使用 `apeglm`，也介绍 `ashr` | `ashr` 2/29（2/3 已报告），`apeglm` 1/29；26/29 未报告 | 保留并显式写 `type="apeglm"`；`ashr` 为可选。保留未收缩 Wald 的 `stat,pvalue,padj`，收缩值单独命名 | 2/3 不能代表整体，也没有推翻锁定版推荐的证据。`apeglm` 必须使用 `coef`；任意 `contrast` 须重参数化或明确改用支持它的估计器 | R:DESeq2/lfcShrink，Usage、Arguments；V:DESeq2/DESeq2.Rmd，上述两节；E:shrinkage，PMC12755864、PMC12893922、PMC10719396 | A |
| P-2 | 事后 FC 筛选与阈值检验 | `results(lfcThreshold=0,altHypothesis="greaterAbs",alpha=0.1,pAdjustMethod="BH")`；无自动事后 FC 筛选 | “Tests of log2 fold change above or below a threshold”：阈值进入假设检验；收缩用于展示/排序 | 原摘录事后筛选 10/29；`lfc_threshold_test` 字段有值 2/29，但其中 1 篇明确对应 `lfcShrink`，不能直接认定为 Wald 阈值检验；阈值异质。核查另发现 PMC12893922 的次级 IPA 分析，按“任一分析报告”会成为 11/29，不能混用口径 | 主分析保留零阈值 Wald，显式 `alpha=0.05` 与报告一致；生物学最小效应由用户预先给定，进入 `results(lfcThreshold=...)`。建议增加默认关闭的展示筛选，完整结果保留，不能称筛选后集合仍享有原 BH 的同一保证 | B 的取舍是是否提供复现论文展示习惯的接口；统计检验与展示筛选必须分开。不能用 `lfcShrink` 的 s-value 替代 Wald padj 而继续沿用原标签 | R:DESeq2/results，`lfcThreshold`、`alpha`；R:DESeq2/lfcShrink，`lfcThreshold`、`svalue`；V:DESeq2/DESeq2.Rmd，上述节；E:lfc_filter、lfc_threshold_test、padj_cutoff；literature/verification.json，PMID 41407857 | B |
| P-3 | 低计数预过滤 | `DESeq()` 无自动“10×最小组”预过滤参数；`results(independentFiltering=TRUE)` 是后续独立过滤，二者不同 | “Pre-filtering”：可选；示例保留 count≥10 且达到最小组样本数的基因，解释了速度和内存收益 | 6/29 报告，6 条不同规则；23/29 未报告 | 两组 bulk 默认按 `count>=10`、`n>=最小组样本数` 显式预过滤；记录保留数和规则；连续协变量或复杂设计要求明确规则，不硬造“最小组” | 原文称预过滤非必需，不能写成统计有效性的强制条件；不为表面一致而将 DESeq2 改成 CPM 规则 | R:DESeq2/DESeq、results；V:DESeq2/DESeq2.Rmd，“Pre-filtering”；E:prefilter | A |

### deseq2-qc（3 项；N=20）

| 编号 | 问题 | 函数默认 | 官方推荐 | 范本多数 (n/N) | 建议 | 理由 | 依据 | 类别 |
|---|---|---|---|---|---|---|---|---|
| P-1 | QA 的 `blind` | `vst`、`rlog`、`varianceStabilizingTransformation` 均 `blind=TRUE`；`vst(nsub=1000,fitType="parametric")` | “Blind dispersion estimation”：独立于设计的样本 QA 用 TRUE；大量真实组间变化、下游分析时用 FALSE，避免过度压缩 | TRUE 1/20；19/20 未报告 | QA 显式 TRUE；已拟合后的 DE 展示显式 FALSE，标题报告目的与设置；强生物学差异下允许用户要求 FALSE 的补充图 | 两种用途不冲突；不能凭 blind QA 图自动删去生物学分组 | R:DESeq2/vst、rlog、varianceStabilizingTransformation；V:DESeq2/DESeq2.Rmd，“Blind dispersion estimation”；E:blind，PMC10711438 | A |
| P-2 | 样本离群警告的统计量/阈值 | `plotPCA(ntop=500,pcsToUse=1:2)` 只给图；DESeq2 Cook 距离处理基因层面，没有通用样本自动剔除阈值 | “Data quality assessment by sample clustering and visualization”“Approach to count outliers”：支持检查图，不给 PCA 到组中心距离的警戒阈值 | 原摘录 17/20 未报告；保留全部 1/20；WGCNA connectivity＜−3 1/20；最低蛋白编码计数 1/20 被独立核查判为非本模块离群规则，修正口径未报应为 18/20 | 可先确定“只展示、人工标记、不自动剔除”；草案的定量 QC warning 暂不冻结 | 缺少 PCA 距离统计量、缩放、组大小要求及校准阈值。下一阶段用注册 QA 数据和已知异常标签校准，并提供误报/漏报结果后再定；不得把 WGCNA 阈值移植成 PCA 阈值 | R:DESeq2/plotPCA；V:DESeq2/DESeq2.Rmd，上述两节；E:outlier_rule，PMC13485302、PMC10703692、PMC7673985；literature/verification.json，PMID 33203890 | C |
| P-3 | 校正批次后的图 | QA 函数不默认作批次校正；`removeBatchEffect(design=NULL,group=NULL)` 默认只保护截距 | DESeq2 “Why after VST are there still batches in the PCA plot?” 区分 VST 与去批次；limma Rd Note 明确仅探索/展示用途 | 结构化摘录未设该字段，不能给完整频率；合格 L3 另可核实校正展示至少 2/20（PMC12893922、PMC7688323），其中明确 `removeBatchEffect` 1/20 | 可由 `sva-batch` 提供保护生物学设计的校正展示，默认关闭，与原图并列并标注；校正矩阵不得进入 DE | 避免展示性残差化悄然改变检验；与 sva-batch P-1 共用输入来源约束 | V:DESeq2/DESeq2.Rmd，上述 FAQ；literature/l3_notes.md，PMC12893922、PMC7688323；跨模块 sva-batch R:limma/removeBatchEffect，Note | A |

### deseq2-lrt（4 项；N=26）

| 编号 | 问题 | 函数默认 | 官方推荐 | 范本多数 (n/N) | 建议 | 理由 | 依据 | 类别 |
|---|---|---|---|---|---|---|---|---|
| P-1 | reduced 模型 | `DESeq(test=c("Wald","LRT"),full=design(object),reduced=缺省)`；`nbinomLRT` 的 reduced 无默认 | “Likelihood ratio test”：显式 `test="LRT"`，reduced 从 full 去掉待检验项，参数数差给出自由度 | 10/26 报告 reduced；包含未写公式的文字描述，不能称 10 篇均给出完整公式 | reduced 必填；检验 full/reduced 嵌套、满秩、自由度差为正；输出两个公式、待检验项及自由度 | reduced 定义科学问题，不能默认一律 `~1`；批次等调整项必须一致保留 | R:DESeq2/DESeq、nbinomLRT；V:DESeq2/DESeq2.Rmd，“Likelihood ratio test”；E:reduced_model、full_model | A |
| P-2 | 模式聚类 | `degPatterns(minc=15,summarize="merge",time="time",col=NULL,consensusCluster=FALSE,reduce=FALSE,cutoff=0.7,scale=TRUE,pattern=NULL,groupDifference=NULL,eachStep=FALSE,nClusters=NULL,skipDendrogram=TRUE)` | DEGreport “Detect patterns of expression”：展示按条件/时间聚类；不规定所有 LRT 均须聚类 | 报告 8/26；DEGreport 1/26，K-means 2/26，其余各 1/26；无统一多数 | 默认关闭；时间过程需要时可选 `degPatterns`，显式登记全部结果相关参数、输入基因选择和 metadata 字段 | B 的取舍是提供便利默认聚类，还是要求研究者选择与时间设计吻合的聚类；建议保留可选功能，不能把探索性簇当作新的确认性检验 | R:DEGreport/degPatterns，Usage；V:DEGreport/DEGreport.Rmd，“Detect patterns of expression”；E:pattern_clustering | B |
| P-3 | LRT 后单一 FC 筛选 | `results(lfcThreshold=0)`；正阈值会转用 Wald 检验并覆盖 LRT p 值 | “I ran a likelihood ratio test, but results() only gives me one comparison.”：单列 LFC 与多项联合 LRT 的含义不同 | 4/26 有 LFC/方向筛选，22/26 未报告；不是支持通用阈值的多数 | LRT 联合显著性不加单系数 FC 门槛，也不把正 `lfcThreshold` 当作 LRT 开关；所需效应大小单列预先指定的 Wald contrasts，报告其独立检验家族 | 单个系数不能代表全部删去项；后续 contrasts 不应只在 LRT 命中的基因里无说明地重算 BH | R:DESeq2/results，`lfcThreshold`、Details；V:DESeq2/DESeq2.Rmd，上述 FAQ；E:lfc_filter | A |
| P-4 | fission 或 pasilla 锚点 | 非函数参数；不适用 | DESeq2 “Likelihood ratio test” 示例 `eval=FALSE`；没有该处的打印数值金标准。registry 将 fission 对应到 rnaseqGene “Time course experiments”，但这不是本地 L1 中已重跑的结果 | 锚点选择未采集，n/N 不适用 | 优先后续在锁定容器补齐 fission 及交互时间模型；pasilla 只作补充的嵌套模型 replay | B 的取舍是安装/锁定成本与时间交互覆盖。pasilla 二因素示例不能代替时间过程验证；两者均须记录容器版本、输入散列和结果来源 | V:DESeq2/DESeq2.Rmd，“Likelihood ratio test”；acceptance/data/ANCHOR_REGISTRY.md，第 3 行；SUITE.md，“M1-S0／待裁决”第 2 项 | B |

### edger-qlf（3 个 P 项及 1 个 Note；N=23）

| 编号 | 问题 | 函数默认 | 官方推荐 | 范本多数 (n/N) | 建议 | 理由 | 依据 | 类别 |
|---|---|---|---|---|---|---|---|---|
| P-1 | 新旧 QL 方法 | `glmQLFit(legacy=FALSE,dispersion=NULL,abundance.trend=TRUE,top.proportion=NULL)`；新方法处理小计数时调整偏差及残差自由度 | User’s Guide §4.4.7 “Dispersion estimation” 使用新 QL；`estimateDisp` 对新流程为可选 | edgeR 3.x 12/23（12/13 报版本），4.0.16 1/23；不是 12 篇显式报告 `legacy=TRUE` | 显式 FALSE；旧版本复现才选择 TRUE 并另列结果；不将 `estimateDisp` 的 trended dispersion 强塞给新流程 | 旧包占比是 **version artefact**。新法 4.0.0 引入、4.2.0 成为默认；4.0.16 那篇也不能仅凭版本认定使用新法 | R:edgeR/glmQLFit，Usage、Details；V:edgeR/edgeRUsersGuide.rendered.txt，§4.4.7；NEWS:edgeR，4.0.0、4.2.0；E:edger_version | A |
| P-2 | `robust` | `glmQLFit(robust=FALSE,winsor.tail.p=c(0.05,0.1))` | §4.4.7 “Dispersion estimation” 明确 strongly recommended TRUE | TRUE 1/23，且正是边界论文 PMC8532352；若按 Note 排除则 0/22，有效决定仍来自指南 | 显式 `robust=TRUE`；相关参数也登记；报告采用稳健 QL 先验估计 | 有直接官方推荐，不能因函数默认 FALSE 或唯一论文被排除就退回 FALSE | R:edgeR/glmQLFit；V:edgeR/edgeRUsersGuide.rendered.txt，§4.4.7；E:robust，PMC8532352 | A |
| Note | MINTIE 是否进入 QLF 多数统计 | 无适用性函数默认；`glmQLFit` 是拟合，`glmQLFTest` 与 `glmLRT` 是不同检验 | Guide §4.4.8 “Differential expression” 对应 QL F-test，不能仅以拟合函数判断测试类型 | 当前 yes 集合含 PMC8532352 1/23；核查指出其最终测试为 `glmLRT` | 建议将其保留为邻近方法实例，从“最终 QLF 流程”频次分母剔除；本表仍如实给当前 N=23，并给排除后的敏感性计数 | B 的取舍是模块范围按拟合还是按最终检验定义。建议后者；排除后 N=22、3.x 11/12 报版本、robust TRUE 0/22、事后 FC 8/22、glmTreat 2/22；本次不改 `_applies` | E:_applies、robust、lfc_filter、edger_version，PMC8532352；literature/verification*.json，该论文核查；R:edgeR/glmQLFTest，Details；PACK 末节 Note | B |
| P-3 | FC 判据 | `glmQLFTest` 检验零效应；`glmTreat(lfc=log2(1.2),null="interval")` 检验最小效应 | §2.14 “Differential expression above a fold-change threshold”、§4.4.8：用 `glmTreat`；Rd 说明阈值与观察 FC 门槛不同 | `glmTreat` 2/23，事后 FC 9/23；未报告不代表不用 | 默认 QLF 零效应；最小生物学 FC 由用户指定并转换成 `lfc=log2(fc)`；`null="interval"` 显式登记；默认关闭的展示筛选与 Wald/limma 共用报告语义 | B 的取舍是支持论文式展示门槛的便利性与误读风险。三个包可统一假设目标和 FC 单位，不能声称它们的统计方法或 p 值等价 | R:edgeR/glmTreat，Usage、Details；V:edgeR/edgeRUsersGuide.rendered.txt，上述节；E:treat、lfc_filter | B |

### limma-voom（3 项；N=24）

| 编号 | 问题 | 函数默认 | 官方推荐 | 范本多数 (n/N) | 建议 | 理由 | 依据 | 类别 |
|---|---|---|---|---|---|---|---|---|
| P-1 | `voom+lmFit` 或 `voomLmFit` | 没有“管线选择”的函数默认。`voom(span=0.5,adaptive.span=TRUE,normalize.method="none")`；本地未存 `edgeR::voomLmFit` 的 Rd/formals，不能列其完整默认 | §15.7 “Differential expression: voomLmFit” 明确推荐后者，理由是零计数条件下残差方差估计及整合权重/相关估计 | voom 家族 24/24，其中 `voomLmFit` 1/24；不能写 24/24 均是独立 `voom+lmFit` | 方法方向建议改用 `voomLmFit`；保留旧管线作明确复现选项。完整参数冻结前必须补齐锁定 edgeR 4.10.5 的 `voomLmFit` Rd/formals，核对输出与下游所需 EList/weights | 缺的是新入口完整默认和输出契约；指南推荐并不缺。按已存 release commit 补收该 Rd，或在锁定容器导出 formals，再登记 §3.3 参数。不能让历史出现频次推翻当前指南，也不能凭记忆补 API | R:limma/voom、lmFit；V:limma/usersguide.rendered.txt，§15.7；NEWS:edgeR，`voomLmFit` 条目；E:voom_variant，PMC13506345；docs/handoff/ENGINEERING_PLAN.md，§1.2 A、§3.3 | C |
| P-2 | FC 判据 | `eBayes` 零效应；锁定 `treat(fc=1.2,lfc=NULL,trend=FALSE,robust=FALSE,legacy=NULL,upshot=FALSE)` | §15.5 “Differential expression: voom” 展示 `eBayes` 及可选 `treat(lfc=log2(1.2))`；Rd 允许 `fc` 参数 | treat 1/24，事后 FC 5/24，五种取值；无阈值多数 | 默认 `eBayes`；可选最小效应 `treat`，统一接受用户预设 FC 并显式转成 `lfc=log2(fc)`（同时 `fc` 按登记策略显式处理）；展示筛选默认关闭 | B 的取舍同 Wald P-2。草案 `treat(fc=1.2)` 在锁定版确实有效，不能依据旧版本印象判为错误；仍不宜把 1.2 当作所有研究的生物学阈值 | R:limma/treat、eBayes；V:limma/usersguide.rendered.txt，§15.5；E:ebayes，PMC13506345；E:lfc_filter | B |
| P-3 | 样本质量权重 | 普通 `voom(weights=NULL)` 不等于自动估计样本质量权重；选择 `voomWithQualityWeights` 才估计，`var.design=NULL,var.group=NULL,method="genebygene"` | §15.6 “Voom with sample quality weights”：MDS 异常样本时可用；§15.7 用 `sample.weights=TRUE` 显式启用 | `voom_variant` 无显式质量权重记录（0/24），不能解释成证实 24 篇均未使用 | 默认不因 QA 标记自动启用；用户依据预先规定的 QC 判断显式开启，记录权重、设计和选项；采用新入口时同样保持显式开关 | B 的取舍是建模质量异质性与增加估计复杂性。草案“on … when QA flags”与“never automatic”含混，统一为标记只提示，用户显式启用 | R:limma/voom、voomWithQualityWeights；V:limma/usersguide.rendered.txt，§15.6–15.7；E:voom_variant | B |

### limma-array（3 项；N=13）

| 编号 | 问题 | 函数默认 | 官方推荐 | 范本多数 (n/N) | 建议 | 理由 | 依据 | 类别 |
|---|---|---|---|---|---|---|---|---|
| P-1 | `eBayes trend/robust` | `trend=FALSE,robust=FALSE,span=NULL,legacy=NULL`；`legacy=NULL` 的算法选择与残差 df 是否相同有关 | §3.2 Quick Start 说二者 often helpful；§17.4 Agilent “Differential expression” 用 TRUE/TRUE；Rd 将 trend 联系到均值—方差关系，并非所有芯片强制 TRUE | 0/13 明报这两个参数；不能将沉默当作 FALSE | 建议将 TRUE/TRUE 作为当前已注册 Agilent/相应平台预设，保留用户显式覆盖；其他已归一化平台需报告并检查均值—方差趋势，不称“芯片一律 TRUE” | B 的取舍是单一便捷预设与平台/预处理适配。与 dupcor 使用同一平台规则；RNA-seq voom 不机械继承芯片 trend | R:limma/eBayes，Usage、Details；V:limma/usersguide.rendered.txt，§3.2、§17.4；E:ebayes；PACK C/D | B |
| P-2 | 探针过滤与重复探针 | `lmFit` 不自动执行平台过滤或同基因合并；矩阵方法 `avereps(ID=rownames(x))`（EList/MAList 方法 `ID=NULL` 从对象取 ID）仅在调用时平均指定 ID 的重复 | Guide 第 7 章 “Filtering”：背景可估计时保留至少 k 张高于背景的探针，k 为最小处理组合重复数，且在归一化后建模前；Rd 区分技术重复点与不同探针 | 7/13 报探针规则；去控制/低背景并平均重复 ID 1/13（PMC13488902），另有合并重复 1/13、最大 t 选探针 1/13、最大 CV 1/13，规则不统一 | 去除明确控制探针；仅在有平台背景信息时使用背景规则并显式 k；默认保留不同探针，按用户指定且验证的同一技术 ID 才 `avereps`，保留探针→基因映射 | B 的取舍是探针层信息保留与基因层交付。不同靶位探针不能仅因同一 gene symbol 就当技术重复；按最大检验 t 选探针会把检验结果用于选择，应拒绝成为通用默认 | R:limma/avereps；V:limma/usersguide.rendered.txt，第 7 章、“Probe Filtering and Array Quality Weights”；E:probe_filter | B |
| P-3 | 是否重新采集 | 不适用 | 包指南没有论文样本量或重采规则；本仓库取证流程另定 | 当前适用 13/30；适用者中 `ebayes` 明报 0/13，现有语料无法裁决选项频率 | 建议后续以平台词分层补采，保留旧语料与判定记录；当前统计按 N=13 发布，不凑成 N=30 | B 的取舍是补采成本与平台覆盖；补采可能改善经验频次，但不会替代已知函数/指南证据，本次不执行采集 | literature/corpus.jsonl、E:_applies、ebayes；SUITE.md，“M1-S0／偏离之处”第 4 项；PACK V、末节 P-3 | B |

### limma-dupcor（3 项；N=30）

| 编号 | 问题 | 函数默认 | 官方推荐 | 范本多数 (n/N) | 建议 | 理由 | 依据 | 类别 |
|---|---|---|---|---|---|---|---|---|
| P-1 | 是否必报一致性相关 | `duplicateCorrelation(trim=0.15)` 返回估计 `consensus.correlation`，不是固定输入常数 | Guide §17.3 “Within-patient correlations”、§18.1 示例输出估计并传给拟合 | 1/30 报值 0.83（PMC9237031），29/30 未报告 | 必报估计值、block 含义/数目/大小、输入设计、RNA-seq 估计轮次；估计值显式传入 `lmFit(correlation=...)` | 报告缺失不是省略理由；不得把示例 0.134/0.446 或文献 0.83 当作默认 | R:limma/duplicateCorrelation，Value、Details；V:limma/usersguide.rendered.txt，上述节；E:consensus_correlation、two_rounds | A |
| P-2 | block 校验与伪重复 | `block=NULL,ndups=2,spacing=1`；非 NULL block 时估计块内重复观测相关，`ndups` 被忽略；要求样本数至少比 design rank 多 2 | §9.7 “Multi-level Experiments”：按相关重复单位建模；§9.4.2 “Blocking” 也介绍固定效应 block | 个体类 23/30，clone 类 2/30，family 1/30，population/experimental repeat 2/30，lane 1/30，species 1/30 | 默认要求 block 的相关单位说明和样本对应；检查重复、可估性、design rank、残差 df；不能同时把同一 block 全部固定效应列与随机相关重复加入。技术批次默认进 design；特殊随机块须明确说明 | 防止伪重复是 A 级原则，但“任何技术批次都绝不能是 block”并非 Rd 定理；建议修正草案绝对措辞。family/clone 等也可表示相关单位，不只同一个体 | R:limma/duplicateCorrelation，Arguments、Details；V:limma/usersguide.rendered.txt，§9.4.2、§9.7；E:block，尤其 PMC11514464、PMC11293591、PMC10349101 | A |
| P-3 | 芯片的 `trend` 与 array 统一 | `eBayes(trend=FALSE,robust=FALSE)` | §17.3 “Within-patient correlations” 展示 `trend=TRUE`，并不因此规定 `robust=TRUE` | 未设独立 trend 摘录字段；现存记录没有可计数的明确 trend 值，不能推断 FALSE，n/N 不适用 | 继承 limma-array P-1 的平台预设及显式覆盖；同输入尺度、平台及设计采用一致的 trend 规则，不因是否有 block 改变 | B 的取舍与 array P-1 相同；robust TRUE 是跨模块预设建议，不能声称该 Illumina 示例直接证明它 | R:limma/eBayes；V:limma/usersguide.rendered.txt，§17.3；literature/extraction.jsonl（字段覆盖）、PACK V；跨模块 limma-array P-1 | B |

### sva-batch（4 项；N=21）

| 编号 | 问题 | 函数默认 | 官方推荐 | 范本多数 (n/N) | 建议 | 理由 | 依据 | 类别 |
|---|---|---|---|---|---|---|---|---|
| P-1 | 校正矩阵能否进入 DE | ComBat/ComBat_seq 返回校正矩阵，函数不规定套件路由；`removeBatchEffect` 的输出为校正 log-expression | sva “Applying the ComBat function to adjust for known batches” 确实用校正后 `f.pvalue`；limma Rd Note 明确线性建模应在设计里放批次；指南存在上下文差别 | 原值重编码：明确检验用途 **11/21（11/17 报用途）**，其中 DESeq2/limma 7/21；纯展示或 SV 入设计 3/21。PACK 的 10/17 漏计包含检验的记录，详见复算索引 | 按套件边界：校正矩阵仅用于展示/描述性打分；DE 用未校正的合法输入，把 batch/SV 显式放进模型。来源已知为校正矩阵时应拒绝进入标准 DE 路径，不能仅警告后照跑 | 统计设计和项目契约优先于范本；不把 limma 的限制夸大为所有 ComBat 方法在任何情境都无效。GSVA 分数若继续作推断，也需单独满足设计/不确定性要求 | R:limma/removeBatchEffect，Note；R:sva/ComBat、ComBat_seq；V:sva/sva.Rnw，上述节及“Adjusting for surrogate variables using the limma package”；E:corrected_used_for；docs/handoff/ENGINEERING_PLAN.md，§1.2 A、§5 路由 | A |
| P-2 | 保留生物学效应与混杂 | `ComBat(mod=NULL)`；`ComBat_seq(group=NULL,covar_mod=NULL,full_mod=TRUE)`；`sva(mod=必填,mod0=NULL)`，不能把所有函数说成 mod 默认 NULL | sva “Setting up the data”“Surrogate variables versus direct adjustment”：full 模型包含研究变量及调整变量，null 去掉研究变量；“ComBat-Seq …” 允许保护 group | 明确保留相关生物学协变量 3/21；15/21 未报 mod；其余有不保留/只报 batch 的情形，不能统算保护 | 研究变量/待检验设计必填（允许连续变量，不局限二分类 group）；验证 batch 与研究变量的联合可估性；完全混杂拒绝，部分混杂报告并检查目标 contrast 可估性 | 不能凭批次校正创造本来不可辨识的生物学效应；保护模型同时用于展示校正和下游 DE 设计传递 | R:sva/ComBat、ComBat_seq、sva；V:sva/sva.Rnw，上述节；E:mod，PMC9833827、PMC13510735、PMC11559625；跨模块 deseq2-wald V:DESeq2/DESeq2.Rmd，“Model matrix not full rank” | A |
| P-3 | SV 数与估计法 | `num.sv(method=c("be","leek"),B=20,seed=NULL,vfilter=NULL)`；`sva(n.sv=NULL,numSVmethod="be")` | “Applying the sva function to estimate batch and other artifacts” 及方差过滤节显式演示 `method="leek"`；并说明不指定 `n.sv` 会估计，没有宣布一种普遍最优 | `n_sv` 仅 1/21 报 SV1，20/21 未报；没有 be/leek 比较频次 | 建议显式 `method="be",B=20,vfilter=NULL` 加固定、记录的 seed；把所得 `n.sv` 显式交给 `sva/svaseq`，输出模型及 SV 数；可选 leek 作明确敏感性方案 | B 的取舍是保留包默认的置换方法及其随机性，还是完全照指南确定性 leek 示例；本地证据不足以证明 be 更优。所有 SV 加入 DE 设计，不先回归掉再检验 | R:sva/num.sv、sva、svaseq；V:sva/sva.Rnw，上述两节及“Adjusting for surrogate variables using the limma package”；E:n_sv，PMC13564084 | B |
| P-4 | bladderbatch 锚点 | 非函数默认 | sva “Overview”“Setting up the data from an ExpressionSet” 实际依赖 `bladderbatch::bladderEset`；ComBat-Seq 模拟和 svaseq zebrafish 为另两条链 | 未采集锚点选择，n/N 不适用 | 建议后续补锁定版本 bladderbatch，分别覆盖 ComBat 和 SV 入模型；另用指南模拟计数覆盖 ComBat_seq，不声称同一锚点验证所有方法 | B 的取舍是追加数据依赖与多入口覆盖；替代数据必须重新登记，不能把不同数据的结果贴作指南打印值 | V:sva/sva.Rnw，上述节、“ComBat-Seq for batch adjustment on RNA-Seq count data”“sva for sequencing (svaseq)”；acceptance/data/ANCHOR_REGISTRY.md，第 8 行；SUITE.md，M1-S0 待裁决第 2 项 | B |

### clusterprofiler-ora（3 项；N=30）

本模块及下面两个 clusterProfiler 模块的 V 为 `clusterProfiler.qmd`，标题 “Statistical analysis and visualization of functional profiles for genes and gene clusters”。“Vignette” 节只提供外链；`L2/README.md` 和 `L2/manifest.tsv` 只保存在线书的来源/散列，没有章节正文。因此下表不把书中 `data-contract`、`go-enrichment`、`comparecluster-analysis` 的 PACK 转述写成已独立核实的官方推荐。补证应按 manifest 对应 commit 收集允许存档的相关段落与上下文，或在后续获准联网的取证任务中核验；本次没有访问外网。

| 编号 | 问题 | 函数默认 | 官方推荐 | 范本多数 (n/N) | 建议 | 理由 | 依据 | 类别 |
|---|---|---|---|---|---|---|---|---|
| P-1 | GO 本体 | `enrichGO(ont="MF")` | 本地 vignette 无取值建议；Rd Examples 使用 `ont="BP"`，只是示例，不是全局强制推荐 | 明确涉及 BP 8/30，其中 BP 单本体 7/30、同时 BP/CC/MF 1/30；明确本体者 BP 8/8，不能说全部 30 篇都选 BP | 默认预设 BP、可明确改 CC/MF/ALL，并在 Methods 记录；与 compare 同步 | 本体取决于问题，BP 有报告惯例与 Rd 示例支持；切换 ALL 需同时明确多重检验范围和 `pool`，不得把一次 BP 的结果当作完整 GO 结论 | R:clusterProfiler/enrichGO，Usage、Arguments、Examples；V:clusterProfiler/clusterProfiler.qmd，“Vignette”；E:gene_set_db | A |
| P-2 | ORA 背景基因集 | `enrichGO(universe=缺省)` 语义为数据库中全部基因；`enricher(universe=NULL)` | 本地 vignette 未提供背景推荐；Rd Arguments 解释可指定 background，不能独立证实 PACK 所引在线书句子 | 与实验可选择范围相关背景 6/30（6/6 报告），24/30 未报告；其中含检测集与注释交集，不全是同一 DE tested 定义 | 背景必填或从上游追溯，取该次列表选择流程中有资格被选中的基因，使用相同 ID 映射；报告候选背景、映射后背景、输入与有效交集数。任意外来列表也不能静默回退全基因组 | 这是条件抽样总体的选择；显著基因自身不可充当背景。“tested genes”须和实际筛选规则一致：若按 padj 选，不能无说明混入无 padj 的不可选行；非 DE 输入按其检测/筛选范围定背景 | R:clusterProfiler/enrichGO、enricher，`universe`；E:universe，6 篇见复算索引；PACK P-2 所引书仅作待补证项 | A |
| P-3 | `simplify` | 不是 enrichGO 自动步骤；调用后默认 `cutoff=0.7,by="p.adjust",select_fun=min,measure="Wang",semData=NULL` | 本地 vignette 无默认开关建议；Rd 提供 GO 冗余简化接口 | `simplify` 2/30；另有 REVIGO 1/30，不能混计；其余 27/30 未报告 | 默认关闭；显式选择时用上述 0.7 预设并保留原始全表、被合并 term 和代表选择规则 | A 级建议保护原始结果且不强加简化；0.7 来自锁定函数默认，不是文献多数。简化是展示/归纳步骤，不能重新解释为更强显著性 | R:clusterProfiler/simplify，Usage、Arguments；V:clusterProfiler/clusterProfiler.qmd，“Visualization”“Vignette”；E:simplify，PMC13545012、PMC11662933、PMC8597987 | A |

### clusterprofiler-gsea（3 项；N=28）

| 编号 | 问题 | 函数默认 | 官方推荐 | 范本多数 (n/N) | 建议 | 理由 | 依据 | 类别 |
|---|---|---|---|---|---|---|---|---|
| P-1 | 排序统计量 | `GSEA/gseGO(geneList=必填)`；enrichit Rd 要求有名称且降序的数值统计量，可举 logFC 为例，没有自动选择收缩 LFC | 本地 vignette 没有排序推荐；在线书的 logFC 示例未存正文。Rd 的 logFC 例子不等于必须使用 shrunken LFC | FC 类 7/28（7/15 报排序；包括 mixed LME/ROTS 和非 log FC），检验统计量 3/28，相关系数 2/28，模型系数 2/28，signed P 1/28，其他 1/28；mixed 行可重叠。7/15 未过半，不能称多数 | 与 fgsea 统一：DESeq2 单 contrast 用带方向 Wald `stat`，limma 用 moderated t；LFC/相关系数等允许用户明确选择并命名。全体可排名基因进入，不预先按显著性截断；不能用无方向 LRT/多 df F 直接代替有方向排名 | B 的取舍是按效应量排序还是按效应相对不确定性排序；本地证据不能证明一种普遍更优。建议统计量作为 DE 衔接预设，解决当前两个模块对同一输入默认排名不一致 | R:clusterProfiler/GSEA、gseGO；L1_cran2026-09-15/enrichit/Rd/gsea.Rd，`geneList`；E:ranking_metric；跨模块 deseq2-wald R:DESeq2/results，Value；limma-voom R:limma/eBayes，Value | B |
| P-2 | 开发层与锁定容器引擎及金标准 | 锁定 `method="multilevel",nPerm=1000,adaptive=FALSE,minPerm=101,maxPerm=1e5,pvalThreshold=0.1`；enrichit 0.2.1 还有 `eps=1e-10,sampleSize=101,seed=FALSE,nPermSimple=1000,scoreType="std",weight=NULL` | 本地 vignette 无迁移操作建议；DOSE NEWS 4.5.1 记载迁移 enrichit；项目 §3.5 规定环境签名和容器金标准 | 明报 nPerm 5/28；没有支持 enrichit 0.2.1 与旧 fgsea 数值等价的范本；旧置换次数不能推翻新 API | 接受版本分层；只用锁定容器生成权威 goldens，开发层签名不符时仅逐字节基线检查 SKIP，其他可执行检查继续；显式登记下游参数及 seed/RNG/并行配置 | 引擎迁移是 **version artefact**。同签名先按项目要求检查主表逐字节一致；PACK 将 padj 自动改容差档未经 §3.5 支持。`eps` 是估计下限，不是随机误差容差；NES 也不能跨引擎保证精确相等 | R:clusterProfiler/GSEA、gseGO；NEWS:DOSE，4.5.1；L1_cran2026-09-15/enrichit/Rd/gsea.Rd、NEWS.txt，0.2.0–0.2.1；E:permutation；docs/handoff/ENGINEERING_PLAN.md，§3.4–3.5 | A |
| P-3 | 0.05 或 Broad 0.25 | `GSEA(pvalueCutoff=0.05,pAdjustMethod="BH")`，Rd 将 cutoff 定义为 adjusted pvalue | 本地 vignette 没有支持 0.25 的推荐；函数 Rd 支持 0.05 | 重算：明确 adjusted/q/FDR 0.05 为 6/28，明确参数名 pvalueCutoff/PvalueCutoff 0.05 为 3/28；仅“P cutoff”1/28 不可确认为 adjusted；FDR 0.25 为 2/28；nominal 0.05 为 1/28；其他阈值 1/28。PACK 将 9 个可靠的 0.05 支持加含混 1 个写成 10/14 | 主推断显式 BH 0.05；0.25 仅作事先声明的探索性/历史复现选项。建议计算时 `pvalueCutoff=1` 以保存全部可检验项，再另存 `p.adjust<0.05` 标记，原始表不裁掉 | 9/14 报告者明确支持 adjusted 或参数层面的 0.05；不能将 nominal P 或旧桌面程序的约定混成同一 FDR。函数 cutoff=0.05 与“总是全表”需要分别实现 | R:clusterProfiler/GSEA，`pvalueCutoff`；E:enrich_cutoff（含混 PMC13535199；0.25 PMC7592056、PMC10668425）；PACK D-G5、P-3 | A |

### clusterprofiler-compare（3 项；N=26）

| 编号 | 问题 | 函数默认 | 官方推荐 | 范本多数 (n/N) | 建议 | 理由 | 依据 | 类别 |
|---|---|---|---|---|---|---|---|---|
| P-1 | GO 本体与 `fun` | `compareCluster(fun="enrichGO")`，通过 `...` 传递的 `ont` 继承 enrichGO 的 MF | 本地 vignette 不给选择；compareCluster Rd 介绍列表/公式接口，ORA 的 enrichGO Rd 示例用 BP；在线书 compare 例子本地无法核实 | BP-only 8/26、包含 BP/CC/MF 或 ALL 3/26、CC-only 1/26；明确本体 12 篇中 BP 出现 11/12，不能说全都 BP。`enrichGO` 合计 **9/26（9/9 报 fun）**，PACK 的 8/9 仅计单一 enrichGO 行 | 与 ORA 同步显式 `fun="enrichGO",ont="BP"`；用户改变本体时连同比较配置记录，保持相同注释版本和检验范围 | 与 ORA 同一含义优先；CC 和 ALL 是真实需求，不是提取错误，也不是 BP 独占的证据 | R:clusterProfiler/compareCluster；跨模块 clusterprofiler-ora R:clusterProfiler/enrichGO；E:gene_set_db、fun；V:clusterProfiler/clusterProfiler.qmd，“Vignette” | A |
| P-2 | 多列表的背景 | compareCluster 本身无背景默认；`fun="enrichGO"` 继承全注释背景 | 无本地指南背景正文；规则同 ORA P-2 | 此模块未采 `universe` 字段；可核实背景记录为 0/26，但不能说 26 篇都没有交代，也不能造 0/0 多数 | 每列表附候选背景与来源；确实来自同一可选择总体时传同一显式 universe；若检测空间不同，分别 enrichment 并注明背景差异，不能拿所有列表并集作“共同背景” | A 级统计边界；“expressed”不自动等于“可被当前规则选中”。比较图并不检验“某通路在列表 A 比 B 更富集”的差异显著性 | R:clusterProfiler/compareCluster，Description、`...`；跨模块 clusterprofiler-ora R:clusterProfiler/enrichGO，`universe`；literature/extraction.jsonl（字段覆盖）；PACK P-2 | A |
| P-3 | 每个列表定义 | `geneClusters` 必填，可为列表或公式；函数不要求附科学选择过程 | Rd “Compare gene clusters functional profile” Examples 演示分组比较；本地 vignette 没有强制命名元数据规则 | `clusters` 严格 `not reported` **4/26**；另有 PMC11540020 1/26 只说功能结果未命名具体基因列表，合计定义不足 5/26；两种口径应分开 | 接收命名列表或可等价转换且保留原式的公式；必报每列表研究单位、上游模型/contrast、方向、阈值、top-N、输入/映射后数量及背景 | A 级报告要求；草案“5 篇未说明”是语义合并，不是 5 个 `not reported`。禁止把重复的同一个体当独立样本，也不把 term 列表误作 gene 列表 | R:clusterProfiler/compareCluster，Arguments、Examples；E:clusters，PMC11540020 及复算索引；PACK P-3 | A |

### fgsea-prerank（3 项；N=30）

| 编号 | 问题 | 函数默认 | 官方推荐 | 范本多数 (n/N) | 建议 | 理由 | 依据 | 类别 |
|---|---|---|---|---|---|---|---|---|
| P-1 | 排序统计量 | `stats` 必填、有名称；`fgseaMultilevel(gseaParam=1,scoreType="std")`，没有自动选择基因统计量 | “Quick run” 使用 exampleRanks，未规定来源统计量；“Starting from files” 读取 ranks | signed P 3/30、Wald 2/30、logFC 2/30、t 2/30、其他研究分数 6/30；15/30 未报（含 mixed run 只在有明确值时归类） | 与 clusterprofiler-gsea P-1 同一排名输入与 provenance；Wald/t 为 DE 衔接预设，其他统计量必须命名；检查有限值、唯一 ID、方向和 ties；signed P 选项必须说明零 P 和无穷值处理 | B 的取舍同 GSEA P-1；一致性靠同一输入契约，不靠两包输出碰巧一致。不得仅给显著 DEG 子集却称全排序 GSEA | R:fgsea/fgseaMultilevel，`stats`、`gseaParam`；V:fgsea/fgsea-tutorial.Rmd，“Quick run”“Starting from files”；E:ranking_metric；docs/handoff/ENGINEERING_PLAN.md，§5 富集路由 | B |
| P-2 | 默认基因集 | `pathways` 必填；无 Hallmark 函数默认 | “Quick run”“Using Reactome pathways” 展示内置/Reactome 数据，不强制 Hallmark | 严格以 fgsea 那次运行计 Hallmark **11/30**，不是总体过半；仅 23/30 有明确该运行集合，另 2 篇在其他分析提数据库不能算已知 fgsea 集合，PACK 的 n.r.=5 应为该口径 7 | 建议提供预选 Hallmark 的 bulk 入口，允许研究问题需要的注册自定义集合；集合、物种、版本及散列必须已解决，不能默默下载或认定 registry 已完备 | B 的取舍是较精炼固定集合与研究特异覆盖；Hallmark 是常见选择而非官方默认。当前锁定容器 msigdb 条目仍待填，依赖基础设施 M1-3，不能称已经可直接运行 | R:fgsea/fgseaMultilevel，`pathways`；V:fgsea/fgsea-tutorial.Rmd，上述节；E:gene_set_db；env/refdata_registry.json，`msigdb_collections` 与开发层对应条目 | B |
| P-3 | 集合大小 | `minSize=1,maxSize=length(stats)-1` | “Quick run”“Starting from files” 使用 15–500；**“Using Reactome pathways” 只设 maxSize=500**，所以 PACK “every tutorial call” 不成立 | minSize=10 为 1/30；29/30 未报，没有 15–500 的论文多数 | 建议主流程显式 15–500，报告 ID 交集后保留/排除数；用户研究小集合时可预设其他范围。与 CP-GSEA 的 10–500 保持明确差异，做两引擎对照时使用同一范围 | B 的取舍是过滤极小/极大集合与保留具体小通路；15–500 有教程实例支持，不是包的普遍强制规则 | R:fgsea/fgseaMultilevel，Usage、Value `size`；V:fgsea/fgsea-tutorial.Rmd，上述三节；E:gs_size，PMC11866449 | B |

### gsva-score（3 项；N=30）

| 编号 | 问题 | 函数默认 | 官方推荐 | 范本多数 (n/N) | 建议 | 理由 | 依据 | 类别 |
|---|---|---|---|---|---|---|---|---|
| P-1 | kernel 与输入尺度 | `gsvaParam(kcdf="auto",kcdfNoneMinSampleSize=200,tau=1,maxDiff=TRUE,absRanking=FALSE,sparse=TRUE)`；参数对象 API | “Overview of the GSVA functionality”：auto/Gaussian/Poisson/none；Gaussian 用连续量、Poisson 用整数。bulk 示例旧段仍称 Gaussian 默认，与 Usage/NEWS 冲突 | Gaussian 1/30；29/30 未报。输入明确值 13/30，其中含原尺度 TPM、rank-normalized TPM、尺度不明 pseudobulk，不全是 log。报版本 17 篇中旧于 1.50 的 12/17 为 **version artefact** | 显式 `kcdf="auto",kcdfNoneMinSampleSize=200`，记录输入尺度/存储类型、实际分支和参数对象；套件 bulk 预设接 VST/logCPM。整数计数模式必须明确 `kcdf="Poisson"`；VST 不重复取 log | 新 API/default 优先于旧文献；auto 可能选 none，“报告 kernel”应允许无 kernel 的 ECDF。拒绝默认计数输入是套件接口策略，不是声称 auto 本身不能处理计数 | R:GSVA/gsvaParam，Usage、`kcdf`；V:GSVA/GSVA.Rmd，“Overview of the GSVA functionality”“Quantification of pathway activity in bulk microarray and RNA-seq data”；NEWS:GSVA；E:kcdf、input、gsva_version | A |
| P-2 | 集合大小 | `gsvaParam(minSize=1,maxSize=Inf)` | “Quantification of pathway activity in bulk microarray and RNA-seq data” 用 5–500；“Differential expression at pathway level／Running GSVA” 用 **5–300**，并非唯一推荐 | 0/30 报大小；无多数 | 建议 bulk 通用预设 5–500，完整报告过滤；复现 immunologic 示例用 5–300。把尺寸视为用户可配置的分析决定，不称官方统一标准 | B 的取舍是集合覆盖与极小/极大集合稳定性；不能为了和 fgsea 一样就改成 15–500，它们计算目标不同 | R:GSVA/gsvaParam；V:GSVA/GSVA.Rmd，上述两节；E:gs_size | B |
| P-3 | 下游组间检验 | GSVA 只返回 scores；不自带组间检验 | “Differential expression at pathway level／Differential expression”：原始 scores 用 `lmFit`，SV 放设计，`eBayes(robust=TRUE)`；还展示 `trend=sqrt(gssizes)`，不是芯片 `trend=TRUE` | limma 3/30（3/15 报下游方法）；Wilcoxon/Mann–Whitney 6/30、相关 4/30、survival 4/30、clustering 1/30，类别重叠；无统一多数 | 打分与推断分开，scores 交给明确接收连续值的 limma 入口并保留样本/设计；不走 `voom` 或计数模型，不自动继承 array 的探针过滤/trend；有重复单位走相关设计；survival 另行分析 | A 级架构边界有直接指南示例。批次校正 scores 仅展示，推断时原始 scores+协变量；不能把每个细胞直接作为独立生物学重复 | R:GSVA/gsva，Value；V:GSVA/GSVA.Rmd，上述节（`lmFit(assay(es),mod)`）；E:downstream_test；docs/handoff/ENGINEERING_PLAN.md，§1.2 B | A |

### limma-camera（3 项；N=29）

| 编号 | 问题 | 函数默认 | 官方推荐 | 范本多数 (n/N) | 建议 | 理由 | 依据 | 类别 |
|---|---|---|---|---|---|---|---|---|
| P-1 | 默认竞争性还是自包含检验 | 没有方法路由默认；`camera(inter.gene.cor=0.01,use.ranks=FALSE,allow.neg.cor=FALSE,trend.var=FALSE,directional=TRUE)`；`cameraPR` 接 ranked statistics | §18.1.10 “Gene set testing” 对 Yoruba 示例 camera 更强的结果不代表普遍优越；Rd 明确竞争性问题，fry/roast 为自包含问题 | camera 14/29、fry 8/29、cameraPR 7/29、roast 6/29（多方法重叠）；camera **14/29 未过半**，只是最常见 | 先按科学问题路由；标准竞争性入口预设 camera，只有排序量时选 cameraPR，自包含问题选 fry/roast；不运行多法后挑显著者。0.01 是 preset，不能报告为估计相关 | B 的取舍是检验集合相对于背景的富集，还是集合内是否存在效应，不能以更小 P 值选择。固定 0.01 与估计相关也有 Rd 所述严格误差控制/排名解释性取舍，必须报告 | R:limma/camera，Usage、Details；R:limma/roast，Details；V:limma/usersguide.rendered.txt，§18.1.10；E:test、inter_gene_cor | B |
| P-2 | roast/mroast 旋转次数 | `nrot=1999,approx.zscore=TRUE,legacy=FALSE`；`mroast(adjust.method="BH",midp=TRUE)` | §18.1.10 用 9999；**roast Rd 明确发表用途推荐至少 9999**，不只是偏离默认的任意示例 | 现有摘录没有 rotations 参数，n/N 不适用；不能宣称论文实际用了默认次数 | 发表预设显式 9999、固定并记录 seed/RNG；小规模开发可显式 1999 但另设签名；记录 `midp`。大量集合需要更高分辨率时按问题选 fry 或增加 nrot | A 级直接官方支持。普通 mixed/双侧 p 下限 `1/(nrot+1)`；单侧 Up/Down 为 `1/(2*nrot+1)`；BH 使用 mid-p 时不能把双侧原始 P 下限当全部 FDR 的下限 | R:limma/roast，Arguments `nrot`、Details；R:limma/mroast；V:limma/usersguide.rendered.txt，§18.1.10；literature/extraction.jsonl（字段覆盖） | A |
| P-3 | 显微镜 camera 负例 | 非函数参数 | 包指南不讨论自然语言路由；项目 G5 要求路由评测 | 当前适用 29/30；留下的当前不适用例为 FRY 基因。extraction 另保留 20 篇旧语料论文，**不计入当前 N**；不能因旧显微镜例存在而降低当前适用率 | 保留一例经语境核实的“camera=显微镜”和一例“FRY=基因”作独立负例，另有 cameraPR/limma 阳性例；与分析频次语料分开标注 | A 级消歧要求来自已记录的检索失败；不能通过全部改名为 camera 而掩盖路由错误 | literature/corpus.jsonl、E:_applies；PACK “Collection history”、末节 P-3；SUITE.md，“M2-S0／偏离之处”第 1 项；docs/handoff/ENGINEERING_PLAN.md，G5 | A |

## 跨模块一致性

| 冲突或潜在冲突 | 统一建议与边界 | 仓库依据 |
|---|---|---|
| Wald、edgeR、limma 的事后 FC 筛选与阈值检验 | 共用“零效应主检验／预先指定最小效应检验／仅展示筛选”三个明确字段；主分析 BH 0.05 显式记录，Wald 的 `alpha` 与报告一致。用户的 fold change 一律先说明线性或 log2 单位，再映射至包参数；不能把三个包的不同阈值检验称完全等价。LRT 联合检验禁止套一个显示系数的 FC 筛选。 | 上文 Wald P-2、edgeR P-3、voom P-2、LRT P-3 的 Rd 与指南；`docs/handoff/ENGINEERING_PLAN.md` §3.3 |
| CP-GSEA 草案用收缩 LFC，fgsea 草案用 Wald/t | 同一上游 contrast 默认生成一份带名称的方向性统计量，再供两个接口使用。若用户选择效应量排名，两边同时改成同一明示的 LFC 类型；不得一边 MLE、一边 shrinkage 而称引擎对照。LRT/F 多项联合统计量没有单一方向，应要求具体 contrast 或明示非方向分析。 | `acceptance/exemplars/clusterprofiler-gsea/PACK.md` P-1；`acceptance/exemplars/fgsea-prerank/PACK.md` P-1；两模块 E:ranking_metric；DESeq2 `results.Rd`、limma `eBayes.Rd` |
| ORA 与 compare 的背景、本体和列表定义 | BP 预设一致；背景定义统一为该选择规则下有资格入选的全集，区别于显著基因列表。不同数据检测空间的多列表不能偷换成共享并集背景。统一保存原始 ID、映射规则、有效背景和注释版本；原始 P、BH adjusted P、q-value 分列。 | 两模块 P-1/P-2/P-3；`acceptance/exemplars/clusterprofiler-ora/L1_bioc3.23/clusterProfiler/Rd/enrichGO.Rd` Arguments；`.../enricher.Rd`；compare `compareCluster.Rd` |
| GSEA 全表与默认 cutoff | 计算/保存与显著性标记分开：建议 `pvalueCutoff=1` 保存全部可检验项，再按 BH 0.05 标记。ORA/compare 若要求全表，也必须明确同时处理 `qvalueCutoff`（建议计算阶段 1）及 API 对 NA 的处理；保存的是实际可检验结果，不能谎称含无重叠/无有效映射的未测试项。 | CP-GSEA P-3；ORA `enrichGO.Rd` 的三重报告过滤；`acceptance/exemplars/clusterprofiler-ora/L1_cran2026-09-15/enrichit/NEWS.txt` 0.2.0 零重叠排除、0.2.1 NA 修复 |
| `voomLmFit` 指南优先级与工程计划旧调用集合 | 方法方向遵循锁定指南；补齐新入口 Rd/formals 后，才建议下一阶段同步更新调用登记、输出契约和相应锚点，保留旧入口复现选项。本次不改工程计划。不得一半迁移拟合、一半让 camera/GSVA 假定仍接旧对象。 | limma-voom P-1；`docs/handoff/ENGINEERING_PLAN.md` §1.2 A、§3.3；`acceptance/exemplars/limma-voom/L1_bioc3.23/limma/vignettes/usersguide.rendered.txt` §15.7 |
| array、dupcor 和 GSVA scores 统一调用 limma 的含义不同 | array 与 dupcor 的同平台趋势设置同步；GSVA 是连续 scores，不套计数 voom、不做芯片探针背景过滤，不盲目继承芯片 `trend=TRUE`。GSVA 指南的 set-size trend 是 `trend=sqrt(gssizes)`；需要单独声明。block 表示相关单位，避免细胞/重复测量被当独立生物学重复。 | array P-1/P-2、dupcor P-2/P-3、GSVA P-3；相应 `eBayes.Rd`、`duplicateCorrelation.Rd`；GSVA.Rmd “Differential expression” |
| sva 校正显示、DESeq2 QA 与下游 scores 推断 | 校正前后图可并列；已知 batch/SV 进入推断模型。`blind=TRUE` 的 QA 与 `blind=FALSE` 的模型后展示分开说明。批次校正 scores 的展示许可不自动扩展为允许对其进行未建模校正不确定性的组间检验。 | sva P-1/P-2、QC P-1/P-3、GSVA P-3；`docs/handoff/ENGINEERING_PLAN.md` §1.2 A；sva `removeBatchEffect.Rd` Note |
| CP-GSEA 10–500、fgsea 15–500、GSVA 5–500 | 常规预设可按各自方法/指南保留差异，但 Methods 必报；同一研究做 CP-GSEA 与 fgsea 方法敏感性比较时，预先统一基因宇宙、排名、集合、交集后尺寸、权重指数及 cutoff。即使统一，也不能保证算法数值相同。 | CP-GSEA `GSEA.Rd`、enrichit NEWS 0.2.1；fgsea `fgseaMultilevel.Rd`；GSVA `gsvaParam.Rd` 与各指南实例 |
| PACK 的 GSEA 容差锚点与工程计划逐字节基线冲突 | 同镜像、平台、RNG、输入与参数先执行 §3.5 的逐字节主表检查。签名不同只 SKIP 对应基线检查。若实验证明固定环境仍有随机/并行差异，提交一次有重复运行结果支持的容差变更建议；不能预先将 `eps` 当容差或只凭 `log2err` 声称 padj 保证落某区间。 | `docs/handoff/ENGINEERING_PLAN.md` §3.4–3.5；CP-GSEA、fgsea PACK C；fgsea `fgseaMultilevel.Rd` 对 `log2err`、NES 的定义；enrichit `gsea.Rd` 的 `eps` |

所有“保留函数默认”的 A/B 决定也须显式写进最终调用登记。本表没有假装完成整个 `calls_registry`：例如 `eBayes(legacy=NULL)`、GSVA `sparse/checkNA/use/filterRows`、富集的种子和并行后端仍须按锁定 Rd 完整登记；本任务覆盖的是全部待裁决项，而不是替代 S2 的逐参数实现核查。依据：`docs/handoff/ENGINEERING_PLAN.md` §3.3；各模块 `L1_bioc3.23/*/Rd/` Usage。

## 基础设施待裁决（5 项）

这些是构建/取证问题，没有可对应的函数默认和论文多数。表中保留两列并标为不适用，避免把构建策略伪装成包默认。包未安装等描述指仓库记录与构建清单的状态，本次没有进入远程容器确认运行状态。

| 编号 | 问题 | 函数默认 | 官方推荐 | 范本多数 (n/N) | 建议 | 理由 | 依据 | 类别 |
|---|---|---|---|---|---|---|---|---|
| M1-2 | 六个锚点包及开发/容器数据版本 | 不适用 | 各 L1 指南指定数据例子，但不决定镜像分层；工程计划 §3.1/§3.5 规定锁定环境及基线 | 不适用，未采集构建策略 | 后续增加专用验收数据层或只读且散列锁定的数据挂载，包含 `airway,pasilla,fission,bladderbatch,zebrafishRNASeq,GSVAdata`；记录容器实际版本、来源及输入对象散列，再在容器生成基线。建议默认专用验收层 | B 的取舍是镜像大小/重建成本与离线可复验性；源码清单确未列这些包，开发层版本不能代替容器数据版本。pasilla 数据来源变化也要重建基线 | `SUITE.md` M1-S0 待裁决第 2 项；`acceptance/data/ANCHOR_REGISTRY.md` §4；`env/layers/*.txt`；`env/conda/setup_dev.sh` 第 3 步；`env/omicstat-env.json`；`docs/handoff/ENGINEERING_PLAN.md` §3.1、§3.5 | B |
| M1-3 | 注释入容器、celldex 后端、msigdbr 缓存及 KEGG 排除 | 不适用；registry 的 `redistributable=null` 表示未验证 | 无所存 L1 指南能直接裁定这些数据的再分发。项目 registry 要求来源、版本、散列、许可和离线使用 | 不适用 | GO/org.* 包从锁定 Bioc 构建并记录数据版本；celldex 后续优先沿已取证的 gypsum 指定资源/版本和树散列，不能一边填 ExperimentHub 一边实际读 gypsum。msigdbr 只预置经许可确认且剔除 KEGG 的产物并给新散列；不要将含 KEGG 的原压缩包烘焙后只在查询时过滤 | C：缺容器条目实际版本/散列、celldex 数据许可证据、MSigDB/BioCarta 具体可分发边界和过滤后资产。取得提供者条款与构建产物，填齐 registry，再用空用户缓存离线回放验证。`redistributable=null` 不能据包代码许可证自动改 TRUE | `SUITE.md` M1-S0 第 3 项；`env/refdata_registry.json` note、`go_annotation`、`msigdb_collections`、`dev_msigdbr_data`、`celldex_*`/`dev_*`；`env/container/Dockerfile` 的 reference-data 占位；`env/conda/README.md` 第 5–6 步说明 | C |
| M1-4 | WGCNA 示例未取得 sha256 | 不适用 | 当前仓库只有教程地址/失败记录，没有可验证的源文件字节 | 不适用 | 保持“未就绪”，不编造散列、不以未核对镜像文件生成权威锚点 | C：缺原文件、sha256 和许可说明。后续从 TLS 验证正常的官方/可验证来源取文件，检查数据对象、记录地址/日期/sha256，再登记；本次不重试网络，不能将历史 TLS 错误说成当前现场诊断 | `SUITE.md` M1-S0 第 4 项；`acceptance/data/ANCHOR_REGISTRY.md` 第 31 行、§3 unresolved 下载记录、§4 | C |
| M2-2 | enrichit 是否进入 pkg_lock，金标准来源 | 不适用 | DOSE 锁定 DESCRIPTION Imports 含 enrichit；L1_cran 记录快照 0.2.1；`write_pkg_lock.R` 记录所有已安装包，但不证明某次构建已安装 | 不适用；旧论文不检验当前镜像依赖 | 后续将 `enrichit==0.2.1` 作为容器构建验收断言，并查 `/opt/omicstat/pkg_lock.csv`、实际 `packageVersion`、依赖来源和最小 ORA/GSEA 调用；金标准只在该签名容器产生。建议显式加入层清单提高可见性，传递安装亦须验收 | C：本仓库未提供构建生成的 pkg_lock，不能确认已进入镜像；层清单没直列不等于传递依赖没装。补证是导出容器 lock 和实际加载/调用结果，不需要再找论文 | `SUITE.md` M2-S0 第 2 项；`env/layers/L2_enrichment.txt`、`env/r/write_pkg_lock.R`、`env/container/Dockerfile`；`acceptance/exemplars/clusterprofiler-gsea/L1_bioc3.23/DOSE/DESCRIPTION`；该模块 `L1_cran2026-09-15/README.md` | C |
| M2-3 | 缺 GSVAdata 时用 scRNA-seq 或缓存锚点 | 不适用 | GSVA “Quantification of pathway activity in bulk microarray and RNA-seq data” 用 GSVAdata；“Quick start” 可用模拟矩阵。GSVA_scRNAseq 为另一种输入路径 | 不适用 | 优先按 M1-2 补 bulk GSVAdata 锚点；在此之前可用固定种子模拟数据做独立计算烟测，pbmc4k 作单细胞补充，缓存 scores 仅验证读取/报告，不算表达矩阵→scores 的计算验收 | B 的取舍是立即获得部分回放覆盖与等待匹配 bulk 用途的端到端锚点。不能把缓存结果复制成功说成算法已经复算；也不能从单细胞稀疏分支通过推断 bulk kernel 已通过 | `SUITE.md` M2-S0 第 3 项；`acceptance/data/ANCHOR_REGISTRY.md` 第 13 行、§4；`acceptance/exemplars/gsva-score/L1_bioc3.23/GSVA/vignettes/GSVA.Rmd` “Quick start”及 bulk 节；`GSVA_scRNAseq.Rmd` | B |

## PACK 草案中与证据不符或需要限定之处

这里区分事实错误、计数口径差异和本次提出的方案修正；没有修改任何 PACK。

1. **QC 样本离群摘录存在已核查的不适用值。** `deseq2-qc/literature/verification.json` 指出 PMC7673985 的 400,000 counts 是前段测序深度纳入标准，不是 VST/PCA 离群规则。原摘录仍是 17/20 未报告；按核查修正后应为 18/20 未报告，剩下保留全部和 WGCNA 规则各 1/20。不能拿该数值支持草案的 PCA warning。
2. **QC 批次展示不止一个可见实例。** PACK P-3 仅列一个使用明确 `removeBatchEffect` 的实例；`deseq2-qc/literature/l3_notes.md` 的 PMC12893922 和 PMC7688323 都描述 VST 的批次校正展示，后者没有指明相同函数。故“校正展示至少 2/20”与“明确函数 1/20”须分开，不能当成结构化字段的完整普查。
3. **sva-batch 的检验用途为 11/17，不是 10/17。** 下方列出 11 篇的记录键；7 篇 DESeq2/limma 与 PACK 一致，其余是其他检验/差异调用，包含 PMC12667713 的 benchmark。若要排除基准比较，应显式重新定义类别；它当前 `_applies=yes`。来源：`sva-batch/literature/extraction.jsonl`，`corrected_used_for`；PACK V/P-1。
4. **ORA 的 GO 不能一律简写为 BP；compare 还有明确 CC。** ORA 有 PMC8617197 同时 BP/CC/MF；compare 有 PMC8111910 的 CC、PMC10578035/PMC8454054/PMC9531456 的三本体/ALL。BP 是预设建议，非全部文献一致。compare 的 enrichGO 总出现为 9/9 报告者，8/9 是仅数单方法行。来源：两模块 E:gene_set_db、compare E:fun。
5. **“多数”必须注明分母。** CP-GSEA 的 FC 7/15 和 camera 14/29 未过半；fgsea Hallmark 11/30 也未过半。GSVA 的“gsva 20/30”含仅写包名而未明确算法的行，不能当作已证实 20 次 `gsvaParam`。来源：各 PACK V/末节；对应 E:ranking_metric、test、gene_set_db、method 及其 note。
6. **CP-GSEA 的 adjusted 0.05 支持需要保守计数。** E:enrich_cutoff 的 PMC13535199 只写 “P cutoff”，保留为含混；明确 adjusted/q 为 6，明确函数参数名为 3。PACK 的 10/14 将该含混项推成 adjusted。且 `qvalueCutoff`、nominal P、BH adjusted P 不得等价替换。来源：该模块 extraction 与 verification.json、`GSEA.Rd`。
7. **fgsea 的集合未知数少记了两篇。** PMC11866441 的 GO 属于另一 GSEA 运行，PMC13589494 的 Hallmark/Reactome 属于另一 proteomics ORA；这两篇对 fgsea 集合是未知，所以本口径 7/30 未知，而非 PACK 的 5/30。PMC10688992 的第二次 fgsea 有明确 Hallmark，仍只计该论文一次。来源：fgsea E:gene_set_db 及 verification.json。
8. **指南示例不能提升为全局规定。** fgsea 的 Reactome 调用只设 maxSize，反驳 P-3 的 throughout/every；GSVA 有 5–300 的新示例，不能只说 vignette 一律 5–500；limma quick start 称 trend/robust often helpful，不能推导所有芯片必须 TRUE/TRUE。来源：fgsea-tutorial.Rmd “Using Reactome pathways”；GSVA.Rmd “Running GSVA”；limma usersguide §3.2。
9. **voom 草案的优先级需调整，但新入口证据尚不完整。** 当前指南 §15.7 明确推荐 `voomLmFit`，历史文献的 voom 家族出现不能推翻该推荐；本地缺它的完整 Rd/formals。S2 不得照草案继续默认旧入口而不说明取舍，也不得自行猜新 API。来源：limma-voom P-1 表中路径及 ENGINEERING_PLAN §1.2/§3.3。
10. **批次输出“只警告”不足以贯彻模块契约。** sva P-1 一面规定不进 DE，一面只写 warns；建议标准路径对已标记来源明确拒绝。dupcor P-2 的技术批次绝对禁用语气则过强，应以相关单位和可估性作验证；本套件默认走 fixed batch 是策略。来源：ENGINEERING_PLAN §1.2 A、limma `removeBatchEffect.Rd` Note、`duplicateCorrelation.Rd` Details。
11. **GSEA 锚点误差描述有统计错误和契约冲突。** 两 PACK C 的“stochastic within eps”错误：`eps` 是计算下限；fgsea `log2err` 是 log p 误差量，不能直接成为 padj 的保证区间。NES 使用随机样本的平均 ES 标准化，不能跨 seed/引擎无条件承诺精确一致。工程计划 §3.5 又将富集主表设为逐字节档，PACK 不应无依据改容差。来源：enrichit `gsea.Rd`；fgsea `fgseaMultilevel.Rd` Value；两 PACK C；ENGINEERING_PLAN §3.5。
12. **roast 的 p 下限需要区分检验类型。** 草案的 `1/(nrot+1)` 仅适用普通双侧/mixed 原始 P；单侧是 `1/(2*nrot+1)`，`mroast(midp=TRUE)` 的 FDR 还另用 mid-p。9999 也不仅是一个示例，Rd 明确建议发表用至少该数。来源：limma-camera `roast.Rd` Details、`mroast.Rd`。
13. **在线书推荐与容器“已锁定”表述超出本地证据。** clusterProfiler 三个包的本地 Vignette 只有外链，L2 只有 manifest，不能声称已从正文重导官方推荐；fgsea P-2 所说 registry pinned release 目前只对开发层有具体记录，容器 `msigdb_collections` 仍待填。来源：三模块 L2/README.md、L2/manifest.tsv；`env/refdata_registry.json`。
14. **锁定文档也有旧段落，需显式报告冲突。** GSVA bulk 旧段仍称 Gaussian 默认，Rd/NEWS 已是 auto；fgsea 教程 eps 1e-10 与锁定 Rd 1e-50 不同；camera Rd Details 一段仍说默认估计相关，与 Usage、后文默认 0.01 不同；edgeR `glmQLFit.Rd` 的 `top.proportion` 参数说明写 legacy TRUE，而 Details 写新法 dispersion NULL 时估计。不能用这些旧段覆盖 Usage/NEWS，也不能假装没有冲突；最后一个涉及动态取值时须在锁定容器用 formals/最小调用核查。来源：对应模块 L1 Rd/NEWS/vignette，具体参数名如上。
15. **旧版本并非充分的参数证据。** edgeR 4.0 引入新法、4.2 才默认新法；GSVA 旧 `gsva(expr,gset,method=...)` 与当前参数对象不能照抄；fgsea 老文章的 nperm 也不能直接决定当前 multilevel 参数。来源：edgeR NEWS 4.0.0/4.2.0；GSVA NEWS 1.50/1.52/2.2；fgsea NEWS 1.13.2/1.19.2。相反，limma 锁定 Rd **确实有** `treat(fc=1.2)`，这条草案不是参数错误。

上述简称路径均相对于 `acceptance/exemplars/`；详细映射按开头的证据索引。这里列出的差异是建议稿的审查发现，不宣称相应实现存在同样错误。

## 复算索引：原始取值与记录定位

以下附录由本仓库 JSONL 只读复算后写入本文件，逐值列出原始 `value` 的出现数及 PMCID。仅严格等于 `not reported` 的值归入“原值未报告”；带分析范围说明的 mixed 值原样列出，因此正文的语义归并（例如 fgsea 集合未知 7 篇）可能与该原值计数不同。所有 n/N 均以当前适用论文为分母；下列逐值计数没有将相近英文写法自动合并。正文的合并类别可据 PMCID 回查 `snippet`、`section_path` 和 `note`。


### 复算 deseq2-wald

来源：`acceptance/exemplars/deseq2-wald/literature/corpus.jsonl` 与 `acceptance/exemplars/deseq2-wald/literature/extraction.jsonl`。当前语料 30 篇，适用 N=29；摘录中不在当前语料的旧论文 0 篇已排除；适用记录键无重复。


- **`shrinkage`**：覆盖 29/29；原值未报告 26/29。

  - `ashr`：2/29；PMC12755864, PMC12893922。
  - `apeglm`：1/29；PMC10719396。


- **`lfc_filter`**：覆盖 29/29；原值未报告 19/29。

  - `fold change greater than 2`：1/29；PMC7917550。
  - `absolute log2-fold-change > 0`：1/29；PMC11687419。
  - `|log2(fold change)| > 1`：1/29；PMC10760521。
  - `absolute fold change > 1.5`：1/29；PMC8805715。
  - `|log2FC| > 2`：1/29；PMC13534237。
  - `|log2FC| > 0.15 (~10% change)`：1/29；PMC11802321。
  - `fold change > 1.5`：1/29；PMC8656144。
  - `fold-change >= 2`：1/29；PMC10711438。
  - `fold change > 2`：1/29；PMC9703767。
  - `|log2FC| > 1`：1/29；PMC11730331。


- **`lfc_threshold_test`**：覆盖 29/29；原值未报告 27/29。

  - `log2(1.5)`：1/29；PMC11687419。
  - `fold-change threshold of 1.5`：1/29；PMC12893922。


- **`prefilter`**：覆盖 29/29；原值未报告 23/29。

  - `5 reads in at least 3 samples`：1/29；PMC12755864。
  - `gene counts greater than 10 in half of the samples`：1/29；PMC11687419。
  - `cpm > 2 in at least 2 of 6 samples`：1/29；PMC13534236。
  - `average count > 10 across all samples`：1/29；PMC11802321。
  - `fewer than 250 total reads across the entire cohort excluded`：1/29；PMC7821903。
  - `minimum read count of 1 in at least one control sample of two biological replicates`：1/29；PMC9703767。


- **`padj_cutoff`**：覆盖 29/29；原值未报告 9/29。

  - `0.05`：14/29；PMC13577902, PMC10760521, PMC8805715, PMC7849389, PMC13534236, PMC13534237, PMC11802321, PMC10719396, PMC13534238, PMC12893922, PMC7821903, PMC10711438, PMC9703767, PMC11730331。
  - `0.1`：4/29；PMC7917550, PMC12890503, PMC8656144, PMC10711424。
  - `0.01`：2/29；PMC11687419, PMC9829537。


### 复算 deseq2-qc

来源：`acceptance/exemplars/deseq2-qc/literature/corpus.jsonl` 与 `acceptance/exemplars/deseq2-qc/literature/extraction.jsonl`。当前语料 30 篇，适用 N=20；摘录中不在当前语料的旧论文 0 篇已排除；适用记录键无重复。


- **`blind`**：覆盖 20/20；原值未报告 19/20。

  - `TRUE`：1/20；PMC10711438。


- **`outlier_rule`**：覆盖 20/20；原值未报告 17/20。

  - `All samples were retained for analysis after QC review`：1/20；PMC13485302。
  - `Samples with WGCNA network connectivity scores of less than -3 were removed as outliers, resulting in a total of 2,115 samples`：1/20；PMC10703692。
  - `Samples retained in the dataset had at least 400,000 estimated counts associated with transcripts of protein-coding genes`：1/20；PMC7673985。


### 复算 deseq2-lrt

来源：`acceptance/exemplars/deseq2-lrt/literature/corpus.jsonl` 与 `acceptance/exemplars/deseq2-lrt/literature/extraction.jsonl`。当前语料 30 篇，适用 N=26；摘录中不在当前语料的旧论文 23 篇已排除；适用记录键无重复。


- **`reduced_model`**：覆盖 26/26；原值未报告 16/26。

  - `reduced model containing only an intercept term for each gene`：1/26；PMC8783694。
  - `~ cell_line`：1/26；PMC9678885。
  - `condition parameter removed from the full model`：1/26；PMC13450217。
  - `reduced null models`：1/26；PMC10663454。
  - `~Replicate`：1/26；PMC10629825。
  - `treatment and time point (no interaction)`：1/26；PMC13462894。
  - `~ 1`：1/26；PMC7428014。
  - `stress + drug`：1/26；PMC12572406。
  - `genotype and time (no interaction)`：1/26；PMC12391433。
  - `no time term (intercept only)`：1/26；PMC10356864。


- **`pattern_clustering`**：覆盖 26/26；原值未报告 18/26。

  - `average-linkage agglomerative hierarchical clustering with Pearson correlation distance`：1/26；PMC8783694。
  - `fuzzy c-means clustering (mfuzz package)`：1/26；PMC13450217。
  - `DEGreport`：1/26；PMC10663454。
  - `GPClust (Gaussian process clustering)`：1/26；PMC7580003。
  - `K-means`：2/26；PMC13582980, PMC13174499。
  - `hierarchical clustering (pheatmap, Ward's D-distance)`：1/26；PMC9663569。
  - `DPGP`：1/26；PMC12391433。


- **`lfc_filter`**：覆盖 26/26；原值未报告 22/26。

  - `0.5`：1/26；PMC13450217。
  - `lfc > 0 (over-expressed) or < 0 (under-expressed)`：1/26；PMC10663454。
  - `absolute log2 FC > 0.5`：1/26；PMC9622893。
  - `absolute fold change ≥ 2`：1/26；PMC10560206。


### 复算 edger-qlf

来源：`acceptance/exemplars/edger-qlf/literature/corpus.jsonl` 与 `acceptance/exemplars/edger-qlf/literature/extraction.jsonl`。当前语料 30 篇，适用 N=23；摘录中不在当前语料的旧论文 0 篇已排除；适用记录键无重复。


- **`edger_version`**：覆盖 23/23；原值未报告 10/23。

  - `3.28`：1/23；PMC13569496。
  - `3.28.1`：3/23；PMC12726832, PMC8709578, PMC7642293。
  - `4.0.16`：1/23；PMC13577898。
  - `3.24.0`：2/23；PMC9710884, PMC7665889。
  - `3.38.4`：1/23；PMC12644894。
  - `3.24.3`：1/23；PMC9681209。
  - `3.20.9`：1/23；PMC8536759。
  - `3.16.5`：1/23；PMC10619980。
  - `3.26.5`：1/23；PMC8532352。
  - `3.40.2`：1/23；PMC13440409。


- **`robust`**：覆盖 23/23；原值未报告 22/23。

  - `TRUE`：1/23；PMC8532352。


- **`treat`**：覆盖 23/23；原值未报告 21/23。

  - `at least 20% fold change (lfc = log2(1.2))`：1/23；PMC13577898。
  - `lfc=log2(1.5) (mutation type vs WT per timepoint); lfc=log2(1.2) (H116 vs H115)`：1/23；PMC11608373。


- **`lfc_filter`**：覆盖 23/23；原值未报告 14/23。

  - `absolute log2FC > 1`：1/23；PMC8604959。
  - `log2(2)`：1/23；PMC11608373。
  - `2`：1/23；PMC9681209。
  - `FC >= 2`：1/23；PMC12828906。
  - `>1`：1/23；PMC7665889。
  - `≥1.5`：1/23；PMC8536759。
  - `>2-fold`：1/23；PMC7642293。
  - `>1.5 (logfc > 0.58)`：1/23；PMC10619980。
  - `logFC > 5 (default logFC > 2, overridden to 5 for all analyses)`：1/23；PMC8532352。


### 复算 limma-voom

来源：`acceptance/exemplars/limma-voom/literature/corpus.jsonl` 与 `acceptance/exemplars/limma-voom/literature/extraction.jsonl`。当前语料 30 篇，适用 N=24；摘录中不在当前语料的旧论文 0 篇已排除；适用记录键无重复。


- **`voom_variant`**：覆盖 24/24；原值未报告 0/24。

  - `voom`：21/24；PMC11790030, PMC8783691, PMC7755902, PMC10721151, PMC9724437, PMC13544910, PMC12685072, PMC9800282, PMC12779551, PMC8664842, PMC13450212, PMC11551748, PMC9683707, PMC13455466, PMC10667096, PMC12643502, PMC10635649, PMC7673985, PMC11514464, PMC9684074, PMC7706724。
  - `voom (via edgeR voomLmFit function)`：1/24；PMC13506345。
  - `voom (via limmaVoom package)`：1/24；PMC13558064。
  - `voom (precision weights)`：1/24；PMC13489952。


- **`ebayes`**：覆盖 24/24；原值未报告 17/24。

  - `empirical Bayes (eBayes)`：1/24；PMC8783691。
  - `empirical Bayes moderation of standard errors towards a common value`：1/24；PMC7755902。
  - `treat function (1.2-fold change threshold) for DE testing; eBayes function (no fold-change threshold) for the iCLIP comparison`：1/24；PMC13506345。
  - `eBayes`：1/24；PMC13450212。
  - `empirical Bayes (via lmFit)`：1/24；PMC11551748。
  - `eBayes (default parameters)`：1/24；PMC12643502。
  - `eBayes (written as 'eBayer' in the text)`：1/24；PMC10635649。


- **`lfc_filter`**：覆盖 24/24；原值未报告 19/24。

  - `>0.2`：1/24；PMC7755902。
  - `≥0.4 (also tested at ≥0.6)`：1/24；PMC9724437。
  - `≥1 (absolute FC)`：1/24；PMC10667096。
  - `>1.5`：1/24；PMC11514464。
  - `>1`：1/24；PMC9684074。


### 复算 limma-array

来源：`acceptance/exemplars/limma-array/literature/corpus.jsonl` 与 `acceptance/exemplars/limma-array/literature/extraction.jsonl`。当前语料 30 篇，适用 N=13；摘录中不在当前语料的旧论文 0 篇已排除；适用记录键无重复。


- **`ebayes`**：覆盖 13/13；原值未报告 13/13。



- **`probe_filter`**：覆盖 13/13；原值未报告 6/13。

  - `low expression probes filtered (genefilter package)`：1/13；PMC7775110。
  - `restricted to protein-coding genes (biomaRt)`：1/13；PMC7736781。
  - `control probes, probes without gene symbols, and low-background genes excluded; duplicate probe IDs averaged`：1/13；PMC13488902。
  - `median intensity threshold of 1.5 to remove lowly expressed genes`：1/13；PMC13558077。
  - `restricted to probe sets with a homologous mouse/human gene; highest-t-score probe set kept per gene`：1/13；PMC11506124。
  - `probe with largest coefficient of variation selected per gene; low-CV genes filtered out`：1/13；PMC7748411。
  - `duplicated probes combined (Agilent); probes annotated Bad/No match removed (Illumina)`：1/13；PMC8582123。


### 复算 limma-dupcor

来源：`acceptance/exemplars/limma-dupcor/literature/corpus.jsonl` 与 `acceptance/exemplars/limma-dupcor/literature/extraction.jsonl`。当前语料 30 篇，适用 N=30；摘录中不在当前语料的旧论文 0 篇已排除；适用记录键无重复。


- **`block`**：覆盖 30/30；原值未报告 0/30。

  - `participant (same participant across time points)`：1/30；PMC13589506。
  - `subject (same subject across multiple brain regions)`：1/30；PMC9668748。
  - `individual subject/mouse (same mouse, multiple brain regions/hemispheres)`：1/30；PMC8448451。
  - `intersubject (same participant, baseline/HIIT groups)`：1/30；PMC10686561。
  - `individual (donor, repeated technical replicates)`：1/30；PMC9630117。
  - `experimental repeats (biological replicates across time points/genotypes)`：1/30；PMC8442926。
  - `individual (fly) ID`：1/30；PMC12802594。
  - `replicate population (random factor)`：1/30；PMC10637773。
  - `clone (non-independent experimental replicates per clone)`：1/30；PMC9237031。
  - `clone donor`：1/30；PMC7695459。
  - `patient (repeated measures from the same patient)`：1/30；PMC13292934。
  - `donor (random effect across donors)`：1/30；PMC12479364。
  - `sequencing lane (batch)`：1/30；PMC11514464。
  - `mouse ID (random effect)`：1/30；PMC10457316。
  - `donor (repeated measure)`：1/30；PMC9151768。
  - `animal ID (same individual across timepoints)`：1/30；PMC12259264。
  - `individual (repeated measures, or related individuals e.g. twins)`：1/30；PMC11378482。
  - `animal (replicated measures on the same animal)`：1/30；PMC10357615。
  - `participant identity`：1/30；PMC8971130。
  - `mouse donor`：1/30；PMC7936006。
  - `individual (same individual, both hemispheres)`：1/30；PMC7063821。
  - `subject (subject pairing across timepoints)`：1/30；PMC12239959。
  - `family ID`：1/30；PMC10349101。
  - `patient (repeated measures/same patient)`：1/30；PMC13293969。
  - `species`：1/30；PMC11293591。
  - `donor (technical replicates)`：1/30；PMC11208617。
  - `bird ID + brain region (or bird ID + hemisphere)`：1/30；PMC10259477。
  - `patient (duplicate cores per patient)`：1/30；PMC6985126。
  - `patient ID`：1/30；PMC13313537。
  - `patient identifier`：1/30；PMC11914184。


- **`consensus_correlation`**：覆盖 30/30；原值未报告 29/30。

  - `0.83`：1/30；PMC9237031。


- **`two_rounds`**：覆盖 30/30；原值未报告 29/30。

  - `yes (voomWithQualityWeights run twice, following the limma-voom guide)`：1/30；PMC8971130。


### 复算 sva-batch

来源：`acceptance/exemplars/sva-batch/literature/corpus.jsonl` 与 `acceptance/exemplars/sva-batch/literature/extraction.jsonl`。当前语料 30 篇，适用 N=21；摘录中不在当前语料的旧论文 0 篇已排除；适用记录键无重复。


- **`corrected_used_for`**：覆盖 21/21；原值未报告 4/21。

  - `input to differential expression testing (DESeq2)`：3/21；PMC10752584, PMC9829537, PMC10699809。
  - `visualization/clustering (principal component analysis)`：1/21；PMC12892902。
  - `input to differential expression testing (limma comparisons between study groups)`：1/21；PMC7775110。
  - `visualization only (batch was included as a covariate in the DESeq2 design for the actual differential testing)`：1/21；PMC13524377。
  - `used for comparative analyses (comparative transcriptomic profiling across cohorts, incl. downstream GSVA pathway scores and immune-cell-fraction estimates)`：1/21；PMC7705019。
  - `input to Z-score-based outlier-expression testing (binomial/chi-squared tests for HPV-breakpoint-associated expression changes)`：1/21；PMC8744672。
  - `input to differential expression testing (DESeq2 model of the temperature effect)`：1/21；PMC13510735。
  - `input to differential expression calling (z-score-difference method) and to visualization (UMAP of top variable genes)`：1/21；PMC12807868。
  - `input to clustering/visualization (PCA/UMAP, consensus clustering) and to differential expression testing (DESeq2)`：1/21；PMC11559625。
  - `input to differential expression testing (DESeq2), as the first step of the analysis workflow`：1/21；PMC10711438。
  - `input to downstream signature validation/discovery analyses across cohorts (classifier training and validation)`：1/21；PMC9797950。
  - `input to eQTL/isoQTL mapping and TWAS model training, after further covariate/hidden-factor removal`：1/21；PMC10703692。
  - `SVs used as covariates in the differential expression testing (DESeq2 design)`：1/21；PMC13564084。
  - `used as a baseline batch-correction method benchmarked before differential expression testing (Wilcoxon rank-sum test or t-test) on pseudobulk replicates`：1/21；PMC12667713。
  - `input directly to the custom Z-score-based differential-effect ('HIT') calling method on the batch-corrected fluorescence intensities`：1/21；PMC8582123。


- **`mod`**：覆盖 21/21；原值未报告 15/21。

  - `sex and disease status (biological covariates preserved)`：1/21；PMC9833827。
  - `host genotype (used as the ComBat-seq batch/covariate, preserving temperature as the biological variable of interest)`：1/21；PMC13510735。
  - `study, sex, and disease state`：1/21；PMC11559625。
  - `no group condition (batch corrected without preserving a biological covariate)`：1/21；PMC10711438。
  - `none for disease samples (healthy controls co-normalized directly; estimated ComBat parameters then applied to disease samples)`：1/21；PMC9797950。
  - `study site (batch variable)`：1/21；PMC10703692。


- **`n_sv`**：覆盖 21/21；原值未报告 20/21。

  - `1 (SV1)`：1/21；PMC13564084。


### 复算 clusterprofiler-ora

来源：`acceptance/exemplars/clusterprofiler-ora/literature/corpus.jsonl` 与 `acceptance/exemplars/clusterprofiler-ora/literature/extraction.jsonl`。当前语料 30 篇，适用 N=30；摘录中不在当前语料的旧论文 0 篇已排除；适用记录键无重复。


- **`gene_set_db`**：覆盖 30/30；原值未报告 0/30。

  - `GO (biological process, BP)`：5/30；PMC13545012, PMC12751217, PMC13534236, PMC12720443, PMC7688965。
  - `GO (subtype not specified)`：13/30；PMC9753996, PMC7762773, PMC13558073, PMC11687023, PMC10734203, PMC9723654, PMC13535199, PMC7702712, PMC12690957, PMC11730331, PMC8597987, PMC10709144, PMC9825193。
  - `GO; KEGG`：3/30；PMC8783694, PMC13578734, PMC10760458。
  - `GO; KEGG; Reactome; MP Ontology; tissue-specific gene sets (GTEx-derived)`：1/30；PMC11694762。
  - `MSigDB C2; MSigDB C5; Hallmark`：1/30；PMC13534237。
  - `KEGG`：1/30；PMC9718532。
  - `GO (BP; CC; MF); MSigDB (v7.0)`：1/30；PMC8617197。
  - `custom gene sets (striatum/cortex marker lists; GO:0071542-based ventral midbrain list; VoxHunt E13 top100 pallial genes; activity-regulated genes; dopaminergic-signaling pathway list)`：1/30；PMC10703680。
  - `GO (slim GO terms from Ensembl BioMart)`：1/30；PMC9825192。
  - `GO BP; KEGG; MSigDB`：1/30；PMC7618435。
  - `GO (biological process); Reactome; KEGG; Hallmark`：1/30；PMC13450225。
  - `GO; DO (Disease Ontology, via DOSE::enrichDGN / DisGeNET)`：1/30；PMC11662933。


- **`universe`**：覆盖 30/30；原值未报告 24/30。

  - `union of genes included in the reference (scRNA-seq) datasets`：1/30；PMC10734203。
  - `all expressed/detected genes`：1/30；PMC9723654。
  - `all expressed genes`：1/30；PMC13534236。
  - `intersection of genes detectable in the long-read data and genes mappable to the selected MSigDB collections`：1/30；PMC13534237。
  - `all genes overlapping between sexes for each region`：1/30；PMC13535199。
  - `all genes in the DESeq2 object per 'Background_Condition' contrast`：1/30；PMC11662933。


- **`simplify`**：覆盖 30/30；原值未报告 27/30。

  - `simplify() function used to remove redundancy (no cutoff stated)`：1/30；PMC13545012。
  - `redundancy removed with ReViGO (external tool), not clusterProfiler's simplify()`：1/30；PMC8597987。
  - `simplify(cutoff = 0.7 or 0.8)`：1/30；PMC11662933。


### 复算 clusterprofiler-gsea

来源：`acceptance/exemplars/clusterprofiler-gsea/literature/corpus.jsonl` 与 `acceptance/exemplars/clusterprofiler-gsea/literature/extraction.jsonl`。当前语料 30 篇，适用 N=28；摘录中不在当前语料的旧论文 0 篇已排除；适用记录键无重复。


- **`ranking_metric`**：覆盖 28/28；原值未报告 13/28。

  - `LME coefficient; log2(fold change) from ROTS`：1/28；PMC12751217。
  - `log2 fold change (DESeq2)`：1/28；PMC13537272。
  - `Wald test statistic (DESeq2)`：1/28；PMC9825171。
  - `signed -log10(p) (sign(log2FC) x -log10(p), from edgeR)`：1/28；PMC13577898。
  - `test statistic (pyDESeq2)`：1/28；PMC12893922。
  - `log2(Coefficient) from the linear model, ranked high to low`：1/28；PMC10709144。
  - `nonlinear scaling degree (beta)`：1/28；PMC8617254。
  - `fold change between clusters`：1/28；PMC12700539。
  - `Spearman correlation coefficient (TTLL gene vs. all other genes, per cancer type)`：1/28；PMC9681853。
  - `partial Spearman correlation coefficient (gene expression vs Signature 17 activity, controlling for tumor purity and other signatures)`：1/28；PMC7705019。
  - `log2 fold change (DESeq2, per hypoxia time point vs 0 hr baseline)`：1/28；PMC13446901。
  - `DESeq2 Wald test statistic`：1/28；PMC9684078。
  - `log fold change (logFC)`：1/28；PMC7591261。
  - `average log2 fold change across four pairwise comparisons with embryonic lineages`：1/28；PMC11725501。
  - `fold change (log2 protein fold-change, AD vs healthy controls)`：1/28；PMC12765837。


- **`enrich_cutoff`**：覆盖 28/28；原值未报告 14/28。

  - `0.05 (qvalueCutoff)`：1/28；PMC12751217。
  - `0.05 (pvalueCutoff)`：2/28；PMC13537272, PMC13446901。
  - `0.1 (L3MBTL3 knockdown); 0.01 (L3MBTL3 rescue)`：1/28；PMC9825171。
  - `p value < 0.05 (nominal, default settings)`：1/28；PMC9705293。
  - `p value < 0.05 and FDR q-value < 0.05`：1/28；PMC8617254。
  - `0.05 (P cutoff)`：1/28；PMC13535199。
  - `FDR < 0.05`：3/28；PMC9681853, PMC9684078, PMC8663569。
  - `p < 0.05 and FDR q < 0.25`：1/28；PMC7592056。
  - `0.05 (PvalueCutoff)`：1/28；PMC11610457。
  - `adjusted P < 0.05`：1/28；PMC11725501。
  - `FDR <= 0.25`：1/28；PMC10668425。


- **`permutation`**：覆盖 28/28；原值未报告 21/28。

  - `nPerm = 10,000; eps = 1e-300`：1/28；PMC12751217。
  - `nPerm = 20,000 (via maxGSSize/nPerm settings)`：1/28；PMC9834056。
  - `not reported (seed=T used for reproducibility)`：1/28；PMC13537272。
  - `not reported (default settings)`：1/28；PMC9705293。
  - `1e5 (100,000) permutations`：1/28；PMC8617254。
  - `10,000 permutations (nPerm = 10000)`：1/28；PMC8597987。
  - `nPerm = 10,000`：1/28；PMC11610457。


### 复算 clusterprofiler-compare

来源：`acceptance/exemplars/clusterprofiler-compare/literature/corpus.jsonl` 与 `acceptance/exemplars/clusterprofiler-compare/literature/extraction.jsonl`。当前语料 30 篇，适用 N=26；摘录中不在当前语料的旧论文 0 篇已排除；适用记录键无重复。


- **`fun`**：覆盖 26/26；原值未报告 17/26。

  - `enrichGO`：8/26；PMC10484682, PMC10544225, PMC13307697, PMC8111910, PMC8454054, PMC8586142, PMC8602344, PMC9531456。
  - `enrichKegg; enrichPathway; enrichGO`：1/26；PMC13545235。


- **`gene_set_db`**：覆盖 26/26；原值未报告 1/26。

  - `GO`：7/26；PMC10484682, PMC10544225, PMC10803260, PMC11186787, PMC12690957, PMC8602344, PMC9635831。
  - `GO BP; GO CC; GO MF; KEGG`：1/26；PMC10578035。
  - `MSigDB Hallmark Gene Sets`：1/26；PMC10673928。
  - `KEGG; Reactome`：1/26；PMC11122669。
  - `MSigDB C5 (GO biological process terms)`：1/26；PMC11649919。
  - `Gene Ontology (GO)`：1/26；PMC12559710。
  - `GO (biological process)`：1/26；PMC12652333。
  - `GO BP`：1/26；PMC13307697。
  - `KEGG; Reactome; GO Biological Process`：1/26；PMC13545235。
  - `GO; KEGG`：1/26；PMC7284308。
  - `GO biological process`：2/26；PMC7730477, PMC8586142。
  - `GO CC (cellular component)`：1/26；PMC8111910。
  - `GO; KEGG; DGN (Disease-Gene Network)`：1/26；PMC8248987。
  - `GO (ont=ALL: BP, CC, MF)`：1/26；PMC8454054。
  - `GO Biological Process`：1/26；PMC8885825。
  - `GO; KOG; KEGG; KO`：1/26；PMC9151784。
  - `GO (all ontology categories)`：1/26；PMC9531456。
  - `GO (BP)`：1/26；PMC9771819。


- **`clusters`**：覆盖 26/26；原值未报告 4/26。

  - `proteins significantly different in pairwise comparisons`：1/26；PMC10484682。
  - `top 100 positive, Padj (< 0.05) genes per Seurat cluster (and separately, top 100 positive/negative genes by plaque location)`：1/26；PMC10544225。
  - `top 20 vs top 50 rank-invariant gene lists`：1/26；PMC10578035。
  - `marker proteins per cluster (Benjamini-Hochberg FDR at 1% threshold defines cluster markers)`：1/26；PMC10673928。
  - `MOFA2 latent factors; separately, top-25 marker genes per single-cell cluster`：1/26；PMC10803260。
  - `significant proteins per trajectory group (TG), defined by a paired t test and BH correction`：1/26；PMC11122669。
  - `top 100 hdWGCNA module-associated genes, per module`：1/26；PMC11186787。
  - `enriched functional profiles (from gseGO/fgsea outputs); specific gene lists not named`：1/26；PMC11540020。
  - `protein-coding genes with ChIP-seq peaks, per genotype (N2 vs mig-32(n4275)) and per peak-type combination (H2AK119ub only, H3K27me3 only, both)`：1/26；PMC12652333。
  - `up-regulated vs down-regulated gene lists (Srr2del/del vs WT)`：1/26；PMC13307697。
  - `union of genes associated with peptides per (Sen High / Sen Low) group`：1/26；PMC13545235。
  - `8 consensus clusters of DEGs (CancerSubtypes consensus clustering, K=2–10)`：1/26；PMC7284308。
  - `single-cell clusters (T, macrophage, DC populations)`：1/26；PMC7730477。
  - `integrated cluster IDs, compared across replicates`：1/26；PMC8111910。
  - `environments (treatment conditions) within each cell type`：1/26；PMC8248987。
  - `annotated genes of ChIP-seq peaks across three tissues (tissue-specific vs constitutive peak sets)`：1/26；PMC8454054。
  - `single-cell clusters (2D/3D hPSC-derived cholangiocyte clusters), upregulated genes per cluster`：1/26；PMC8586142。
  - `sets of cells (Monocle3 differential-expression cell groupings)`：1/26；PMC8602344。
  - `K-means clusters of GO Biological Process network communities (edge-betweenness community detection on GSEA-derived GO terms)`：1/26；PMC8885825。
  - `orthogroup-inherited functional terms across myriapod lineages/taxa`：1/26；PMC9151784。
  - `k-means clusters of differentially expressed genes (row Z-scores, elbow-selected k)`：1/26；PMC9635831。
  - `per-cluster DEGs, from mouse and monkey`：1/26；PMC9771819。


### 复算 fgsea-prerank

来源：`acceptance/exemplars/fgsea-prerank/literature/corpus.jsonl` 与 `acceptance/exemplars/fgsea-prerank/literature/extraction.jsonl`。当前语料 30 篇，适用 N=30；摘录中不在当前语料的旧论文 0 篇已排除；适用记录键无重复。


- **`ranking_metric`**：覆盖 30/30；原值未报告 15/30。

  - `not reported (run 1, tumor RNA-seq); Wald statistic (run 2, longitudinal time points)`：1/30；PMC10688992。
  - `AUC rank of DEGs (obtained with and without CHIP, per cluster)`：1/30；PMC11623926。
  - `gene log-fold change (logFC)`：1/30；PMC11866441。
  - `not reported (Riboseq/cytoplasmic RNA run); test difference (proteomics run)`：1/30；PMC12807877。
  - `-log10(p-value), signed by log fold change`：1/30；PMC12878702。
  - `Wald statistic (from DESeq2)`：1/30；PMC13522794。
  - `ranked log2 fold changes`：1/30；PMC13589494。
  - `ranked risk scores (from risk-score backpropagation on the meta-learned survival model)`：1/30；PMC7733508。
  - `t-based testing statistics`：1/30；PMC7773548。
  - `-log(P_val)*sign(avg_log2FC)`：1/30；PMC8810382。
  - `compartment-specific FMRP CLIP scores`：1/30；PMC8820740。
  - `gene expression-based t score`：1/30；PMC9621134。
  - `ratio between the knockouts (average of each target gene) and their respective controls`：1/30；PMC9753996。
  - `Spearman rank correlation coefficients (between viral loads and rlog-normalized expression)`：1/30；PMC8714852。
  - `-log(p_val)*sign(avg_log2FC)`：1/30；PMC9977678。


- **`gene_set_db`**：覆盖 30/30；原值未报告 5/30。

  - `Hallmark`：1/30；PMC10645381。
  - `not reported (run 1); MSigDB Hallmark signature set; complement signature from Ricklin et al. 2010 (run 2)`：1/30；PMC10688992。
  - `custom curated gene lists (striatum/cortex signatures; GO:0071542 ventral midbrain + own markers; VoxHunt E13 top100 pallial genes; activity-regulated genes; dopaminergic signaling response genes)`：1/30；PMC10703680。
  - `marker gene lists (per cell type), not a named collection`：1/30；PMC11610197。
  - `Hallmark (MSigDB)`：3/30；PMC11623926, PMC12867153, PMC9753996。
  - `50 canonical hallmark gene sets (MSigDB v7.5.1)`：1/30；PMC11645280。
  - `not reported (for the fgsea run itself; GO Biological Process ontology is named for the separate MSigDB CLI label-permutation GSEA)`：1/30；PMC11866441。
  - `Hallmark (MSigDB, via MSigDBr)`：1/30；PMC11866449。
  - `Reactome; Hallmark (MSigDB) -- named pathways: Hallmark Myc V1/V2, several Reactome WNT and translation-initiation pathways`：1/30；PMC12807877。
  - `LIPSTIC gene signature (custom, previously published)`：1/30；PMC12878702。
  - `MSigDB (collection not further specified)`：2/30；PMC13521511, PMC13589481。
  - `Hallmark; Reactome (MSigDB, via msigdbr)`：1/30；PMC13522794。
  - `not reported (for the fgsea/RNA-seq run itself; Hallmark and Reactome are named for the separate proteomics ORA)`：1/30；PMC13589494。
  - `KEGG; Reactome; WikiPathways`：1/30；PMC7733508。
  - `custom gene sets (fragile sites; R-loop-associated loci)`：1/30；PMC7773548。
  - `KEGG canonical pathways; GO biological process; GO molecular function`：1/30；PMC8663774。
  - `ERG and FOXA1 custom gene signatures (250 downregulated genes each, from siRNA knockdown); Hallmark gene signatures (for AR and MYC)`：1/30；PMC8770127。
  - `Hallmark gene sets (Homo sapiens, MSigDB, via msigdbr)`：1/30；PMC8810382。
  - `HumanBase functional module gene lists (custom, from module detection)`：1/30；PMC8820740。
  - `custom gene sets: stem cell signature (LGR5+ intestinal crypts); DNA biosynthesis; gastric cancer signature; SPEM; regenerative Sca1+ vs homeostatic epithelium signature`：1/30；PMC9621134。
  - `Reactome pathway set; cell-subset marker set (50 defining genes/subset)`：1/30；PMC8714852。
  - `GO Biological Process (via msigdbr)`：1/30；PMC9977678。


- **`gs_size`**：覆盖 30/30；原值未报告 29/30。

  - `minimum gene set size of 10 (maxSize not reported)`：1/30；PMC11866449。


### 复算 gsva-score

来源：`acceptance/exemplars/gsva-score/literature/corpus.jsonl` 与 `acceptance/exemplars/gsva-score/literature/extraction.jsonl`。当前语料 30 篇，适用 N=30；摘录中不在当前语料的旧论文 0 篇已排除；适用记录键无重复。


- **`kcdf`**：覆盖 30/30；原值未报告 29/30。

  - `Gaussian`：1/30；PMC13549129。


- **`input`**：覆盖 30/30；原值未报告 17/30。

  - `log-transformed counts per million (CPM) expression matrix`：1/30；PMC13549129。
  - `RNA-seq TPM gene expression scores`：1/30；PMC7755902。
  - `variance-stabilizing transformation using DESeq2 followed by a log transformation`：1/30；PMC9705439。
  - `log-transformed TMM normalized TPM counts`：1/30；PMC8791834。
  - `varianceStabilizingTransformation (DESeq2)`：1/30；PMC10715489。
  - `TPM values, rank normalized per sample`：1/30；PMC9724437。
  - `pseudo-bulked snRNA-seq samples (scale not further specified)`：1/30；PMC12893110。
  - `log-CPM (TMM-normalized, edgeR)`：1/30；PMC11630822。
  - `TPM`：1/30；PMC9700682。
  - `log-transformed normalization expression matrix of tumor spots`：1/30；PMC8683021。
  - `log-transformed (METABRIC run); not stated for the scRNA-seq ssGSEA runs`：1/30；PMC13521511。
  - `not reported (bulk RNA-seq run); normalized scRNA-seq expression (single-cell run)`：1/30；PMC13590603。
  - `variance-stabilized expression values`：1/30；PMC13488922。


- **`gsva_version`**：覆盖 30/30；原值未报告 13/30。

  - `1.36.3`：1/30；PMC8694594。
  - `1.26`：1/30；PMC7755902。
  - `1.42.0`：1/30；PMC12807877。
  - `1.34.0`：3/30；PMC9705439, PMC7720616, PMC9700682。
  - `1.46.0`：1/30；PMC10689851。
  - `1.34`：1/30；PMC8791834。
  - `1.40`：1/30；PMC12764429。
  - `1.26.0`：1/30；PMC9724437。
  - `1.32.0`：1/30；PMC7746723。
  - `1.52.3`：1/30；PMC12893110。
  - `1.44.0`：1/30；PMC11630822。
  - `2.2.1`：2/30；PMC13521511, PMC13488922。
  - `1.50.0`：1/30；PMC13590603。
  - `2.2.0`：1/30；PMC13488881。


- **`gs_size`**：覆盖 30/30；原值未报告 30/30。



- **`downstream_test`**：覆盖 30/30；原值未报告 15/30。

  - `Mann-Whitney U test`：1/30；PMC13549129。
  - `limma (Benjamini-Hochberg-corrected P<=0.01); t-test (PDAC vs normal, for KEGG metabolic pathway scores)`：1/30；PMC8694594。
  - `Spearman correlation (with mutational signature weights, as part of 'immune scores')`：1/30；PMC7755902。
  - `Pearson correlation (Sox9-high signature vs TCGA-BRCA); median split into high/low activity groups for survival analysis (no test named for the split itself)`：1/30；PMC9705439。
  - `Kaplan-Meier survival comparison (median split into High/Low GSVA-score groups; survfit(), survival R package)`：1/30；PMC8683505。
  - `Mann-Whitney U-test (two-sided)`：1/30；PMC12764429。
  - `correlation analysis (scatter plots, ggpubr package)`：1/30；PMC10715489。
  - `limma (linear model + moderated t-statistic, empirical Bayes; Benjamini-Hochberg FDR)`：1/30；PMC7746723。
  - `Wilcoxon's rank-sum test (GSE56308 and GDPx2 Hallmark runs); Wilcoxon rank-sum test and 1-way ANOVA (GSE289407 Reactome run)`：1/30；PMC12893110。
  - `categorical split via maxstat (maximally selected rank statistics), then Kaplan-Meier / log-rank test for survival`：1/30；PMC11630822。
  - `hierarchical clustering (Ward's minimum variance method) on per-cluster averaged GSVA scores`：1/30；PMC8683021。
  - `Mann-Whitney U tests (responders vs nonresponders, per time point); Kaplan-Meier curves with log-rank tests (TNBC quartile survival)`：1/30；PMC13521511。
  - `limma (Benjamini-Hochberg-corrected P<0.01)`：1/30；PMC9767677。
  - `Wilcoxon rank-sum test (P<0.05)`：1/30；PMC13547331。
  - `Spearman's correlation analyses (bulk RNA-seq run); Kruskal-Wallis test then pairwise Wilcoxon rank-sum tests with Holm's correction (scRNA-seq timepoint run)`：1/30；PMC13590603。


### 复算 limma-camera

来源：`acceptance/exemplars/limma-camera/literature/corpus.jsonl` 与 `acceptance/exemplars/limma-camera/literature/extraction.jsonl`。当前语料 30 篇，适用 N=29；摘录中不在当前语料的旧论文 20 篇已排除；适用记录键无重复。


- **`test`**：覆盖 29/29；原值未报告 0/29。

  - `cameraPR`：5/29；PMC10849759, PMC12685072, PMC8643633, PMC9589007, PMC13383671。
  - `camera`：10/29；PMC11564874, PMC12764432, PMC8660905, PMC8783691, PMC9800282, PMC7511692, PMC12618235, PMC8411513, PMC11408255, PMC12286850。
  - `roast`：3/29；PMC11602548, PMC11527454, PMC13038199。
  - `roast (Mixed test, integrated protein+metabolite dataset); cameraPR (pre-ranked, on Hitman mediation results)`：1/29；PMC8630169。
  - `fry`：5/29；PMC13588164, PMC7673760, PMC12479364, PMC13388965, PMC10145939。
  - `roast; camera`：1/29；PMC13313547。
  - `fry (RNA-seq gene sets; ChIP-seq/ATAC-seq peak sets); camera (ImmuneSigDB subset of MSigDB)`：1/29；PMC9314343。
  - `camera; cameraPR`：1/29；PMC12286861。
  - `roast (RNA-seq aging signature); fry (Hi-C differentially interacting promoters)`：1/29；PMC11146594。
  - `fry (defined gene sets); camera (HALLMARK and KEGG gene sets)`：1/29；PMC11018811。


- **`inter_gene_cor`**：覆盖 29/29；原值未报告 27/29。

  - `0.01 (default)`：1/29；PMC7511692。
  - `0.01 (standard)`：1/29；PMC12618235。


### 有争议类别的明确归并

`sva-batch` 的 `corrected_used_for` 归入“明确用于检验/差异调用”的 11 篇：PMC10752584、PMC7775110、PMC9829537、PMC10699809、PMC8744672、PMC13510735、PMC12807868、PMC11559625、PMC10711438、PMC12667713、PMC8582123。其中 DESeq2/limma 子集为 PMC10752584、PMC7775110、PMC9829537、PMC10699809、PMC13510735、PMC11559625、PMC10711438（7 篇）；纯展示/SV 进设计为 PMC12892902、PMC13524377、PMC13564084（3 篇）。其余 reported 为比较/打分、分类器或 QTL/TWAS，用途不同，不合并进此类。来源：该模块 `literature/extraction.jsonl`，参数键如上。

`clusterprofiler-gsea` 的 FC 类 7 篇为 PMC12751217、PMC13537272、PMC12700539、PMC13446901、PMC7591261、PMC11725501、PMC12765837；其中 PMC12751217 同时计入模型系数类，另一模型系数为 PMC10709144。这样才能解释类别总数可大于 15，而不是把 16 次类别命中当成 16 篇。来源：该模块 `literature/extraction.jsonl`，`ranking_metric`。

`fgsea-prerank` 的 Hallmark 11 篇为 PMC10645381、PMC10688992、PMC11623926、PMC11645280、PMC11866449、PMC12807877、PMC12867153、PMC13522794、PMC8770127、PMC8810382、PMC9753996。PMC13589494 的 Hallmark 来自另一分析，排除；PMC10688992 的第二次 fgsea 明确使用，计入。来源：该模块 `literature/extraction.jsonl`，`gene_set_db`；`verification.json` 的 mixed-run 说明。

Wald 的 `lfc_threshold_test` 非未报告有 2 行，但 PMC12893922 的 snippet 明确是 `lfcShrink(type="ashr")`，且 note 说 1.5 的线性/log2 尺度不明确；只有 PMC11687419 明确说提取 `lfcThreshold=log2(1.5)` 的 test results。因此 PACK 将两者统一写成“inside the test, log2(1.5): 2”超出摘录证据。此处不把收缩阈值/S-value 自动解释为 `results()` 的 Wald 阈值检验。来源：`acceptance/exemplars/deseq2-wald/literature/extraction.jsonl`，上述两条键；该模块 `L1_bioc3.23/DESeq2/Rd/lfcShrink.Rd`。

## 本次交付的验证与限制

- 覆盖检查：逐模块对照 PACK 的 P 编号和 edgeR Note，44 个 P 项、1 个 Note 均有且仅有一条裁决；SUITE 指定的 M1-2/3/4、M2-2/3 均已覆盖。50 行均有九列及 A/B/C 分类，分类合计与开头一致。
- 复算检查：14 个当前 corpus 均为 30 篇；适用分母、旧语料排除及记录唯一性已核对，44 个相关参数字段保留了原值计数和 PMCID 定位。语义合并与核查报告修正均显式区分。未重新取得论文全文，结论限于仓库已有摘录、笔记与核查报告。
- 文档检查：所引 Rd 文件可在本次 14 模块的锁定证据中定位；中文 UTF-8、表格列数和尾随空白检查通过。`voomLmFit.Rd` 和构建产物 `pkg_lock*` 在仓库文件列表中未找到，相关事项没有伪报已验证。
- 写入边界：只有本决策表及指定工作日志为新增文件，`git diff` 未显示既有跟踪文件改动。本次未修改 PACK/源码/registry，未重新生成任何分析产物，未执行包安装或容器运行。因此本报告是 S1 决策建议的完成，不表示 S2 实现、数据许可核实或容器数值验证已完成。
