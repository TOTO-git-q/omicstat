# ASTRA 科学逻辑审计

状态：审计与验证完成。35 个模块、共享层、MCP 和路由器均已检查；23 条问题记录已修复，另有 2 项所有者裁决事项。

审计范围为除 seurat-markers、scanpy-markers、scran-markers 之外的 35 个分析模块，以及共享代码、MCP 和路由器。没有修改三个排除模块、验收数据或 vendor。运行环境为 omicstat-r:2026.10.1 与 omicstat-py:2026.09.1，容器使用当前用户并禁网。以下日志均位于 `/home/<user>/omic-sol61/astra_scan/`。

## 已确认问题及修复

类别对应任务文件：1 表述，2 拒绝绕过，3 重复单位，4 隐式科学决定，5 数值追踪。

重现入口：R 模块为锁定容器内 `Rscript skills/<module>/tests/run_smoke_test.R`，Python 模块为 `python3 skills/<module>/tests/run_smoke_test.py`；共享拒绝为 `Rscript skills/_shared/tests/test_scientific_refusals.R`。完整命令及对应原始输出见 `sealed-r/logs/index.tsv`、`python-suite/logs/index.tsv`。下表的聚焦日志保留失败前、修复后的实际调用及输出；独立探测脚本均与日志同在 lane scratch。

| 模块/共享层 | 类别 | 严重度 | 证据与行为 | 状态 |
|---|---|---|---|---|
| fgsea-prerank、clusterprofiler-gsea、limma-camera；ranked_list.R | 2 | 会将错误结论写入论文 | `probe-before.log`：LRT 配合 directional=TRUE 被接受；新回归覆盖 LRT、F、F statistic、likelihood ratio 的直接 CLI，以及 sidecar/handoff 方向冲突 | 统一无方向统计量拒绝；核对全部必需的 sidecar 字段；已修复（`9051259`） |
| Seurat/SCE/AnnData 转换及中性后端 | 2 | 会将错误结论写入论文 | `probe-before.log`：直接 SCE 的已校正表达及错误生态标签被接受；首次新增 h5ad 回归失败，定位为 HDF5 遍历深度；`conversion-final2.log` 全部通过、零跳过 | 保留内嵌谱系；直接对象与 from-run 均校验；保留上游生态标签，中性后端另记 neutral；已修复（`5d5925e`） |
| GSVA 下游 limma-array、limma-dupcor、limma-camera 等 | 2 | 会将未经裁决的推断写入论文 | GSVA 自身拒绝推断，但此前 score handoff 可进入通用 limma；共享回归和 GSVA smoke 增加实际 handoff 消费回归 | 添加 score_inference_pending 及共享 OS_OWNER_DECISION_PENDING 拒绝；已修复（`f212b90`） |
| limma-dupcor | 2、3 | 会将错误结论写入论文 | `scientific-regressions-final.log`：重复测量行数不能代替独立 correlated unit 数；两组独立单位数不足时拒绝 | 以独立 block 单位检查复制；QC、canonical n_group1/n_group2、result JSON 及报告使用独立单位数，观测文库数单独保留；Yoruba 重放 JSON 为 33/41 独立单位、40/46 文库，完整结果表逐字节不变（dupcor-counts-validation.log）；已修复（`8fa0403`、`9056bc6`） |
| limma-camera 的重复测量路线 | 2、3 | 会将错误结论写入论文 | 直接 expression 的原检查只数样本行；Yoruba 派生样本表把每组 cellline 设为一个单位仍可进入 fry。`scientific-regressions-final4.log` 两项独立单位检查通过；实际 CLI 回归加入 smoke | direct 与历史 limma handoff 均检查独立 block 单位；handoff 保留显式 technical_batch 角色，避免把技术批次当生物单位；已修复（`8f419dd`） |
| deseq2-lrt | 2、3 | 会将错误结论写入论文 | `--group-col` 原本同时控制显示和加性模型复制检查，能隐藏被检验因子的 singleton 水平；增加 fission 派生样本表回归 | 独立检查 full 相对 reduced 引入的因子，不允许显示分组绕过；已修复（`5d5925e`） |
| muscat-pseudobulk | 2、3 | 会将错误结论写入论文 | `muscat-zero-probe.log`：Kang B-cell 派生数据中，一个零文库样本在 native 复制检查之后被移除，仍输出 P 值；`replicate-fixes.log` 显示模块已拒绝 | 对每个实际拟合数据对象复核保留的生物样本，少于两例/条件时不发布结果；已修复（`3a59cb0`） |
| cellchat-communication | 2、3 | 会将错误结论写入论文 | `owner-probes.log`：humanSkin 两条件各取 200 个细胞，native group.dataset 返回 127 个 marker 行，同时警告全部细胞被当作 sample1；`replicate-fixes.log` 验证拒绝 | do.DE 时拒绝 dataset 比较及偏离声明 cluster-col 的 group.by；回归含 JSON/RDS 入口，并封堵 1/"TRUE" 的 R 逻辑强制转换绕过；已修复（`529fde7`） |
| scanpy-cluster | 4 | 误导 | `hvg-before.log` 验证 seurat_v3 接收到 log-normalized X；`hvg-after.log` 两种 v3 flavor 均与 native raw-count replay 完全一致 | v3/v3_paper 使用保留的 counts layer；默认 flavor 不变；已修复（`f212b90`） |
| seurat-cluster | 1、5 | 会将错误数值写入论文 | alternate HVG method、批次 HVG 并集可使实际 HVG 数不同于请求数；native normalization override 原先仍被称为 LogNormalize | state 与报告使用实际 VariableFeatures 长度及实际归一化方法；绑定测试覆盖；已修复（`f212b90`） |
| seurat-integrate | 1、5 | 会将错误数值写入论文 | HarmonyIntegration 使用完整输入 PCA，而 graph/UMAP 可以只使用较少维度，原报告把两者混为同一 dims | 报告实际整合维数；另述 graph/UMAP 子集，新增不等维数回归；已修复（`5d5925e`） |
| singler-annotate | 1、4 | 会将错误标签写入论文 | native prune-get-thresholds 返回每标签阈值，旧代码把数值向量当作逐细胞剔除下标 | 拒绝不兼容返回模式，保留原始剪枝行为；新增 smoke 拒绝回归，涵盖 true、1 和 "TRUE"；已修复（`529fde7`） |
| immunedeconv-infiltration | 1、2 | 会将错误方法写入论文 | MCP-counter method-args 可覆盖 log_transform、特征类型和已校验参考；log2TPM 仍被报告为 non-log TPM，ESTIMATE 输出被称作 cell types | 保护尺度/参考参数，报告实际输入尺度及 score/purity 行类型；新增原始数据与 log2 派生数据回归；已修复（`9051259`） |
| seurat-modulescore | 2 | 误导 | 用户 GMT 的来源检查与 AUCell 不一致 | 拒绝路径及 GMT 名称/来源字段标记的禁用集合；测试仅使用虚构名称，不含禁用内容；已修复（`9051259`） |
| deseq2-qc | 1 | 会将错误方法写入论文 | draft 称距离使用 PCA 的 same values，实际 sample_distances 使用全部转换后保留特征 | 明确区分 PCA 高变特征子集与距离所用的全部保留特征；已修复（`5d5925e`） |
| limma-camera 的单集合 roast | 1 | 会将错误方法写入论文 | 原始 UpOrDown P 被通用模板称作 BH adjusted P | 单集合 draft、barcode 图注、bar 坐标轴/图注/阈值元数据明确写 raw UpOrDown P；不修改数值列。baseline 新回归先失败，修复后的实际 --spec 重放通过（roast-labels-validation.log）；已修复（`8fa0403`） |
| wgcna-network | 1、5 | 会将错误方法/阈值写入论文 | 非 Pearson 相关仍使用 Pearson 图注；soft threshold 图线与图注固定 0.85，忽略 native RsquaredCut | 模块内图注/参考线使用实际相关设置与阈值；共享回归验证 0.7 与 Spearman；已修复（`f212b90`） |
| batchelor-integrate | 1、5 | 会将错误维数写入论文 | before UMAP 使用 n-pcs，图注原先使用校正后的 umap-dims | before/after 分别记录实际维数；已修复（`9051259`） |
| slingshot-trajectory | 1 | 误导 | tradeSeq 以细胞为观察单位；原生成 Methods 缺少推断范围说明 | 明确说明探索性细胞层面关联，不等同于生物重复的条件效应或因果调控；已修复（`9051259`） |
| slingshot-trajectory 的 trajectory-rds | 2、5 | 会将错误数值写入论文 | `trajectory-alignment-before.log`：将 2660 个输入细胞倒序后仍接受旧 trajectory，输出完全相同的 pseudotime 矩阵，导致细胞与时间错配；after 日志确认已拒绝 | 重用前精确核对所选 embedding 的数值及行顺序；增加实际 CLI 倒序拒绝回归，正常锚点数值不变；已修复（`529fde7`） |
| sc_bioc_io.R | 1、2 | 误导 | 补充 JSON 中覆盖受保护参数的条目原先被静默忽略，却仍可能出现在参数报告 | 改为 OS_CONFLICTING_PARAMETERS；回归覆盖受保护输入和控制项；已修复（`ea011f6`） |
| 单细胞共享报告、mcp/publication.py | 5 | 误导 | 初次出版扫描：AUCell 的细胞数、集合数、aucMaxRank 无 result JSON 对应；门禁还遗漏根目录 results.json | 添加可机读的结果摘要，并把 AUCell 被过滤后的实际评分集合数与加载集合数分开；门禁读取根目录 results.json；14 个出版门禁测试通过；已修复（`5d5925e`） |
| limma-array、limma-dupcor、limma-voom、deseq2-wald、edger-qlf 的 volcano 图注 | 1、5 | cosmetic | limma-dupcor rnatreat 图实际只有 2 个标注、0 个下调基因，图注却断言每方向标注 5 个；同一共享生成句用于这些 bulk 报告 | 仅当某方向不足请求数时改为 Up to，保留实际标签集合与数值；新增 rnatreat 回归；实际 CLI 重放图注通过，结果表和 PNG 逐字节不变（volcano-cap-validation.log）；已修复（`f4a9c64`），最终 smoke 已通过 |

| wgcna-network 非标准相关 | 1、3 | 会将错误 P 值写入论文 | `owner-probes.R` / `owner-probes.log`：cosine 相关进入统一的 corPvalueStudent；权重/缺失值也使用总样本数 | 所有者事项：建议限制推断配置，其他设置只作描述；详见下节 |
| cellchat-communication 外部对象分组 | 2、3 | 会将错误结论写入论文 | `cellchat_communication_core.R:4` 拒绝显式 alternate group，但无可信样本/聚类谱系时无法验证外部 cluster-col 的语义 | 所有者事项：建议决定是否强制样本列及可信聚类谱系；详见下节 |

## 需所有者裁决

1. **WGCNA 非标准相关的推断范围（类别 1、3；可能写入错误 P 值）。** `owner-probes.R` 使用 FemaleLiver 锚点的 134 个样本和前三个基因，`wg_cor(..., cor-cosine=true)` 被接受，随后同一生产路径的 `corPvalueStudent` 返回 `0.35754, 4.0959e-05, 0.97968`。代码还支持权重和成对缺失值，而 P 值路径统一使用总样本数。建议把可作推断的相关设置限定为有明确校准依据的配置；其余选项仅提供描述性相似性，或由所有者指定正确的检验。未擅自选择新的统计方法或放宽断言。
2. **外部无样本谱系对象的 CellChat 分组真实性（类别 2、3）。** 已封堵显式 native dataset/alternate-group 入口；但直接外部对象的 `cluster-col` 仍是调用者的声明。在没有样本标识和可信上游聚类记录时，程序无法区分一个被命名为“cluster”的条件列与真实细胞标签。建议所有者确定直接入口是否必须提供样本列/可信聚类谱系，再应用 marker lane 的同一逐样本分组规则；不伪造样本标识。

## 重现环境与入口

镜像实际 ID：R `sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7`；Python `sha256:dedf331e03f3832cbd069bd3c75af3ac1a6f4f1daf88eea6f72204a3b114b96f`。

```bash
OMICSTAT_TEST_ARTIFACTS=/home/<user>/omic-sol61/astra_scan/sealed-r bash env/test.sh
OMICSTAT_TEST_ARTIFACTS=/home/<user>/omic-sol61/astra_scan/python-suite bash env/py/test.sh
# 上一入口在 Python 镜像内执行 bash tools/run_tests_py.sh。
OMICSTAT_MCP_SCRATCH=/home/<user>/omic-sol61/astra_scan/e2e/mcp \
OMICSTAT_RUNS_ROOT=/home/<user>/omic-sol61/astra_scan/e2e/runs \
OMICSTAT_E2E_PYTHON=/home/<user>/omic-venv/bin/python bash env/py/test_e2e.sh
```

E2E 此次另以 lane scratch 指定产物目录，具体环境见 `e2e-console.log` 与 `env/py/e2e_report.txt`。每个单独的 R 聚焦重放使用 scratch 的 `run-r.sh`：`docker run --rm --network none --user "$(id -u):$(id -g)"`，只挂载本工作树、lane scratch、只读验收库与只读 Git common dir。

## 验证记录与初次失败说明

- 首轮完整 R 命令的客户端会话返回 143，但随后确认 Docker 内的测试继续执行。曾误启动一次重复运行；已通过同 UID 和精确 final-r 挂载路径验证进程身份，按具体 PID 停止重复运行，并复查无残留。首轮已完成到 WGCNA，但在分析 smoke 循环之后发生 shell 语法错误而中断：运行中的 harness 曾新增一行共享回归，错误位置与 Bash 后续读文件的偏移错位相符；当前脚本 `bash -n` 通过。该轮及重复运行均不计为完整通过；第二轮 verified-r 在 harness 更新后启动。首轮日志保留在 `baseline-console.log` 和 `baseline/logs/`。
- 首轮新增回归还揭示单集合 roast 图注、dupcor JSON/拒绝优先级问题，均已修复。Seurat 新增绑定测试最初误把 RC 与需要 log 值的 mean.var.plot 组合，已拆成 LogNormalize/mean.var.plot 和 RC/vst；原生图控制及 SCT 模型断言全部保留，聚焦重放通过（`seurat-binding-fixed.log`）。
- 第二轮 R 在 limma-array 的 container golden 检查发现共享重复单位修复给普通 array JSON 额外加入了四个字段；与首轮逐字节比较确认仅结果 JSON 增加字段，数值表和 PNG 不变。已将独立单位/观测计数字段限定为两种计数确实不同的重复测量路线，保留计数相同时的原有输出契约；不更新 golden。独立 limma-array 全 smoke 已通过；该轮最终完成 184 个命令，只有这一项失败，其余分析、静态与 MCP 检查通过。最终整套验收结果见下文 `sealed-r`。
- 转换回归 `conversion-final2.log`：全部通过，零跳过。最初两项新增谱系检查失败的日志同样保留。
- Scanpy 两种 counts-based HVG flavor 的 native replay 通过；调用注册检查为 99 call sites、0 registry problems、0 default-drift problems。
- 出版门禁聚焦测试：锁定 R 镜像的 `/opt/omicstat/venv/bin/python3 mcp/test_publication.py OmicsPublicationGateTests`，14 tests，OK。主机 Python 缺依赖的尝试不计作验收结果。
- 主机 E2E：`OMICSTAT_E2E_PYTHON=/home/<user>/omic-venv/bin/python bash env/py/test_e2e.sh`（另设本 lane scratch/run 路径），99 assertions，99 passed，0 failed；3 项 native-host 检查因无 Rscript/native 环境明示跳过，R/Python 两个锁定容器均实际执行。日志 `e2e-console.log`。
- 额外 CLI 拒绝探测 `additional-refusals.log`：5 PASS；CellBench 派生输入的 speckle 单样本/组在 direct 与 from-run 都拒绝；JSON sample 覆盖及 spec/RDS group 覆盖均不在参数白名单；Monocle 的 RDS root 仍不能省略 root rationale。
- 已通过工具重新生成改动模块的 R/Python locks，并运行 `--check`；35 个范围内模块均已有 --check OK；R/Python 分别在对应镜像检查，汇总见 lock-check-summary.json。最初误用 R 镜像检查 Python lock 的 environment 差异已由正确镜像的 OK 记录澄清。
- 已通过 git diff 核实无 golden 修改。没有手写 golden、lock 或验收数值。

## 未发现模块自身缺陷的清单

本轮未发现模块自身缺陷的 12 个模块：clusterprofiler-compare、clusterprofiler-ora、maftools-landscape、monocle3-trajectory、scanpy-qc、scanvi-annotate、scater-qc、scran-cluster、scvi-integrate、seurat-qc、speckle-propeller、sva-batch。部分模块受益于共享谱系/参数保护修复，不能把“模块自身无缺陷”理解成共享层无问题；SVA A6a 按任务保留既有已知差异。

## 最终 publication gate 与图像核对

对 35 个模块最终 smoke 的代表性锚点运行 `mcp/publication.py` 的 `_text_coverage` 和 `_case_flow_check`；R 使用 `sealed-r`，Python 使用已通过的 `python-suite`，Slingshot 选择含 tradeSeq 的锚点。共扫描 **1438** 个数值，自动未覆盖 **165** 个，病例流不一致 **0** 个。未覆盖条目均人工追溯到表格、对象、图形 JSON、实际参数或格式/标识；没有把这些条目伪装成自动覆盖。原始机器结果见 `publication-sealed-r/*.json`、`publication-python/*.json`；逐项人工证据见 `publication-manual-traces.txt`。

| 模块 | 扫描数值 | 自动未覆盖 | 人工追踪依据 | 最终 smoke 日志 |
|---|---:|---:|---|---|
| aucell-score | 8 | 2 | GPL-3 许可标识 | `sealed-r/logs/021.log` |
| batchelor-integrate | 37 | 0 | 全部自动覆盖 | `sealed-r/logs/022.log` |
| cellchat-communication | 25 | 0 | 全部自动覆盖 | `sealed-r/logs/023.log` |
| clusterprofiler-compare | 33 | 1 | max-size=500 参数 | `sealed-r/logs/024.log` |
| clusterprofiler-gsea | 70 | 5 | ridge 9 集合及 P 值科学记数法 | `sealed-r/logs/025.log` |
| clusterprofiler-ora | 24 | 1 | max-size=500 参数 | `sealed-r/logs/026.log` |
| deseq2-lrt | 32 | 6 | 27 截断值、±2、50 行与 12 上限 | `sealed-r/logs/027.log` |
| deseq2-qc | 18 | 2 | vst nsub=1000 原生调用 | `sealed-r/logs/028.log` |
| deseq2-wald | 49 | 8 | 625/341/11870 行及热图设置 | `sealed-r/logs/029.log` |
| edger-qlf | 84 | 20 | 12 样本、20 标签、500 特征、50 行、9 截断值及原生阈值 | `sealed-r/logs/030.log` |
| fgsea-prerank | 34 | 9 | 5+5 展示集合、原生参数、版本/记数法 | `sealed-r/logs/031.log` |
| gsva-score | 48 | 19 | 集合大小/中位数64、24展示样本、38/56/26/53分组及原生参数 | `sealed-r/logs/032.log` |
| immunedeconv-infiltration | 15 | 2 | threads=1、seed 参数 | `sealed-r/logs/033.log` |
| limma-array | 44 | 1 | 42877 非对照探针 | `sealed-r/logs/034.log` |
| limma-camera | 43 | 2 | 86 样本行及 SHA-256 标识 | `sealed-r/logs/035.log` |
| limma-dupcor | 51 | 5 | 12 样本及每方向最多5标签 | `sealed-r/logs/036.log` |
| limma-voom | 67 | 12 | 9 样本、17061 趋势点、51.37百万中位文库及原生参数 | `sealed-r/logs/037.log` |
| maftools-landscape | 33 | 5 | 192 TMB 行、300 配对及 seed | `sealed-r/logs/038.log` |
| monocle3-trajectory | 8 | 2 | 5576 有限/612 不可达时间 | `sealed-r/logs/039.log` |
| muscat-pseudobulk | 31 | 20 | 8簇逐行计数、16样本/每组8例、436..2880细胞 | `sealed-r/logs/040.log` |
| scanpy-cluster | 46 | 0 | 全部自动覆盖 | `python-suite/logs/015.log` |
| scanpy-qc | 35 | 0 | 全部自动覆盖 | `python-suite/logs/023.log` |
| scanvi-annotate | 26 | 0 | 全部自动覆盖 | `python-suite/logs/027.log` |
| scater-qc | 13 | 0 | 全部自动覆盖 | `sealed-r/logs/042.log` |
| scran-cluster | 50 | 16 | pool-sizes 21..101 原始参数串 | `sealed-r/logs/043.log` |
| scvi-integrate | 43 | 0 | 全部自动覆盖 | `python-suite/logs/031.log` |
| seurat-cluster | 65 | 0 | 全部自动覆盖 | `sealed-r/logs/045.log` |
| seurat-integrate | 47 | 0 | 全部自动覆盖 | `sealed-r/logs/046.log` |
| seurat-modulescore | 35 | 4 | 独立重数每组86..201细胞 | `sealed-r/logs/048.log` |
| seurat-qc | 58 | 5 | 对象中13个线粒体特征 | `sealed-r/logs/049.log` |
| singler-annotate | 33 | 3 | 10个参考得分列及SHA-256标识 | `sealed-r/logs/050.log` |
| slingshot-trajectory | 128 | 3 | 1641有限/1019缺失，genes=1:240参数串 | `sealed-r/logs/051.log` |
| speckle-propeller | 8 | 6 | 6样本/每组2例、225..902细胞 | `sealed-r/logs/052.log` |
| sva-batch | 32 | 3 | 模型公式-1及PCA 500参数 | `sealed-r/logs/053.log` |
| wgcna-network | 65 | 3 | quickCor=0、detectCutHeight=0.995、cor quick=0 | `sealed-r/logs/054.log` |

已打开本 lane 保留的 **1763 个 PNG 文件**；按 SHA-256 区分的 **329 种内容**均完成目视检查，相同字节的副本按同一内容复核。清单及打开记录为 `png_inventory.json`、`opened-png-paths.json`、`viewed-png-hashes.json`。该计数不包含测试自行清理的临时图像。

## 最终整套结果与范围核对

- `bash env/test.sh`：**184 个命令，ALL PASSED**；最终原始输出 `sealed-r-console.log`，详细日志 `sealed-r/logs/`。SVA 仅保留任务允许的两项 A6a `KNOWN-FAILING`（日志末尾会重复汇总）；新增科学拒绝回归 31 项通过，转换检查零跳过。
- R 套件内的 publication 测试：74 项、2 项明示跳过；MCP 客户端：83 assertions、83 passed、0 failed、3 项环境相关跳过。主机 E2E 另行验证两个真实容器入口。
- `bash env/py/test.sh` 在锁定 Python 镜像内执行 `bash tools/run_tests_py.sh`：**31 个命令，ALL PASSED**。
- `env/py/test_e2e.sh`：**99 assertions、99 passed、0 failed、3 项明示 native-host skip**；两个锁定容器均实际执行。
- 35 个范围内模块的 lock 均 `--check OK`。无 golden 修改（0）；三个排除模块、vendor、验收数据、配置及共享绘图文件均未改动。`git diff --check 4e6287c` 通过。
- 表中 23 条问题记录已修复；两项需要科学判断的问题保留给所有者，并给出证据和建议，未替所有者选择方法。

提交由外部 helper 生成，本 lane 未调用 git commit。表中提交号定位该修复的相关代码变更；回归、说明及共享层可能跨相邻 helper 提交，完整范围为 `4e6287c..fix/astra-scan`。
