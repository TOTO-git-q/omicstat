# build_m3a_bioc 构建报告（S2，等待独立 S3）

## 待裁决（所有者优先）
- AUCell 或 GSVA 是否成为套件标准单细胞打分路线仍待所有者裁决。aucell-score 仅实现 AUCell，未修改 gsva-score。
- QC 阈值、线粒体注释、HVG/PC/邻居数量、批次定义、marker 排序与展示数量等研究选择以明确选项暴露；文档要求调用 reference_advise/reference_search，未采用文献“多数派”默认值。
- scran-markers 文献分母是否纳入六篇非聚类分组研究、batchelor 文献适用范围及 S0 返工报告的其他开放项仍待所有者/独立核验人处理；不以这些文献计数决定计算默认值。
- 目前 AUCell 只批准容器内锁定 GPL-3 示例 geneSignatures.gmt（SHA256 7df395bd…）。其他集合返回 OS_REFDATA_MISSING，包含 KEGG/PanglaoDB 的集合不得使用。新增许可干净集合需另行登记。

## 已完成检查与模块状态
- scater-qc：续跑前已完成。Zeisel 20006×3005；官方 MAD3 路径保留 2874 个细胞；容器 smoke/golden/lock OK，三个 PNG 已检查（见原工作日志）。不重做已完成模块。
- scran-cluster：续跑完成锁生成/校验。Grun 20148×1728；真实 scater-qc 交接保留 396 细胞，1000 HVG、15 PC、9 簇。容器 smoke/golden PASS、lock OK；五图已在原日志检查。scran 官方打印 size factor 中位数 0.753183 路径依赖镜像缺失 scrapper，未声称复现。
- batchelor-integrate：Zeisel 20006×3005、Tasic 24150×1809 打印维度断言 PASS；真实 Tasic QC/cluster 交接后与 Zeisel 合并 300 细胞/1000 HVG/15 校正维度；原始 logcounts 完全一致，原生 fastMNN 对象保存，smoke/golden/lock OK。四张校正前后 batch/label UMAP 已打开检查、无裁切；figure lint 无 blocker；25/25 参数文档通过。
- scran-markers：原生 scoreMarkers 精确直接回放、全表 20148×9 行、396 细胞，effect-only 无虚构 P 值；golden PASS。两图已打开检查、无裁切；17/17 选项有文档。容器模块锁生成和校验 OK。
- aucell-score：官方 GEO 文件 SHA256 PASS；seed333 抽样打印维度 5000×3005 PASS。120-cell smoke 的原生 rankings/AUC 与官方直接调用完全一致；正常 SCE handoff、许可拒绝、golden PASS。四个实际打分基因集；原生 AUCell 将匹配不足的 Neuron_Cahoy/Astrocyte_Lein 排除，保留警告而不改变阈值。两张分布/热图已打开检查、无裁切。容器 lock OK（8 文件），18/18 选项有文档；4909 个明确兼容 feature 的 Seurat→SCE 打分与同一 SCE 完全一致。原始 GEO 中 91 个 `_`/`|` feature 被 convert.R 正确拒绝；AnnData 返回 OS_ENV_MISSING，原因是运行用户不能访问预构建 anndata 0.12.3 basilisk 缓存，未安装/下载环境。

## 共享代码
只新增/扩展车道拥有的 sc_bioc_io.R 和 fig_mod_sc_bioc.R。输入、chain state、显式 convert.R 转换、原生 JSON 选项、Methods/输出统一在车道辅助代码中；图使用 suite 现有 embedding/QC violin/dotplot/heatmap 与主题。未改 router、method_map、run_tests、gsva-score 或其他共享框架。

## 偏离与已知限制
- 镜像保留 scuttle/scran 兼容 API，但 scrapper 不存在，调用会产生弃用警告；警告保留在 qc/engine_warnings.csv。不安装包，不重写算法。
- Lane A 实际目录缺少已登记 GSE60361 GEO 文件；在本车道首次获取该文件并按 S0 SHA256 验证（日志 aucell-anchor-fetch.log）。没有重复下载已存在的 Zeisel/Tasic/Grun 文件。
- 小规模 smoke 按 slim build 验证关键打印维度与原生回放，不声明全量官方数值复现；动态 os_bioc_call/do.call 登记不由旧静态扫描器完整追踪，额外容器检查锁定 defaults 与包版本。
- 构建中曾同时运行两个独立模块 smoke，偏离一次只运行一个的旧 brief；后续 smoke 顺序运行。未改容器或其他车道。

## 未执行
独立 S3、S5 安装、router 注册与出版规则安装按任务要求留给协调者。git 提交遵守 00:20 更新，不尝试操作只读 .git；由外部 helper 根据车道日志自动提交。

所有 S3_REQUEST.md 包含运行方法、锚点来源、输出路径、限制、建议 router 行与出版规则。日志和原生输出均在 /home/<user>/omic-sol61/build_m3a_bioc/，未对外发布。

## 最终验证范围
三个新模块的 R 解析、实际包版本和登记 formals 检查通过；容器参数文档检查 batchelor 25/25、markers 17/17、AUCell 18/18。引擎 lint 6 文件、0 问题。每个新模块有真实容器 golden_manifest.csv 和 module_lock.json，所有五个模块均执行 --check。新图合计八张逐张打开，自动 lint 无 blocker。不存在 TODO 引擎或虚构数值。

## 留给独立核验的限制
- AnnData 入口代码使用既有 convert.R，但本次锁定用户环境不可达，未跑通其数值回放；需协调者提供可读预构建环境后验证。
- scran-cluster 官方 2026 scrapper 前置路径打印 size-factor 中位数未重放；scran-markers findMarkers 兼容选项未单独数值锚定。
- AUCell 使用 120-cell 官方抽样子集，图中的 first/second 是明确 smoke 分组，非生物学细胞类型。原生匹配不足的两个基因集被 AUCell 排除。
- batchelor 测试中 joined_anchor 是真实 QC/cluster 处理样本的明确合并 fixture，不代表模块自动合并多个 run。小规模结果不作为全量官方 50 维数值复现。
- 未编辑其他共享文件。native 空 colour_registry 写入问题通过新模块明确创建各自分组 registry 避开，未修改 fig_style.R。
