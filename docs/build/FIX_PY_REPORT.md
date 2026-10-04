# Python 五模块 S4 修复报告

本 lane 按 fin_fix_py.md 的封闭修复清单完成，不修改 vendor、环境定义或其他模块。Python 使用 omicstat-py:2026.09.1，OMICSTAT_PY_IMAGE_ID=sha256:dedf331e03f3832cbd069bd3c75af3ac1a6f4f1daf88eea6f72204a3b114b96f，固定 seed 和线程；R 使用 omicstat-r:2026.10.1。所有容器非 root、--rm、--network none。运行日志和前后比较存于 `/home/<user>/omic-sol61/fix_py/`。未执行 git commit；提交由外部 helper 按 lane worklog 完成。

## scanpy-qc

Scrublet 九个原先固定的参数：已关闭。score/filter 与默认及替代 Scrublet 的分数和判定直接复算；替代值包含 sim_doublet_ratio=1.5、manhattan 距离及非默认布尔选项；filter 保留细胞与 score 的 predicted_doublet 完全对应。
generate_golden.sh 第 1 次全部通过（numeric smoke、golden、第二次 smoke、seal、check）；日志 `scanpy-qc-generate-1.log`。
generate_golden.sh 第 2 次全部通过（numeric smoke、golden、第二次 smoke、seal、check）；日志 `scanpy-qc-generate-2.log`。
Golden：全部 CSV 与修复前逐字一致，数值未变。 golden 精确层 CSV 改变/新增：无；golden numeric.npz 中超出原有 tolerance 的字段：无。完整逐字段前后比较见 `/home/<user>/omic-sol61/fix_py/golden_comparison.json`。
图形：在 R 镜像渲染 6 个请求，全部 exit 0；已打开 6 张 PNG（2 个 SHA256 内容；相同内容去重），visual sheets [1]。非空，标签可读、不裁切；caption/spec 记录细胞/基因/样本数及参数。渲染命令和日志见 `/home/<user>/omic-sol61/fix_py/render_inventory.json`；逐 PNG 索引见 `visual/inventory.json`。
module_lock scanpy-qc: OK (66 files)

## scanpy-cluster

缩放显式选项，教程默认不强制缩放：已关闭。默认 scale=off 和显式 scale=on 分别直接复算 PCA、距离图、连接图、Leiden 标签和 UMAP；替代组合另验证 cell_ranger、minkowski/gauss、Leiden iterations/weights/partition 与 UMAP 优化参数。
normalize/log1p/HVG/scale/PCA/neighbors/Leiden/UMAP 全部封闭清单参数：已关闭。所有原生参数从已解析值传入；flag、锁定默认值、registry、S0 key 和实际参数记录均保留。
generate_golden.sh 第 1 次全部通过（numeric smoke、golden、第二次 smoke、seal、check）；日志 `scanpy-cluster-generate-1.log`。
generate_golden.sh 第 2 次全部通过（numeric smoke、golden、第二次 smoke、seal、check）；日志 `scanpy-cluster-generate-2.log`。
Golden：去掉强制 scale，PCA solver/neighbor metric 改为已核对的锁定 None 分发，故 PCA/方差、邻居图、聚类/UMAP 改变；HVG 不变，保留显式 scaled 分支。 golden 精确层 CSV 改变/新增：cell_metadata.csv, pca_variance.csv；golden numeric.npz 中超出原有 tolerance 的字段：cell_metadata__x, cell_metadata__y, pca__PC1, pca__PC10, pca__PC2, pca__PC3, pca__PC4, pca__PC5, pca__PC6, pca__PC7, pca__PC8, pca__PC9。完整逐字段前后比较见 `/home/<user>/omic-sol61/fix_py/golden_comparison.json`。
600 细胞默认聚类：修复前 {'0': 226, '1': 149, '2': 138, '3': 73, '4': 14}（5 簇）；修复后 {'0': 156, '1': 114, '2': 92, '3': 81, '4': 58, '5': 57, '6': 42}（7 簇）。
图形：在 R 镜像渲染 9 个请求，全部 exit 0；已打开 14 张 PNG（9 个 SHA256 内容；相同内容去重），visual sheets [1, 2, 3]。非空，标签可读、不裁切；caption/spec 记录细胞/基因/样本数及参数。渲染命令和日志见 `/home/<user>/omic-sol61/fix_py/render_inventory.json`；逐 PNG 索引见 `visual/inventory.json`。 默认与 scaled 分支的 caption 分别明确 scale=off/on。
module_lock scanpy-cluster: OK (67 files)

## scanpy-markers

reference/groups/mask_var/rankby_abs/corr_method/tie_correct/n_genes：已关闭。默认与 named_reference 路径直接复算；后者 Wilcoxon、命名参考组、highly_variable mask、rankby_abs=True、bonferroni、tie_correct=True、n_genes=25。
保留原生 dataframe 的列、值和排序：已关闭。原生 CSV 与直接 sc.get.rank_genes_groups_df 的列顺序、行顺序、数值逐一比较；原生 AnnData uns 与 suite feature_table 同时保留。
协调员 02:10 Methods/Results 参数化措辞：已关闭。正文从解析后的参考组、groups、mask、排序、校正、tie 与 n_genes 填入；默认及命名参考分支 smoke 检查正文，禁用旧固定 BH/remaining-cells 说法；n_clusters 按实际 tested groups 统计。
generate_golden.sh 第 1 次全部通过（numeric smoke、golden、第二次 smoke、seal、check）；日志 `scanpy-markers-generate-1.log`。
generate_golden.sh 第 2 次全部通过（numeric smoke、golden、第二次 smoke、seal、check）；日志 `scanpy-markers-generate-2.log`。
Golden：新原生 CSV 是新增交付物；上游默认 cluster 不再强制 scale，聚类数/成员改变，故 marker/feature/dot 表随之改变；marker 默认检验仍为锁定默认。 golden 精确层 CSV 改变/新增：feature_table.csv, marker_details.csv, marker_dot_data.csv, rank_genes_groups_native.csv；golden numeric.npz 中超出原有 tolerance 的字段：无。完整逐字段前后比较见 `/home/<user>/omic-sol61/fix_py/golden_comparison.json`。
图形：在 R 镜像渲染 9 个请求，全部 exit 0；已打开 13 张 PNG（6 个 SHA256 内容；相同内容去重），visual sheets [1, 3, 4]。非空，标签可读、不裁切；caption/spec 记录细胞/基因/样本数及参数。渲染命令和日志见 `/home/<user>/omic-sol61/fix_py/render_inventory.json`；逐 PNG 索引见 `visual/inventory.json`。
module_lock scanpy-markers: OK (67 files)

## scvi-integrate

setup covariates/size_factor、constructor、train、neighbors/UMAP 参数：已关闭。在同一小型 fixture 中直接独立训练默认结构与 n_layers=2、gene_likelihood=nb 的 tutorial_structure；另改 covariates、size factor、dispersion、latent_distribution、split/plan/datasplitter、metric/UMAP，并比较潜变量、图和 UMAP。
generate_golden.sh 第 1 次全部通过（numeric smoke、golden、第二次 smoke、seal、check）；日志 `scvi-integrate-generate-1.log`。
generate_golden.sh 第 2 次全部通过（numeric smoke、golden、第二次 smoke、seal、check）；日志 `scvi-integrate-generate-2.log`。
Golden：上游 cluster 默认变化影响 before graph 与 UMAP 指标；分 stage 比较已确认 after graph/UMAP 差值为 0，latent/training_history 不变；默认 SCVI 结构及原始 counts 保留。 golden 精确层 CSV 改变/新增：无；golden numeric.npz 中超出原有 tolerance 的字段：batch_mixing__normalized_batch_entropy, batch_mixing__same_batch_weight_fraction, embedding_comparison__x, embedding_comparison__y。完整逐字段前后比较见 `/home/<user>/omic-sol61/fix_py/golden_comparison.json`。
图形：在 R 镜像渲染 8 个请求，全部 exit 0；已打开 16 张 PNG（6 个 SHA256 内容；相同内容去重），visual sheets [4, 5]。非空，标签可读、不裁切；caption/spec 记录细胞/基因/样本数及参数。渲染命令和日志见 `/home/<user>/omic-sol61/fix_py/render_inventory.json`；逐 PNG 索引见 `visual/inventory.json`。
module_lock scvi-integrate: OK (67 files)

## scanvi-annotate

train split/adversarial/plan/datasplitter 与 predict use_posterior_mean：已关闭。对同一 hash-verified 上游模型直接构建/训练 SCANVI，比较默认与 native_split_predict 的硬标签、软概率及列顺序；替代 split=0.8/0.2、shuffle=False、adversarial=False、plan/datasplitter 非默认、posterior mean=False；腐败上游 model 文件必须 OS_HANDOFF_MISMATCH。
generate_golden.sh 第 1 次全部通过（numeric smoke、golden、第二次 smoke、seal、check）；日志 `scanvi-annotate-generate-1.log`。
generate_golden.sh 第 2 次全部通过（numeric smoke、golden、第二次 smoke、seal、check）；日志 `scanvi-annotate-generate-2.log`。
Golden：上游 cluster 默认变化使 cluster-label crosstab 从 4 行变为 3 行；annotations 与 label_probabilities（包括概率数值）未变。原始 counts、参考标签及默认 SCANVI 参数保留。 golden 精确层 CSV 改变/新增：cluster_annotation_crosstab.csv；golden numeric.npz 中超出原有 tolerance 的字段：无。完整逐字段前后比较见 `/home/<user>/omic-sol61/fix_py/golden_comparison.json`。
图形：在 R 镜像渲染 10 个请求，全部 exit 0；已打开 20 张 PNG（8 个 SHA256 内容；相同内容去重），visual sheets [4, 5, 6]。非空，标签可读、不裁切；caption/spec 记录细胞/基因/样本数及参数。渲染命令和日志见 `/home/<user>/omic-sol61/fix_py/render_inventory.json`；逐 PNG 索引见 `visual/inventory.json`。
module_lock scanvi-annotate: OK (66 files)

## 共用代码与完整性

五模块最终 check_calls/default drift、check_defaults、check_flag_docs 全过（static-final.log）；env/py/test.sh / tools/run_tests_py.sh 所用静态 gates 全过（runner-static.log：image --static、环境配置、call-checker unit、scaffold、build contracts）。未执行完整 suite runner；五模块数值 smoke 已通过各自两次 generate_golden.sh，均无 SKIP。

新增 `skills/_shared/py/ospy/native_options.py`：仅转换 on/off/none、JSON dict/list/groups、nullable 字符串和 Leiden class；使用类型化 OS_INVALID_PARAMETER，不 eval。`sc_module.py` 将实际 native_options 同时写入 Methods/Results JSON/provenance，并把 scale 加入 caption context、软件版本加入 Methods。`test_ospy.py` 检查合法/非法转换；共享 unit tests 全过，0 skipped。`s4_option_replay.py` 是封闭清单的原生独立复算；`sc_smoke_support.py` 的 cluster 直接 replay 同步显式 scale 开关和锁定 PCA solver=None，调用该复算，并增加 scanVI model-file hash refusal。没有放宽数值断言或 tolerance（ATOL=RTOL=1e-6；marker 严格原生比较保留）。

marker 严格 smoke 曾发现 nullable template 槽和 requested n_genes 与通用 feature-count n_genes 的字段冲突；分别以专用 prose 字段和 requested_n_genes 修复，未放宽断言，默认及命名参考分支均重新通过。scanpy-markers-rejected-summary.log 保留失败证据。已核对全部新增默认与锁定签名；capture --replace 已经审阅后使用并记录。最终五模块锁通过独立新容器 --check，包含重建环境定义与全部 fig_*.R（含四个合并 fig_mod 文件）。模块修复、golden 变化、两次运行、PNG 视觉检查均完成。无开放修复项。
