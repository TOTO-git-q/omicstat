# 环境重建报告（完成）

## 待 owner 裁决

AUCell vs GSVA 及 Python→R 的 ecosystem 标签维持原待裁决状态，没有自行决定。CIBERSORT 两条成功路径需要用户自备合法 source/LM22；没有捆绑这些受限文件，没有虚报成功。没有执行独立 S3。

2026-10-01 17:00 UPDATE 已明确允许替换本 lane 的新 tag，并接受 Seurat 自动 presto 后端；本报告的 Seurat golden 更新仅限这项授权。

## 镜像、包锁与回滚

| 项目 | 值 |
|---|---|
| 旧镜像 | `omicstat-r:2026.09.1` |
| 旧 ID（保持不变） | `sha256:410f4c27e7080c8a589fb0a14195a03da39cb50de1bec185b40c07c3556192f6` |
| 初次新 tag ID | `sha256:50ba2605ae8e576fac76e63fd6219f6770ad3a44f5d90abcae91cd38ababfd8f` |
| 最终镜像 | `omicstat-r:2026.10.1` |
| 最终 Docker image ID | `sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7` |
| archive config digest | `sha256:cda79cdba88b119b1cd20454d6499aacbfd627a3d3cfebe1a3cb11ecc799ac02` |
| R / Bioconductor / CRAN | 4.6.1 / 3.23 / 2026-09-15 snapshot |

Docker 此处将 OCI manifest digest 返回为 live ID；load 后初次 guard 误把 config digest 当作 live ID，因此末尾断言失败。已核对 build metadata 的 manifest/config 对应关系，最终 live ID、内容及旧 tag 均验证；未进行额外 tag 操作。

L0–L7 从不可变旧 image 继承；原 layer 构建定义保留，L8 及 basilisk/refdata 在后。live package lock 与旧锁比对：530 原包全部字段相同，0 版本变化、0 移除、14 新增，共 544 包。严格 stop gate 通过；`env/pkg_lock.csv`、`env/image_id.txt`、metadata 与 BUILD_RECORD 已更新。新增：ALL 1.54.0、BiocStyle 2.40.0、ConsensusClusterPlus 1.76.0、DEGreport 1.48.0、GPArotation 2026.8-2、Rigraphlib 1.4.0、bookdown 0.48、dendextend 1.19.1、ggdendro 0.2.0、logging 0.10-111、mnormt 2.1.2、presto 1.1.0、psych 2.6.5、scrapper 1.6.3。presto pin 为 `immunogenomics/presto@b5df6ee6097eb62522f2e557aa93ac21bab2d05f`。

basilisk 直接迁移旧预构建环境和 Python interpreter 至 `/opt/omicstat/basilisk`，`chmod -R a+rX`，只让 lock/expiry 元数据可写；环境保持离线。23 个旧 Python 包版本完全一致，避免重下载时 msgspec 0.21.1→0.22.0 的漂移。最终 live 非 root native H5AD/Python freeze gate 通过。默认 R route、agent/run helpers、MCP container mode、tools 与 suites 使用新 metadata 标签；旧 tag 未覆盖，latest 未操作，没有 rmi/prune。

回滚：使用 `OMICSTAT_IMAGE=omicstat-r:2026.09.1` 调用支持此 override 的 R route / `env/test.sh`；完整回滚应在本 worktree 恢复 lane 基线 e996c69 的代码、metadata、golden manifests 与 module locks，包含 Seurat 的旧 golden；该基线原有的缺包及 integration findings 也会恢复。不要通过 tag 操作覆盖旧镜像。新包分支与非 root H5AD 功能不能在旧环境宣称可用。

## Seurat presto 前后比较（唯一获准改变既有 golden 的模块）

own smoke 脚本以 `OMICSTAT_WRITE_GOLDEN=1` 生成新 golden，随后严格 hash 与 native replay PASS，未放宽任何检查。旧 image 同一对象原生输出精确等于原 golden。before hash `c4790181bb87da7b24e341b451f4379348cd19b9686522c3dca9bca091acf27f`，after hash `9c3913ca5322716aa7a76f0caa8405d1d8bbe80f38418606c518579560de7d2f`。

| 指标 | 旧环境 | presto 环境 | 教程打印 |
|---|---|---|---|
| PBMC cells / clusters | 2638 / 9 | 2638 / 9 | 2638 / 9 |
| 全 marker 行数 | 11648 | 11648 | — |
| log2FC > 1 行数 | 7023 | 7023 | 7019（未复现） |
| cluster-2 IL32 log2FC | 1.324556 | 1.324556 | 1.3070772（未复现） |
| contrast 前五基因 | IL32, LTB, CD3D, IL7R, LDHB | 相同 | 相同 |
| 全表最前五基因 | RPS12, RPS6, RPS27, RPL32, RPS14 | 相同 | — |

11648 行的 gene/cluster/order/log2FC/pct 完全相同，仅 5628 个 raw P 与 2907 个 adjusted P 字段有浮点差异；最大绝对差分别 `1.8041124150158794e-16` / `2.398081733190338e-14`。例如 cluster 4 的 MSC，raw P `3.78734659068917e-05` → `3.787346590689e-05`，adjusted P `0.519396711447113` → `0.519396711447089`。锁定 Seurat 的 WilcoxDETest 在 presto 安装后自动改用该后端；fold-change 计算未变，因而 presto 未解决历史打印 FC/count 差异。这些历史差异保留供独立 S3 检查；不是新增包导致其他 existing golden 漂移。

## 科学锚点及新增分支

- SingleR：官方 Grun/Muraro pancreas wilcox 流程 1718 个细胞、59 个 pruned，标签计数精确通过：acinar 723、alpha 228、beta 232、delta 65、duct 344、endothelial 15、epsilon 2、mesenchymal 69、pp 36、unclear 4。原始 EH 数据 fixture 漏了 scRNAseq 官方构造函数的 ERCC altExp split；按锁定 scRNAseq 2.26.0 源码补齐后通过，未放宽断言。完整 smoke 已通过，首次生成 annotations / scores / cluster_labels golden 与 lock。
- scran：独立官方完整数据路径重放 ERCC split、seed 100、scrapper analyze.se、quickCluster 和 computeSumFactors，median `0.753182785733022`，按打印精度为 `0.753183`；原 400-cell subset golden 保留。
- CellChat：既有显式 Wilcoxon 分支 golden 保留，human-skin 默认 `do.fast=TRUE` presto 分支通过，只追加 `communication_fast.csv` 的新 golden 行。17328 genes × 5011 cells、12 groups；完整 smoke 通过。
- DESeq2-LRT：DEGreport pattern clustering 仅显式开启，必须给出 gene list 与 time column，原生 options 和 native result 保存。fission 60-gene probe 通过，开启前后 LRT 主结果 CSV 字节一致；完整 smoke 通过（含原 golden、native pattern assignments、LRT byte parity）。
- 非 root AnnData：AUCell 实际 h5ad 输入 smoke 已 PASS、scores 与原 golden 字节一致；修正方案的 native write/read gate（维度、轴、计数、metadata）通过；shared test_convert 全部通过、0 skips。最终 live 镜像的非 root native H5AD gate 已通过。实际 h5ad smoke 已加入：AUCell、CellChat、muscat、speckle 在修正方案容器中已通过，原生表与 RDS 路径一致；SingleR pancreas h5ad 的 annotations/scores 亦已通过字节一致验证；Monocle/Slingshot 在 converter 修正后完整 h5ad smoke/native table parity 通过。全部七条 requested non-root h5ad 路径已在 disposable fixed environment 通过，最终 live full suite 已逐条通过。
- Python：五个模块的 figure requests 均由新 R 镜像成功渲染，共 8 张 PNG，已逐张打开检查。CellChat 6 张与 SingleR 10 张 PNG 已打开检查（重复结果字节一致），布局可读；caption 包含 n、阈值或无 display cutoff 的说明。

## immunedeconv 扩展

锁定包源、实际安装包 LICENSE 和各方法输入规则已记录在 `skills/immunedeconv-infiltration/references/options.md`。全部验证在 `--network none` 中执行，不安装新的方法依赖。输出保留原生表及对象；score heatmap 使用按行 z-score，并明确不解释为比例、不跨 cell type 比较；ABIS 原生百分比估计保留负值。EPIC 必须显式 `--accept-licence epic`，许可、输入尺度及实际选项记录在 Methods 和 provenance。

下面维度为 cell types × 4 samples；原生 CSV 另含 cell_type 列，共 5 列，smoke 严格断言原生表 shape。

| method | 状态 | 许可与数据来源 | Racle 检查 |
|---|---|---|---|
| quantiseq | 已启用（原分支） | quantiseqr GPL-3；锁定包内签名 | 原 golden 与打印 B-cell 值保留；11×4 |
| mcp_counter | 已启用 | GPL-3；官方 MCPcounter 固定 commit 的 genes/probesets 文件，build-time SHA256 校验 | 原生 parity；映射后 11×4 |
| epic | 已启用，必须许可 acknowledgement | academic non-commercial、不可再分发；私有镜像内原包数据 | 原生 parity；8×4；比例和为 1 |
| xcell | 已启用 | GPL-3；锁定包内数据 | 原生 parity；39×4 |
| timer | 已启用，必需 indications | GPL-2；锁定包内数据，RNA-seq 路径 | 原生 parity；6×4 |
| abis | 已启用 | pinned immunedeconv README 标明 GPL-2；锁定包内签名 | 原生 parity；17×4 |
| consensus_tme | 已启用，必需 indications | GPL-3；锁定包内数据，ssGSEA 路径 | 原生 parity；18×4 |
| estimate | 已启用 | GPL-2；锁定包内数据 | 原生 parity；4×4 |
| cibersort | 有条件支持 | restricted academic licence；只能用户提供 source 与 LM22，必须 acknowledgement | 缺文件/许可 typed refusals 通过；成功路径未验证，无文件、不生成 golden |
| cibersort_abs | 有条件支持 | 同上，absolute 原生路径 | 同上 |

MCP-counter 来源 commit：`b6eac73e91c246fcff0bb1a5c68a816cd588fc48`。genes SHA256 `408f6c5d02c8f9bd2f1599c598367881853520934f8ce398a4886a8b296922bb`；probesets SHA256 `68778e6632fefac944127dba8d1ae1e8b8889ba36c71500776f8a7f00098c573`，均登记于 `env/refdata_registry.json` 并放在 `/opt/omicstat/refdata/mcp_counter/`。其余方法使用已锁定包内数据；不分发 CIBERSORT source 或 LM22。

八个可离线方法的 native parity 全部通过，原 quanTIseq golden 不改，仅追加七个方法表。初次完整 smoke 在末尾 static registry 检查发现问题，已修正，targeted static / defaults / docs / golden / lock 检查通过；最终完整 smoke 已通过：42 checks，static calls/docs/golden/lock 全通过。10 张方法/交接 PNG 已逐张检查。


## 最终逐模块结果

原 32 scientific goldens：31 不变，Seurat 1 个按 UPDATE 更新；CellChat/immunedeconv 只追加新分支；SingleR 首次建立 3 表。与 e996c69 的严格 manifest 审计未发现其他旧行修改。33 scientific R module locks 均在最终 live image 生成/check OK，selftest 另行运行。

| 模块 | 最终镜像重放 | golden |
|---|---|---|
| aucell-score | PASS | 原 golden 不变 |
| batchelor-integrate | PASS | 原 golden 不变 |
| cellchat-communication | PASS | 原 golden 不变，仅新增分支 |
| clusterprofiler-compare | PASS | 原 golden 不变 |
| clusterprofiler-gsea | PASS | 原 golden 不变 |
| clusterprofiler-ora | PASS | 原 golden 不变 |
| deseq2-lrt | PASS | 原 golden 不变 |
| deseq2-qc | PASS | 原 golden 不变 |
| deseq2-wald | PASS | 原 golden 不变 |
| edger-qlf | PASS | 原 golden 不变 |
| fgsea-prerank | PASS | 原 golden 不变 |
| gsva-score | PASS | 原 golden 不变 |
| immunedeconv-infiltration | PASS | 原 golden 不变，仅新增分支 |
| limma-array | PASS | 原 golden 不变 |
| limma-camera | PASS | 原 golden 不变 |
| limma-dupcor | PASS | 原 golden 不变 |
| limma-voom | PASS | 原 golden 不变 |
| maftools-landscape | PASS | 原 golden 不变 |
| monocle3-trajectory | PASS | 原 golden 不变 |
| muscat-pseudobulk | PASS | 原 golden 不变 |
| omicstat-selftest | PASS | 原 golden 不变 |
| scater-qc | PASS | 原 golden 不变 |
| scran-cluster | PASS | 原 golden 不变 |
| scran-markers | PASS | 原 golden 不变 |
| seurat-cluster | PASS | 原 golden 不变 |
| seurat-integrate | PASS | 原 golden 不变 |
| seurat-markers | PASS | 授权 presto 更新 |
| seurat-modulescore | PASS | 原 golden 不变 |
| seurat-qc | PASS | 原 golden 不变 |
| singler-annotate | PASS | 首次 golden（3 表） |
| slingshot-trajectory | PASS | 原 golden 不变 |
| speckle-propeller | PASS | 原 golden 不变 |
| sva-batch | PASS；保留 A6a 已知失败 | 原 golden 不变 |
| wgcna-network | PASS | 原 golden 不变 |

## Suites、精确计数与 skips

- `bash env/test.sh`：ALL PASSED，0 skipped for missing packages；101 个顶层命令：17 shared/static、34 R smokes（33 scientific + selftest）、6 Python smokes、40 defaults、4 infrastructure。完整日志：`env/test_report.txt` 与 scratch `full_r_published.log`。
- `bash env/py/test.sh`：ALL PASSED，24 顶层 commands；6 个 Python 模块各 calls/defaults/smoke，shared ospy 0 skips。仅 selftest 1 个 R-render skip（Python image 无 Rscript，最终 R image 已重放五请求/eight PNG）。日志：`env/py/test_report.txt`。
- `bash env/py/test_e2e.sh`：92 assertions、92 passed、0 failed、3 skipped。三个原因：host 无 Rscript；native-only legacy/strict/publication/default-outdir checks 的 native engine 不可用；native Python 无 environment file。真实 container routes 已通过。日志：`env/py/e2e_report.txt`。
- 最终 live `test_convert.R`：非 root/offline，103 checks PASS，0 skips；含 embedding 顺序、单/未使用 factor levels、native H5AD categories、单 feature/cell axis 与 metadata。最终 live `test_basilisk_nonroot.R` native 往返与 23 Python versions 全通过；scran printed anchor 严格 PASS。
- R suite 内部共 15 skips（与顶层 missing-package skip=0 分开）：shared ospy 2、Python selftest 3、五个 scientific Python smoke 各 1、publication 2、MCP client 3。五个 scientific Python numerical/model/golden smoke 因 R image 不是 pinned Python environment 而跳过，仅验证 typed environment refusal；这五项已在 locked Python image 完整通过。
- R image 内 shared ospy 的 2 个 skips：此 R/MCP venv 未安装 torch、scvi；对应部分已在 Python image 通过。R-container MCP client 的 3 个 skips：image 内无 docker CLI（R container / Python container 两项）、native Python key 未配置；host E2E 覆盖真实 container paths。publication 60 tests：58 PASS，2 Windows junction skips。R-image selftest-py 另有 3 个 skips：R/MCP venv 无 anndata；不是正式 managed Python environment；未显式设置 OMICSTAT_SMOKE_RSCRIPT（测试虽然打印 no Rscript，实际 Rscript 已安装，此项需要显式变量）。shared R render-request 与五模块最终 R render 都已通过。没有 R module 缺包/缺 anchor skip。
- `sva-batch` A6a 保留原严格已知失败，绝不修改 assertions 或 golden；smoke 的原生 known-failing 机制使 suite 成功。详细项目保留在 module 的 S4_FIXES.md。
- integration contract unit tests 13/13 PASS；reference config tests 7/7 PASS；CLI defaults 按最终 full suite 逐模块验证。

## Integration 修正与共享代码

method_map 的 19 个新 R entries 改为 `source_built_pending_locked_acceptance`（与 Python 的 source-built vocabulary 相同）；BUILD_STATUS 改为 24 new engines built、0 unimplemented，`complete_request=false`、independent S3 pending。router 和 reference store 不扩展；checker 按实际 source/routed 分别验证，缺真实入口仍拒绝。contract test 保留 unimplemented 时禁止 pretend engine 的检查，并增加已实现项的 entry/smoke/registry/lock/status 必须一致，未削弱测试。

默认一致性：immunedeconv 记录 extension 与 native choices 的真实 CLI defaults；maftools 补齐既有 registry 的 8 个 CLI 默认；scran `--pool-sizes` 文档改为锁定 `computeSumFactors` 的值；SingleR 19 项可选 JSON overrides 未提供时保留 native lazy defaults，因此 registry 增加 `cli_default=null`。check_defaults 最小扩展仅识别显式 cli_default，同时保留 native `value/function_default` 校验，不把省略误判为改变 native 默认。limma-voom frontmatter description 引用修复已完成，module lock 重新生成。最后文档审计修正 11 个模块的旧镜像示例/已解决的 missing scrapper/presto/non-root AnnData 限制（共五处旧 tag 示例、七条后端 AnnData 说明及 SingleR/CellChat 缺包说明），并修正 scran method-basis 的历史缺包描述；受影响 locks 重新生成/check，没有修改 engine 或 numerical golden。

共享 converter 的新增 order metadata 与原生 pandas/AnnData 恢复解决 embedding 排序、singleton categorical/axis、unused categories 及 all-NA 字符运输问题；新增严格回归全部通过。后端 smoke helper 增加真实 h5ad/native table parity；M4 figure helper 区分 fraction/percent/score。module lock 绑定 image/env_version 并递归覆盖 fixtures，--check 同时验证 packages/environment。R test helper 非 root、禁网、只读挂载 acceptance library，显式 image ID 与 h5ad gate。首轮 full suite 另外暴露 muscat fixture / Seurat-QC smoke/harness 的 /scratch 硬编码；只修改写出路径为 OMICSTAT_TEST_TMP/tempdir，保留原生计算、全部 asserts 与 goldens，随后刷新受影响 locks 并完整重跑 suite。env/test.sh 增加可选 OMICSTAT_TEST_ARTIFACTS 挂载，tools/run_tests.sh 可保留逐 command 原始日志和 index，便于逐项 skips/counts 与 PNG 审计；不改变命令、成功/失败或 skip 判定。修改运行中的 runner 文件导致首轮末尾 shell 读取偏移/parse 错误，这是执行时序失误；随后 bash -n 通过，并在源文件稳定后完整重跑。首轮原始日志保存在 scratch full_r_first_published.log。

## 图检查、偏差与未完成事项

最终 Python 五模块八 PNG、Seurat final-prep PNG 与以前逐个打开检查的结果 SHA256 相同，0 新 unseen plots。此前全部 current module PNG 已用 review ledger/sheets 打开检查；主体图与新增方法图可读、非空。最终 full-suite-final 的所有 PNG 对照 SHA256 review ledger，仅新增 qc_alt 的两张图；两张原始 PNG 已打开，violin 与 percent.mt scatter 可读、非空、标签无裁切、阈值线清楚，其余全部 SHA256 命中已检查结果。逐 command 原始日志/index 和 review manifest 保存在 lane scratch。既有 supplementary compare dotplot 的长 GO labels 与部分 DESeq2 MA labels 拥挤，保留为 S3 图审限制，没有更改 scientific golden。

偏差：初次 tag 的 basilisk interpreter 仍指向 root cache，修正 prebuild 曾出现 Python transitive drift；最终通过迁移旧环境、非 root/freeze build gate 解决，并仅依 17:00 授权替换 lane 新 tag。Seurat 自动 presto P 序列化变化按 UPDATE 唯一例外更新，历史 FC/count mismatch 仍报告。CIBERSORT 无合法输入文件，仅条件接口/refusals 已验证。没有执行独立 S3，没有替 owner 决定两项 open items。

任务执行全部完成。worklog 最后写 DONE；不执行 git commit/push，按 common UPDATE 由 sandbox 外 helper 使用最后一条 worklog 行提交。
