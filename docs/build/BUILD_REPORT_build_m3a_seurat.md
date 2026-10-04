# build_m3a_seurat 构建报告

## 需要所有者裁决 / 待裁决

- 每个研究的 QC 创建/保留阈值、物种/线粒体标识、LogNormalize 或 SCTransform 路线、HVG/PC/邻居数、聚类 resolution、整合方法和批次变量均由调用方明确选择；不由本车道把论文出现频次转成默认值。SKILL 对科学选择要求先查 reference_advise/reference_search；options.md 列出锁定默认值、教程示例和真实 S0 parameter 键。
- marker 检验/比较、assay、筛选与展示规则、基因集成员/来源/物种、控制基因背景由调用方选择。没有通用 module-score 阈值，未自动标准化或作条件推断；后者交给 muscat-pseudobulk。
- S0_REDO_lane_a 的 38110959（Slide-seq 珠粒）证据适用范围仍是 owner/验证员问题；本车道没有据此扩展空间分析范围。Cell-cycle 教程用 cc.genes，不能静默换成 cc.genes.updated.2019。
- marker 旧教程打印数值与当前锁定执行存在差异（见下），交独立 S3 复核；没有提高容差或修改原证据。

## 各模块状态、锚点与验证

本次遵循 2026-10-01 SLIM BUILD 覆盖条款；保留重启前已经工作的 QC/cluster 模块，没有从头重建。所有 R 执行、golden 和 module_lock 均在 `omicstat-r:2026.09.1`；Seurat 5.5.1、SeuratObject 5.4.0、harmony 2.0.5。每个入口保留原生 Seurat RDS、原生结果表 CSV、交接状态/生态/散列、provenance、简短 Methods 和套件风格图。五个模块均有独立 S3_REQUEST（含执行方法、结果位置、局限、router 行与出版规则建议）。没有进行 S3 验收或 S5 安装。

### seurat-qc

S2 完成，待独立 S3。重启前 qc_slim.log 记录 19 项 PASS：PBMC 教程 2700 细胞、CreateSeuratObject 后 13714 基因、首细胞 2419 counts/779 features/3.0177759% mito，严格 QC 原生复算、旗标效果、错误、spec 表/PNG 确定性和 golden。来源：PACK C，锁定 Seurat PBMC3k 教程 QC 节。重启后真实下游链再次执行 QC；前一完成状态保留。

Harmony packaged pbmc_stim 没有 MT- 基因，增加显式 `--missing-mito error|zero`，默认仍拒绝；zero 是用户明确选择不测该指标，图注/状态记录匹配特征数，不宣称测得质量良好。已刷新锁。九个原始 anchor/replay/alternate PNG 已在原 worklog 审图；本次各新链 QC 图亦已打开。输出 `qc_anchor/`，主表 cell_qc/filter_flow。

### seurat-cluster

S2 完成，待独立 S3。原 smoke 再现锁定 PBMC 教程 2638 nodes、95927 无向 SNN edges、9 communities、2000 HVG/50 PC；PCA 与簇标签原生复算一致，真实 QC handoff 和 golden PASS。来源：PACK C，PBMC3k 教程聚类节。输出 `cluster_anchor/`，主表 clusters/hvg/pca_stdev。

本次补齐纯 accessor 的 registry 声明（VariableFeatures/Embeddings/Stdev），不改变数值代码。六个既有 PNG 已审图；新 marker/score 链中的 cluster/sample UMAP 和 elbow 另行审图。SCTransform 为明确可选路线；PBMC 打印锚点覆盖 LogNormalize，不能把它解释成全部路线验收。

### seurat-integrate

S2 完成，待独立 S3。PACK C 的原始 pbmc_stim RData SHA256 校验；真实 QC→cluster→integration，教程打印 2000 cells、原生 2000×20 Harmony reduction、RunHarmony 原生复算（1e-8）和 raw counts 保留全部 PASS；两个官方入口 RunHarmony 和 IntegrateLayers(HarmonyIntegration) 都跑通。当前 RunHarmony 观察值为 10 communities/85396 无向 edges，不冒充旧版本打印锚点。来源：锁定 harmony Seurat.Rmd、Seurat v5 layer integration 文档。

Harmony2 generic 依赖首参数 dispatch，修正为 object 首位；JoinLayers 参数显式登记。自定义 layer reduction 名已贯穿邻域图/簇/UMAP/状态；默认 Harmony embeddings 与已有 anchor 一致。整合只改变 reduction，RNA counts 保留。Layer 路线限 RNA/LogNormalize；SCT 可选 RunHarmony。

golden 主表 harmony/batch_clusters；输出 `integrate_anchor/`、`integrate_layers/`，日志 integrate_smoke.log、integrate_options.log。八个 integration PNG（两路线各 before/after batch、cluster、sample UMAP）及六个 upstream PNG 已打开，非空、可读、无裁切。所有图经 suite finalizer/lint，metadata 图注写明 n/实际参数。

### seurat-markers

S2 完成，待独立 S3。真实 QC→cluster→markers，PBMC 2638 cells/9 clusters，完整 FindAllMarkers table 原生复算、FindMarkers(ident.1=2) 基因与 log2FC 原生复算、golden 和 handoff PASS。保留原生列与顺序；只将 separate display 表另存。对比支持逗号分隔身份（教程 ident-2=0,3）。

当前 11648 返回行，其中 log2FC>1 为 7023，旧 rendered 教程打印 7019；cluster-2 top5 仍为 IL32/LTB/CD3D/IL7R/LDHB，但 IL32 log2FC 当前 1.324556、旧打印 1.3070772。wrapper 与锁定原生调用一致，旧页面依赖与当前执行是否一致尚不能确定；按 slim 指令记录，不耗时重建旧依赖、不放宽容差。norm.method 在 FindMarkers.Seurat 内由历史推导，不能重复透传，已删除不合法 CLI override。

十个链 PNG 已打开：两条 marker 路线 dotplot/heatmap 共四图，加 upstream 六图。DotPlot 数据按 Seurat 的 log1p(mean(expm1(data))) 和逐基因缩放；热图为选中且 native scale.data 存在基因的簇均值（部分基因不在 upstream HVG scale.data 中，输出解释明确）。绘图可读、无裁切。输出 `markers_anchor/`、`markers_contrast/`；最终退出成功日志 markers_final.log。所有替代检验/SCT/自定义控制不是 PBMC anchor 已验证路线，包错误按原生捕获。

### seurat-modulescore

S2 完成，待独立 S3。PACK C Nestorowa 原档 SHA256 校验，774 cells/24193 features 的真实 QC→cluster→score 链；11 项 smoke PASS。教程打印 Prog_013 counts=2563089/features=10211 均硬断言通过。直接 AddModuleScore 与 CellCycleScoring underlying scores 精确一致；spec replay 的 module_scores.csv 逐字节一致，golden PASS。首细胞 S=-0.1424869076321628、G2M=-0.4680395233793241，与旧打印 -0.14248691/-0.4680395 在原打印精度一致（另行验证，没有增宽容差）。

教程 cc.genes 的 S=43/G2M=54，实际匹配 41/54；MLF1IP/GMNN 由原生函数警告缺失，gene_sets.csv 和 engine_warnings 保留。锚点显式 ctrl=43、nbin=24、seed=1（CellCycleScoring 的 control 规则）；直接 AddModuleScore 的 CLI ctrl 默认仍为锁定 100，suite seed 默认仍为 20260925。没有把细胞周期 wrapper 参数混为 direct function 默认值。读入调用方 GMT；原生对象 metadata 列 Cluster1/Cluster2、wide/long score CSV 与集合清单保留。另加的聚类步骤只用于真实 chain/图，不改用于 scoring 的 normalized RNA。

十四个 chain/replay PNG 已打开：两套 S/G2M raw-score violin 和 signed-score UMAP 共八张，加 upstream 六张，非空、清晰、无裁切。没有 score cutoff、标准化或 condition test。k/自定义 pool/其他 slot 为显式原生选项，锚点不覆盖所有组合；HGNC search 固定 FALSE 满足离线约束。输出 score_anchor/、score_replay/；日志 score_smoke.log，主 golden 为 tables/module_scores.csv。

## 共享代码修改

仅新增/维护本车道拥有的 `skills/_shared/scripts/sc_seurat_io.R` 与 `fig_mod_sc_seurat.R`：Seurat I/O、真实 single-cell chain state、原生表/对象保存、handoff/provenance、conversion 对 convert.R 的显式委托；QC/UMAP/elbow/integration/marker/score 图均走 fig_style/现有 builders/finalizer。科学分析只封装社区包函数，没有重写算法。没有修改其他 lane helper、args、handoff、convert、module_kit、figure 基础层、Python helper、router、method_map、run_tests 或 publication registry。所有 router/出版条目仅在 S3_REQUEST 建议。

## 机械检查、记录与偏离

五模块 calls_registry 一致性、锁定 formals drift、check_flag_docs（22/81/68/42/16 个旗标）、check_defaults 和 lint_r 均通过；每个模块的 golden 与 make_module_lock --check PASS。最终日志 final_audit.log、final_locks.log、static_checks.log；源码与报告通过外部定时 helper 提交，按 00:20 覆盖条款没有尝试 git commit 或绕过只读 .git，没有 push。

保持全部原始锚点/证据只读；复制已有下载，没有重新下载、安装包或调用参考服务容器。偏离：marker 测试运行中修改文件曾引发 R 流式读取末尾语法错误，改为 source 一次解析整份测试后重跑，最终运行成功；启动时合并阅读文本曾暂放 /tmp，已移入车道 scratch 并清理该临时路径。其余偏离：无。

未做：独立 S3、S5、跨平台/全部替代路线验收，均按本任务范围留给协调者；没有用构建成功冒充独立验收。主表/PNG 位于 `/home/<user>/omic-sol61/build_m3a_seurat/`，每模块工作日志在本 worktree 的 acceptance/exemplars/<module>/build_worklog.md，lane 日志在 docs/build/build_m3a_seurat_worklog.md。
