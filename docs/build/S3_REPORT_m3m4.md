# M3/M4 独立 S3 审查报告

审查基线：`d7355bec9aa73496eba8e2c548a55415455e0508`，分支 `s3/m3m4`。按 owner 的 slim 标准判定；只写 24 个审查文件、本报告和 lane worklog。未修改代码、golden、lock，未提交或推送；遵守 common UPDATE，由外部 helper 处理提交。所有运行均为非 root、无网络的 `docker run --rm`，suite 与 acceptance library 只读，结果存于 `/home/<user>/omic-sol61/s3_m3m4/`。

## 待裁决与安装边界

科学阈值、PC/HVG/邻居数量、分辨率、参考集、数据库及训练预算由调用者结合 `reference_advise` / `reference_search` 后选择，资料不足时问用户。没有以文献“多数值”设默认。AUCell 与 GSVA 的通用 router 选择仍需 owner 决策；指定 AUCell 的用户请求不能替代对基因集的选择。CIBERSORT 成功路径仍需用户合法提供源码与签名矩阵；本次不下载或分发签名，也不把拒绝测试当作其成功证据。

FAIL 模块不得进入 S5。PASS WITH NOTES 仅在各模块已声明的输入/科学范围内具备 S5 安装资格；本审查不执行安装。缺失五份参考文件、完整 QC catalogue 或全部打印值均不作为失败理由。

## 24 个模块结论

| 模块 | smoke / golden | lock --check | verdict | S5 | 关键判断 |
|---|---|---|---|---|---|
| [seurat-qc](../../acceptance/exemplars/seurat-qc/S3_REVIEW_m3m4.md) | PASS / PASS | OK | PASS WITH NOTES | 可 | 原生流程/结果通过；限定范围及文档备注见逐模块审查 |
| [seurat-cluster](../../acceptance/exemplars/seurat-cluster/S3_REVIEW_m3m4.md) | PASS / PASS | OK | FAIL | 不可 | FindClusters 初始分组、节点权重未开放 |
| [seurat-integrate](../../acceptance/exemplars/seurat-integrate/S3_REVIEW_m3m4.md) | PASS / PASS | OK | FAIL | 不可 | Harmony project.dim 未开放 |
| [seurat-markers](../../acceptance/exemplars/seurat-markers/S3_REVIEW_m3m4.md) | PASS / PASS | OK | FAIL | 不可 | contrast 路径没有传递 base |
| [seurat-modulescore](../../acceptance/exemplars/seurat-modulescore/S3_REVIEW_m3m4.md) | PASS / PASS | OK | PASS WITH NOTES | 可 | 原生流程/结果通过；限定范围及文档备注见逐模块审查 |
| [scater-qc](../../acceptance/exemplars/scater-qc/S3_REVIEW_m3m4.md) | PASS / PASS | OK | PASS WITH NOTES | 可 | 原生流程/结果通过；限定范围及文档备注见逐模块审查 |
| [scran-cluster](../../acceptance/exemplars/scran-cluster/S3_REVIEW_m3m4.md) | PASS / PASS | OK | PASS WITH NOTES | 可 | 原生流程/结果通过；限定范围及文档备注见逐模块审查 |
| [batchelor-integrate](../../acceptance/exemplars/batchelor-integrate/S3_REVIEW_m3m4.md) | PASS / PASS | OK | PASS WITH NOTES | 可 | 原生流程/结果通过；限定范围及文档备注见逐模块审查 |
| [scran-markers](../../acceptance/exemplars/scran-markers/S3_REVIEW_m3m4.md) | PASS / PASS | OK | PASS WITH NOTES | 可 | 原生流程/结果通过；限定范围及文档备注见逐模块审查 |
| [aucell-score](../../acceptance/exemplars/aucell-score/S3_REVIEW_m3m4.md) | PASS / PASS | OK | FAIL | 不可 | 科学基因集选择被限定为单一示例 GMT |
| [singler-annotate](../../acceptance/exemplars/singler-annotate/S3_REVIEW_m3m4.md) | PASS / PASS | OK | FAIL | 不可 | 动态原生参数与 Methods/图注不一致 |
| [muscat-pseudobulk](../../acceptance/exemplars/muscat-pseudobulk/S3_REVIEW_m3m4.md) | PASS / PASS | OK | PASS WITH NOTES | 可 | 原生流程/结果通过；限定范围及文档备注见逐模块审查 |
| [speckle-propeller](../../acceptance/exemplars/speckle-propeller/S3_REVIEW_m3m4.md) | PASS / PASS | OK | PASS WITH NOTES | 可 | 原生流程/结果通过；限定范围及文档备注见逐模块审查 |
| [slingshot-trajectory](../../acceptance/exemplars/slingshot-trajectory/S3_REVIEW_m3m4.md) | PASS / PASS | OK | PASS WITH NOTES | 可 | 原生流程/结果通过；限定范围及文档备注见逐模块审查 |
| [monocle3-trajectory](../../acceptance/exemplars/monocle3-trajectory/S3_REVIEW_m3m4.md) | PASS / PASS | OK | PASS WITH NOTES | 可 | 原生流程/结果通过；限定范围及文档备注见逐模块审查 |
| [cellchat-communication](../../acceptance/exemplars/cellchat-communication/S3_REVIEW_m3m4.md) | PASS / PASS | OK | PASS WITH NOTES | 可 | 原生流程/结果通过；限定范围及文档备注见逐模块审查 |
| [wgcna-network](../../acceptance/exemplars/wgcna-network/S3_REVIEW_m3m4.md) | PASS / PASS | OK | FAIL | 不可 | 多个影响结果的原生参数写死 |
| [maftools-landscape](../../acceptance/exemplars/maftools-landscape/S3_REVIEW_m3m4.md) | PASS / PASS | OK | FAIL | 不可 | TMB captureRegions 未开放 |
| [immunedeconv-infiltration](../../acceptance/exemplars/immunedeconv-infiltration/S3_REVIEW_m3m4.md) | PASS / PASS | OK | FAIL | 不可 | CIBERSORT absolute 算法参数不能传入 |
| [scanpy-qc](../../acceptance/exemplars/scanpy-qc/S3_REVIEW_m3m4.md) | PASS / PASS | FAIL | FAIL | 不可 | Scrublet 多个参数写死；锁失配 |
| [scanpy-cluster](../../acceptance/exemplars/scanpy-cluster/S3_REVIEW_m3m4.md) | PASS / PASS | FAIL | FAIL | 不可 | 引用教程未要求的强制 scale；参数缺口；锁失配 |
| [scanpy-markers](../../acceptance/exemplars/scanpy-markers/S3_REVIEW_m3m4.md) | PASS / PASS | FAIL | FAIL | 不可 | 缺原生 CSV 与比较参数；锁失配 |
| [scvi-integrate](../../acceptance/exemplars/scvi-integrate/S3_REVIEW_m3m4.md) | PASS / PASS | FAIL | FAIL | 不可 | 模型结构/训练选项缺口；锁失配 |
| [scanvi-annotate](../../acceptance/exemplars/scanvi-annotate/S3_REVIEW_m3m4.md) | PASS / PASS | FAIL | FAIL | 不可 | 训练/预测参数缺口；锁失配 |

审查计数：{'PASS WITH NOTES': 11, 'FAIL': 13}。全部 24 次最终 smoke 的 golden PASS；19 个 R lock OK，5 个 Python lock 失败。Python 完整只读 build 比较（正确设置 OMICSTAT_PY_IMAGE_ID）发现 `env/omicstat-env.json` 漂移，以及四个新合并 fig_mod_*.R 文件未列在旧 manifest；package/image environment 一致。环境定义是已授权 rebuild 的结果。不会因 smoke 通过而忽略锁失败。原始比较：`/home/<user>/omic-sol61/s3_m3m4/python_lock_diagnosis.json`。

可进入 S5 的模块：`seurat-qc`, `seurat-modulescore`, `scater-qc`, `scran-cluster`, `batchelor-integrate`, `scran-markers`, `muscat-pseudobulk`, `speckle-propeller`, `slingshot-trajectory`, `monocle3-trajectory`, `cellchat-communication`。

## 所有闭合修复清单

以下每项明确位置、修复动作和复验。保留原生参数名称以避免歧义；完整证据与实际 docker 命令见逐模块审查。每个新绑定均须同步更新 calls_registry、options 的 source key/none、reference-service 指引与实际 Methods 值。所有修复须在原 locked image 完成；不得放宽 tolerance 或静默替换 golden。

### seurat-cluster：FindClusters 初始分组、节点权重未开放

- `skills/seurat-cluster/scripts/seurat_cluster_core.R:7` — 开放 FindClusters 的 initial.membership、node.sizes，保留 locked NULL 默认并支持原生 JSON/RDS 输入。用小图的指定初始分组和节点权重对照直接原生调用，再运行 smoke/golden/lock。
- `skills/seurat-cluster/scripts/seurat_cluster_core.R:4` — 开放 mean.function、dispersion.function 以及 SCTransform 的 reference.SCT.model、residual.features，提供文档化的原生函数名称/RDS 绑定并保留 locked 默认。分别验证替代 HVG 函数和提供的 SCT reference/residual features 与原生结果一致，再复验 smoke/lock。

### seurat-integrate：Harmony project.dim 未开放

- `skills/seurat-integrate/scripts/seurat_integrate_core.R:9` — 开放 RunHarmony project.dim，默认保留 locked TRUE。分别验证 TRUE/FALSE 的原生 loading 输出，更新 options/registry，复验 smoke/lock。

### seurat-markers：contrast 路径没有传递 base

- `skills/seurat-markers/scripts/seurat_markers_core.R:8` — contrast 分支也必须绑定 base；当前 --markers-base 只进入 all 模式。默认保持 2，补齐 registry/options；以 base=exp(1) 对照原生 FindMarkers 的 effect 列，再复验 smoke/lock。
- `skills/seurat-markers/scripts/seurat_markers_core.R:6` — 开放 FindAllMarkers 固定为 NULL 的 mean.fxn，并在适用的 contrast 路径绑定同一原生参数。使用文档化原生函数名或 RDS callable，默认 NULL；与直接 FindAllMarkers/FindMarkers 对照值和列语义，再复验严格 golden/lock。

### aucell-score：科学基因集选择被限定为单一示例 GMT

- `skills/aucell-score/scripts/aucell_score_core.R:6` — 把单一示例 GMT 的 SHA 限制改为明确必填的用户离线基因集、来源与许可声明，继续阻止 GT103 禁止集合。保留合法示例作 smoke fixture；用两个允许的自定义 GMT 验证原生 AUCell 一致，再复验 golden/lock。

### singler-annotate：动态原生参数与 Methods/图注不一致

- `skills/singler-annotate/scripts/singler_annotate_report.R:12` — core 返回实际 resolved SingleR/pruneScores 参数，Methods/results/caption 使用这些值，而非 a$quantile、a$de-method、a$nmads。fig_mod_sc_backend.R:14/:20 应接收实际 min.diff.med/min.diff.next，不固定 -Inf/0。以 quantile=.5、prune-min-diff-next=.05 验证原生结果与生成文字/spec 同时一致，再复验 smoke/lock。

### wgcna-network：多个影响结果的原生参数写死

- `skills/wgcna-network/scripts/wgcna_network_core.R:42` — 开放目前写死的原生控制项：goodSamplesGenes 的 minFraction/minNSamples/minNGenes/tol/minRelativeWeight/weights；pickSoftThreshold 的 RsquaredCut/removeFirst/nBreaks/corFnc/corOptions/weights；blockwiseModules 的 corType/maxPOutliers/quickCor/pearsonFallback/cosineCorrelation/TOMDenom/replaceMissingAdjacencies/suppressTOMForZeroAdjacencies/suppressNegativeTOM/detectCutHeight/pamStage/minCoreKME/minCoreKMESize/minKMEtoStay/impute；moduleEigengenes 的 impute/nPC/align/excludeGrey/subHubs/scale；cor 的 method/use/weights/cosine。用文档化原生参数绑定，保留 locked 默认或已引用教程值，并在 Methods 记录实际值。验证 bicor/Pearson 及 TOMDenom 替代配置与原生调用一致，再复验完整官方 anchor/lock。
- `skills/wgcna-network/scripts/wgcna_network_core.R:131` — 开放 trait-correlation 的 p.adjust method，保留原生未调整 p_value，并说明额外探索性调整的 family/method。验证 BH 与 none 对应 stats::p.adjust 的值及 Methods/caption，再复验 smoke/lock。

### maftools-landscape：TMB captureRegions 未开放

- `skills/maftools-landscape/scripts/maftools_landscape_core.R:12` — 开放 tmb 的 captureRegions，按原生 Rd 作为 captureSize 的互斥 callable-territory 输入；Methods/provenance 记录实际区域文件来源与 hash。用本地区域子集对照 maftools::tmb 的改变，保持全部原生变异/汇总，再复验 smoke/lock。

### immunedeconv-infiltration：CIBERSORT absolute 算法参数不能传入

- `skills/immunedeconv-infiltration/scripts/immunedeconv_infiltration_core.R:24` — 提供 method-specific 原生参数绑定，至少开放当前无法传入的 CIBERSORT abs_method（locked sig.score），继续要求用户源码、矩阵与 licence acknowledgement。Methods/options 记录实际值；以合法用户授权的本地 stub/interface fixture 验证两种 absolute 算法参数转发，并保留拒绝测试及八种离线方法 golden。不能把接口测试称为合法 CIBERSORT 生物学成功验证。

### scanpy-qc：Scrublet 多个参数写死；锁失配

- `skills/scanpy-qc/scripts/scanpy_qc_core.py:50` — 开放 Scrublet 的 sim_doublet_ratio、stdev_doublet_rate、synthetic_doublet_umi_subsampling、knn_dist_metric、normalize_variance、log_transform、mean_center、use_approx_neighbors、n_neighbors，保留 locked 默认，记录实际值。至少以替代 sim_doublet_ratio 与距离度量对照原生调用，再复验 score/filter anchor golden。
- `skills/scanpy-qc/module_lock.json:15` — 在最终授权环境定义与模块修复通过验证后重新封锁。正确设置 OMICSTAT_PY_IMAGE_ID 的独立 --check 仍报 OS_LOCK_MISMATCH：环境定义 hash 漂移、四个新合并 fig_mod_*.R 文件未列入旧 manifest。复验 locked smoke/golden，再 make_module_lock.py --check → OK；不能为掩盖锁漂移修改数值 golden。

### scanpy-cluster：引用教程未要求的强制 scale；参数缺口；锁失配

- `skills/scanpy-cluster/scripts/scanpy_cluster_core.py:38` — 将 scale 改为明确的工作流选项，引用教程的参考默认路径不应强制添加 scale。相同 anchor 上对照教程原生 PCA/graph/labels；单独保留显式 scaled 分支并验证原生一致与 caption，不能通过放宽 tolerance 隐藏差异。
- `skills/scanpy-cluster/scripts/scanpy_cluster_core.py:28` — 开放 normalize_total 的 exclude_highly_expressed/max_fraction、log1p base、HVG flavor/span/n_bins、scale zero_center、PCA solver/zero_center/dtype、neighbors method/metric/metric_kwds/transformer、Leiden n_iterations/use_weights/partition_type、UMAP spread/maxiter/alpha/gamma/negative_sample_rate/init_pos/a/b。逐函数绑定原生参数，保留 locked 默认并记录 resolved 值。用替代 HVG flavor、metric、Leiden iterations 对照原生调用，再复验 golden/lock。
- `skills/scanpy-cluster/module_lock.json:15` — 在最终授权环境定义与模块修复通过验证后重新封锁。正确设置 OMICSTAT_PY_IMAGE_ID 的独立 --check 仍报 OS_LOCK_MISMATCH：环境定义 hash 漂移、四个新合并 fig_mod_*.R 文件未列入旧 manifest。复验 locked smoke/golden，再 make_module_lock.py --check → OK；不能为掩盖锁漂移修改数值 golden。

### scanpy-markers：缺原生 CSV 与比较参数；锁失配

- `skills/scanpy-markers/scripts/scanpy_markers_core.py:32` — 开放 rank_genes_groups 的 reference/groups/mask_var/rankby_abs/corr_method/tie_correct/n_genes；不能将全部比较永久固定为 all-versus-rest、BH、无 tie correction。文档未决定的科学比较须显式选择。用 tie-corrected Wilcoxon 与指定 reference 对照原生调用，再复验 golden/lock。
- `skills/scanpy-markers/scripts/scanpy_markers_core.py:44` — 另外保存 sc.get.rank_genes_groups_df 原生 CSV，保留 names/scores/logfoldchanges/pvals/pvals_adj 及原生顺序。当前 marker_details 只是重复的 suite 重命名表。对照原生 dataframe 的列、值、顺序并继续保留 AnnData uns。
- `skills/scanpy-markers/module_lock.json:15` — 在最终授权环境定义与模块修复通过验证后重新封锁。正确设置 OMICSTAT_PY_IMAGE_ID 的独立 --check 仍报 OS_LOCK_MISMATCH：环境定义 hash 漂移、四个新合并 fig_mod_*.R 文件未列入旧 manifest。复验 locked smoke/golden，再 make_module_lock.py --check → OK；不能为掩盖锁漂移修改数值 golden。

### scvi-integrate：模型结构/训练选项缺口；锁失配

- `skills/scvi-integrate/scripts/scvi_integrate_core.py:39` — 开放 setup 的 categorical/continuous covariates、size_factor_key；constructor 的 n_hidden/n_layers/dropout_rate/dispersion/gene_likelihood/use_observed_lib_size/latent_distribution；train 的 train_size/validation_size/shuffle_set_split/early_stopping/plan_kwargs/datasplitter_kwargs；neighbors metric/method 及 UMAP spread/初始化/优化参数。locked 默认可保留，但必须能复现引用教程 n_layers=2、gene_likelihood=nb。记录实际模型与训练设置；同一小 fixture 验证两种原生结构（包括教程结构），再复验 smoke/golden/lock，继续声明有限验证范围。
- `skills/scvi-integrate/module_lock.json:15` — 在最终授权环境定义与模块修复通过验证后重新封锁。正确设置 OMICSTAT_PY_IMAGE_ID 的独立 --check 仍报 OS_LOCK_MISMATCH：环境定义 hash 漂移、四个新合并 fig_mod_*.R 文件未列入旧 manifest。复验 locked smoke/golden，再 make_module_lock.py --check → OK；不能为掩盖锁漂移修改数值 golden。

### scanvi-annotate：训练/预测参数缺口；锁失配

- `skills/scanvi-annotate/scripts/scanvi_annotate_core.py:47` — 开放 train_size/validation_size/shuffle_set_split/adversarial_classifier/plan_kwargs/datasplitter_kwargs 和 predict use_posterior_mean，保留 locked 默认并在 Methods/registry/options 记录实际值。用不同 split/prediction setting 对照真实、已 hash 验证的 upstream native SCANVI，再复验 golden/lock 与模型文件损坏拒绝测试。
- `skills/scanvi-annotate/module_lock.json:15` — 在最终授权环境定义与模块修复通过验证后重新封锁。正确设置 OMICSTAT_PY_IMAGE_ID 的独立 --check 仍报 OS_LOCK_MISMATCH：环境定义 hash 漂移、四个新合并 fig_mod_*.R 文件未列入旧 manifest。复验 locked smoke/golden，再 make_module_lock.py --check → OK；不能为掩盖锁漂移修改数值 golden。

## 跨模块链及交接证据

Seurat：实际 seurat-qc → seurat-cluster → seurat-markers / seurat-modulescore；Harmony 接实际 Seurat 聚类输出，RNA 表达保持。Bioconductor：实际 scater-qc → scran-cluster → scran-markers；batchelor 的 corrected reduction 与原始表达层分离。scran-markers 首次隔离 scratch 未找到已完成 upstream，因此记录了 harness 失败；重新挂载真实 scran-cluster 输出后运行其原 smoke，初始日志保留为 `smoke.initial.log`。

为区分“手写 handoff fixture”与真实 producer，下列补充链实际调用 producer 再运行 consumer。CellChat 官方输入只有 logcounts，scater-qc 正确拒绝；随后使用已执行的 CellChat producer 输出再交接，未伪造 raw counts。QC 的诊断性 permissive thresholds 全部显式设置；第一特征作为 carrier subset，不能解释为生物学线粒体鉴定。消费者推断仍用其官方 anchor assays/embeddings。

| 消费者 | 实际 producer | 运行结果 / 原生表相等 |
|---|---|---|
| aucell-score | real scater-qc producer, explicit permissive diagnostic thresholds (first feature is a carrier subset, not a mitochondrial biological claim) | `{"exits": [0, 0, 0], "table": "tables/scores.csv", "native_anchor_bytes_equal": true, "upstream": "real scater-qc producer, explicit permissive diagnostic thresholds (first feature is a carrier subset, not a mitochondrial biological claim)", "consumer": "/home/<user>/omic-sol61/s3_m3m4/aucell-score/real_chain/consumer/tables/scores.csv"}` |
| singler-annotate | real scater-qc producer, explicit permissive diagnostic thresholds (first feature is a carrier subset, not a mitochondrial biological claim) | `{"exits": [0, 0, 0], "table": "tables/annotations.csv", "native_anchor_bytes_equal": true, "upstream": "real scater-qc producer, explicit permissive diagnostic thresholds (first feature is a carrier subset, not a mitochondrial biological claim)", "consumer": "/home/<user>/omic-sol61/s3_m3m4/singler-annotate/real_chain/consumer/tables/annotations.csv"}` |
| muscat-pseudobulk | real scater-qc producer, explicit permissive diagnostic thresholds (first feature is a carrier subset, not a mitochondrial biological claim) | `{"exits": [0, 0, 0], "table": "tables/differential.csv", "native_anchor_bytes_equal": true, "upstream": "real scater-qc producer, explicit permissive diagnostic thresholds (first feature is a carrier subset, not a mitochondrial biological claim)", "consumer": "/home/<user>/omic-sol61/s3_m3m4/muscat-pseudobulk/real_chain/consumer/tables/differential.csv"}` |
| speckle-propeller | real scater-qc producer, explicit permissive diagnostic thresholds (first feature is a carrier subset, not a mitochondrial biological claim) | `{"exits": [0, 0, 0], "table": "tables/differential.csv", "native_anchor_bytes_equal": true, "upstream": "real scater-qc producer, explicit permissive diagnostic thresholds (first feature is a carrier subset, not a mitochondrial biological claim)", "consumer": "/home/<user>/omic-sol61/s3_m3m4/speckle-propeller/real_chain/consumer/tables/differential.csv"}` |
| slingshot-trajectory | real scater-qc producer, explicit permissive diagnostic thresholds (first feature is a carrier subset, not a mitochondrial biological claim) | `{"exits": [0, 0, 0], "table": "tables/pseudotime.csv", "native_anchor_bytes_equal": true, "upstream": "real scater-qc producer, explicit permissive diagnostic thresholds (first feature is a carrier subset, not a mitochondrial biological claim)", "consumer": "/home/<user>/omic-sol61/s3_m3m4/slingshot-trajectory/real_chain/consumer/tables/pseudotime.csv"}` |
| monocle3-trajectory | real scater-qc producer, explicit permissive diagnostic thresholds (first feature is a carrier subset, not a mitochondrial biological claim) | `{"exits": [0, 0, 0], "table": "tables/pseudotime.csv", "native_anchor_bytes_equal": true, "upstream": "real scater-qc producer, explicit permissive diagnostic thresholds (first feature is a carrier subset, not a mitochondrial biological claim)", "consumer": "/home/<user>/omic-sol61/s3_m3m4/monocle3-trajectory/real_chain/consumer/tables/pseudotime.csv"}` |
| cellchat-communication | actual CellChat anchor producer -> CellChat consumer; hash-verified saved SCE with native logcounts | `{"exits": [0, 0], "upstream": "actual CellChat anchor producer -> CellChat consumer; hash-verified saved SCE with native logcounts", "native_anchor_bytes_equal": true, "table": "tables/communication.csv", "scope": "The official skin input has normalized expression only; attempted scater-qc producer correctly refused absent raw counts. No invented count assay was added. Both attempts and commands retained.", "ecosystem": "bioconductor front_end_ecosystem; neutral backend"}` |
| wgcna-network | real limma-array with unchanged complete-feature subset of normalized-array input; artificial groups for transport only | `{"exits": [0, 0, 0], "upstream": "real limma-array with unchanged complete-feature subset of normalized-array input; artificial groups for transport only", "n_features": 145, "native_anchor_bytes_equal": true, "scale": "normalized_array", "ecosystem": "neutral", "initial_refusal": "limma correctly refused 163 missing values; original attempt log retained"}` |

M4 的 maftools 用自身真实 MAF producer → consumer，immunedeconv 用真实 infiltration producer 保存的 expression → consumer，两者 smoke 逐表 hash 相等。WGCNA 的补充 limma-array producer 仅用人工平衡组验证传输，先显式剔除含 missing 的特征，145 个完整特征的网络仍基于原始 normalized_array 表达和真实 other_fat trait，并与相同完整子集的直接运行比较；不能把此人工分组解释为差异表达生物结论。

Python smoke 调用了实际 QC/cluster/scVI 上游，然后 marker/scVI/scANVI 消费；counts、模型文件和 features 顺序在 handoff 中 hash 验证。scVI embedding 修正不改变表达或已有 cluster labels。混用 ecosystem 及损坏 hash/lineage 的拒绝见 smoke 日志。真实 opposite frontend 补充命令和输出：`seurat-cluster/mixed_frontend.command.json` / `.log` 与 `scran-cluster/mixed_frontend.command.json` / `.log`。两个方向都须报告 OS_ECOSYSTEM_MIXED。

全部补充运行命令、exit 和日志均位于 lane scratch 对应模块；`real_chain_*.command.json`、`real_chain.status.json`、`render_*.command.json`、`render_summary.json` 是可重放审计证据。

## Owner 指定已知问题

- **seurat-markers**：7023 vs 旧打印 7019、IL32 1.324556 vs 1.3070772 均公开。锁定当前包的直接 native replay 一致；没有放宽阈值。最终 presto baseline 在授权 rebuild 后 PASS。此差异可接受，模块 FAIL 来自 contrast base 的独立接口缺口。
- **CellChat**：默认 presto 与显式 do.fast=FALSE/Wilcoxon 分支分别 sealed 与 PASS；没有拿一个分支的 golden 覆盖另一个。raw.use=FALSE 的不支持情形明确拒绝，圈图等节点与省略自环均在 caption 说明，原生网络保留自环。
- **SingleR**：重建 scrapper 后，pancreas 官方路径 1718 cells、59 pruned、1659 assigned 与十类打印计数通过；依赖问题已解决。FAIL 是 override 后生成 Methods/图注没有用实际 resolved 参数，详见补充 override 证据。
- **immunedeconv**：8 个离线方法均实际执行并逐方法 native replay/golden PASS。EPIC licence acknowledgement 必须明确；CIBERSORT/abs 需要合法用户文件。fraction、percent、score、purity 不混用；score 热图明确 within-row z-score，原生表保持原尺度。FAIL 来自不可传入的 CIBERSORT abs_method；不是因未获得受限文件而要求非法下载。
- **scVI/scANVI**：96×160、两批次、两 epochs 的官方 synthetic_iid fixture 足以验证工程运行/序列化/模型交接，不能验证真实队列收敛、batch removal 或标签准确率。reload native model 的再推断不是独立训练。小 fixture 范围如实说明，可接受作为 smoke；参数与锁问题仍阻止 S5。

## 图、Methods 与参考映射

生成 PNG 总数 256，不同 SHA256 内容 146；全部已打开（重复字节共享一次视觉检查）。索引 `/home/<user>/omic-sol61/s3_m3m4/visual/inventory.json` 保存所有路径、sheet、尺寸、opened 和观察。Python 每个成功 run 的 figure_request 另在最终 R image 渲染；所有 render exit 见 `render_summary.json`。图采用 suite 的现有 builders/theme/palette/finalizer，caption 在 figure_spec.json；没有要求图内重复整段图注。高密度 WGCNA 3600-leaf 树是社区原生信息密度，small subset 另可读；没有误称稠密树为空白。

所有 references/options.md 的 non-none key 均在对应 S0 extraction.jsonl 存在；每模块 scratch `.static.json` 保存验证结果。引用 locked defaults、教程和 S0 §3/4.3 修正，未把 α 版 scverse PACK 当作 1.12.4 证据。实际 Methods/结果版本与参数检查、原生对象和表的保留情况见各审查；SingleR 的参数报告不一致以及 scanpy-markers 的 native CSV 缺口已明确列为修复。

## 变更与未完成项

共享代码变更：无。代码、golden、lock 变更：无。提交：遵循 common UPDATE，不执行 git commit，不绕过只读 .git。GT103 禁止的容器管理、sudo、受限数据下载和其他 lane 写入：无。

本 lane 的 24 模块独立审查、闭合修复清单、补充链、全部 PNG 视觉检查和中文报告已完成。FAIL 项留给 builder 修复并重新申请 S3；本 lane 不修 builder 代码，不执行 S5。
