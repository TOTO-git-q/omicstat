# build_m1 建设报告（2026-09-28）

工作树 `/home/<user>/omic-build`，分支 `build/m1m2`；锁定镜像 `omicstat-r:2026.09.1`。本车道完成任务 1–4 与 8；四个模块均为 **S2 已完成、待独立 S3**。各模块的复核入口、候选路由行与 `module_rules_v1.json` 记录见各自的 `acceptance/exemplars/<module>/S3_REQUEST.md`。

## 需要所有者或独立复核者处理的事项

1. **deseq2-qc P-2**：样本离群的统计量、阈值及“仅标记”的边界仍待所有者裁决。S2 删除了超出临时决定的 centroid-distance 列；不自动判定或剔除样本。A2 回放锚点是否足够独立，留给暂停中的 S3 F1 复核。
2. **deseq2-lrt P-2**：锁定镜像没有 DEGreport，`--pattern-clustering` 返回 `OS_UNAVAILABLE_DEPENDENCY`。启用前需要所有者决定镜像重建和输入基因选取规则；目前不生成模式聚类结果。
3. **sva-batch**：连续研究变量如何进入 `ComBat_seq` 的 `group`/`covar_mod` 尚未裁决，当前类型化拒绝；SV 展示矩阵使用 `removeBatchEffect(batch=NULL, covariates=SVs, design=mod)`，请独立复核其与 P-3 交叉引用的一致性。ComBat 的 base-graphics 先验密度图未纳入本次统一图层。
4. **edger-qlf**：S1 未冻结 QL F 统计量的有向排名构造，因而不交接 `ranked_list`；需所有者决定后续是否设立这种契约。官方指南输出使用 edgeR 4.9.9，与锁定镜像 4.10.5 的显著性分箱略有差异；S2 保留锁定估计器并以同版本独立回放核对，请 S3 确认。`cpm()` 的 Rd 未包含于本模块 L1 包，调用登记使用锁定容器 `formals()` 实测值。
5. **计划中仍待定的 C 项**：`limma-voom` 的 `voomLmFit` 主方向、输出契约和锚点，以及 GSVA scores 的 limma 接收入口与 `eBayes` 取值，已按 SUITE 记入 v1.2，未在本车道代为冻结。

## 各模块 S2 结果

| 模块及提交 | 锚点（来源、实测与结果） | 测试、图与开放项 |
|---|---|---|
| `sva-batch` `12127da` | PACK C / 官方 sva vignette：bladderbatch ComBat 受保护设计回放矩阵相等；`num.sv(method="be", B=20, seed=20260925)` 回放为 9 个 SV；`method="leek"` 与指南打印值 2 一致；zebrafishRNASeq `svaseq` 打印值 1；ComBat_seq 模拟数据校正整数矩阵与直接调用逐字节一致。全部 PASS。 | 锁定容器 golden 写入及普通检查 PASS，lock 已重生成；检查 A1–A5、F0、F3 等唯一的前后 PCA 图，标签、标题、图注可读且标明展示用途。待裁决见上。 |
| `deseq2-qc` 1.0.1 `5a0fd30` | pasilla：14,599 行中 8,148 行参与变换，`blind=FALSE` 的 3 行 VST 值与官方打印值在 5e-6 容差内；`blind=TRUE` 的 treated1、untreated4 PC1/PC2 与测试会话回放一致。F5 合成数据触发直接 VST 回退及 DQ-05。全部 PASS。 | S3 暂停记录的 F2–F5 明显缺陷已修复；容器 golden 写入/检查 PASS，lock 重生成；A1 四张 PNG 逐张查看，坐标、图例与方法说明无裁切。F1 的锚点独立性待 S3，离群定义待所有者。 |
| `deseq2-lrt` `1bcd08c` | fission 交互 LRT：assay SHA256 `4bec9e6d01665301ced3de128eff4cfb1269aed9701146e794087e24f526fe30`，7,039 输入、6,205 检验、8 显著、df=5；独立 DESeq2 回放的 P 值及调整 P 缺失模式一致。pasilla 次级回放：14,599 输入、8,148 检验、1,112 显著、df=1。全部 PASS。 | 类型化错误、`--from-run`、spec 逐字节回放、golden 写入/检查、lock 均 PASS；fission 热图与轨迹、pasilla 热图已目视，修正后的轨迹分面标签不裁切。DEGreport 缺失使模式聚类待实现。 |
| `edger-qlf` `c7f1c1e` | GSE60450 gz SHA256 `906b6ec4c33e95ca0ba454a3e0d07ad74e9cb7528ee38b89a9b122f5674a5f0d`；27,179 输入、15,969 通过 `filterByExpr`。edgeR 4.10.5 的 QLF 下/不显著/上为 **2,608/10,546/2,815**（指南 4.9.9：2,607/10,546/2,816）；`glmTreat(1.2)` 为 **1,535/12,570/1,864**（指南：1,533/12,573/1,863）。Mrgprf/Entrez 211577 的 logFC −5.148701616、F 473.1673102、P 7.554955726e−13；同镜像独立回放全 15,969 基因 P/FDR 一致。全部 PASS。 | `--legacy`、仅展示 FC 筛选、类型化拒绝、引擎参数静态检查、spec 的表/PNG/图规逐字节回放、golden 写入/检查与 lock PASS；QLF 的火山图、MD、BCV、热图及可选 treat/legacy 图均已目视，12 个 GEO 样本标签无裁切。排名交接、指南版本差异待复核。 |

各模块均有 `S3_REQUEST.md`，提出路由行与规则记录，但未执行独立 S3。容器输出与原始日志位于 `/home/<user>/omic-build-logs/build_m1/`；每个请求文件列出可复跑入口和重点。

## 共享代码与计划同步

- `skills/_shared/scripts/module_kit.R`：修复 Bioconductor `data()` 登记名与实际对象名不同时的唯一对象读取，支持 bladderbatch 锚点。
- `skills/_shared/scripts/feature_table.R`：仅剥除 Ensembl 数字版本后缀，保留 fission `SPAC212.11` 等真实 ID；定向探针与现有 `deseq2-wald` smoke/golden 回归 PASS。
- `skills/_shared/scripts/fig_mod_bulk.R`：加入 sva 前后 PCA、LRT 轨迹、edgeR MD 构图；`fig_style.R` 仅增加 log2 CPM 轴 token，并同步 `FIGURE_STYLE.md`。容器共享图形测试 `ALL FIGURE CHECKS PASSED`。
- `docs/handoff/ENGINEERING_PLAN.md` 以 `ed4ad05` 升为 v1.2，同步 SUITE 所列 10 项；只改文档，不提前裁决 C 项。

## 偏离与未完成

**偏离：无。** 未进行 S3 独立验收或 S5 路由/规则装机，是车道任务明确的分工。`limma-voom`、`limma-array`、`limma-dupcor` 已转 M1b；M2 富集模块属另一车道。本车道未推送分支，也未安装新包。
