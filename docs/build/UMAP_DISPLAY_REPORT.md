# UMAP 展示工作流报告

分支：`feat/umap-display`。本 lane 不合并到 `integrate/final`，不操作 release checkout，不自行 commit；提交由外部 helper 根据 worklog 最后一行完成。

## 实现与设计

- `scvi-integrate` 新增 `--latent-from-run`，校验来源 run、细胞子集及物种/注释状态，逐细胞对齐 `X_scVI` 后跳过训练，重建 scVI 图与 UMAP；可选 `--leiden-resolution` 与 `--scvi-cluster-col` 必须同时提供，拒绝覆盖已有列，保留原 `--cluster-col` 不变断言。
- `scanpy-cluster --use-rep` 使用已有表示构建邻域、Leiden 和 UMAP，跳过重算 PCA；原默认路径保持。归一化与 HVG 仍用于保留表达层及诊断；复用路径使用专门的 Methods/Results 和 representation 表，明确未重算 PCA/scale，维数守卫只适用于实际 PCA 路径。默认 PCA 的断言、表和数值 golden 保持。
- `os_embedding` 接收 Python 提供的 `label_xy`；默认全组中位数不变。按组 DBSCAN 的最大岛中位数为显式选项；没有密度岛时回退到全组中位数并记录。R 不新增依赖。最大岛用完整输入 embedding 计算，先于绘图 cap；因此抽样不会重新定义最大岛。
- Python 公共 `--colour-registry` 写入 run 内 registry，并作为路径传给 `FigureRequest`。颜色来自用户指定或共享 R token；已有登记不改变，完整预设可超过 23 类。
- `--display-max-per-group` 仅抽样 figure_data，分析对象和下游表不变；图的 os_meta/spec/caption 记录 cap、绘制数量与原始分母，并写明 display only。新增尺寸选项支持长标签。
- `scanpy-annotate` 用 Scanpy 原生 aggregate 计算 panel 均值，保留 marker 证据；`--label-map` 是用户的描述性命名决定。未映射簇保留为显式 unresolved 标签，不自动删除或声称验证身份。
- `scanpy-purity` 报告非自身邻居中同标签比例、UMAP 邻居比例、DBSCAN 岛大小与 isolated/retained 标志，输出显式 rerun 列表，不隐式 subset。
- `scanpy-ingest` 用 `sc.tl.ingest` 投影 query；参考 UMAP 转为 float32/C contiguous 时也必须保持值完全不变，并在 ingest 后断言完全不变。输出 query AnnData、参考坐标表、逐 query 的参考邻居同标签比例及合并展示表；合并表保留 reference 中未出现的 query 标签，并清除未使用类别，避免丢失名称或产生幽灵标签；后续固定参考投影继续使用原 reference run。参考图必须显式声明共同 obsm 表示；拒绝自动 PCA/raw-X fallback，以免错误比较不同空间。query/reference 表示必须来自同一模型/基底，独立拟合的 PCA/scVI 不可混用。

为保留原 scvi-integrate 输入契约，复用路径仍要求 batch/cluster 列、counts、未校正图及至少两个 batches；旧 CLI 的 max-epochs 仍必填，但该预算和模型构造/训练选项不执行，复用 Methods/caption 明确说明。此次没有扩展成任意 AnnData latent 导入器，也没有自动命名或自动选择清理阈值。为满足本 lane 的非 root 容器规则，MCP 两个 provenance probe 在 Linux 上显式传入调用者 UID/GID；不改变计算命令或包版本。

三个模块通过 `tools/new_module.py --python` 建立，前缀 YA/YP/YG 来自 qc_prefixes。Publication registry 补齐三条记录，声明描述性命名、诊断分母与 display-only 边界；精确集合断言保持。已补齐 SKILL、六种 references、调用登记、smoke、router、参考服务 method map/source inventory，以及 SUITE/CONVENTIONS 展示规则。

## 科学边界

纯度清理、显式 balanced cell-list 与 ingest 均在 handoff 和 AnnData 内嵌状态保存 `display_only: true`；通过 QC/聚类/整合继续传递，复用 display latent 也不会清除标记。Python marker 输入校验（包括当次 cell-list）与 R inference handoff/backend 输入校验在计算前拒绝 `OS_DISPLAY_ONLY_INPUT`，禁止用于比例、pseudobulk、marker 或 DE。比例与表达推断必须回到未经展示清理的队列。

纯度 cutoff、DBSCAN eps/min_samples/min_size、每组 cap 和可选 Leiden resolution 没有数据导出的默认值。SKILL 要求先查询 reference_advise/reference_search。图抽样与对象 cell-list 选择有不同语义：前者不改变分析队列，后者明确标记展示用途。

## 验证记录

已观察的锁定签名数：scvi-integrate 7，scanpy-cluster 8，scanpy-annotate 1，scanpy-purity 5，scanpy-ingest 4；calls/default-drift 初检全部零问题。三个新模块的 numerical smoke、独立 native oracle、确定性 replay 和脚本生成 golden 已通过；golden 只由各模块自身 smoke 脚本生成，既有 golden 不重写。最终 full Python suite 43 个命令全部通过，补充 contract tests 38/38 通过（4.38s）；pytest 缺失由 scratch-only wheel 安装补齐，科学包/image 未更改。八个 Python seals 已用实际 pinned image ID 经标准生成器重建，逐一 `--check` 全通过。

Reference 本地配置保持原 38 targets 顺序/资料，仅追加 3 个 display targets；生成器扩展 6 个配置的精确校验，13 个 config/provenance 和 122 个 app unit tests、offline reference MCP 均通过。新 discovery profiles 为 weak，无筛选语料或已策展证据；未接触部署服务。基线 73 个 golden 文件逐字节比对均未改变。 34 个既有 R module_lock 已用实际锁定 image ID 完整 `--check` 通过；omicstat-selftest 在 smoke 通过后由标准生成器更新旧 image digest，没有改其分析源码或 golden。

`test_figures.R`（含多岛显式坐标、display metadata/caption、完整预设超过 23 类）通过。33 张原 gallery PNG 已重新生成并逐图通过 contact sheet 打开检查；原 PNG/spec 字节保持，PDF 时间戳变动已恢复。新增多岛 gallery PNG 已打开。既有 enrichment network gallery 有较密集标签，属于本次之前的输出，未为此修改默认布局。

最终视觉审计覆盖 1,188 个保存的 PNG 路径、331 种不同内容：逐文件打开解码，不同内容逐图或 contact sheet 视觉检查，相同 SHA 的路径对照已审图；另有 34 张 gallery PNG 全部打开。manifest 为 scratch `visual/reviewed_png_hashes.json`，最终检查无 pending，记录路径及字节哈希均真实匹配。MCP 两张新 synthetic 图仅用于 wiring 测试，未作生物学解读。

最终 ASCII router 的新盲读保持原 133 题并新增 6 题：before first-choice 124/139（89.21%）、expected-or-acceptable 133/139（95.68%）；after 129/139（92.81%）与 139/139（100%），通过 90%/98% 门槛。原 133 题的 primary 为 before 124/133、after 123/133，acceptable 为 before/after 均 133/133；新增 6 题为 before 0/6、after 6/6。按既有协议将一步 pipeline 与裸模块等价；out-of-scope 的不同措辞逐项审阅为相同类别。早先含中文别名的 router 盲读为 after 130/139、138/139，唯一 R116 额外插入 SingleR；ASCII 审计移除新行中文别名后，以全新 reader-only 会话重测，R116 为可接受的后端链。没有更改期望、门槛或消歧规则；不同盲读仍有波动，不声称科学正确性已由路由验证。最终答案、interim 答案、精确 router 哈希及可复算评分保存在 `docs/build/routing_umap/`。

验收命令和可复核结果如下，日志均位于 `/home/<user>/omic-sol61/umap_display/logs/`：

| 检查 | 观察到的结果 | 日志 |
|---|---|---|
| 完整 Python suite | 43 个命令 ALL PASSED，包含默认 golden、reuse/native oracle、calls/defaults/flag docs | `py_suite_verified.log` |
| 补充 contract tests | 38/38 通过，4.38s；pytest 仅装到 scratch，未改 image/科学包 | `sc_contracts.log` |
| 完整 R suite | 196 个命令完成；34 个 R smoke 通过；唯一未过项为新模块缺少 publication registry 记录，修复后相关四命令全部通过 | `r_suite_final.log`、`r_publication_retry.log` |
| Publication/MCP R 重测 | 43 条 module records、50 个唯一 rule IDs；package identity 3 tests、publication 74 tests；native MCP 83/83 assertions | `r_publication_retry.log` |
| Host MCP e2e | 99/99 assertions，0 failed；实际 Python container → R container 渲染与版本/immutable image ID 通过 | `mcp_e2e.log` |
| 全部现存 module locks | 34 个 R locks 与 8 个 Python locks，合计 42 个，全 `--check` 通过；Python 使用标准生成器及实际 image ID 重封 | `r_locks_final.log`、`py_locks_final.log` |
| Lint/front matter | R lint 159 文件零问题；44 个 SKILL front matter 零问题；83 个变更英文文件 ASCII 通过，六个旧 SKILL 的原非 ASCII 行完全保持 | `r_suite_final.log`、`ascii_verified.log` |
| Reference 配置 | 13 config/provenance、122 app unit tests、offline MCP 通过；6 个配置精确生成校验 | `reference_config_final.log`、`reference_app_tests.log`、`reference_stdio.log` |
| 不变性 | 73 个 canonical baseline goldens + 1 个历史 fixture manifest；66 个原 gallery PNG/spec 文件，全字节不变 | `existing_golden_bytes_final.log`、`gallery_bytes_final.log` |

保留所有失败日志，不把早先失败改写为绿灯：首轮 R 的两个 inventory 数量检查已精确修正并在最终完整 R 中通过；最终 R 的 publication registry 缺项用真实三条记录补齐，原集合/唯一性/必需字段断言不改。四个受影响的 publication/MCP 命令原样重测通过，没有再重复已通过的数值 fit。首两轮 Python 的新 reuse fixture 参数和仍生效的 PCA-only 守卫问题已修复，最终 43 命令全通过，旧数值断言和 tolerance 未改。Host MCP 首轮因 test scratch 不在 configured run root 而拒绝（计算前）；将两个测试路径对齐后 99 assertions 全通过，没有放宽路径白名单。

跳过项的范围明确：R image 中的八个 Python 数值 smoke 因不属于 pinned Python 环境而跳过，均已在完整 Python suite 真正执行；R MCP 缺少 Docker/native Python，host MCP 缺少 native R/Python 环境，分别由另一侧的真实 native R/container 路径覆盖。R suite 无 missing R-package skip。SVA 保留两个已接受的 A6a known-failing anchors；此次没有修改该模块或它的 assertion。

## GP6 实例

原输入 19,911 cells。显式 QC 后 17,948 cells、399 samples；首轮 scVI 使用 2,000 个 HVG、10 维 latent、100 epochs。scVI 图 Leiden 得到 38 簇；panel/命名表从 reference 的协调员注释推导，依据 cell membership 适配当前簇，未把来源研究 cell_type 当作身份验证。未解决的 1,972 cells 在 annotation 对象中保留。

第一次 purity flags 3,308/17,948，导出 14,640 retained IDs 后显式 rerun。QC 后保留 121/122 个在 reference 注释中标记 Platelets 的输入细胞。第二次 purity flags 1,005/14,640，显式 rerun 保留 13,635 cells；最终 purity/isolation pass flags 427/13,635，导出 13,208 retained IDs。Balanced 参考 4,225 cells、354 batches，逐 ID 复用 round-2 latent 而不训练；ingest 添加 3,698 cells，总展示 7,923 cells，reference_max_abs_diff = 0。最终 23 个 label 均有密度岛（无 fallback），116 个 Platelets 位于可见独立岛。第一轮 rerun 正确拒绝了已被 QC 删除的旧 feature IDs；改用该轮 cluster 输出的 HVG 列表，从已完成且哈希通过的步骤继续，不重做已完成计算。

本例显式使用两种 purity cutoff 0.6、UMAP 15-NN、清理 DBSCAN eps 0.35/min_samples 5/min_size 10，并排除 unresolved；这些是实例选择，不是模块默认值。Balanced 每类最多 200，填充后每类最多 500；复用 latent 的 UMAP 使用 n_neighbors 30/min_dist 0.5/spread 1.5。标签 eps 取参考 embedding span 的 2.5%，min_samples 5；双栏宽、160 mm 高。可复查运行代码：`docs/build/umap_display_e2e.py`。

完整 scratch：`/home/<user>/omic-sol61/umap_display/`，实例：`e2e/`，日志：`logs/`。参考 CSV 重建比较图：`e2e/reference_comparison/reference_map.png`（已打开）。最终 PNG：`/home/<user>/omic-sol61/umap_display/e2e/ingest/figures/umap_celltypes.png`（已打开）。岛结构、标签和 Platelets 可见性与参考图可比；坐标布局不同，未追求与协调员训练结果逐点重合。所有名称保留描述性语义。

## 待所有者审阅

- 命名是描述性决策，需审阅 panel 和适配后的 `e2e/label_map_evidence.csv`。
- 新 display/annotation 模块仍需独立 S3 审阅；sealed 不等于论文 ready。
- R116 在 interim 盲读额外加入 SingleR、最终读者则给出可接受的后端链；后端比较题的措辞与期望是否需要更明确，留给所有者复核。
