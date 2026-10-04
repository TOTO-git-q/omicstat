# build_m3b 构建交接报告

日期：2026-10-01；工作树 `/home/<user>/omic-b-m3b`；分支 `build/m3b`。按 SingleR、muscat、speckle、slingshot、monocle3、CellChat 顺序续做，遵循 common 的 SLIM BUILD 与禁止直接提交更新。本报告记录 S2 构建与失败交接，不表示独立 S3 已验收。

## 需要 owner 处理／待裁决（优先）

1. **SingleR 必需 pancreas anchor 未通过。** 锁定镜像没有 `scrapper`，官方 wilcox 路径失败。classic 合成测试通过不能代替 pancreas anchor；因此不生成本模块 golden 或 module_lock。请修复镜像后由独立 S3 重跑，未安装依赖或改换必需 anchor。
2. **CellChat 默认快速检验路径缺少 `presto`。** `identifyOverExpressedGenes(do.fast=TRUE)` 的锁定默认保持不变并独立复现失败。官方函数明确提供的 `--genes-do-fast false` 标准 Wilcoxon 路径跑通完整 anchor；其 golden 只证明该显式分支。请修复默认依赖或裁决是否接受这一支持分支。该 pin 不导出教程可选的 `projectData`，`raw.use=FALSE` 明确拒绝，未重写它。
3. **AnnData 实际转换仍被已有镜像问题阻断。** 非 root 容器访问不到预构建 basilisk 环境，确认 `OS_ENV_MISSING`。已有 `docs/build/infra_convert_worklog.md` 记录 `/root/.cache/R/basilisk/` 布局问题；应由镜像负责人提供普通用户可访问的环境。本 lane 未安装、更改权限或以 root 绕过。六个 SKILL 均记录此限制。SCE anchor 已执行；Seurat 实际等价转换及修复后 h5ad 测试交独立 S3。
4. **Python 前端接 R 后端的标签待裁决。** 完整保存 upstream state 和生态标签，在 QC 标记 crossing，不造新标签；人工 scverse 链验证保存状态及 `OS_ECOSYSTEM_MIXED` 拒绝有效。
5. **科学选择仍由调用方决定。** 参考数据／标签、比较组、样本列、已有 embedding、轨迹起点及其生物学依据、CellChat 物种／数据库子集等显式提供。SKILL 要求调用 LLM 先查 `reference_advise`／`reference_search`，无 curated 证据时展示 vignette 示例并询问用户；不声称文献“多数”。Slingshot 的旧 PACK V/D 数量和 L3 部分未修复，选项映射采用修正 extraction.jsonl，默认取锁定 formals。

## 各模块结果

所有执行使用 `docker run --rm --user uid:gid` 的 `omicstat-r:2026.09.1`，没有调用正在并行构建的前端模块。直接从注册数据构造 anchor 所需对象，并构造 upstream handoff 测试 `--from-run`。每模块都有 `calls_registry.json`、SKILL、选项证据表、Methods 和 S3_REQUEST；native RDS、CSV、实际参数／包版本／seed provenance 与 suite figure spec 保留。

| 模块／锁定版本 | anchor 和来源 | 结果与范围 |
|---|---|---|
| singler-annotate / SingleR 2.14.2 | PACK C、L1 pancreas 官方 wilcox 工作流；预期 1718 cells、59 pruned，完整标签计数见 S3_REQUEST | **必需 anchor FAIL**：缺 scrapper。40-cell classic 合成 labels、determinism、nmads 生效、from-run、typed errors、batch lineage 检查 PASS。golden／lock withheld。|
| muscat-pseudobulk / 1.26.0 | PACK C Kang18 EH2259、L1 muscat vignette 原 QC／prepSCE／aggregateData／pbDS | **PASS**：7118 genes × 26820 cells、8 cell types；NOC2L ctrl101 的 12，ISG15 ctrl101 的 13、stim101 的 1362；ISG15 logFC 四舍五入 5.47346，P 输出精度 3.0e-21。保留 native local/global FDR。|
| speckle-propeller / 1.12.0 | PACK C CellBench、L1 官方共同基因及 seed=10 bootstrap recipe | **PASS**：六个技术 bootstrap 样本，每技术两个；H1975 logit P=.01841045、FDR=.05003357；asin P=.01578743，按打印精度断言。native 三行 ANOVA 表。技术 bootstrap 是教程回放，不构成真实生物学重复实验。|
| slingshot-trajectory / slingshot 2.20.0、tradeSeq 1.26.0 | PACK C slingshotExample；L1 tradeSeq.Rmd countMatrix/crv 官方 recipe | **PASS**：140×2 embedding、两条 lineage；另用真实 2660-cell countMatrix 和官方 cached crv、RNGversion(3.5.0)、seed=7、6 knots，240 converged genes 精确通过。初始坐标 fixture 的 carrier counts 不参与拟合；主 golden 使用真实 tradeSeq 表。|
| monocle3-trajectory / 1.4.27 | PACK C Packer 三个注册 RDS；L1 trajectory guide preprocess／align／reduce／cluster／learn_graph／order_cells | **PASS**：20222 genes × 6188 cells，4 partitions；教程 earliest-time helper 得 root Y_134；5576 finite、612 Inf 原样保留。这两个 pseudotime 数量是锁定回放结果，不冒充稳定出版 anchor；graph_test smoke 显式仅取 20 genes，默认全基因。|
| cellchat-communication / 2.2.0.9001 | PACK C human skin LS、L1 单数据集教程 create／subset／overexpression／probability／pathway／aggregate／centrality | **显式标准 Wilcoxon 分支 PASS；默认 fast 分支 FAIL**。17328 genes × 5011 cells、12 groups 与教程输入相符；human Secreted Signaling、triMean、seed=1、nboot=100 得 365 significant LR rows、16 pathways。这些是观察回放值，教程未打印可移植网络数量，不作出版数值断言。|

monocle3 GitHub pin `536f1033d6de7c957f26a1f403f81efbd825e0db` 与 CellChat pin `75253cd0c9e68410e6e721a6d3a0419a1d7e358f` 已在容器中确认。没有调用 pin 不存在的 API。monocle3 SCE→CDS 转换使用锁定 CDS 的已有 cluster／partition slots，因为该版本没有公共 setters；算法仍是 native 函数。

muscat 与 speckle 以 sample 为重复单位，拒绝选定比较缺少样本重复的设计。额外短 contract check 验证这两项、lazy dependent defaults、局部 RDS 参数对象、完整 scverse chain state 与混合生态拒绝。五个通过分支的 direct/from-run 主表 hash 相同；CellChat 保存完整概率/P、筛选通信、count/weight、centrality 表。SingleR 保存 prediction 原对象及 annotated SCE。

## 测试、golden、lock 与图

最终封存日志：`/home/<user>/omic-sol61/build_m3b/final-checks.log`。五模块 golden 实际比对要求状态为 PASS；五个 `tools/make_module_lock.R <module> --check` 为 OK。六模块 calls/default drift 和 R lint 通过，两份自有 shared R 文件 parse 通过。SingleR 必需 anchor 的失败记录和 withheld 状态保留。

所有图均经 `fig_all.R`／本 lane `fig_mod_sc_backend.R`、suite theme/palette 与自动 figure lint。全部生成 PNG 已逐个打开：SingleR score/crosstab（run、replay、nmads0、chain），muscat direct/chain 比例与八组 volcano（18张），speckle 比例（2张），slingshot 三张 trajectory，monocle3 两张 trajectory，CellChat direct/chain heatmap 与 circle（4张）。图非空且标签可读；n、cutoff／无 cutoff、推断范围保存在 accompanying figure-spec caption。CellChat circle arrowheads 留出节点距离并重新渲染／检查，autocrine edges 保留于 heatmap/native tables；相同 hash 的 direct/chain 重渲染图也已打开。

每模块 S3_REQUEST 列出复跑命令、预期、输出路径、限制、拟议 router row 与 publication rules。执行日志与对象位于 `/home/<user>/omic-sol61/build_m3b/`：`singler-slim.log`、`muscat-smoke.log`、`speckle-smoke.log`、`slingshot-smoke.log`、`monocle-smoke.log`、`cellchat-smoke.log`、`cellchat-default-failure.log`、`backend-contract.log`；各 `<module>-smoke/` 下保留 direct/chain，Slingshot 另有 tradeseq。SingleR 使用 `singler-smoke/`。以上为本机私有 scratch，没有上传外部。

## Shared code 改动

只更改 lane 自有两文件：

- `skills/_shared/scripts/sc_backend_io.R`：统一使用已有 convert／handoff；保留整个 upstream state 和 label；逐 locked formal 生成 JSON CLI 参数，正确求值 lazy dependent defaults，允许局部 RDS 复杂对象；native output、QC、Methods、输入及额外 RDS 参数 hash；sample replicate guard；轻量 direct/from-run smoke 与严格 golden 状态检查；S4 `.local` formal inventory。
- `skills/_shared/scripts/fig_mod_sc_backend.R`：SingleR relative-score／cross-tab，muscat local-FDR volcano，native curve／principal graph pseudotime 图，CellChat weight heatmap／有向 circle。仅可视化 native 数值，不重实现统计方法。

没有改其他 shared、registry、router、run_tests、vendor、配置或其他 lane 工作树。只读取 S0／verify 证据，anchor 从已有本地文件复制，没有重新下载。

## 偏离与未做事项

按更新后的 SLIM BUILD 留下已有效的 SingleR 旧参考文件，不补做五件套／全 QC catalogue／全部出版打印值。每个函数参数用 JSON CLI（帮助里展示 locked default）以覆盖 native 向量／对象参数；旧 `check_defaults.py`／`check_flag_docs.py` 不理解动态 JSON “未提供则继承 native default”，未沿用它们；保留 calls/default drift、R lint 与实际参数 provenance。S4 method 默认直接从锁定实现读取。CellChat 显式支持分支、SingleR 失败后继续、monocle3 20-gene graph_test smoke 的边界如上，未放宽 anchor tolerance 或篡改默认。

未做 S3 独立验收、S5 安装、router／publication registry 合并；这些按任务只交接建议。未修复 image 缺依赖及 AnnData 环境，不声称所有六模块完整通过。muscat native TMB/glmmTMB build-version warning、CellChat tutorial metadata 缺 samples 的 native warning 保留；后者为单 RNA 数据集推断，不作重复样本条件比较。

提交由 common 的外部每十分钟 helper 负责；未尝试 git commit／push 或绕过只读 .git。lane worklog 是步骤与提交记录。报告进入 helper 提交后再追加最后一行 DONE；其含义是本 lane 按“失败记录后继续”的更新完成构建交接，独立 S3 和上述 owner 修复仍待完成。
