# omicstat 实现规格 v2：按 medstat 现行方式实现的生物信息分析 MCP

> **2026-09-27 更新**：§0 中"不引入 Python 分析引擎；不加第二个容器；不新增 MCP 工具"的前两条，由 ENGINEERING_PLAN 第十部分（Python 通道，scverse）在其限定范围内取代；"不新增 MCP 工具"仍然有效。
>
> **2026-09-25 更新**：模块划分、单细胞生态（Seurat 与 Bioconductor 两线并行）、参考文档采集、Rscript 冻结、skill 与路由构建，以 `ENGINEERING_PLAN.md` 为准；本文件只保留基础设施分叉部分（§0、§3、§4、§5、§7）的效力。


> **本项目只有一条总纲：把 medstat 现行版（`medstat-55692f7`）整套分叉过来，只替换分析模块。** 基础设施、MCP、出版规则层、合同、发布门禁、参考伴随服务、建设流程、注册方式，全部照搬 medstat 现有做法，不另起架构，不"顺手改良"。
> 读者：负责实现的 agent。你负责实现和自测，不做产品取舍。遇到必须偏离 medstat 做法的地方，写进 worklog 的"待裁决"一节，由用户或主会话决定；不得自行另起一套。

**权威参考（只读，一律不许修改）**
- `E:\claude workspace\skills-dev\medstat-55692f7\`：分叉源。包括 `SUITE.md`、`bin/`、`mcp/`、`skills/_shared/`、`skills/<27 模块>/`、`skills/medstat/SKILL.md`（路由器）、`research/`（出版语料、审计包、报告指南注册表）
- `E:\claude workspace\skills-dev\medstat\docker\`：`medstat-r` 镜像的 Dockerfile 与 `install_packages*.R`（容器构建方式）
- `E:\claude workspace\skills-dev\medstat\acceptance\replication-sop.md`：范本复刻制 SOP（建设流程）
- `E:\claude workspace\skills-dev\medstat-reference\`：参考伴随服务 v2（`DESIGN-v2.md`、`GT103_DEPLOYMENT.md`、`medstat_entry.py`）
- `E:\claude workspace\skills-dev\medstat\research\skillmd-craft\SYNTHESIS.md`：SKILL.md 撰写规范 v1

---

## 0. 分叉对照表（先读这张表）

| medstat 现行组件 | omicstat 对应做法 | 改动范围 |
|---|---|---|
| 仓库 `skills-dev/medstat-55692f7/`（SUITE.md、bin、mcp、research、skills） | 新仓库 `skills-dev/omicstat/`，目录结构一模一样 | 只改名 |
| 全 R 引擎，每模块一个 `scripts/run_*.R` | **同样全 R**（单细胞也用 R 生态，见 §2），每模块一个 `run_*.R` | 模块内容替换 |
| 单一容器 `medstat-r`（docker/Dockerfile + install_packages*.R，按层追加安装） | 单一容器 `omicstat-r`，构建方式相同（按层追加，老层不动以便缓存） | 包清单替换 |
| `bin/medstat-r-route.ps1`（Windows 路径翻译、`/ws` 挂载、`MEDSTAT_*` 环境变量透传、`MEDSTAT_R_NATIVE=1` 走本机） | `bin/omicstat-r-route.ps1`，逐行复制后只改名称和镜像名 | 只改名 |
| `_shared/scripts`（effect_table / forest / render_md / render_docx / report_engine / spec / var_typing / survey_design / validate_effect_table_cli） | 原样复制；新增 `feature_table.R` 与 `validate_feature_table_cli.R`（组学结果表，写法照抄 effect_table） | 新增两个文件 |
| `_shared/publication`（universal_rules_v1.json + module_rules_v1.json，数据式规则，不选 estimator） | 同结构：通用规则基本沿用，模块规则为 omicstat 各模块各写一条记录 | 规则内容替换 |
| `_shared/schemas`（study_contract / publication_manifest / publication_review / literature_evidence，v1） | 原样复制四个 schema；study_contract 的必填字段按 §4 做组学映射，**字段名不变** | 字段含义映射 |
| MCP `mcp/server.py`（5 个工具）+ `publication.py` + `package_identity.py` + 测试 | 逐文件分叉，工具名把 `medstat_` 换成 `omicstat_`，行为不变 | 只改名 + 模块注册 |
| 发布门禁 RG-01～RG-12（正向数值矩阵、盲测、publication core、MCP stdio 验收、package identity……） | 同一套门禁，逐条照做 | 数据集替换 |
| 参考伴随服务 `medstat_reference`（GT103 Docker + SSH stdio，10 工具）+ 包装入口 `medstat_entry.py` | `omicstat_reference`（同一代码库、独立实例、独立数据卷）+ `omicstat_entry.py` | 期刊白名单与检索画像替换 |
| 路由器 `skills/medstat/SKILL.md`（路由表、消歧树、流水线配方、标签总表、MCP 一节） | `skills/omicstat/SKILL.md`，结构一样 | 内容替换 |
| 注册：Claude `.mcp.json` + 29 个 skill junction；Codex `config.toml` | 同样方式注册 `omicstat` 与 `omicstat_reference` | 由主会话或用户执行 |
| 建设流程：范本复刻制 S0–S5；全局一次构建 → 一次审计（GPT Pro 或独立子代理）→ 一次集中整改 → 一次最终验证 | 完全相同 | 不改 |

**明确不做的事**：不引入 Python 分析引擎；不加第二个容器；不新增 MCP 工具（例如后台任务工具）；不另起合同格式；不改 medstat 的任何文件。这些都属于偏离，要做必须先走"待裁决"。

---

## 1. 目标与原则（与 medstat 相同）

目标：任意 agent 对同一份数据做同样的选择，得到逐字节一致的数字、格式一致的图表、写法一致的文字；选择本身受约束，并通过 StudyContract 和 provenance 完整留痕。

实现的六层机制与 medstat 一一对应：
1. **固定 R 引擎 + 固定容器**：计算不交给 LLM。
2. **`_shared` 统一输出**：结果表 schema、标准图形、渲染和草稿都走共享层；表、图、文字的数字来自同一个结果对象。
3. **范本复刻制定默认值**：默认值取范本多数派，写进 PACK 并注明出处。
4. **强制显式选择 + 带出处的 QC 规则族**：关键选择没有默认值，缺了就拒绝运行，返回类型化错误；QC 规则每条都有出处。
5. **MCP 统一调用和回报**：参数白名单来自 `--help`；manifest 包含产物、`qc_triggered`、`engine_warnings`、效应（特征）表和 `degenerate_estimates`；每次运行一个 UUID 目录；StudyContract 与出版校验照 medstat 执行。
6. **路由器 + reference 伴随服务**：让不同 agent 做出相同的选择。

分层铁律照旧：只做科学层，期刊版式不进本项目。

---

## 2. 模块清单（阶段 1）

输入从定量好的数据开始：bulk 是计数矩阵加样本表，单细胞是 10x 矩阵目录、rds（Seurat 或 SingleCellExperiment）或 h5ad（用 R 的 zellkonverter 读取）。FASTQ→counts 不在范围内。

| # | 模块 | 问题 | R 引擎（按范本多数派确认，§6 S0） |
|---|---|---|---|
| 1 | `bulk-de` | bulk RNA-seq 差异表达 | DESeq2（主）；edgeR / limma-voom 作敏感性分析并排输出 |
| 2 | `enrichment` | ORA 与排序 GSEA | clusterProfiler + fgsea；基因集版本锁定 |
| 3 | `sc-qc-cluster` | 质控、归一化、降维、聚类、UMAP | Seurat v5（预期的多数派；若 S0 统计出 Bioconductor OSCA 流程为多数派，走"待裁决"） |
| 4 | `sc-integration` | 多样本整合 | Harmony（R 包，CPU 运行，确定性好） |
| 5 | `sc-annotation` | 细胞类型注释 | SingleR（Bioconductor，参考数据锁定）+ marker 打分并排；两者冲突时标"待人工确认" |
| 6 | `sc-pseudobulk-de` | 条件间差异表达 | 按"样本 × 细胞类型"聚合（muscat 或自行聚合）→ 调用 bulk-de 的同一套引擎函数 |
| 7 | `sc-composition` | 细胞比例差异 | speckle::propeller |
| 8 | `deconvolution` | 用 bulk 推断细胞组成 | MuSiC 或 BayesPrism（必须能离线运行、许可允许） |
| 9 | `coexpression` | 共表达模块与性状关联 | WGCNA |
| 10 | `omics-survival` | 基因或签名与生存结局 | 签名打分在本模块完成；生存模型部分写出交接命令给 medstat 的 `survival-nonph` / `assoc-workflow`（照抄 medstat `--with-rcs` 的交接写法，交接时带上标签），不重复实现 |

另有 `omicstat`（路由器，没有引擎）与 `_shared`。

每个模块的目录与 medstat 一致：`SKILL.md`、`scripts/run_<name>.R`、`references/`（包括 `qc-rules.md`、`reporting-templates.md`、`troubleshooting.md` 以及方法依据）、`tests/run_smoke_test.R`。

---

## 3. 基础设施分叉步骤（M0，按顺序执行）

1. **建仓库**：`git init skills-dev/omicstat`，复制 medstat-55692f7 的 `bin/`、`mcp/`、`skills/_shared/`、`SUITE.md` 骨架。随后全局重命名：`medstat` → `omicstat`、`MEDSTAT_` → `OMICSTAT_`、`MS_` 错误码前缀 → `OS_`。**重命名要列清单逐项确认**，不能用盲目的全局替换误伤注释里的出处引用。
2. **需要按字节保持的文件**（种子、锚点数据、测试 fixture）在 `.gitattributes` 中标为 `-text`，并写哈希测试。medstat-reference 就因为换行符规范化出过部署事故。
3. **容器**：以 `medstat/docker/Dockerfile` 为模板写 `omicstat/docker/Dockerfile`：基础镜像 `rocker/r-ver:<与 medstat 相同版本>`，Bioconductor 版本锁定；包按层追加安装（DESeq2、edgeR、limma、apeglm、clusterProfiler、fgsea、msigdbr、Seurat、harmony、SingleR、celldex、muscat、speckle、MuSiC 或 BayesPrism、WGCNA、zellkonverter 等）。每一层最后用 `stopifnot(requireNamespace(...))` 做自检，与 medstat 相同。镜像名 `omicstat-r:latest`，镜像 ID 进入 provenance。
4. **路由脚本**：复制 `medstat-r-route.ps1` 为 `omicstat-r-route.ps1`，只改镜像名和环境变量前缀；保留 `/ws` 无空格挂载，以及"参数经临时 bash 脚本传递、不走 wsl argv"的做法（原因见 medstat 的记录：wsl 会把 argv 里的空格改写成 `~+~`）。
5. **`_shared` 新增组学结果表**：
   - `feature_table.R`：列为 `feature_id`（不带版本号的 Ensembl ID）、`symbol`、`contrast`、`base_mean`、`log2fc`、`log2fc_se`、`stat`、`pvalue`、`padj`、`method`、`shrinkage`、`n_group1`、`n_group2`、`filtered_reason`。
   - `validate_feature_table_cli.R`：照抄 `validate_effect_table_cli.R` 的写法。
   - 生存、比例检验等仍然使用原有的 `effect_table`，两种表并存。
6. **标准图形**：用 `_shared` 的风格机制（forest.R、CONVENTIONS.md）扩展出火山图、MA 图、样本 PCA、样本距离热图、Top 基因热图、富集点图、GSEA 曲线、UMAP、marker 点图、比例堆叠图、模块—性状热图。配色、字体、尺寸、阈值线、基因标签的选择规则全部固定在共享层。每张图同时输出 PNG、PDF 和 `figure_spec.json`（记录用了哪张表的哪些行）。
7. **MCP 分叉**：`server.py`、`publication.py`、`package_identity.py` 与测试逐文件分叉。
   - 5 个工具与 medstat 同构：`omicstat_list_modules`、`omicstat_describe`、`omicstat_run`、`omicstat_read`、`omicstat_validate_publication`。
   - 行为保持不变：模块注册表从路由器 SKILL.md §1 的表格解析；参数白名单从 `--help` 解析，正则用 `--[A-Za-z0-9][A-Za-z0-9-]*`；子进程 `stdin=DEVNULL`；UUID 运行目录与注册表；路径根目录白名单；manifest 预算 8k 字符；25 分钟强制结束；`engine_warnings` 与 `degenerate_estimates`；StudyContract 可选，省略时出版状态为 `needs_input`。
   - **只改两处**：①manifest 的主载荷识别 feature_table（按列头识别，照 medstat 两档识别的写法再加一档）；②退化检查增加组学判据：padj 全为 NA、全部显著、log2fc 出现无穷值。
8. **出版规则层**：复制 `universal_rules_v1.json`，保留适用于组学的通用规则（例如 PUB-U-001 要求可追溯的分析人群与分母，组学里对应样本数、细胞数、基因数），并按 S0 范本补充组学通用规则。`module_rules_v1.json` 为每个 omicstat 模块写一条记录，结构与 medstat 相同。`journal_specific` 类别保持"只警告"。
9. **路由器**：`skills/omicstat/SKILL.md`，结构照抄 medstat 路由器：路由表、消歧树（bulk 还是单细胞？单细胞比较表达还是比例？注释还是聚类？）、流水线配方（`sc-qc-cluster → sc-integration → sc-annotation → sc-pseudobulk-de → enrichment`）、交给 medstat 的一节、标签总表，以及 MCP 一节。每个模块的 SKILL.md 在主示例命令后加上与 medstat 措辞一致的 "Via MCP" 段。

M0 的完成判据：`_shared` 测试全过；MCP 在没有任何模块时也能启动并列出空表；分叉出来的 medstat 原有测试（publication、package identity 等）改名后全部通过。

---

## 4. StudyContract v1 的组学映射（字段名不变，只定义含义）

medstat 的 `study_contract.v1` 必填字段为：`study_design`、`population`、`estimand`、`exposure`、`comparator`、`outcomes`、`missing_data`、`multiplicity`，另有 `semantic_declarations`。omicstat 沿用同一个 schema（`schema_version` 改为 `omicstat.study-contract.v1`），各字段在组学中的含义如下：

| 字段 | 组学含义（写进 schema 的 description 与 README） |
|---|---|
| `study_design` | 实验设计：两组、多组、配对、时间序列、批次结构；`design_type` 枚举 |
| `population` | 样本集合：样本表路径、纳入与排除的样本、生物学重复单位（单细胞必须声明哪一列是样本） |
| `estimand` | 对比与效应量：设计公式、对比（如 `condition: treated vs control`）、效应量（log2FC，是否做 shrinkage） |
| `exposure` / `comparator` | 条件变量及其参照水平 |
| `outcomes` | 特征空间：基因、细胞类型比例或共表达模块；物种与注释版本（例如 `GENCODE_v44`） |
| `missing_data` | 过滤策略：低计数过滤、质控阈值、被剔除的样本或细胞及理由 |
| `multiplicity` | 多重检验：BH 与阈值；富集分析的多重校正 |

出版状态、审阅决定、发布门禁的逻辑全部沿用 medstat 的 `publication.py`：只有声明完整、产物一致，状态才能到 `ready_for_manuscript_integration`；合同声明与实际运行参数不一致判为 blocker。

---

## 5. 组学特有的确定性问题（在 medstat 机制上的必要增补）

这些是 medstat 不需要、但组学必须补上的内容。实现位置都在 medstat 已有的机制里（引擎参数、provenance、QC 规则、发布门禁），不新增架构。

| 来源 | 对策 |
|---|---|
| UMAP、Leiden/Louvain、PCA（irlba）的随机性 | 引擎参数 `--seed`，默认值固定并写入 provenance；Seurat 各函数显式传 `seed.use` / `random.seed`；PCA 输出前做符号规范化（每个主成分中载荷绝对值最大的一项取正） |
| 多线程 BLAS 与浮点求和顺序 | 容器环境变量固定 `OMP_NUM_THREADS=1`、`OPENBLAS_NUM_THREADS=1`；R 端 `RhpcBLASctl` 设单线程。与 medstat 一样，引擎内部不做并行 |
| 簇编号随机 | 按簇大小降序、并列时按字典序重新编号 |
| 基因 ID | 内部统一使用不带版本号的 Ensembl ID；symbol 只用于显示；一对多、多对一的处理规则写死在 CONVENTIONS.md；丢失率进入 QC |
| 参考数据版本（注释 GTF、GO/KEGG/Reactome/MSigDB、SingleR/celldex 参考、单细胞图谱） | 与 medstat 容器一样**构建期固化**：在 Dockerfile 的一个独立层里下载并校验 sha256，或挂载只读卷。`refdata_registry.json` 记录 ID、版本、URL、许可、sha256。**运行时一律离线**；缺项或校验不符时拒绝运行（`OS_REFDATA_MISSING` / `OS_REFDATA_MISMATCH`）。许可不允许再分发的数据（KEGG 等）标注"用户自备"，不打包 |
| 大对象 | 引擎直接读挂载路径；MCP 从不回传 rds 或 h5ad，只给路径、大小和哈希 |
| 运行时长 | 沿用 medstat 的同步执行与 25 分钟强杀，**不新增后台任务工具**。每个模块的 SKILL.md 写明适用规模（例如细胞数上限），超出时给出类型化拒绝和下采样指引。如果实测发现必须支持长任务，走"待裁决" |

**一致性验收分两档（写入各模块 PACK 与发布门禁）：**
- 逐字节一致：bulk-de、enrichment、sc-pseudobulk-de、sc-composition、deconvolution、coexpression。同种子重跑时，主表与 figure_spec 逐字节相同；medstat 原生与容器两个平台也要求一致（与 medstat 冒烟测试相同）。
- 容差一致：sc-qc-cluster、sc-integration、sc-annotation 的嵌入与聚类。同平台同种子重跑时 ARI = 1；跨平台时 ARI ≥ 0.95，并记录实际数值。

**组学必备 QC 规则**（每条都要按 DOI 核实出处后再写入）：
- 用逐细胞检验做条件间比较的主分析（伪重复）→ blocker；
- 每组生物学重复 < 2 → blocker，< 3 → 警告；
- 设计矩阵不满秩，或批次与条件完全混杂 → blocker；
- 非整数计数进入 DESeq2/edgeR → blocker；
- 富集分析没有使用检测基因作背景 → blocker；
- 基因 ID 映射丢失率 > 5% → 警告；
- 某个簇只来自一个样本 → 警告；
- 双细胞未处理 → 警告；
- padj 全为 NA 或全部基因都显著 → blocker。

---

## 6. 建设流程（照抄 medstat，不改）

**每个模块**按 `replication-sop.md` 的 S0–S5 执行：
- **S0 范本采集**：A 层精读 8–10 篇，B 层广度 20–30 篇，统计变体频次，多数派即默认值。来源为高质量期刊（Nature/Cell 系、Genome Biology、NAR、Genome Research、Nature Methods、Nature Biotechnology）以及官方 vignette 和教程。PMID/DOI 必须实测验真。全文走小主机 GT103 的开放获取线路，不批量下载订阅内容。
- **S1 审定冻结**：由主会话或用户复核 PACK。规则须有出处才能写入，推测性拦截一律不收。
- **S2 建设**：
  - 引擎、渲染、SKILL.md、QC、冒烟测试一次建完；
  - 锚点复算：用公共数据集复现官方 vignette 中打印出来的数值；
  - 旗标有效性检查：每个开关开、关各跑一次，产出没有差异即 FAIL；
  - 旗标文档覆盖率检查：每个参数都要在文档中出现过；
  - §5 的确定性检查。
- **S3 复刻验收**：单轮，只判四项——锚点、表格形似、文字形似、机械核。图形审必须由能看图的主体亲眼完成。
- **S4 修复**：只修闭口清单里的问题。
- **S5 装机**：junction、路由表、SUITE 记录。

**全项目**：一次完整构建 → 一次统一审计（交网页版 GPT Pro，审计包格式参照 medstat 的 `research/gpt-pro-audit-package/`；或由一个没参与构建的子代理完成）→ 一次集中整改 → 一次最终验证。不做"审一个修一个"的循环。所有子代理遵守 worklog 续跑协议。

**模型分工**（与 medstat 相同）：检索与元数据整理用便宜模型；证据综合与实现用中档模型；统计判断、schema 设计和最终发布门禁由主会话决策。

---

## 7. 发布门禁（与 medstat RG-01～RG-12 同构）

照 medstat 最终构建报告的门禁逐条设置，数据集换成组学的：
1. 每个模块的正向数值矩阵：锚点复算全部通过；
2. 每个模块一个盲测边界案例（拒绝路径和 QC 触发）：全部 PASS，0 REVIEW，0 BLOCKER；
3. publication core 测试（分叉自 medstat）全部通过；
4. package identity 正例与负例测试；
5. MCP 真实 stdio 验收，分别在源码目录、无 `.git` 的解压安装包、最终安装目录三处运行；
6. 原生与容器双平台冒烟测试；
7. §5 的逐字节一致与容差一致检查；
8. **跨 agent 一致性**：两个独立 agent 拿同一份数据和同一段自然语言需求各自完成分析。选择上的差异必须能从 StudyContract 中逐项看出；参数相同的部分，主表逐字节一致。
9. 不知情用户盲测：一个只读路由器和模块文档的 agent 完成 4 个端到端任务，critical 级别的问题清零；
10. Git bundle 与安装 ZIP 的完整性、逐成员 SHA-256 校验；
11. 最终工作树干净（没有未提交的改动）；
12. 构建报告与机器可读结果（`FINAL_BUILD_REPORT.md`、`machine_results.json`）齐全。

---

## 8. 参考伴随服务（阶段 3）

直接复用 `medstat-reference` 的代码库（v2），**不分叉逻辑，只换配置**：
- 新实例 `omicstat-reference`：独立容器、独立数据卷，镜像由同一套代码构建，只替换配置文件。
- 配置：`journals.json`（组学期刊白名单，ISSN 必须实测核验）、`discovery_profiles.json`（每个模块用方法节检索式 + 方法节正文信号）、`method_map.json`（omicstat 路由表顺序）、种子目录（可以从空库开始）。
- 包装入口 `omicstat_entry.py` 照抄 `medstat_entry.py`：只在工具描述中追加"先查 reference"的引导，并增加一个 workflow 资源；5 个工具的 schema 逐字节不变。
- 部署到 GT103 的方式照 `GT103_DEPLOYMENT.md` 执行（部署由主会话负责）。

---

## 9. 已知的坑（medstat 实际踩过，照做即可避免）

1. Windows + Git Bash：多行 `Rscript -e` 会段错误，改写成 .R 文件；路径中有空格时，容器内使用 `/ws` 挂载。
2. `system2` 的参数中如果出现未加引号的 `;`，在 Unix 上会被当作命令分隔符，一律用 `shQuote`。
3. 对拟合对象取值用 `[[ ]]`：`$` 会做部分匹配（`fit$n` 会取到 `null.deviance`）。布尔标志不要以另一个字段名的前缀开头。
4. formula 里不要用 `get(var)`，会被同名的数据列遮蔽；改用 `as.formula(sprintf(...))`。
5. Rscript 顶层的 `on.exit` 在 `stop()` 时不会执行，清理工作改用 `options(error=)` + `quit()`。
6. 不要在可能正在被 source 的文件上做编辑。
7. 需要按字节绑定的文件标为 `-text`，并写哈希测试。
8. 图形通用缺陷清单：概率轴不超过 100%、图例不压数据、P 值注记不出现双符号、同一张图里 CI 分隔符统一、文字不溢出画布、风险表从 t=0 开始。
9. 容器路由经 PowerShell 管道输出时，stdout 可能被截断；以退出码为准，完整日志在 WSL 内重定向保存。
10. 统计 md 文档时按语义单元计数，不要按行计数。

---

## 10. 里程碑与回报

| 里程碑 | 内容 | 完成判据 |
|---|---|---|
| M0 | §3 的全部基础设施分叉 | §3 末尾的判据 |
| M1 | bulk-de、enrichment | 各自通过 S0–S5 |
| M2 | sc-qc-cluster、sc-integration、sc-annotation、sc-pseudobulk-de、sc-composition | 各自通过 S0–S5（单细胞类按容差档） |
| M3 | deconvolution、coexpression、omics-survival、路由器定稿 | 各自通过 S0–S5 |
| M4 | 统一审计 → 一次整改 → §7 门禁全绿 → 打包 | 形成 FINAL_BUILD_REPORT |
| M5 | 参考伴随服务（§8） | 按 medstat-reference v2 的验收标准 |

每个里程碑结束时在 `SUITE.md` 记一节，并回报四项：已完成的内容、测试结果、偏离 medstat 做法之处及理由（没有就写"无"）、待裁决事项。注册（`.mcp.json`、junction、Codex config）和小主机部署由主会话或用户执行，实现 agent 只提供配置片段。

**纪律**：不修改 medstat 系列的任何目录；不碰小主机上的服务、cron 和 PaperFlow；不凭记忆填写文献出处、数值或包的功能；不下载订阅内容。
