# omicstat 落地工程文档：以"R 包分析部分"为模块单元的生信标准化分析体系

> v1.3 同步说明（2026-10-04）：2026-09-29 所有者参数政策覆盖旧“多数派”措辞：
> 默认只取锁定函数默认或有出处的官方 vignette 值；科学判断显式选项，先查参考服务。
> 2026-10-01 M3/M4 slim 标准保留原生流程/对象/表、options、Methods、smoke/golden/lock。
> 协调员决定 3（所有者可逆）：单细胞逐细胞活性→AUCell，bulk/pseudobulk 样本分数→GSVA，
> 不选统一标准。决定 4（所有者可逆）：中立后端保留 front_end_ecosystem，记录
> backend_ecosystem=neutral，Python→R 用信息级 OS_ECOSYSTEM_CROSSING，前段混用仍拒绝。
> R 镜像改为 omicstat-r:2026.10.1，加入 scrapper、presto 并将预建 basilisk 环境迁至
> 非 root 可访问的 /opt/omicstat/basilisk。正文保留为历史设计，不整段重写。


> 版本 v1.2（2026-09-28：同步 SUITE「计划需要同步的地方」10 项 S1 决定与待定项；v1.1 于 2026-09-27 新增第十部分 Python 通道，仅在该部分范围内取代“不引入 Python 引擎、不加第二个容器”的旧规定）。本文件是 omicstat 的**权威落地文档**。基础设施部分沿用 `IMPLEMENTATION_SPEC.md`（v2，"整套分叉 medstat-55692f7"）；模块划分、参考文档采集、Rscript 冻结、单模块 skill 生成、路由 skill 构建，以本文件为准。
> 读者：执行各阶段工作的 agent 与主会话。执行 agent 只做实现和自测；本文件没有覆盖的取舍一律写入 worklog 的"待裁决"一节，不自行决定。
> 架构参照（只读）：`skills-dev/medstat-55692f7/`（引擎、_shared、publication、MCP）、`skills-dev/medstat/acceptance/replication-sop.md`（范本复刻制）、`skills-dev/medstat-reference/`（文献采集与参考伴随服务）、`skills-dev/medstat/research/skillmd-craft/SYNTHESIS.md`（SKILL.md 撰写规范）。

---

## 第一部分 总体设计

### 1.1 模块单元的定义

**一个模块 = 一个常规生信 R 包中的一个"分析部分"。** 判定规则：
1. 以该包**官方 vignette 或 Bioconductor workflow 中的一个独立小节**为边界。每个小节回答一个独立的分析问题，并产生一种独立的结果类型（差异表、富集表、聚类结果、打分矩阵、网络模块……）。
2. 只起辅助作用、本身不回答分析问题的步骤（例如归一化因子计算、ID 转换、读入数据），**不单独成模块**，而是做成 `_shared` 函数，或作为上游模块的一部分。
3. 同一个包里，两个分析部分只要统计模型或结果类型不同，就拆成两个模块。例如 DESeq2 的 Wald 两组比较和 LRT 多组或时间序列检验，要回答的是不同的假设。
4. 纯作图包（ComplexHeatmap、enrichplot、ggplot2）**不成模块**，统一收进 `_shared` 的标准图形套件，由各分析模块调用。
5. 联网取数据的包（GEOquery、TCGAbiolinks）**不成分析模块**：分析运行时一律离线，取数据另外单独处理（见 §1.4）。

命名规则：`<包名小写>-<分析部分>`，例如 `deseq2-wald`、`clusterprofiler-ora`、`seurat-cluster`。入口脚本为 `scripts/run_<包名>_<部分>.R`。

### 1.2 阶段 1 模块目录（33 个：bulk 8 + 富集 6 + 单细胞 16 + 网络/突变/浸润 3）

每个模块下表所列的"核心函数"就是本模块要冻结的调用集合（§3.3）。包的版本在 M0 由容器锁定（§3.1）。

**A. Bulk 转录组：差异表达与质控**

| 模块 | 包 | 分析部分（vignette 小节） | 核心函数 | 主要产物 |
|---|---|---|---|---|
| `deseq2-qc` | DESeq2 + limma | 样本级质控：VST/rlog 变换、PCA、样本距离、可选展示校正 | `DESeqDataSetFromMatrix`、`vst`/`rlog`、`plotPCA` 的等价实现、`dist`、`limma::removeBatchEffect`（只用于展示） | 样本 PCA 图、距离热图、描述性样本指标表；离群统计量和阈值 C 待定，不自动判离群 |
| `deseq2-wald` | DESeq2 | 两组或指定对比的 Wald 检验 + LFC shrinkage | `DESeq`、`results`、`lfcShrink` | 特征表、火山图、MA 图、Top 热图 |
| `deseq2-lrt` | DESeq2 + DEGreport（可选） | 多组或时间序列的似然比检验 | `DESeq(test="LRT", reduced=)`、`results`、`DEGreport::degPatterns`（P-2 可选；锁定镜像缺包时类型化拒绝） | 特征表、可选模式聚类热图 |
| `edger-qlf` | edgeR | 准似然 F 检验 | `DGEList`、`filterByExpr`、`normLibSizes`、`estimateDisp`、`glmQLFit`、`glmQLFTest`/`glmTreat` | 特征表、MD 图、BCV 图 |
| `limma-voom` | limma | RNA-seq 的 voom 流程（含可选的样本权重） | `voomLmFit`（拟定主方向，C 待定）；`voom`/`voomWithQualityWeights` + `lmFit`（旧入口供复现）；`contrasts.fit`、`eBayes`/`treat`、`topTable` | 特征表、mean-variance 图；`voomLmFit` 的输出契约和复算锚点待补证后冻结 |
| `limma-array` | limma | 芯片数据差异分析 | `avereps`（P-2 可选技术重复合并）、`lmFit`、`eBayes`、`topTable`（输入为已归一化的表达矩阵） | 特征表 |
| `limma-dupcor` | limma | 同一个体重复测量的相关结构 | `duplicateCorrelation`、`lmFit(block=, correlation=)` | 特征表、组内相关系数报告 |
| `sva-batch` | sva | 批次校正与替代变量 | `ComBat_seq`（计数）/`ComBat`（连续）、`num.sv`、`sva`/`svaseq` | 校正后的矩阵（**只用于可视化和下游打分；差异分析模块必须拒绝已知校正来源的矩阵**）、SV 表、校正前后 PCA 对照图 |

**B. 功能富集与通路打分**

| 模块 | 包 | 分析部分 | 核心函数 | 主要产物 |
|---|---|---|---|---|
| `clusterprofiler-ora` | clusterProfiler | 过表达分析（GO/KEGG/Reactome/MSigDB） | `enrichGO`、`enricher`、`enrichKEGG`（离线数据）、`simplify` | 富集表、点图、cnet 图 |
| `clusterprofiler-gsea` | clusterProfiler | 排序基因集富集 | `gseGO`、`GSEA` | 富集表、GSEA 曲线、山脊图 |
| `clusterprofiler-compare` | clusterProfiler | 多组富集比较 | `compareCluster` | 比较点图 |
| `fgsea-prerank` | fgsea | 快速预排序 GSEA | `fgseaMultilevel`（S1 附录中显式列出全部参数；登记时与 D 表选用同一函数）、`collapsePathways` | 富集表、enrichment 曲线 |
| `gsva-score` | GSVA | 单样本通路打分（GSVA/ssGSEA/z-score/PLAGE） | `gsvaParam`/`ssgseaParam` + `gsva`（按锁定版本的新 API） | 样本 × 通路打分矩阵、热图；scores 的 limma 组间比较原则已定，但接收入口与 `eBayes` 取值待澄清 |
| `limma-camera` | limma | 竞争性基因集检验 | `camera`、`cameraPR`、`roast`/`mroast`/`fry` | 基因集检验表 |

**C. 单细胞：Seurat 与 Bioconductor（OSCA）两套生态并行**

范本中两种生态都常见，所以前段处理（质控、聚类、整合、marker）两套都建，各自独立成模块，彼此不互相替代。后段分析（注释、pseudobulk、比例、通讯、轨迹）本身就是生态中立的包，只建一份，两种对象都能接收（见 §1.3 的对象转换）。

C1 前段：Seurat 线

| 模块 | 包 | 分析部分 | 核心函数 | 主要产物 |
|---|---|---|---|---|
| `seurat-qc` | Seurat | 质控与细胞过滤 | `CreateSeuratObject`、`PercentageFeatureSet`、subset 过滤 | QC 小提琴图、过滤前后流向表 |
| `seurat-cluster` | Seurat | 归一化 → HVG → PCA → 邻域图 → 聚类 → UMAP | `NormalizeData`/`SCTransform`、`FindVariableFeatures`、`ScaleData`、`RunPCA`、`FindNeighbors`、`FindClusters`、`RunUMAP` | 聚类结果、UMAP、肘部图 |
| `seurat-integrate` | Seurat + harmony | 多样本整合 | `IntegrateLayers(method=HarmonyIntegration)`，或 `harmony::RunHarmony` | 整合前后的 UMAP、混合度指标 |
| `seurat-markers` | Seurat | 簇 marker 基因 | `FindAllMarkers`、`FindMarkers` | marker 表、点图、热图（**标明这是簇间描述，不是条件间推断**） |
| `seurat-modulescore` | Seurat | 基因集模块打分 | `AddModuleScore` | 每个细胞的打分、按簇的小提琴图 |

C2 前段：Bioconductor（OSCA）线

| 模块 | 包 | 分析部分（OSCA 书中的章节） | 核心函数 | 主要产物 |
|---|---|---|---|---|
| `scater-qc` | scater + scuttle | 质控与细胞过滤 | `perCellQCMetrics`、`perCellQCFilters`/`isOutlier`（MAD 自适应阈值） | QC 指标图、过滤前后流向表 |
| `scran-cluster` | scran + scater + bluster | 归一化 → HVG → PCA → 图聚类 → UMAP | `quickCluster`、`computeSumFactors`、`logNormCounts`、`modelGeneVar`、`getTopHVGs`、`fixedPCA`/`denoisePCA`、`clusterCells`（bluster `NNGraphParam`）、`runUMAP` | 聚类结果、UMAP、方差分解图 |
| `batchelor-integrate` | batchelor | 多样本整合 | `multiBatchNorm`、`fastMNN`（或 harmony 作用于 SCE） | 整合前后的 UMAP、批次混合诊断 |
| `scran-markers` | scran | 簇 marker 基因 | `scoreMarkers`（`findMarkers` 作兼容项） | marker 表（含效应量 AUC/Cohen's d）、热图（**同样标明是簇间描述**） |
| `aucell-score` | AUCell（或 GSVA 的单细胞模式，按 PACK 多数派确定） | 基因集活性打分 | `AUCell_buildRankings`、`AUCell_calcAUC` | 细胞 × 基因集打分、按簇分布图 |

C3 后段：生态中立（两条前段线都能接）

| 模块 | 包 | 分析部分 | 核心函数 | 主要产物 |
|---|---|---|---|---|
| `singler-annotate` | SingleR + celldex | 参考注释 | `SingleR`、`plotScoreHeatmap`、`pruneScores` | 注释表、打分热图、与簇的交叉表 |
| `muscat-pseudobulk` | muscat | pseudobulk 差异状态分析 | `aggregateData`、`pbDS` | 按细胞类型的特征表 |
| `speckle-propeller` | speckle | 细胞比例差异 | `propeller` | 比例表、堆叠图、结果表 |
| `cellchat-communication` | CellChat | 细胞通讯推断 | `createCellChat`、`computeCommunProb`、`aggregateNet`、`netAnalysis_*` | 通讯强度表、环形图、气泡图 |
| `monocle3-trajectory` | monocle3 | 轨迹与拟时序 | `learn_graph`、`order_cells`、`graph_test` | 拟时序图、随拟时序变化的基因表 |
| `slingshot-trajectory` | slingshot + tradeSeq | Bioconductor 线的轨迹与拟时序 | `slingshot`、`fitGAM`、`associationTest` | 谱系图、随拟时序变化的基因表 |

**两套前段线的等价对照**（写进路由器 §2，也是 PACK V 节分生态统计的依据）：

| 步骤 | Seurat 线 | Bioconductor 线 |
|---|---|---|
| 质控 | `seurat-qc`（通常固定阈值，以 PACK 为准） | `scater-qc`（通常 MAD 自适应阈值，以 PACK 为准） |
| 归一化到聚类 | `seurat-cluster`（LogNormalize 或 SCTransform + Louvain/Leiden） | `scran-cluster`（去卷积 size factor + 图聚类） |
| 整合 | `seurat-integrate`（Harmony） | `batchelor-integrate`（fastMNN） |
| marker | `seurat-markers`（Wilcoxon） | `scran-markers`（成对效应量汇总） |
| 基因集打分 | `seurat-modulescore` | `aucell-score` |
| 轨迹 | `monocle3-trajectory` | `slingshot-trajectory` |

**D. 网络、突变与免疫浸润**

| 模块 | 包 | 分析部分 | 核心函数 | 主要产物 |
|---|---|---|---|---|
| `wgcna-network` | WGCNA | 软阈值选择 → 构网 → 模块 → 模块—性状关联 | `pickSoftThreshold`、`blockwiseModules`、`moduleEigengenes`、`cor`/`corPvalueStudent` | 软阈值图、树图、模块—性状热图、hub 基因表 |
| `maftools-landscape` | maftools | 突变全景 | `read.maf`、`oncoplot`、`tmb`、`somaticInteractions` | oncoplot、TMB 表、共突变/互斥图 |
| `immunedeconv-infiltration` | immunedeconv（含 ESTIMATE/MCP-counter/xCell/EPIC；**CIBERSORT 需要许可，默认不打包**） | 免疫浸润估计 | `deconvolute(method=)` | 样本 × 细胞类型矩阵、热图、组间比较 |

**移交 medstat、不在本系统重复实现的**：生存分析（KM、Cox、非比例风险）、临床预测模型（LASSO-Cox 签名、列线图、DCA、校准）、时间依赖 ROC 以外的诊断准确性、meta 分析。omicstat 的相应模块只输出打分或签名，并写出可直接运行的 medstat 交接命令，照 medstat `--with-rcs` 的交接写法，并带上标签。

**阶段 2 预留**（本阶段不建）：DiffBind/ChIPseeker（染色质）、minfi/ChAMP（甲基化）、infercnv、SCENIC、DESeq2-ATAC、timeROC（时间依赖 ROC）、GEO/TCGA 取数工具。

### 1.3 模块之间的串联：`--from-run` 交接约定

包级粒度意味着大多数分析都要串联多个模块（例如 `seurat-qc → seurat-cluster → singler-annotate → muscat-pseudobulk → clusterprofiler-gsea`）。这是 medstat 不需要、但本系统必须有的机制，**只在引擎层实现，MCP 不增加工具**：
- 每个模块把可交接的对象写到 `objects/`（例如 `dds.rds`、`seurat.rds`、`feature_table.csv`），同时写 `objects/handoff.json`，内容包括：对象类型、sha256、产生它的模块和版本、StudyContract 的哈希、以及关键状态（例如 "normalized=LogNormalize; clusters=res0.5; seed=20260925"）。已知经批次校正的矩阵须标为 `batch_corrected_matrix`，不可冒充原始 `count_matrix`。
- 下游模块用 `--from-run <上游输出目录>` 读取对象，并**先校验** `handoff.json` 中的 sha256 与对象类型；类型不符或哈希不符时拒绝运行（`OS_HANDOFF_MISMATCH`）。
- 差异分析模块收到已知 `batch_corrected_matrix` 来源时必须类型化拒绝（`OS_BATCH_CORRECTED_INPUT`）；原始计数进入差异检验时，用设计项处理已知批次或替代变量。该拒绝在入口输入校验阶段执行，不降级为警告。
- 下游 provenance 记录完整的上游链（run_id 链）。MCP 的 manifest 增加 `upstream_runs` 字段（这是 manifest 字段，不是新工具）。
- 同一条链上的 StudyContract 必须一致（哈希相同）；下游如果改了合同，视为新的一条链。

**单细胞对象的生态规则（Seurat 与 SingleCellExperiment 并存）**：
- `handoff.json` 增加 `ecosystem` 字段，取值为 `seurat`、`bioconductor` 或 `scverse`（`scverse` 见第十部分）。一条链的**前段**（质控、聚类、整合、marker、打分）必须在同一个生态内完成；不允许 Seurat 做质控、scran 做聚类这样半途换生态。混用时拒绝运行（`OS_ECOSYSTEM_MIXED`）。
- **后段**的生态中立模块两种对象都接收，由 `_shared/convert.R` 做**显式转换**（`as.SingleCellExperiment` / `as.Seurat`，或 CellChat、monocle3 需要的对象构造）。规则如下：
  - 转换时必须写明使用哪个 assay 或 layer（原始计数还是归一化值）；转换后校验细胞数、基因数，以及簇标签是否一致；
  - 转换本身作为一个步骤记进 provenance，包括转换函数、源 layer 和前后的哈希；
  - 簇标签、UMAP 坐标等元数据原样带过去，**后段模块不重新聚类、不重新降维**。
- 后段模块的冒烟测试必须**两种输入各跑一次**（Seurat 对象和 SCE 对象）。只要前段结果相同（相同的簇标签和相同的计数），后段的数值结果必须逐字节一致。这条同时检验转换层的正确性。

### 1.4 数据入口与离线原则
所有分析模块只读本地文件，运行时不联网。GEO/TCGA 等取数工作在系统之外完成，或由阶段 2 的独立取数工具完成，产出"本地文件 + 来源清单"后再进入分析。参考数据（注释、基因集、SingleR 参考集、CellChat 数据库）在容器构建期固化（§3.1）。

---

## 第二部分 参考文档怎么找（每个模块的 S0 阶段）

### 2.1 证据分层

每个模块都要按下列四层逐层收集。每一层都有明确的"用来干什么"，不能混用。

| 层 | 来源 | 用途 | 数量要求 |
|---|---|---|---|
| **L1 包官方文档（锁定版本）** | 锁定 Bioconductor 版本对应的 vignette、参考手册（Rd）、NEWS/ChangeLog、包的方法学论文 | 定义**正确用法**；取**复算锚点**（vignette 中打印出来的数值）；记录**默认值随版本的变化** | 必须齐全 |
| **L2 官方工作流与社区最佳实践** | Bioconductor workflow 包（例如 rnaseqGene、RNAseq123）、OSCA 在线书（与锁定版本对应的那一版）、Seurat 官方教程（与锁定版本对应）、基准比较和最佳实践论文 | 裁决"推荐做法"与"函数默认值"之间的冲突；确定 QC 规则的出处 | 每个模块 2–5 篇 |
| **L3 高质量应用范本（A 层）** | Nature/Cell 系、Genome Biology、NAR、Genome Research、Nature Methods、Nature Biotechnology、Cancer Cell、Immunity 等 | 逐篇精读：表格骨架、图形语法、Methods 与 Results 的逐字句式、参数的实际取值 | 8–10 篇全文 |
| **L4 广度样本（B 层）** | 同 L3 的期刊白名单，可放宽到 JAMA/Lancet 系和各专科的顶刊 | 统计参数变体频次，作为 S1 裁决证据；指南/Rd 与范本冲突时按 S1 裁决。称“多数”须超过半数且注明分母，最常见取值不自动成为默认值 | 20–30 篇（至少方法段可读） |

### 2.2 采集流程（照搬 medstat 已有的采集工具）

1. **L1/L2 直接拿**：在 `omicstat-r` 容器里运行 `browseVignettes` 或直接读 `system.file("doc", package=)` 里的 vignette（**用的必须是锁定版本随包附带的 vignette，不能用网上最新版**），再用 `tools::Rd2txt` 导出核心函数的帮助页。NEWS 文件从包目录中读取。以上都存进 `acceptance/exemplars/<module>/L1/`，记录包版本与文件 sha256。
2. **L3/L4 检索**：复用 `medstat-reference` v2 的采集代码（Europe PMC 分节检索 + ISSN 期刊白名单闸门 + 方法节正文信号 + 许可规则），为 omicstat 另建一套配置：
   - `journals.json`：组学期刊白名单，ISSN 必须实测核验；
   - `discovery_profiles.json`：每个模块一个检索画像，形如 `METHODS:"DESeq2" AND (METHODS:"lfcShrink" OR METHODS:"apeglm")`。检索式里必须同时写包名和该分析部分的特征词，只写包名会把整个包的用户全部检出来；
   - `signal_regex`：方法节正文必须命中"包名 + 分析部分特征"（例如 `DESeq2[^.]{0,200}(likelihood ratio|LRT)`）。
   检索画像实测最多 3 轮；仍不达标的，标为 weak 并如实报告。
3. **全文获取**：只走开放获取的 JATS 全文（Europe PMC / PMC），可通过小主机 GT103 的开放获取线路；**不批量下载订阅内容**。正文只在解析时临时读取，持久化只保存 ≤25 词的片段、节定位和哈希；精读笔记用自己的话写。
4. **补充材料**：很多组学论文把参数写在补充方法里。只取开放许可的补充材料，取不到的记为"参数未报告"，**不猜**。
5. **每篇都验真**：PMID/DOI 用 efetch 回显标题、期刊和年份核对，原始 XML 存档。**不许有任何一条凭记忆写出来的引用。**

### 2.3 PACK 的内容（在 medstat 的 T/F/W/V/C 基础上增加 D 与 X 两节）

`acceptance/exemplars/<module>/PACK.md` 共七节：
- **T 表格骨架**：结果表在论文中的列、排序、截断方式（例如"Top 20 按 padj 排序"），补充表的形态。
- **F 图形语法**：每种图的坐标轴、阈值线、标签规则、配色惯例、分面方式；论文原图存入 `figures/`，供图形审对照。
- **W 文字模板**：Methods 与 Results 的逐字句式，要写到"软件名 + 版本 + 函数 + 关键参数"的粒度，例如 "Differential expression was assessed with DESeq2 (v1.xx) using the Wald test; log2 fold changes were shrunk with apeglm."
- **V 变体频次**：每个可调参数在 L4 样本中各种取值的出现次数及篇数分母；超过半数才称“多数”，最常见取值即使居首也不自动成为默认值。指南/Rd 与范本频次冲突时由 S1 明确裁决，并写明理由。**单细胞前段模块的频次按生态分开统计**：Seurat 线只统计用 Seurat 的论文，Bioconductor 线只统计用 scater/scran 的论文，不把两边的参数混在一起算多数派（例如 Seurat 论文的 Leiden 分辨率惯例，不能拿去当 scran 线的默认值）。L4 采集时同时记录每篇论文用的是哪种生态，用于路由器 §2 的"领域习惯"依据。
- **C 复算锚点**：公共数据集（优先用 vignette 自带的数据，例如 airway、pasilla、pbmc3k 等随包附带或 vignette 指定的数据）加上 vignette 打印出来的数值，作为冒烟测试的硬断言。
- **D 默认值三方对照（新增，组学关键）**：每个参数一行，列出①锁定版本中的**函数默认值**（来自 Rd），②**vignette 或官方工作流的推荐值**，③**范本频次、分母及是否过半**。来源不一致或未有过半取值时，在 S1 由主会话裁决并写明理由。**引擎最终使用的值一律显式写进调用（§3.3），不依赖函数默认值。**
- **X 版本敏感项（新增）**：锁定版本与前一个主要版本之间，本模块核心函数有哪些行为变化（来自 NEWS），例如 Seurat v4→v5 的 layer 化、GSVA 新旧 API。它决定哪些范本的做法因版本不同而不能照搬。

---

## 第三部分 Rscript 怎么冻结

"冻结"指：给定同样的输入和同样的选择，引擎在任何时间、任何机器上都跑出同样的结果；任何改动都会被机械地发现。一共七道锁。

### 3.1 锁 1：环境锁（容器 + 包版本）
- 单一容器 `omicstat-r`，构建方式照 `medstat/docker/`：基础镜像 `rocker/r-ver:<固定版本>`；`BiocManager::install(version="<固定 Bioc 版本>")`；包按层追加安装，每层末尾用 `stopifnot(requireNamespace(...))` 自检。
- 额外生成 `docker/pkg_lock.csv`：所有已安装包的名称、版本、来源（Bioconductor、CRAN 快照日期或 GitHub commit）。**GitHub 来源的包（例如 CellChat）必须钉到 commit hash。**CRAN 包从固定日期的快照仓库安装（例如 Posit Package Manager 的日期快照），不用"最新版"。
- 参考数据层：注释、基因集（msigdbr 的数据包版本）、celldex 参考集、CellChatDB 在单独一层下载，并按 `refdata_registry.json` 逐个校验 sha256。
- 镜像 ID（digest）写进每次运行的 provenance。
- 线程固定：`OMP_NUM_THREADS=1`、`OPENBLAS_NUM_THREADS=1`、`MKL_NUM_THREADS=1`；R 端用 `RhpcBLASctl::blas_set_num_threads(1)`；BiocParallel 固定为 `SerialParam()`。

### 3.2 锁 2：入口脚本结构统一
每个 `run_*.R` 按同一个骨架分段（照 medstat 引擎的结构）：
1. 定位 `_shared`，然后 `source`；
2. `parse_args`：用 `KNOWN_FLAGS` 白名单；`--spec` 可回放，跳过 `*_resolved` 信息键；
3. **参数解析与校验**：必填项缺失、枚举值非法、组合冲突，都返回类型化错误 `OS_*`；
4. **输入校验**：对象类型、维度、计数是否为整数、样本表与矩阵列名是否一致、`--from-run` 的交接校验；差异分析对已知 `batch_corrected_matrix` 来源返回 `OS_BATCH_CORRECTED_INPUT`，不进入拟合；
5. **计算**：只能调用 `calls_registry.json` 中登记过的函数（锁 3）；
6. **结果对象**：一个列表，是后续所有表、图、文字的唯一数据来源；
7. **渲染**：调用 `_shared` 的表、图、草稿函数；
8. **QC**：运行规则族，blocker 会扣下草稿；
9. **provenance**：写入命令、resolved_spec、sessionInfo、包版本、镜像 ID、种子、输入 sha256、上游链、refdata ID；
10. **收尾**：控制台最后一行统一为 "N of M rules triggered; read X first"。

ASCII only；不用顶层 `on.exit` 做清理，改用 `options(error=)` + `quit()`；对拟合对象一律用 `[[ ]]` 取值；formula 用 `as.formula(sprintf())` 构造。这些都是 medstat 的已知坑。

### 3.3 锁 3：调用登记与"显式参数"规则（本方案的核心）
- 每个模块有一份 `scripts/calls_registry.json`，列出本模块调用的每一个包函数，以及该函数**每个影响结果的参数**：参数名、取值来源（`pack_majority` / `vignette` / `user_required` / `user_optional_default`）、具体值或取值的来源字段、对应的 PACK 小节。
- **显式参数规则**：凡是影响结果的参数，都必须在调用中显式写出，**哪怕它的取值恰好等于函数默认值**。原因是包的默认值会随版本变化；显式写出之后，升级版本不会让结果静默地改变。
- **登记一致性检查**（`tools/check_calls.R`，每个模块的冒烟测试都要调用）：
  - 用 `getParseData` 解析入口脚本和模块自身的脚本，找出所有登记函数的调用点；
  - 核对每个调用点都显式写出了登记表中列出的全部参数；
  - 出现未登记的包函数调用（来自 `_shared` 白名单的除外）即 FAIL。
- **默认值漂移检查**：对登记表中每个函数，用 `formals()` 读取锁定版本中的实际默认值，与 PACK D 节记录的"函数默认值"比较；不一致即 FAIL。这说明锁定版本和 PACK 编写时依据的版本对不上。

### 3.4 锁 4：随机性锁
所有带随机性的步骤接受 `--seed`（默认一个固定值，写进 provenance），并在调用处显式传入：
- `set.seed`；
- Seurat 的 `seed.use` / `random.seed`；
- `RunUMAP` 的 `seed.use`；
- `FindClusters` 的 `random.seed`；
- fgsea 的 `nproc=1` 且设种子；
- enrichit 的 multilevel GSEA 在 `seed` 默认 `FALSE` 时会生成随机种子；须显式固定并记录种子；
- limma 的 `roast`/`mroast` 旋转抽样（包括 `nrot = 9999`）须固定种子；
- `num.sv(method = "be", seed = )` 的随机路径须显式传入并记录种子；
- WGCNA 的 `randomSeed`；
- CellChat 与 monocle3 的相应种子参数。

此外：PCA 做符号规范化（每个主成分中载荷绝对值最大的一项取正）；簇按大小降序重新编号，并列时按字典序。

### 3.5 锁 5：金标准输出（golden baseline）
- S5 装机时，用锚点数据集以固定参数运行一次，记录所有产物的 sha256，写入 `tests/golden_manifest.csv`，同时记录环境签名：镜像 ID、平台、锁定的 Bioc 版本。
- 冒烟测试分两档核对：
  - **逐字节一致**：bulk、富集、打分、pseudobulk、比例检验、WGCNA 的主表与 `figure_spec.json`；
  - **容差一致**：单细胞的嵌入与聚类，同平台 ARI = 1，跨平台 ARI ≥ 0.95。
- 环境签名不一致时（例如本机原生 R 与容器），逐字节检查显式 SKIP 并说明原因，不能 FAIL（medstat competing-risks 的做法）。
- PDF 创建时间戳、绝对路径等已知的非确定字段，在 manifest 中声明为豁免项。

### 3.6 锁 6：模块锁文件
`skills/<module>/module_lock.json` 在 S5 生成，内容包括：
- 入口脚本及模块内其他脚本的 sha256；
- `calls_registry.json` 的 sha256；
- PACK 版本与 sha256；
- 锚点清单；
- `golden_manifest.csv` 的 sha256；
- 依赖包及版本（从 pkg_lock 中截取本模块用到的部分）；
- 模块版本号（从 1.0.0 开始）。

MCP 启动时由 package identity 机制（分叉自 medstat 的 `package_identity.py`）逐项校验；不一致时，该模块的运行结果在出版校验中不能达到 ready。

### 3.7 锁 7：变更流程
冻结以后，对模块的任何改动都必须：①升级模块版本号；②重跑锚点与金标准，差异逐项记录进 SUITE；③改变数值的改动必须有可复现的错误作为依据（与 medstat 相同：没有可复现的统计错误，不改 estimator 和默认值）；④重新生成 `module_lock.json`。**只改渲染或文案的改动**，金标准中的数值表必须保持逐字节不变；变化的只能是图和草稿，并且需要登记。

---

## 第四部分 每个分析部分的 skill 怎么建

### 4.1 目录与文件（每个模块一模一样）
```
skills/<module>/
  SKILL.md
  module_lock.json            # S5 生成
  scripts/
    run_<pkg>_<part>.R        # 唯一入口
    <pkg>_<part>_core.R       # 计算
    <pkg>_<part>_report.R     # 渲染与草稿
    <pkg>_<part>_qc.R         # QC 规则族
    calls_registry.json
  references/
    method-basis.md           # L1/L2 出处：包、版本、vignette 小节、方法学论文、基准研究
    parameters.md             # calls_registry 的人读版：每个参数取值的理由与出处（PACK 小节号）
    qc-rules.md               # 规则编号、判据、处置、出处
    reporting-templates.md    # W 节的逐字模板与占位符说明
    troubleshooting.md        # 常见报错→原因→修法（英文，含"预期的无害控制台输出"）
  tests/
    run_smoke_test.R
    golden_manifest.csv
    fixtures/
```

### 4.2 脚手架生成器
`tools/new_module.py <pkg> <part>`：从 `templates/module/` 生成上述骨架，自动填好模块名、入口文件名、QC 规则前缀（取包名缩写，先 grep 全套件已占用的前缀避免重名），以及 SKILL.md 的章节标题。生成后由 S2 建设位按 PACK 填写内容。

### 4.3 SKILL.md 模板（遵循 skillmd-craft SYNTHESIS v1 撰写规范）

**frontmatter**：
- `name`：模块名。
- `description`（**≤1000 字符**；官方的列表上限是 1536 字符，超长的部分可能被截断或丢弃）：
  - 第一句以"动词 + 论文产物"开头，例如 "Run DESeq2's Wald-test differential expression with apeglm shrinkage on an RNA-seq count matrix and produce the publication feature table, volcano and MA plots, and a Methods/Results draft with the numbers filled in."；
  - 第二句写何时使用；
  - 然后是**带出口的消歧句**，例如 "NOT for multi-group or time-course tests (use deseq2-lrt); NOT for microarray data (use limma-array)"；
  - 最后是中英双语触发词（包名、函数名、中文说法），**放在描述靠前的位置，不要压在末尾**。
- 锚定"产物"，不锚定"身份"：不写 "You are a bioinformatician"。

**正文八节**，对应 medstat 的完整度八项清单：
1. **When to use / when not**：每条"不适用"都带出口，说明应改去哪个模块。
2. **Input requirements**：对象类型、计数或归一化状态、样本表的必需列、`--from-run` 上游模块。
3. **Run**：主示例命令（`Rscript scripts/run_*.R ...`），紧跟 "Via MCP" 段（措辞与 medstat 一致），写明 "`--help` lists every option; the ones that matter most:"，再列最重要的参数及其取值理由（指向 parameters.md）。
4. **What gets produced**：产物文件名清单，指明主表、主图、草稿、QC 报告和交接对象。
5. **Reading the results**：结果如何写进论文，指向 reporting-templates.md；包括常见误读，这些误读要**改写成"命名的失败模式 + 正确形态"**，不贴错误示例原文。
6. **When a QC rule fires**：规则范围（例如 `DW-01..DW-12`），以及每类规则的处置方式，指向 qc-rules.md。
7. **Known limitations**：本模块答不了的问题，每条都要有出处或可以验证的引擎行为。
8. **Reference files**：列出 references/ 下各文件的用途。

**撰写约束**：
- 否定句按"有出处吗？与本模块执行相关吗？值这几行 token 吗？"三问审查，三问全过才能保留；
- 已经由 `_shared` 代码强制执行的规矩，不在 SKILL.md 里重复；
- 防御性的历史记录放进 tests/ 或 acceptance/，SKILL.md 里只留指针；
- **旗标文档覆盖率**：`--help` 中的每个参数，都必须在 SKILL.md 或 references 中出现过。由 `tools/check_flag_docs.py` 做机械检查，接入冒烟测试。

### 4.4 references/ 各文件的写法
- `method-basis.md`：每条格式为"论断 → 出处（包名@版本、vignette 小节名，或 PMID/DOI）"。
- `parameters.md`：从 `calls_registry.json` 自动生成表格骨架，理由由人来写。**表格部分由工具重新生成，不许手工修改**，以免文档与代码漂移。
- `qc-rules.md`：规则编号、严重级别、是否 blocking、判据（可以机械检查）、控制台与报告里的原话、处置方式、出处。
- `reporting-templates.md`：W 节模板中的占位符（例如 `{n_samples}`、`{padj_threshold}`），要与引擎里的字段名一一对应，并列出对照表。
- `troubleshooting.md`：用英文写；每条的格式为"现象原文 → 原因 → 修法"。

### 4.5 各模块的 QC 规则族：必须覆盖的共性规则（每个模块按适用情况取用，编号用本模块前缀）
- **输入状态类**：计数不是整数（计数模型）；已经归一化的数据被当作计数；样本表与矩阵不一致；物种或注释版本未声明。
- **设计类**：设计矩阵不满秩；批次与条件完全混杂；每组生物学重复少于 2 为 blocker，少于 3 为警告；对比中引用的水平不存在。
- **推断类**：条件间比较使用逐细胞检验（伪重复）为 blocker；富集没有使用检测基因作背景为 blocker；marker 结果被表述成条件差异；批次校正后的矩阵被送去做差异分析，为 blocker。
- **数值退化类**：padj 全为 NA；全部基因都显著；log2FC 出现无穷值；软阈值始终达不到无尺度拓扑的拟合标准；轨迹图不连通。
- **报告类**：图表里出现原始列名；文字中的数字与结果对象不一致；阈值没有写进图注。

每条规则都必须有出处（L1/L2 文献，或 PACK 小节）。没有出处的规则不准写入。

---

## 第五部分 路由 skill 怎么建

### 5.1 结构（照 `medstat/SKILL.md`）
`skills/omicstat/SKILL.md`：
1. **§1 路由表**：列为"问题听起来像……"、模块、入口脚本。**MCP 从这张表解析模块注册表，全系统只有这一份契约。**
2. **§2 消歧树**，按族分：
   - **差异分析引擎怎么选**：先看数据类型（RNA-seq 计数、芯片、单细胞），再看设计（两组、多组或时间序列、重复测量、复杂设计），落到 `deseq2-wald` / `deseq2-lrt` / `edger-qlf` / `limma-voom` / `limma-array` / `limma-dupcor` / `muscat-pseudobulk`。**默认主引擎依各模块 PACK 的 S1 裁决确定**，范本频次仅为证据之一；“多数”须过半并标明分母，指南/Rd 冲突由 S1 明裁。其他引擎只作敏感性分析，并排输出，不能替换主分析。
   - **富集怎么选**：有明确的阈值基因列表用 ORA；有全基因排序用 GSEA；需要每个样本一个打分用 GSVA；做竞争性检验用 camera；多组比较用 compare。
   - **单细胞走哪套生态**（必须先定，定了之后整条前段链不能再改），依次判断：
     1. 用户已有对象：`.rds` 里是 Seurat 对象的，走 Seurat 线；是 SingleCellExperiment 的，走 Bioconductor 线。
     2. 用户明确指定，或者要复现某篇论文：按指定或按论文所用的生态。
     3. 以上都没有：按用户研究领域中范本的多数派生态（依据 L4 的生态统计），并把选择理由写进 StudyContract。
     两套线的等价对照见 §1.2 C 节末尾的表。**禁止**同一分析中两套各跑一遍后挑结果；如需做稳健性对照，另起一条链并明确标注为敏感性分析。
   - **单细胞的问题是什么**：簇的描述（`seurat-markers` / `scran-markers`）、条件间的表达差异（pseudobulk）、条件间的比例差异（propeller）、细胞类型身份（SingleR）、细胞间通讯（CellChat）、细胞状态连续变化（`monocle3-trajectory` / `slingshot-trajectory`，与前段所用生态保持一致）。
   - **批次**：只用于可视化和打分（`sva-batch`），差异分析中把批次放进设计公式。
3. **§3 标准流水线配方**：每条配方写明模块顺序、`--from-run` 串联方式，以及每一步为什么需要：
   - Bulk 标准：`deseq2-qc → deseq2-wald → clusterprofiler-ora + clusterprofiler-gsea`
   - Bulk 多组或时间序列：`deseq2-qc → deseq2-lrt → clusterprofiler-compare`
   - 单细胞标准（Seurat 线）：`seurat-qc → seurat-cluster → seurat-integrate（多样本时）→ singler-annotate → seurat-markers`
   - 单细胞标准（Bioconductor 线）：`scater-qc → scran-cluster → batchelor-integrate（多样本时）→ singler-annotate → scran-markers`
   - 单细胞条件比较（两条线通用的后段）：`<前段> → muscat-pseudobulk → fgsea-prerank`，另加 `speckle-propeller`
   - 单细胞轨迹：Seurat 线接 `monocle3-trajectory`，Bioconductor 线接 `slingshot-trajectory`
   - 通路打分转临床：`gsva-score → 交给 medstat survival/assoc`
4. **§4 交给 medstat 的场景**：生存分析、预测模型、临床协变量调整的关联分析。
5. **§5 标签总表**：各模块接受的标签参数。
6. **§6 Via MCP**：说明工具、封套字段含义；并写明路由决策仍由本文件做出。
7. **§7 参考伴随服务**：`omicstat_reference` 的使用顺序是先 search，再 advise，依据不足时发 request（不等待）。

### 5.2 路由 skill 的 description
以"Route a bioinformatics analysis question to the right package-level module…"开头；列出族名与典型触发词（差异表达、富集、单细胞、WGCNA、免疫浸润、突变全景……）；写明 "has NO engine of its own"。控制在 1000 字符以内。

### 5.3 路由评测集（新增，路由器的机械验收）
- `skills/omicstat/tests/routing_eval.jsonl`：至少 60 条自然语言问题（中英混合），每条标注期望的模块或流水线，以及可以接受的备选。问题要覆盖每个模块至少 2 条，外加每棵消歧树的易混淆样例。
- 评测方法：由一个只读路由器 SKILL.md 的 agent 逐条作答（不读模块源码），统计首选命中率。**门槛：首选 ≥ 90%，且"首选或可接受备选"≥ 98%。**未命中的条目回头修消歧树，然后重测一次。
- 评测集本身要冻结，并与路由器版本一起记录。

---

## 第六部分 基础设施（照 IMPLEMENTATION_SPEC v2 §3 执行，这里只列差异）

| 项 | 做法 |
|---|---|
| 仓库、`bin/`、`_shared`、publication、schema、MCP 5 工具、package identity、发布门禁 | 整套分叉 `medstat-55692f7`（见 IMPLEMENTATION_SPEC v2 §3 第 1–9 步） |
| `_shared` 新增 | `feature_table.R` + 校验 CLI；`handoff.R`（`--from-run` 读写与校验）；`calls_check.R`（锁 3 的检查）；组学标准图形套件（火山图、MA、PCA、距离热图、Top 热图、富集点图与 GSEA 曲线、UMAP、marker 点图、比例图、模块—性状热图、oncoplot 包装器） |
| MCP 改动（只有两处） | ①manifest 主载荷识别 feature_table；②新增 `upstream_runs` 字段与组学退化判据。**不新增工具。** |
| StudyContract | 字段名不变，使用组学含义的映射（IMPLEMENTATION_SPEC v2 §4）；**同一条 `--from-run` 链必须使用同一份合同** |
| 出版规则 | `module_rules_v1.json` 每个模块一条记录；规则内容来自 PACK 的 T/F/W 节 |
| 参考伴随服务 | 复用 medstat-reference v2 的代码，配置换成组学版本（§2.2）；部署到 GT103 的独立容器 `omicstat-reference` |

---

## 第七部分 执行编排与工作卡

### 7.1 阶段与里程碑

| 里程碑 | 内容 | 完成判据 |
|---|---|---|
| **M0 地基** | 仓库分叉；容器与 pkg_lock；refdata 层；`_shared` 新增件；脚手架生成器；`check_calls.R`、`check_flag_docs.py`；MCP 分叉 | `_shared` 测试全过；MCP 空表能启动；分叉带来的 medstat 原有测试改名后全部通过；新容器中能加载 §1.2 全部包（含 Seurat 线与 scater/scran/bluster/batchelor/AUCell/slingshot/tradeSeq 等 Bioconductor 线） |
| **M1 bulk DE 族**（8 个） | deseq2-qc、deseq2-wald、deseq2-lrt、edger-qlf、limma-voom、limma-array、limma-dupcor、sva-batch | 每个模块完成 S0–S5 |
| **M2 富集族**（6 个） | clusterprofiler-ora、clusterprofiler-gsea、clusterprofiler-compare、fgsea-prerank、gsva-score、limma-camera | 同上 |
| **M3a 单细胞前段**（10 个：Seurat 线 5 个 + Bioconductor 线 5 个） | 按 §1.2 C1、C2 表；两条线可以并行建设 | 同上（按容差档验收）；两条线各自的等价步骤在同一锚点数据集上的结果差异必须如实记录（不要求一致，要求可以解释） |
| **M3b 单细胞后段**（6 个） | 按 §1.2 C3 表，外加 `_shared/convert.R` | 同上；每个模块用 Seurat 与 SCE 两种输入各跑一次，只要前段结果相同，后段数值必须逐字节一致 |
| **M3c 单细胞 scverse 通道**（5 个 + Python 地基） | 第十部分：`omicstat-py` 环境、`_shared/py`、MCP 分发，加上 §10.2 的 5 个模块 | §10.8 的判据 |
| **M4 网络、突变、浸润**（3 个） | wgcna-network、maftools-landscape、immunedeconv-infiltration | 同上 |
| **M5 路由与集成** | 路由器 §5 全部内容；路由评测；流水线端到端串联测试；跨 agent 一致性测试 | §8 的 G4–G8 |
| **M6 审计与发布** | 一次统一审计（GPT Pro 或独立子代理）→ 一次集中整改 → 全部门禁通过 → 打包 | §8 全部门禁 |
| **M7 参考伴随服务** | omicstat-reference 配置与部署 | 按 medstat-reference v2 的验收标准 |

同一族内的模块可以并行建设；族与族之间按 M1→M4 的顺序推进，因为富集依赖差异分析的产物，单细胞的 pseudobulk 依赖 bulk-de 的引擎函数。

### 7.2 工作卡模板（派发子代理时逐张填写）

**S0 采集卡**（便宜模型）：
- 目标模块；锁定的包版本；检索画像（查询式、信号正则）；
- 本卡的采集数量上限（L3 8–10 篇、L4 20–30 篇）；请求次数上限；
- 产出物：L1 导出的文件、PMID 清单（附 efetch 回显）、每篇的方法片段定位、参数取值表（原文未报告的写"未报告"）；
- **禁止**：凭记忆写引用；下载订阅内容；做工程决策；给出"推荐值"。
- 停止条件：配额用完或请求次数用完；缺口如实报告。

**S1 冻结卡**（主会话）：
- 审阅 PACK 七节；裁决 D 节中三方不一致的参数；确认 QC 规则的出处；确认锚点可以复算（在容器里亲自重跑一遍）；
- 在 PACK 末尾写"S1 审定附录"。

**S2 建设卡**（中档或高档模型）：
- 输入：冻结后的 PACK、脚手架、`_shared`；
- 产出：引擎（锁 2 的结构）、`calls_registry.json`、SKILL.md 与 references、QC 规则族、冒烟测试（锚点、旗标有效性、登记一致性、默认值漂移、旗标文档覆盖率、确定性）；
- 自测：原生与容器双平台；
- 纪律：遵守 worklog 续跑协议；只做一次完整构建和一次自测。

**S3 验收卡**（没有参与构建的模型）：
- 只判四项：锚点、表格形似、文字形似、机械核；另外亲眼看每一张图；
- 返修单的每一条都必须引用 PACK 小节。

**S4 修复卡**：只修闭口清单里的问题，修完复跑受影响的门禁。

**S5 装机卡**（主会话）：
- 生成 golden_manifest 与 module_lock；
- 建 junction；在路由表中加一行；在 SUITE 中加记录。

### 7.3 工作法（与 medstat 相同）
- 全项目只做一次统一审计，发生在 M6。
- 各族建设期只走 S3 单轮验收，不做开放式审计。
- 子代理按活选模型：采集用便宜模型，实现用中档模型，统计判断与冻结裁决由主会话负责。

---

## 第八部分 验收门禁

| 门禁 | 标准 |
|---|---|
| G1 锚点 | 每个模块复算官方 vignette 或 PACK C 节的数值，全部命中（容差写在 PACK 中） |
| G2 冻结 | 调用登记一致性、默认值漂移、module_lock 校验全部通过 |
| G3 确定性 | 逐字节档与容差档按 §3.5 执行 |
| G4 旗标 | 每个开关都真实改变产出；文档覆盖率 100% |
| G5 路由 | 路由评测：首选 ≥ 90%，"首选或可接受备选"≥ 98% |
| G6 流水线 | §5.1 的每条标准配方端到端跑通（单细胞两条生态线都要跑）；`--from-run` 交接校验的正例和负例都通过；故意混用生态时必须被 `OS_ECOSYSTEM_MIXED` 拒绝 |
| G7 跨 agent 一致性 | 两个独立 agent 拿同一份数据和同一段需求，各自完成分析。选择上的差异必须能从 StudyContract 中逐项看出；参数相同的部分主表逐字节一致 |
| G8 盲测 | 一个只读路由器和模块文档的 agent，完成 6 个端到端任务（bulk DE + 富集、多组 LRT、单细胞 Seurat 线从 QC 到注释、单细胞 Bioconductor 线从 QC 到注释、单细胞条件比较、WGCNA），critical 问题清零 |
| G9 MCP | 分叉自 medstat 的 stdio 验收，在源码目录、解压安装包、最终安装目录三处全部通过 |
| G10 出版 | publication core 测试全过；每个模块至少有一个运行在声明完整时能达到 `ready_for_manuscript_integration` |

---

## 第九部分 风险与应对

| 风险 | 应对 |
|---|---|
| 包的默认值或 API 随版本变化 | 版本锁定、显式参数规则、默认值漂移检查、PACK X 节 |
| GitHub 来源包（CellChat 等）不稳定 | 钉到 commit；镜像层内自检；上游仓库消失时，镜像本身就是存档 |
| 许可问题（CIBERSORT、KEGG、部分参考集） | 在 refdata_registry 中标注许可；不能再分发的标为"用户自备"，模块检测到缺失时给出类型化拒绝 |
| 单细胞运行时间超过 MCP 的 25 分钟上限 | 每个模块的 SKILL.md 写明适用规模；超出时给出类型化拒绝和下采样指引；需要长任务支持的，在 M5 走"待裁决" |
| 包级模块数量多，agent 路由困难 | 消歧树 + 流水线配方 + 路由评测集门槛 |
| 范本以 Python 生态为主的分析部分（例如部分单细胞整合方法） | v1.1 起：单细胞按第十部分建受限的 scverse 通道；其他领域仍然只收 R 包，Python 引擎不扩到第十部分之外 |

---

## 第十部分 Python 通道（scverse）（v1.1 新增，2026-09-27）

### 10.1 为什么要加，范围到哪为止

- **目的是兼容**。单细胞领域有相当一部分论文和公共数据用的是 scanpy / AnnData（h5ad）/ scvi-tools。只有 R 两条线时，这类用户要么先转换对象，要么没法按原论文的生态复现。加上 scverse 通道，就能按路由器的"用户已有对象 → 要复现的论文 → 领域多数派"顺序选到它。
- **scverse 在范本中占多少比例，由 S0 的 L4 统计给出**，本文不预设数字。如果 L4 显示占比很低，M3c 可以缩减或推迟，由用户裁决。
- **范围严格限定**：
  - 只收**单细胞**的 scverse 包的分析部分；
  - bulk、富集、网络、突变、浸润继续只用 R；
  - 同一分析部分 R 里已有成熟实现的，不另建 Python 版来做"对照"。
- 模块单元的定义不变（§1.1）：一个模块 = 一个包的官方教程中的一个独立分析部分，只是"包"可以是 scverse 的 Python 包。

### 10.2 模块目录（M3c，5 个）

| 模块 | 包 | 分析部分（官方教程小节） | 核心函数 | 主要产物 |
|---|---|---|---|---|
| `scanpy-qc` | scanpy | 质控与细胞过滤 | `sc.pp.calculate_qc_metrics`、`sc.pp.filter_cells`/`filter_genes`、双细胞检测 `sc.pp.scrublet` | QC 小提琴图、过滤前后流向表 |
| `scanpy-cluster` | scanpy | 归一化 → HVG → PCA → 邻域图 → Leiden → UMAP | `sc.pp.normalize_total`、`sc.pp.log1p`、`sc.pp.highly_variable_genes`、`sc.pp.pca`、`sc.pp.neighbors`、`sc.tl.leiden`、`sc.tl.umap` | 聚类结果、UMAP |
| `scanpy-markers` | scanpy | 簇 marker 基因 | `sc.tl.rank_genes_groups` | marker 表、点图（**标明是簇间描述，不是条件间推断**） |
| `scvi-integrate` | scvi-tools | scVI 潜空间多样本整合 | `scvi.model.SCVI.setup_anndata`、`SCVI(...)`、`.train`、`.get_latent_representation` | 整合前后 UMAP、批次混合诊断 |
| `scanvi-annotate` | scvi-tools | scANVI 标签迁移注释 | `scvi.model.SCANVI.from_scvi_model`、`.train`、`.predict` | 注释表、预测置信度、与簇的交叉表 |

**明确不收**：
- **scGPT 等单细胞基础模型**：依赖 GPU 和大模型权重，权重版本和推理结果难以锁定，也不是论文标准分析流程中的固定步骤。如需要，列入阶段 3 的"探索性"类别，不进发布门禁。
- **omicverse**：它是把很多方法再封装一层的框架，API 变动快，一个函数背后可能换了实现，违反"一个包的一个分析部分"这条模块定义。只作为设计参考，不作为引擎。
- **scanpy 自带的伪重复式条件比较**（逐细胞的 `rank_genes_groups` 跨条件用）：条件间比较一律走生态中立的后段模块（`muscat-pseudobulk`、`speckle-propeller`）。

**与 R 两条前段线的等价对照**（补进 §1.2 C 节的对照表）：质控 `scanpy-qc`；归一化到聚类 `scanpy-cluster`；整合 `scvi-integrate`；marker `scanpy-markers`；注释：`scanvi-annotate`（与 `singler-annotate` 并列，两者用途不同，由路由器区分）。scverse 线没有独立的打分和轨迹模块，要用时交给后段模块处理。

### 10.3 与 R 模块的串联

- `handoff.json` 的 `ecosystem` 增加 `scverse`；交接对象类型增加 `AnnData`（文件为 `.h5ad`）。
- **前段同一生态规则不变**：scverse 线的质控、聚类、整合、marker 必须都在 scverse 内完成；混用时报 `OS_ECOSYSTEM_MIXED`。
- **后段**（`singler-annotate`、`muscat-pseudobulk`、`speckle-propeller`、`cellchat-communication`、`monocle3-trajectory`、`slingshot-trajectory`）接收 AnnData：由 `_shared/convert.R` 用 zellkonverter（已在 L4 层）转成 SCE。§1.3 的转换规则全部照用：写明 assay/layer、校验细胞数和基因数、簇标签原样带过去、转换过程记进 provenance。
- 后段冒烟测试从"两种输入各跑一次"扩为**三种**（Seurat、SCE、AnnData）。只要前段结果相同，后段数值逐字节一致。
- R 模块产出的对象如果要交给 scverse 模块，同样用 zellkonverter 显式转换并记录，但只允许在"后段 → 后段"的方向使用，前段不能跨生态。

### 10.4 七道锁在 Python 上的对应做法

| 锁 | R 的做法 | Python 通道的做法 |
|---|---|---|
| 1 环境 | `omicstat-r` 镜像 + pkg_lock | 第二个镜像 **`omicstat-py`**，用 conda-lock 或 pixi 锁文件（全部依赖带哈希），写 `env/py_lock.txt`；**只用 CPU 版 PyTorch**；镜像 ID 进 provenance。R 镜像不变 |
| 2 入口结构 | `run_*.R` 十段骨架 | `scripts/run_<pkg>_<part>.py`，同样十段；共享件放 `_shared/py/`（参数白名单与 `--spec` 回放、`OS_*` 类型化错误、警告捕获、provenance、feature_table 写出、handoff 读写），接口与 R 版一一对应 |
| 3 调用登记 | `calls_registry.json` + getParseData 核对 + `formals()` 漂移检查 | 同一份 schema；`tools/check_calls.py` 用 `ast` 找调用点并核对显式参数；默认值漂移检查用 `inspect.signature` 读锁定版本的默认值 |
| 4 随机性 | seed、BLAS 单线程 | `--seed` 显式传给 `scvi.settings.seed`、`numpy`、`random`、`torch.manual_seed`，以及 Leiden/UMAP 的 `random_state`；`torch.use_deterministic_algorithms(True)`；`OMP/MKL/OPENBLAS/NUMBA_NUM_THREADS=1`；`torch.set_num_threads(1)` |
| 5 金标准 | 逐字节档 / 容差档 | scanpy 的表：同平台逐字节；嵌入、聚类、scVI 潜空间：容差档（同平台 ARI = 1、潜空间逐元素容差写进 PACK；跨平台 ARI ≥ 0.95）。scANVI 预测：同平台标签逐字节一致 |
| 6 模块锁 | `module_lock.json` | 同一格式；依赖版本从 `py_lock.txt` 截取 |
| 7 变更流程 | 照 §3.7 | 同样照 §3.7 |

### 10.5 图形：只有一套样式系统

**Python 模块不画出版图。** 它把作图所需的数据（坐标、分组、表格）写成 `figure_data/*.parquet` 或 csv，外加 `figure_request.json`；最后由 R 的 `_shared/scripts/fig_*.R` 统一渲染，经 `os_finalize_figure` 输出。这样图表层（FIGURE_STYLE、色觉检查、n 的单位、自动图注、lint）只有一份，不会出现两套风格。实现上，入口脚本最后一步调用一个固定的 R 渲染步骤（`_shared/scripts/render_figure_request.R`）。这一步在 `omicstat-r` 镜像里运行，并作为一个步骤记进 provenance。

### 10.6 MCP 需要改的地方（仍然不新增工具）

1. **模块注册**：路由器 §1 的表格解析，从只认 `scripts/run_*.R` 扩为 `run_*.R` 或 `run_*.py`（`server.py` 中的正则）。
2. **引擎分发**：按入口扩展名选命令和镜像：`.R` → `Rscript` + `omicstat-r`；`.py` → `python` + `omicstat-py`；Python 模块的作图步骤再调用 `omicstat-r`。原生模式同理（`native-env.json` 增加 `python` 键）。
3. **参数白名单**：Python 入口的 `--help` 输出格式与 R 版一致（argparse 的格式经 `_shared/py` 统一），沿用同一个正则。
4. **provenance 探针**：增加 Python 环境探测（解释器版本、`importlib.metadata` 读到的包版本、镜像 ID）。
5. **时长**：25 分钟上限不变。scVI/scANVI 在 CPU 上训练很慢，每个模块的 SKILL.md 写明适用规模（细胞数、epoch 上限），超出时给出类型化拒绝和下采样指引。需要 GPU 或长任务的，走"待裁决"，不在本阶段支持。

### 10.7 S0 与路由的变化

- **L4 生态统计从两方扩为三方**（Seurat / Bioconductor / scverse），分开计算多数派。scverse 线的默认值只从使用 scverse 的论文中统计（§2.3 V 节的规则照用）。**所以从现在起，M3 的 L4 采集就要记录每篇论文所用的生态，包括 scverse。**
- PACK X 节增加 scanpy / anndata / scvi-tools 的版本敏感项（例如 AnnData 的 layer 约定、scanpy 的默认值调整、scvi-tools 的 API 迁移）。
- L1 取锁定版本随包附带的文档和官方教程（scanpy tutorials、scvi-tools user guide），存档方式与 §2.2 相同。
- 路由器 §2 的"单细胞走哪套生态"：输入是 `.h5ad` 并且用户没指定时，默认走 scverse 线（之前是用 zellkonverter 读进 R）；其余判定顺序不变。仍然**禁止**多套生态各跑一遍后挑结果。
- 路由评测集增加 scverse 线的问题（至少每个模块 2 条，外加"h5ad 该走哪条线"的易混淆样例）。

### 10.8 M3c 的完成判据

1. `omicstat-py` 镜像建成，锁文件齐全，镜像内自检通过；`_shared/py` 的测试通过。
2. MCP 能在同一个注册表里同时列出 R 模块和 Python 模块；stdio 验收（G9）覆盖一个 Python 模块。
3. 5 个模块各自完成 S0–S5（按容差档验收）；锚点优先用官方教程的数据（例如 pbmc3k），数值来自教程打印值，或按"回放锚点"验证。
4. 后段模块三种输入（Seurat、SCE、AnnData）的一致性测试通过。
5. G6 流水线增加一条：`scanpy-qc → scanpy-cluster → scvi-integrate → singler-annotate / scanvi-annotate → muscat-pseudobulk`。
6. 图形全部经 R 图表层渲染，lint 通过，并由主会话亲眼看图。

### 10.9 新增风险

| 风险 | 应对 |
|---|---|
| PyTorch 的数值在不同 CPU 指令集上略有差异 | 金标准分平台记录签名；跨平台只做容差档比较，环境签名不同时显式 SKIP（§3.5 同样做法） |
| 两个镜像的版本组合漂移 | `omicstat-env.json` 同时钉住两个镜像的版本，改任何一个都算新的 `env_version` |
| AnnData 与 SCE 转换丢失信息（layer、obsm、分类变量的顺序） | 转换校验写进 `_shared/convert.R` 的测试，覆盖 layer、嵌入和分类变量的水平顺序 |
| scvi-tools 迭代快、API 变动 | PACK X 节登记；显式参数规则；默认值漂移检查 |

## 附录 A：模块命名与 QC 前缀预分配（M0 时 grep 核对，避免重复）

| 模块 | QC 前缀 | 模块 | QC 前缀 |
|---|---|---|---|
| deseq2-qc | DQ | seurat-qc | SQ |
| scater-qc | XQ | scran-cluster | XC |
| batchelor-integrate | XI | scran-markers | XM |
| aucell-score | AU | slingshot-trajectory | SL |
| deseq2-wald | DW | seurat-cluster | SC |
| deseq2-lrt | DL | seurat-integrate | SI |
| edger-qlf | EQ | seurat-markers | SM |
| limma-voom | LV | seurat-modulescore | SS |
| limma-array | LA | singler-annotate | SA |
| limma-dupcor | LD | muscat-pseudobulk | MP |
| sva-batch | SB | speckle-propeller | SP |
| clusterprofiler-ora | CO | cellchat-communication | CC |
| clusterprofiler-gsea | CG | monocle3-trajectory | MT |
| clusterprofiler-compare | CX | wgcna-network | WG |
| fgsea-prerank | FG | maftools-landscape | MF |
| gsva-score | GV | immunedeconv-infiltration | ID |
| limma-camera | LC | omicstat（路由器） | — |

v1.1 新增（第十部分）：`scanpy-qc` YQ、`scanpy-cluster` YC、`scanpy-markers` YM、`scvi-integrate` VI、`scanvi-annotate` VA（已与 medstat 和上表核对，无冲突）。

（与 medstat 已占用的前缀比对：AG AW BT CM CPM CR DA DR HE IA IT LC MD ME MR NM NP PS RC RE RP SC SD SS TD TR TT。**冲突项在 M0 改名**：`LC`、`SC`、`SS`、`SA` 可能与 medstat 重名；omicstat 统一加 `O` 前缀，例如 `OLC-01`。）

## 附录 B：calls_registry.json 示例（结构说明，数值以 S1 冻结为准）

```json
{
  "module": "deseq2-wald",
  "package_versions": {"DESeq2": "<pkg_lock>", "apeglm": "<pkg_lock>"},
  "calls": [
    {"fn": "DESeq2::DESeq", "args": {
      "test": {"value": "Wald", "source": "vignette", "pack": "D-01"},
      "fitType": {"value": "parametric", "source": "pack_majority", "pack": "V-03"},
      "sfType": {"value": "ratio", "source": "pack_majority", "pack": "V-04"},
      "parallel": {"value": false, "source": "determinism", "pack": "LOCK-1"}}},
    {"fn": "DESeq2::results", "args": {
      "contrast": {"source": "user_required", "flag": "--contrast"},
      "alpha": {"source": "user_optional_default", "flag": "--alpha", "pack": "V-07"},
      "independentFiltering": {"value": true, "source": "vignette", "pack": "D-05"}}},
    {"fn": "DESeq2::lfcShrink", "args": {
      "type": {"value": "apeglm", "source": "pack_majority", "pack": "V-09"}}}
  ]
}
```
（示例中的具体取值与 PACK 小节号只是示意，以 S1 冻结结果为准，不得照抄进代码。）

## 附录 C：SKILL.md 骨架（由脚手架生成）

```markdown
---
name: deseq2-wald
description: >
  Run DESeq2's Wald-test differential expression with LFC shrinkage on an RNA-seq count matrix and
  produce the feature table, volcano/MA plots and a Methods/Results draft with numbers filled in.
  Use for two-group or single-contrast bulk RNA-seq comparisons. NOT for multi-group/time-course
  tests (use deseq2-lrt); NOT for microarrays (use limma-array); NOT for single-cell condition
  comparisons (use muscat-pseudobulk). Triggers: DESeq2, 差异表达, differential expression, lfcShrink, apeglm, 火山图 ...
---
# deseq2-wald
## When to use / when not
## Input requirements
## Run
### Via MCP
## What gets produced
## Reading the results
## When a QC rule fires
## Known limitations
## Reference files
```
