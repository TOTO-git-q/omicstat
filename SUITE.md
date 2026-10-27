# omicstat SUITE（建设记录）

> 结构照 medstat `SUITE.md`：每个里程碑结束时记一节，回报四项——已完成内容、测试结果、偏离 medstat 做法之处及理由、待裁决事项（IMPLEMENTATION_SPEC §10）。

## 模块注册表

当前注册 59 个 accepted 模块（50 R / 9 Python），全部进入执行路由；其中 57 个分析/显示模块进入 reference method_map，另有 2 个自检工具。生产 R 镜像为 `omicstat-r:2026.10.4`，Python 仍为 `omicstat-py:2026.09.1`。执行入口以 `skills/omicstat/SKILL.md` §1 为准。

---

## M0 地基（2026-09-26）

### 已完成
1. **仓库分叉**：`bin/`、`mcp/`、`skills/_shared/`（scripts / schemas / publication / docs / tests）分叉自 medstat-55692f7；`medstat→omicstat`、`MEDSTAT_→OMICSTAT_`、`MS_→OS_`、工具名 `medstat_*→omicstat_*` 按清单逐项重命名（`docs/fork/RENAME_LOG.md`）。
2. **MCP 的两处改动**（其余不变）：manifest 主载荷识别 feature_table（列头 `feature_id+log2fc+pvalue+padj`）；退化判据增加 padj 全 NA / 全部显著 / log2fc 非有限；manifest 新增 `upstream_runs`（读 `objects/handoff.json`）。空路由表可启动。
3. **StudyContract** 字段名不变，description 改为组学含义（`omicstat.study-contract.v1`）；出版规则：通用规则保留 ID 并改写分母措辞，模块规则为空表。
4. **容器**：`docker/Dockerfile` + `install_packages*.R`（L1 bulk … L7 作图，逐层自检）、`write_pkg_lock.R`、`refdata_registry.json` 骨架（未构建，见下）。
5. **路由器骨架** `skills/omicstat/SKILL.md`：§1 空表，§2–§7 按 ENGINEERING_PLAN §5.1 写好（模块标注为 planned）。
6. **组学图形层（本里程碑的重点）**：`_shared/scripts/fig_style.R`（token/主题/调色板/颜色登记表/保存/质检）、`fig_heatmap.R`、`fig_bulk.R`、`fig_enrich.R`、`fig_sc.R`、`fig_network.R`、`fig_compose.R`、`fig_all.R`；规范 `_shared/docs/FIGURE_STYLE.md`；画廊 `docs/figure-gallery/`（20 种单图 + 2 张组合图）。
7. **其余 `_shared` 新增件**：`feature_table.R` + `validate_feature_table_cli.R`、`handoff.R`（`--from-run` 与类型化拒绝）、`calls_check.R`（锁 3：显式参数、未登记调用、默认值漂移）。
8. **工具**：`tools/new_module.py`（脚手架 + QC 前缀分配）、`tools/check_calls.R`、`tools/check_flag_docs.py`、`tools/qc_prefixes.json`、`tools/run_tests.sh`；模板 `templates/module/`。
9. `.gitattributes`（字节敏感文件 `-text`）、`reference/`（交接包中的只读参照源）。

### 测试结果（`bash tools/run_tests.sh`，Ubuntu 24.04 / R 4.3.3 / Python 3.11 + mcp 1.28.0）
| 测试 | 结果 |
|---|---|
| `test_figures.R` | 150/150 PASS（13 种图 PNG/SVG 逐字节、PDF 内容哈希一致；token 表与文档一致；颜色登记表；错误码；语义；卫生） |
| `test_omics_shared.R` | 30/30 PASS（feature_table、handoff 正负例、calls_check） |
| `test_effect_table.R` / `test_var_typing.R` / `test_survey_design.R` | PASS |
| `test_publication_rules.py` | PASS（0 模块，7 条通用规则） |
| `test_package_identity.py` | 3/3 OK |
| `test_publication.py` | 55 项：46 OK，9 SKIP（需要已装机模块 6 项、Windows junction 2 项、Windows 原生 R 路径 1 项） |
| `test_client.py`（真实 stdio） | 18/18 PASS，模块相关验收块 SKIP |
| `test_forest.R` / `test_integration.R` / `test_render.R` | NOT_RUN：本环境无法从 CRAN 安装 forestploter / gt（出网策略 403） |
| `test_spec.R` / `test_primitives.R` | 1 FAIL / 不能运行：它们交叉校验 medstat 的 `rcs-analysis` 脚本，该模块不在 omicstat 中（待裁决 9） |
| Docker 构建 | NOT_RUN：无 docker daemon，且 Bioconductor / Posit PM 被出网策略拦截 |

### 偏离 medstat 做法之处
1. 新增 `bin/omicstat-r-route.sh`（Linux/macOS 路由），medstat 只有 PowerShell 版。
2. `test_publication.py` 的一处断言改为按平台选择“根目录之外”的探针文件（原断言只在 Windows 成立）。
3. 图形层：medstat 的 forest.R 基于 forestploter；omicstat 的组学图形全部基于 ggplot2 + patchwork 自建（含热图引擎，不用 ComplexHeatmap），以便所有图共用一套 token 并逐字节复现。
4. PDF 的逐字节一致改为“内容哈希一致”：cairo 1.18 把 CreationDate 写进压缩对象流且不认 SOURCE_DATE_EPOCH；ENGINEERING_PLAN §3.5 已把 PDF 时间戳列为豁免字段。PNG、SVG、figure_spec.json 仍为逐字节。

### 待裁决
见 `README.md` “待裁决事项”一节（M0 汇总）。

---

## M0.1 独立化：不绑定 medstat + 自有 R 环境（2026-09-26，用户裁决）

### 裁决
1. **不绑定 medstat**：omicstat 不调用、不安装、不假设任何 medstat 组件。删除从 medstat 带来的临床统计共享件（`forest.R`、`survey_design.R`、`var_typing.R`、`spec.R`）及其 6 个测试、4 份文档和 NHANES fixture；路由器 §4 由“交给 medstat”改为“临床统计不在范围内，只导出打分表”；MCP 测试改用自有的 `omicstat-selftest` 模块；`reference/` 只作设计文档保留。
2. **全新的 R 环境 `env/`**：`omicstat-env.json` 为唯一版本来源——Bioconductor 官方镜像 `RELEASE_3_23-R-4.6.1` 按 digest `sha256:821dbf9a…` 锁定（2026-09-26 实拉核对：R 4.6.1、Bioc 3.23、Ubuntu 24.04.4、Python 3.12.3）；CRAN 为 Posit PM 2026-09-15 日期快照；8 层包清单；GitHub 包首次构建时钉 SHA（含传递依赖）；镜像内置 MCP 的 Python venv。另有不依赖 docker 的原生隔离库（`Rprofile.omicstat` 只暴露 omicstat 库 + R 基础库）。
3. **MCP 引擎**：删除写死的 Windows R 路径；`container` / `native` 两种引擎都经路由器（`.sh` / `.ps1`）启动；POSIX 超时按进程组杀树。
4. **大数据图（原待裁决 5）**：> 50,000 点只栅格化点图层（ggrastr，600 dpi），其余保持矢量，图注自动披露。
5. **需要 gt 的测试（原待裁决 4）**：在 GT103 的容器里跑（`env/gt103.sh`）；其他机器缺包时 `tools/run_tests.sh` 显式 SKIP。

### 未能在本云端环境完成
- 镜像实际构建与容器内测试：本环境的出网策略拦截 CRAN / Bioconductor / Posit PM / r-universe（403），只能在 GT103 执行 `bash env/gt103.sh`。已完成的静态验证：`docker build --check`（唯一警告为有意不设默认的 `BASE_IMAGE`）、`env/test_env_config.py`（JSON、层、Dockerfile、路由器、pin 文件一致性）、`env/r/test_layer_lib.R`（离线解析与未钉 SHA 的快速拒绝）。

### 已完成（续）
- `skills/omicstat-selftest/`：环境自检模块（ST-01..ST-08：R 与 Bioconductor 版本、UTF-8、单线程、字体、作图包、运行环境、原生库隔离），同时出一张标准火山图、一张 feature table、handoff 与 provenance。MCP 测试改用它作 fixture，不再依赖任何 medstat 模块；`env/gt103.sh` 构建后以 `--strict` 运行它。
- `mcp/server.py`：新增 `OMICSTAT_NATIVE_ENV`（原生环境描述文件路径）；`publication.py` 修正 severity `blocker` 被映射为 `info` 的问题（现为 `critical`）。
- 图形层：数据标签等图内文字自动抬到期刊最小字号（Cell 为 6 pt），修复 `--journal cell` 时火山图被 lint 拒绝的问题；新增 Cell 预设下 7 种图的 lint 测试。
- 删除 medstat 时期的测试数据 `mcp/testdata/make_cohort800.R`。

### 测试结果（`bash tools/run_tests.sh`，本云端环境：R 4.3.3 + apt 包，Python 3.11 + mcp 1.28.0）
| 测试 | 结果 |
|---|---|
| `env/test_env_config.py`、`env/r/test_layer_lib.R` | PASS |
| `test_figures.R`（含 T7 栅格化、Cell 预设 lint） | ALL PASSED |
| `test_omics_shared.R`、`test_effect_table.R` | PASS |
| `test_render.R` | SKIP（需要 gt；在 GT103 容器内运行） |
| `omicstat-selftest` 冒烟测试 | SMOKE PASSED |
| `test_publication_rules.py` | PASS（1 个模块，8 条规则） |
| `test_package_identity.py` | 3 OK |
| `test_publication.py` | 59 项 OK，2 SKIP（Windows junction） |
| `test_client.py`（真实 stdio，原生引擎） | 76/76 PASS，1 SKIP（容器引擎：镜像未在本环境构建） |

## M0.2 出图与引擎契约补强（2026-09-27）

三路并行改进，均已合并进本分支：

1. **引擎契约**（`skills/_shared/scripts/args.R`、`engine_run.R`、`design_check.R`）：带类型的参数规范（`os_arg_spec` / `os_parse_args` / `os_help`）；R 警告统一捕获到 `qc/engine_warnings.csv`，同时在 stderr 输出 `OS_ENGINE_WARNING`；样本与分组校验、配对对齐、重复数分类。配套工具 `tools/check_defaults.py`（`--help`、SKILL.md、calls_registry 三处的默认值必须一致）和 `tools/lint_r.py`（R 代码 lint）。模板和 `omicstat-selftest` 都已迁移到新规范。
2. **统计标注与色觉检查**（`fig_style.R` v1.1.0，FIGURE_STYLE §16–17）：`os_n_label`（每组 n）、`os_clip_note`（截断披露）、`os_p_stars` / `os_p_label`（星号阈值固定为 token）；新增 lint 规则 FIG-03：先用 Machado 2009 模拟三种色觉缺陷，再用 CIEDE2000 计算色差，颜色太近判为 warning；只在灰度打印时才难区分的颜色记为 info。
3. **扩展图型**（`fig_sc_extra.R`、`fig_enrich_network.R`，FIGURE_STYLE §18）：分块热图（行注释 + 行/列分块）、stacked violin、ridge、高亮 embedding、alluvial、聚类树 + dotplot、密度 embedding、cnet、emap、GO 术语树、多通路 GSEA 曲线。画廊扩到 31 张单图 + 2 张组合图，逐张目视检查过。

合并时的修正：`os_cluster_tree_dotplot` 透传必填参数 `mean_definition`；stacked violin 数据非负时每行从 0 起画，图注写明“每行一个刻度，从 0 起”；cnet / emap 的通路名加宽白边，避免压在连线上看不清；扩展图测试 E2 允许 FIG-03 的 info 提示（Okabe-Ito 配色保证的是色觉缺陷安全，不保证灰度打印）。

### 测试结果（`bash tools/run_tests.sh`，本云端环境：R 4.3.3 + apt 包，Python 3.11 + mcp 1.28.0）
全部 PASS：`test_figures.R`、`test_figures_ext.R`、`test_omics_shared.R`、`test_effect_table.R`、`test_engine_contract.R`、`tools/test_tools.py`、`lint_r.py`（30 个文件，0 个问题）、selftest 冒烟测试、`check_defaults.py`、publication 规则、MCP 三组测试。唯一的 SKIP 是 `test_render.R`（需要 gt，要在 GT103 容器里跑）。

### 留给本机的工作
`bash env/gt103.sh` 建环境（需要能访问 CRAN / Bioconductor）→ M1–M4 共 33 个模块，每个走 S0–S5 → M5–M7。步骤见 `docs/LOCAL_BUILD_GUIDE.md`。

## M0.3 开发层环境 + 样板模块 deseq2-wald（2026-09-27）

云端碰壁的完整记录见 `docs/build/CLOUD_BLOCKERS_2026-09-27.md`。按所有者决定，本轮只搭底座；文献检索（S0 的 L3/L4）和其余 32 个模块改在本机完成。

### 已完成
- **开发层环境** `env/conda/`：R 4.5.3 + Bioconductor 3.22（conda-forge / bioconda 的精确构建清单）。GitHub 上的包按 `env/layers/github_pins.txt` 的 commit 安装。`setup_dev.sh` 可以复现整套安装，`check_dev.R` 用于自检。这一层只用于开发，金标准仍以锁定容器为准。
- **GitHub 包钉版本**：monocle3、CellChat、immunedeconv 以及 immunedeconv 的 5 个 GitHub 依赖（xCell、EPIC、MCPcounter、mMCPcounter、ConsensusTME）都已钉到 commit，锁定容器和开发层用同一份源码。
- **共享层**：
  - `module_kit.R`：输入表读取、QC 规则表、`--spec` 回放、provenance、环境签名、从 references 读报告模板、金标准写入与比对；
  - `calls_check.R`：注册表支持 `accessors`；
  - `fig_style.R` 1.2.0：标签排布改为固定迭代 100,000 次；
  - `run_tests.sh`：读取冒烟测试的 `# requires:` 行；
  - 出版规则测试和 MCP 注册表测试：模块集合改从路由器 §1 解析。
- **工具**：
  - `tools/collect_l1.R`：导出已安装包的 vignette（含渲染后的打印值）、Rd、NEWS、CITATION 和 formals；
  - `tools/make_module_lock.R`：生成和校验 `module_lock.json`（锁 6）；
  - `acceptance/data/fetch_anchor_data.sh`：下载 10x pbmc3k / pbmc4k 并校验 sha256。
- **样板模块 `deseq2-wald` 1.0.0**：S0（L1）、PACK、S1 裁决、S2 建设、冒烟测试、S5（开发层）全部完成，已登记进路由器 §1 和 `module_rules_v1.json`。锚点和 DESeq2 vignette 的打印值完全一致：
  - pasilla 数据：检验 8,148 个基因；`padj < 0.1` 的 1,069 个（533 上调 / 536 下调）；`alpha = 0.05` 时 416 上调 / 437 下调；
  - 单基因 MLE、padj、apeglm 值逐位吻合；`~ type + condition` 设计的结果同样吻合。
- **建设说明书** `docs/build/MODULE_BUILD_BRIEF.md`：其余模块按它建设。

### 测试结果（开发层：R 4.5.3 / Bioconductor 3.22，Python 3.11 + mcp 1.28.0）
全部 PASS，没有 SKIP：之前需要 `gt` 的 `test_render.R` 在开发层也能跑了。`deseq2-wald` 的冒烟测试共 45 项检查全部通过，耗时约 3.5 分钟。

### 已知问题
- 画廊 `28_cnet`：中心通路名 “response to lipopolysaccharide” 贴着节点圆圈，可以读但不够干净；属于共享层 `os_cnet` 的标签避让，建富集模块时一并处理。
- 画廊已在开发层（ggplot2 4.0.3）重新生成；锁定容器建好后要再生成一次，并逐张目视检查。
- 本轮顺带修复：组合图里嵌套的子图（热图、GSEA 曲线）以前会被面板字母压住，现在上方留出了一行字母的边距（`fig_compose.R`）。

### 留给本机
见 `docs/build/CLOUD_BLOCKERS_2026-09-27.md` 第 4 节：建锁定容器 → 在容器里重新生成 `deseq2-wald` 的金标准 → S0 的 L3/L4 文献检索并复核 S1 裁决 → 建其余 32 个模块。

---

## M1-S0 联网取证：文献工具 + M1 bulk 差异表达族（2026-09-27，网络改为 Full 之后）

按所有者经本机会话转交的两条任务执行（第二条"云端额度分工与子代理派发"优先）：云端只做必须联网的 S0 取证和数据准备；S2 引擎、金标准、S3 目检、容器内测试都留给本机。S1 只起草，待裁决项写在各模块 PACK 末尾。

### 已完成
- **网络探测与 vendor 组件实测**：26 个域名中 25 个可达。Bioconductor Hub 的旧存储域名已停用，新地址 `mghp.osn.xsede.org` 可达。组件实测 11 项：10 项 PASS，OpenAlex 因为没有 API key 记为 SKIP。详见 `docs/build/NETWORK_CHECK_2026-09-27.md`。
- **合并 `vendor/claude-science-bio-tools`**：vendor 目录只读，`SHA256SUMS.txt` 校验通过，运行时不在其中写字节码。`.gitattributes` 保证 vendor、L1 和 efetch 证据按原字节保存。
- **omicstat 自有文献采集工具** `tools/lit/`：
  - 期刊白名单：38 本，A 档 23、B 档 15，ISSN 均经 Europe PMC 回显。
  - 检索画像：M1 8 个、M2 6 个。
  - Methods 节信号定位；许可闸门：只计 CC BY / CC BY-NC / CC0，且不得有 TDM 禁令。
  - 片段 ≤25 词，PubMed efetch 回显存档。
  - 按年份分层抽取候选，避免只取到当年的文章。
  - 子命令：`sample` 抽检、`summarize` V 节汇总（只统计当前语料中 `_applies = yes` 的文章）。
  - `collect_l1_release.py`：从 git.bioconductor.org 的 `RELEASE_3_23` 分支取包文档；只有 PDF 的用户指南用 pypdf 转成文本。
  - 离线测试 6 项，全部通过。
- **M1 族 8 个模块 S0 完成**：L1 取自 Bioconductor 3.23，L3/L4 每个模块 30 篇。PACK 已写 T/F/W/V/C/D/X 各节和 S1 待裁决草案。独立核查用 sonnet 代理，不是做采集或摘录的同一个代理，每个模块随机抽 ≥20%。

| 模块 | L1（3.23） | 语料 / 适用 | 核查（抽 6 篇） | 待裁决 |
|---|---|---|---|---|
| deseq2-wald | DESeq2 1.52.0、apeglm 1.34.0 | 30 / 29 | 59/60 = 98.3%，通过 | P-1 收缩估计（apeglm 还是 ashr）；P-2 事后倍数变化过滤；P-3 预过滤 |
| deseq2-qc | DESeq2 1.52.0 | 30 / 20 | 33/34 = 97.1%，通过 | P-1 `blind=TRUE`；P-2 离群样本只标记不删；P-3 批次校正后的图只用于展示 |
| deseq2-lrt | DESeq2 1.52.0、DEGreport 1.48.0 | 30 / 26（信号收紧后重采） | 46/46 = 100%，通过 | P-1 reduced 必填；P-2 模式聚类可选；P-3 LRT 后不做倍数变化过滤；P-4 fission 锚点 |
| edger-qlf | edgeR 4.10.5 | 30 / 23 | 第 1 轮 50/54 = 92.6%，**返工**（30 篇全部重做，改 11 行）；第 2 轮换种子抽 6 篇 54/54 = 100%，通过 | P-1 新旧 QL 方法；P-2 `robust=TRUE`；P-3 glmTreat |
| limma-voom | limma 3.68.5、edgeR 4.10.5 | 30 / 24 | 54/54 = 100%，通过 | P-1 voom 还是 voomLmFit；P-2 倍数变化准则；P-3 样本质量权重 |
| limma-array | limma 3.68.5 | 30 / 13 | 41/41 = 100%，通过 | P-1 eBayes 的 trend/robust；P-2 探针过滤与重复探针；P-3 是否重采 |
| limma-dupcor | limma 3.68.5 | 30 / 30 | 48/48 = 100%，通过 | P-1 必报一致性相关；P-2 block 校验；P-3 芯片上的 trend |
| sva-batch | sva 3.60.0、limma 3.68.5 | 30 / 21 | 26/26 = 100%，通过 | P-1 校正矩阵不进差异检验；P-2 必须保留生物学分组；P-3 SV 数；P-4 bladderbatch 锚点 |

- **参考数据改用正式包**：开发层安装了官方 GO.db、org.Hs.eg.db、org.Mm.eg.db 3.22.0 和 celldex 1.20.0，GO.db 替身已淘汰。msigdbr（MSigDB 2026.1）和 celldex/gypsum 缓存已预置。登记见 `env/refdata_registry.json`，共 10 条，带 sha256 和许可证。注释交叉核对 100 个基因：symbol↔Entrez 100/100，Ensembl 98/100（`docs/build/ANNOTATION_CROSSCHECK_2026-09-27.md`）。
- **锚点数据登记**：`acceptance/data/ANCHOR_REGISTRY.md` 和 `fetch_anchor_data.sh` 共登记 27 个文件，约 282 MB，每个都带登录号、URL 和 sha256，按 10x / bulk / sc / hub 分组。

### 测试结果
- `tools/lit/test_omlit.py` 6/6 PASS。
- 所有 L1 manifest 的 sha256 与仓库字节一致（renormalize 后抽查 123 个文件，0 个不符）。
- GT103（本机用 89f3696 建成 omicstat-r:2026.09.1）的 MCP 测试失败：在去掉 `.git` 的情况下可以复现。推测是 git 的 safe.directory 所有权检查，建议在 `env/test.sh` 加 `GIT_CONFIG_*` 环境变量，**尚未验证**，交回本机。

### 偏离之处及理由
- 注释员和锚点员是在"额度分工"那条消息到达之前派出的，用的是默认模型，而不是 sonnet。
- 检索员（haiku）在 M1 有几个模块失败（Europe PMC 单篇 500 错误导致整次中断），由主会话修复 `collect.py` 后重跑。
- deseq2-lrt 和 deseq2-qc 的信号正则在中途收紧（两个词要求出现在同一句），deseq2-lrt 语料因此重采；旧摘录行保留，但不计入统计。
- limma-array 的信号不区分平台，30 篇里只有 13 篇适用。按平台词重采成本很小，由所有者决定（limma-array P-3）。

### 待裁决（汇总）
1. 上表各模块的 P 项，详见各模块 `PACK.md` 末节。
2. 锚点数据包不在容器层里：airway、pasilla、fission、bladderbatch、zebrafishRNASeq、GSVAdata。开发层是 3.22，容器是 3.23，数据版本不同。
3. 注释数据怎样进入锁定容器（registry 里的容器条目标为 `TO_FILL_AT_BUILD`）；celldex 走 gypsum 还是 ExperimentHub；msigdbr 缓存是否预置；MSigDB 压缩包内含 KEGG/BioCarta，按许可闸门必须排除 KEGG。
4. WGCNA 示例数据：主机的 TLS 证书过期，未取得 sha256。

### 计划 v1.1（scverse 通道）对后续采集的影响（2026-09-27 记）
- 本机会话已把 `plan/python-lane` 合并进本分支（6c0aab4），云端已 pull。ENGINEERING_PLAN 第十部分新增 M3c（scanpy-qc、scanpy-cluster、scanpy-markers、scvi-integrate、scanvi-annotate），不收 scGPT 和 omicverse。
- 采集规则相应更新（`tools/lit/README.md`）：M3 起每篇论文都记录所用生态（seurat / bioconductor / scverse / mixed），V 节按生态分开统计；scverse 线的默认值只从用 scverse 的论文中统计，scverse 占比如实报告。
- M3c 的 S0 属于云端范围，内容为：L1 取锁定版本的 scanpy、scvi-tools 文档和官方教程；L3/L4 文献；锚点优先用官方教程的数据；PACK X 节写 AnnData / scanpy / scvi-tools 的版本敏感项。
- 不在云端做：omicstat-py 镜像、`_shared/py`、MCP 按扩展名分发的改造、S2 引擎和金标准。
- M1、M2 不受影响；M2 完成后照旧停下，等用户确认后再做 M3/M4。

---

## M2-S0 富集族取证（2026-09-27）

### 已完成
- **6 个模块的 S0**：
  - L1 取自 Bioconductor 3.23：clusterProfiler 4.20.0、enrichplot 1.32.1、DOSE 4.6.0、fgsea 1.38.0、GSVA 2.6.6、limma 3.68.5。
  - clusterProfiler 的 ORA/GSEA 还补了 **enrichit 0.2.1**（锁定镜像的 CRAN 快照 2026-09-15），原因见下文。
  - L3/L4 每个模块 30 篇。
  - PACK 已写 T/F/W/V/C/D/X 各节和 S1 待裁决草案。
  - 独立核查用 sonnet 代理，不是做采集或摘录的同一个代理，每个模块抽 20%。
- **L2**：clusterProfiler 包内的 vignette 只指向在线书。书的源码仓库没有许可证文件，所以相关章节只按 commit（5496131）和 sha256 登记，不复制原文。

| 模块 | L1 | 语料 / 适用 | 核查（抽 6 篇） | 待裁决 |
|---|---|---|---|---|
| clusterprofiler-ora | clusterProfiler 4.20.0 + enrichit 0.2.1 | 30 / 30 | 54/54 = 100%，通过 | P-1 GO 本体（默认 MF，实际多用 BP）；P-2 背景基因集（默认全注释基因，书和范本都用实测基因）；P-3 simplify |
| clusterprofiler-gsea | 同上 | 30 / 28 | 48/48 = 100%，通过 | P-1 排序统计量；P-2 开发层与容器的引擎不同；P-3 阈值惯例（0.05 还是 0.25） |
| clusterprofiler-compare | clusterProfiler 4.20.0 | 30 / 26 | 42/42 = 100%，通过 | P-1/P-2 与 ORA 同步；P-3 必须说明比较的是哪些列表 |
| fgsea-prerank | fgsea 1.38.0 | 30 / 30 | 48/48 = 100%，通过 | P-1 排序统计量；P-2 默认基因集用 Hallmark；P-3 集合大小取 15–500（教程值） |
| gsva-score | GSVA 2.6.6 | 30 / 30 | 48/48 = 100%，通过 | P-1 kcdf 与输入尺度；P-2 集合大小取 5–500；P-3 下游比较交给 limma |
| limma-camera | limma 3.68.5 | 30 / 29（信号收紧后重采） | 48/48 = 100%，通过 | P-1 默认检验用 camera；P-2 roast 旋转次数；P-3 路由评测保留"显微镜相机"混淆样例 |

### 关键发现
- **锁定镜像换了富集计算引擎**：
  - Bioconductor 3.23 中，DOSE 4.5.1 起 ORA/GSEA 的计算已移到 CRAN 包 enrichit；GSEA 用 enrichit 的 C++ multilevel 实现（源自 fgsea）。
  - 开发层（Bioc 3.22：clusterProfiler 4.18.4 / DOSE 4.4.0）仍然调用 fgsea，两层的 P 值会不同。
  - enrichit 0.2.0 把排序缩放对齐了 `fgsea::prepareStats()`；0.2.1 改为先把基因集与排序基因取交集，再套用大小过滤。
  - 金标准只认容器生成的；开发层按环境签名 SKIP（待裁决 GSEA P-2）。
- **GSVA 2.x 与范本不兼容的地方**：
  - 旧的 `gsva(expr, gset, method=)` 调用方式已彻底移除；报告了版本的范本中 12/17 只用过旧 API，参数名需要映射，不能照抄。
  - GSVA 2.0 起 `kcdf` 默认为 "auto"。
- **fgsea**：`fgsea()` 从 1.13.2 起默认用 multilevel 算法；1.19.2 起 eps 默认改为 1e-50，但教程文字仍写 1e-10。
- **limma camera**：3.30.0 起默认使用预设的 inter.gene.cor = 0.01；3.64.0 新增 `directional` 参数。

### 偏离之处及理由
- **limma-camera 重采**：第一轮信号的 `camera (` 分支会命中显微镜相机的写法，30 篇里只有 11 篇适用。信号收紧后重新采集，保留 10 篇、新增 20 篇，适用数升到 29/30。旧摘录行保留，但不计入统计。
- **L1 工具修正**：clusterProfiler / DOSE / enrichplot 的 release 分支里同时放着 2017 年的旧 `NEWS` 和当前的 `NEWS.md`。`collect_l1_release.py` 改为选"最新版本标题最高"的那份，并记录在 `NEWS.source`。M1 各包只有一份 NEWS，不受影响。
- **L1_cran 字节保护**：enrichit 的 NEWS 是 CRLF 换行。`.gitattributes` 增加 `L1_cran*` 的 -text 规则，manifest 的 sha256 已全部复核一致。
- **摘录员核对片段的方式**：两个摘录员大部分片段用本地复刻的 check 逻辑核对，只抽查了部分线上结果；独立核查员则一律用线上 `collect.py check`，结果全部 FOUND。

### 待裁决（汇总）
1. 上表各模块的 P 项，详见各模块 `PACK.md` 末节。
2. enrichit 是 clusterProfiler 3.23 的新 CRAN 依赖（锁定快照中为 0.2.1）：确认它进入容器的 pkg_lock，且金标准只在容器里生成。
3. GSVAdata 在两层都没有安装，gsva-score 只能用 pbmc4k 的 scRNA-seq 教程或缓存结果做回放锚点。

---

## M1/M2 S1 审定（2026-09-27）

所有者于 2026-09-27 对 `docs/build/S1_DECISION_TABLE_M1M2.md`（gpt-6-astra 起草、主会话抽查，下称"决策表"）裁决：**A 类与 B 类一律按「建议」栏批准**（建议含可选项的，默认值与可选项一并冻结）；**C 类 5 项保持待定**。逐项冻结值与参数写在 14 个模块 `acceptance/exemplars/<模块>/PACK.md` 末尾的"S1 审定附录"，D 表 Used/Decision 列同步；原"S1 drafts and pending decisions"保留为历史。本节只是文档层的记录：没有修改任何引擎代码、模块文件或 ENGINEERING_PLAN。逐模块提交记录见 `docs/build/s1_apply_worklog.md`。

### 计数
- 共 50 项（14 模块 44 个 P 项 + edgeR 核查 Note 1 项 + 基础设施 5 项）：**A 24 项、B 21 项已批准（45 项冻结）；C 5 项待定**。
- 冻结项中有 10 处写成"待澄清"（决策表对具体取值或口径没有写明），问题原文写在各 PACK 附录：deseq2-qc P-2（C 项中"只展示、人工标记、不自动剔除"这部分是否先行批准）、deseq2-lrt P-2（模式聚类的默认输入基因）、limma-voom P-2（`treat` 中 `fc` 的登记方式）、limma-array P-1（Agilent 以外平台的预设）与 P-2（"平台背景信息"的判定口径）、limma-dupcor P-3（Illumina 锚点回放用指南原调用还是套件预设）、sva-batch P-2（`ComBat_seq` 连续研究变量的放置）、clusterprofiler-gsea P-2（enrichit `seed` 是否需经 `...` 显式传入——S2 须在容器核对）、gsva-score P-3（scores 上 `eBayes` 的 trend/robust 取值；由哪个 limma 入口接收）。
- PACK 更正：决策表「PACK 草案中与证据不符或需要限定之处」15 条已全部落到对应 PACK；正文就地修改并以"（2026-09-27 更正：…）"标注；落在"S1 drafts"历史节里的错误不改原文，更正记在附录"对上一节草案原文的更正"中。`literature/`、`L1*/` 证据文件未改动。

| 模块 | 冻结（A/B） | C 待定 | 待澄清 |
|---|---|---|---|
| deseq2-wald | 3（A2 B1） | 0 | 0 |
| deseq2-qc | 2（A2） | 1（P-2） | 1 |
| deseq2-lrt | 4（A2 B2） | 0 | 1 |
| edger-qlf | 4（A2 B2，含 Note） | 0 | 0 |
| limma-voom | 2（B2） | 1（P-1） | 1 |
| limma-array | 3（B3） | 0 | 2 |
| limma-dupcor | 3（A2 B1） | 0 | 1 |
| sva-batch | 4（A2 B2） | 0 | 1 |
| clusterprofiler-ora | 3（A3） | 0 | 0 |
| clusterprofiler-gsea | 3（A2 B1） | 0 | 1 |
| clusterprofiler-compare | 3（A3） | 0 | 0 |
| fgsea-prerank | 3（B3） | 0 | 0 |
| gsva-score | 3（A2 B1） | 0 | 2 |
| limma-camera | 3（A2 B1） | 0 | 0 |
| 基础设施 | 2（B：M1-2、M2-3） | 3（M1-3、M1-4、M2-2） | 0 |

基础设施两项 B 的冻结内容：**M1-2** 后续增加专用验收数据层（或只读、散列锁定的数据挂载），含 `airway, pasilla, fission, bladderbatch, zebrafishRNASeq, GSVAdata`，记录容器实际版本、来源与输入对象散列后再在容器生成基线，默认走专用验收层；pasilla 数据来源变化也要重建基线。**M2-3** 优先按 M1-2 补 bulk GSVAdata 锚点；此前可用固定种子的模拟数据做独立计算烟测、pbmc4k 作单细胞补充；缓存 scores 只验证读取/报告，不算"表达矩阵→scores"的计算验收。

### 跨模块统一规则（决策表「跨模块一致性」节的压缩版）
1. **FC 判据三字段**（Wald、edgeR、limma）：零效应主检验／预先指定的最小效应检验／仅展示筛选，三者分开记录；主分析 BH 0.05 显式写出，Wald 的 `alpha` 与报告一致；用户的 FC 先说明线性或 log2 单位再映射到包参数（`results(lfcThreshold)`、`glmTreat(lfc = log2(fc))`、`treat(lfc = log2(fc))`）；展示筛选默认关闭；不称三个包的阈值检验等价。LRT 联合检验不套单系数 FC 筛选。
2. **预排序 GSEA 的排名契约**（CP-GSEA 与 fgsea 共用）：同一上游 contrast 生成一份带名称、带方向的统计量（DESeq2 Wald `stat` / limma moderated t 为预设）；选效应量排名时两边用同一明示的 LFC 类型；LRT/多自由度 F 不作方向排名。
3. **ORA 与 compare**：BP 预设一致；背景 = 该选择规则下有资格入选的全集；不同检测空间的多列表不得用并集作共同背景；原始 P、BH adjusted P、q-value 分列，保存原始 ID、映射规则、有效背景和注释版本。
4. **全表与 cutoff 分开**：GSEA 计算时 `pvalueCutoff = 1` 保存全部可检验项，再按 BH 0.05 标记；ORA/compare 若要全表，须同时处理 `qvalueCutoff`（计算阶段 1）与 NA，并如实说明未被检验的集合。
5. **`voomLmFit`**：方法方向遵循锁定指南 §15.7；补齐新入口 Rd/formals 前不冻结调用集合；迁移时拟合与下游（camera、GSVA→limma）一起迁，不得半迁。
6. **limma 的三种用法**：array 与 dupcor 同平台共用 `trend` 规则；GSVA scores 是连续值，不套 voom、不做芯片探针过滤、不盲目继承 `trend = TRUE`（指南的集合大小趋势 `trend = sqrt(gssizes)` 需单独声明）；block 表示相关单位。
7. **批次**：校正前后图可并列；已知 batch/SV 进入推断模型；`blind = TRUE` 的 QA 与 `blind = FALSE` 的模型后展示分开说明；批次校正 scores 只作展示，不对其做忽略校正不确定性的组间检验；标准 DE 路径拒绝已知来源为校正矩阵的输入。
8. **集合大小**：CP-GSEA 10–500、fgsea 15–500、GSVA 5–500 各按方法/指南保留差异，Methods 必报；做 CP-GSEA 与 fgsea 方法对照时预先统一基因宇宙、排名、集合、交集后尺寸、权重指数与 cutoff，统一后也不保证数值相同。
9. **GSEA 金标准**：同镜像、平台、RNG、输入与参数时按 §3.5 逐字节核对主表；签名不同只 SKIP 基线检查；`eps` 是计算下限、不是容差；若重复运行证明固定环境仍有差异，另提有数据支持的容差变更建议。
10. 所有"保留函数默认"的 A/B 决定也须显式写进 `calls_registry.json`；决策表不替代 S2 的逐参数登记（例如 `eBayes(legacy = NULL)`、GSVA `sparse/checkNA/use/filterRows`、富集的种子与并行后端）。

### C 类待定（5 项，缺的证据与补证办法照录决策表）
1. **deseq2-qc P-2 样本离群警告的统计量/阈值**：缺 PCA 到组中心距离的统计量定义、缩放方式、组大小要求和经校准的警戒阈值。补证：下一阶段用已登记的 QA 数据和已知异常标签校准，给出误报/漏报结果后再定；不得把 WGCNA connectivity 阈值移植为 PCA 阈值。
2. **limma-voom P-1 `voom + lmFit` 或 `voomLmFit`**：所有者接受方向（按锁定指南 §15.7 改用 `voomLmFit`，旧管线保留为复现选项），但调用集合未冻结。缺锁定 edgeR 4.10.5 的 `voomLmFit` Rd/formals 及输出契约（EList/weights）。补证：按已存 release commit 补收该 Rd，或在锁定容器导出 `formals()`，再按 §3.3 登记；不得凭记忆补 API。
3. **M1-3 注释入容器、celldex 后端、msigdbr 缓存及 KEGG 排除**：缺容器条目实际版本/散列、celldex 数据许可证据、MSigDB/BioCarta 的具体可分发边界和过滤后资产。补证：取得提供者条款与构建产物，填齐 `env/refdata_registry.json`，再用空用户缓存离线回放验证；`redistributable = null` 不能因包代码许可证自动改为 TRUE。（fgsea-prerank P-2 的 Hallmark 入口依赖此项。）
4. **M1-4 WGCNA 示例 sha256**：缺原文件、sha256 与许可说明。补证：从 TLS 验证正常的官方/可验证来源取文件，检查数据对象，记录地址/日期/sha256 后登记；保持"未就绪"，不编造散列。
5. **M2-2 enrichit 是否进入 pkg_lock、金标准来源**：仓库没有构建生成的 pkg_lock，不能确认已进入镜像。补证：导出容器 lock（`/opt/omicstat/pkg_lock.csv`）、实际 `packageVersion("enrichit")`、依赖来源和最小 ORA/GSEA 调用结果；建议把 `enrichit==0.2.1` 作为容器构建验收断言，并显式加入层清单。

### 对已建模块的影响：deseq2-wald 1.0.0 与审定决定的差异（S2 跟进，按锁 7 升版本并重跑金标准）
对照 `skills/deseq2-wald/scripts/calls_registry.json`、`run_deseq2_wald.R`（及其 `deseq2_wald_core.R`）、`references/parameters.md`。一致的部分：`alpha = 0.05`（`--alpha`，同时驱动独立过滤与显著性）、`lfcThreshold = 0` 可由 `--lfc-threshold` 设最小效应（log2 单位）、`altHypothesis = "greaterAbs"`、`pAdjustMethod = "BH"`、`lfcShrink(type = "apeglm", coef = ..., res = ..., lfcThreshold = 0, svalue = FALSE, apeAdapt = TRUE, apeMethod = "nbinomCR")`、`ashr` 可选、p 值来自未收缩 Wald、预过滤 10 / 较小比较组并写入 provenance。差异：
1. **P-2 缺少"默认关闭的仅展示 FC 筛选"**：模块只有检验内的 `--lfc-threshold`，没有展示筛选开关；`references/reporting-templates.md` 的陷阱段只把事后 FC 筛选当作错误写法，没有"展示筛选"的 Methods 句式。S2：新增默认关闭的展示筛选 flag（不改 padj、完整结果表保留）、对应的报告句式与 `calls_registry`/`parameters.md` 条目，并落实三字段语义（跨模块规则 1）。
2. **P-1"收缩值单独命名"**：主表 `tables/feature_table.csv` 的 `log2fc` 列存放收缩后的值（以 `shrinkage` 列标明估计器），只有补充表用 `log2fc_shrunken` / `log2fc_mle` 分列命名。是否满足"单独命名"需所有者判断；若要求主表也单独命名，涉及 `_shared` 的 FEATURE_TABLE_SCHEMA（主表列头 `feature_id+log2fc+pvalue+padj` 也被 MCP manifest 识别），不是本模块单独能改的。
3. **P-3 复杂设计的预过滤规则**：`--min-samples 0` 时模块总是取两个比较组中较小者的样本数，即使给了 `--covariates`（复杂设计）也自动推导；决定要求复杂设计/连续协变量时由用户给出明确规则。S2：给了 `--covariates` 时要求显式 `--min-samples`（或类型化拒绝），并在 `parameters.md` 写明。另需核对：condition 多于两个水平时，模块保留全部样本但只按两个比较组取"最小组"，与指南"smallest group size"是否一致。（另注：模块把所有协变量转成因子，连续协变量不被支持——这不是本次决定的内容，只作记录。）
4. **登记表的来源标注**：`calls_registry.json` 中 `alpha`、`type` 等条目的 `source` 仍写 `vignette`，`package_versions` 与 `function_default` 记录的是开发层 DESeq2 1.50.2。S2 重登记时把来源指向 PACK 的"S1 审定附录"，并在锁定容器重跑 `check_default_drift`。

第 1、3 项会改变输出或参数面，按锁 7：升模块版本、重跑锚点与金标准、差异记入 SUITE、重新生成 `module_lock.json`；第 2 项若改列名同样按锁 7 处理；第 4 项只改登记文本。

### 计划需要同步的地方（只记录，本次未改 `docs/handoff/ENGINEERING_PLAN.md`）
1. **§1.2 A limma-voom 核心函数**列 `voom`/`voomWithQualityWeights`、`lmFit`：决定方向为 `voomLmFit`（C 待定，调用集合补证后冻结）；届时同步核心函数、输出契约与锚点，并保留旧入口作复现选项。
2. **§2.1 L4"多数派即默认值"、§2.3 V"多数派为默认"、§5.1"默认主引擎由各模块 PACK 的范本多数派决定"**：本轮审定多处以锁定版 Rd/指南优先于范本频次（edgeR `robust = TRUE`、`voomLmFit` 方向、roast `nrot = 9999`），并规定"最常见"不等于多数、未过半不作多数（camera 14/29、CP-GSEA 7/15、fgsea Hallmark 11/30）。计划中的"多数派即默认"原则需要改写为"指南/Rd 与范本冲突时按 S1 裁决，多数须过半并注明分母"。
3. **§1.2 A sva-batch**写"校正后的矩阵只用于可视化和下游打分，不喂给差异分析"：与 P-1 一致，但决定进一步要求 DE 模块**拒绝**已知来源为校正矩阵的输入（不是警告）；§1.3 交接约定/§3.2 输入校验需要相应的类型化拒绝（例如在 `handoff.json` 标记校正来源）。核心函数列表还缺 `num.sv`（P-3）与 `limma::removeBatchEffect`（deseq2-qc P-3 的展示校正）。
4. **§1.2 A deseq2-lrt** 核心函数未列 `DEGreport::degPatterns`（P-2 可选模式聚类，产物"模式聚类热图"依赖它）。
5. **§1.2 A deseq2-qc** 主要产物"离群样本表"：离群统计量/阈值为 C 待定，产物在 P-2 冻结前只能是描述性标记。
6. **§1.2 A limma-array** 核心函数未列 `avereps`（P-2 可选的技术重复合并）。
7. **§1.2 B limma-camera** 核心函数列 `camera`、`roast`/`fry`：P-1/P-2 还用到 `cameraPR` 与 `mroast`。
8. **§1.2 B fgsea-prerank** 核心函数写 `fgsea`（multilevel）：附录按 `fgseaMultilevel` 写出全部参数；登记时二者择一并与 D 表一致。
9. **§1.2 B gsva-score**"可交给 limma 做组间比较"：P-3 冻结了原则，但接收 scores 的 limma 入口与 `eBayes` 取值待澄清。
10. **§3.4 随机性锁**的清单未列 limma `roast`/`mroast`（`nrot = 9999` 的旋转抽样）、`num.sv(method = "be", seed = )`、enrichit 的 multilevel GSEA（`seed` 默认 FALSE 时生成随机种子）；需补入。

---

## M1/M2 建设（2026-09-27 起，锁定容器 omicstat-r:2026.09.1）

建设记录：`docs/build/m1m2_build_worklog.md`；最终报告：`docs/build/M1M2_BUILD_REPORT.md`。

### 环境修复（第 1 步）
- 合并 `origin/env/gt103-build-20260927`（pkg_lock、image_id、BUILD_RECORD、BPCells/speedglm 钉版）。
- MCP 测试 4 项失败的根因已在 GT103 复现并修复（不重建镜像）：①容器以 root 运行而检出目录属 toto，git 报 "dubious ownership"；②`~/omic-build` 是 linked worktree，`.git` 指针在挂载之外；③原生路由在镜像内继承了 `OMICSTAT_CONTAINER=1`，selftest 把自己报成容器（ST-07）。修法：`env/test.sh` 以调用者身份运行、经 `GIT_CONFIG_*` 设 safe.directory、只读挂载 git common dir；`bin/omicstat-r-route.sh` 原生分支清除容器标记。`bash env/test.sh`：ALL PASSED，0 SKIP。
- **验收数据层（S1 M1-2 落地）**：`acceptance/data/install_acceptance_lib.R` + `acceptance_lib_lock.csv`（Bioc 3.23：airway 1.32.0、bladderbatch 1.50.0、fission 1.32.0、GSVAdata 1.48.1、zebrafishRNASeq 1.32.0 装入 `.omicstat-acceptance/library`；pasilla 1.40.0 依赖 DEXSeq，只解包使用，不改包）。每次使用复核源码包 sha256；冒烟测试另核输入文件 sha256。
- 共享层：`read_handoff()` 对 `batch_corrected_matrix` 类型给出 `OS_BATCH_CORRECTED_INPUT`（sva-batch P-1）；新增 `fig_mod_bulk.R` / `fig_mod_enrich.R` 槽位。
- **图形层 1.3.0（只改渲染）**：锁定容器（ggrepel 0.9.8）中 pasilla 火山图 / MA 图出现标签互压——斥力在消除重叠前衰减停止（1,000 与 100,000 次迭代布局相同），固定 `aspect.ratio` 加重此问题。火山图 / MA 图改用确定性排布 `os_label_place()`（FIGURE_STYLE §7.3），两图不再固定 aspect.ratio（火山图默认高 92 mm）。所有 figure_spec 记录样式版本，故此前生成的金标准中的 figure_spec 行需重生成（数值表不变）。画廊在容器中重生成，变化的 PNG 逐张目视。

### deseq2-wald 1.0.0 → 1.1.0（第 2 步，锁 7）
1. **P-2 仅展示 FC 筛选**：新 flag `--display-lfc-filter`（log2 单位，默认 0 = 关闭）。只额外写 `tables/display_filtered.csv`，padj 与完整结果表逐字节不变（冒烟 F6 验证）；Methods/Results 用单独模板 `methods_display` / `results_display` 陈述且不声称 FDR 保证；results JSON 新增 `fc_criterion`（`null_test`、`min_effect_lfc_threshold`、`display_lfc_filter`、`display_lfc_type`、`n_display_filtered`）。
2. **P-3 复杂设计的预过滤**：给了 `--covariates` 或条件列多于两个水平时，`--min-samples 0` 被拒（`OS_MISSING_PARAMETER`），须显式给出。锚点 A3（`~ type + condition`）改为显式 `--min-samples 3`（= vignette 的 smallestGroupSize），数值不变。
3. **登记表重登记**：`package_versions` 取 pkg_lock（DESeq2 1.52.0、apeglm 1.34.0、ashr 2.2-63）；冻结决定的 `source` 指向 "S1-appendix P-n"；容器内 `check_default_drift` 通过。
4. **未改（所有者待定）**：主表 `log2fc` 列存收缩值（SKILL.md Known limitations 已注明）。
- 锚点 A1–A3 在容器中全部复现（8,148 检验；padj<0.1：1,069 = 533 + 536；alpha 0.05：416 / 437；FBgn0000017 等单基因值）。金标准在容器生成；数值表（feature_table、results_full）与 1.0.0 相同，变化只在 results JSON（新增 fc_criterion）与 figure_spec（样式 1.3.0）。


## Source-bundle integration (historical infrastructure build; not a release acceptance)

The following records the earlier source-only handover. Its pending and
unimplemented statuses were superseded by the M3/M4 S2–S5 installation record
below; the original build evidence remains unchanged.

The four supplied infrastructure overlays are merged. limma-camera 1.1.1 adds
a per-set collection/matching/selection/test ledger. The run-ID and lineage
contracts are retained across the merged R and Python lanes.

Five new Python analysis engines are implemented in source: scanpy-qc,
scanpy-cluster, scanpy-markers, scvi-integrate, and scanvi-annotate. Their
locked-container numerical runs, API-default capture, goldens, and module locks
remain pending. No generated scientific result or module seal was fabricated.
Nineteen requested new R modules remain unimplemented; none is registered as
a runnable engine. The router lists 19 analysis engines plus two self-tests;
the reference method map retains all 38 planned analysis targets with statuses.

See docs/build/BUILD_STATUS.json, docs/build/sandbox_tests/, and the delivered
GPT_BUILD_REPORT.md for the actual test scope, failed prerequisites, missing
modules, ordered container commands, and release limitations. Historical
container/deployment records supplied in the overlays are not tests run here.

## M3/M4 S2–S5（2026-10-04）

24 个 M3/M4 已装机：19 R + 5 Python；合计38 个分析模块和2 个自检工具。
S2 commit 是原 S3 基线 `d7355bec` 中各模块 S3_REQUEST 的最后交接提交，
不是本次 helper 的滚动提交。原独立复验仍保留原判定；五 Python 按协调者
2026-10-04 03:20 更新先运行原 golden 数值 smoke、R 渲染、新容器封锁检查，
成功后视为 PASS WITH NOTES。本次无未安装项。

| 模块 | S2 交接 commit | 最新独立 S3 / 本次安装依据 | S5 installed |
|---|---|---|---|
| scanpy-qc | `b6a6ad5` | [原复验 FAIL（仅 stale seal）；协调者允许重封后 PASS WITH NOTES](acceptance/exemplars/scanpy-qc/S3_RECHECK_m3m4.md) | 是 |
| scanpy-cluster | `b141c6f` | [原复验 FAIL（仅 stale seal）；协调者允许重封后 PASS WITH NOTES](acceptance/exemplars/scanpy-cluster/S3_RECHECK_m3m4.md) | 是 |
| scanpy-markers | `b141c6f` | [原复验 FAIL（仅 stale seal）；协调者允许重封后 PASS WITH NOTES](acceptance/exemplars/scanpy-markers/S3_RECHECK_m3m4.md) | 是 |
| scvi-integrate | `e9a19f4` | [原复验 FAIL（仅 stale seal）；协调者允许重封后 PASS WITH NOTES](acceptance/exemplars/scvi-integrate/S3_RECHECK_m3m4.md) | 是 |
| scanvi-annotate | `9549f5a` | [原复验 FAIL（仅 stale seal）；协调者允许重封后 PASS WITH NOTES](acceptance/exemplars/scanvi-annotate/S3_RECHECK_m3m4.md) | 是 |
| seurat-qc | `8258a72` | [PASS WITH NOTES](acceptance/exemplars/seurat-qc/S3_REVIEW_m3m4.md) | 是 |
| seurat-cluster | `9dc4d3d` | [PASS](acceptance/exemplars/seurat-cluster/S3_RECHECK_m3m4.md) | 是 |
| seurat-integrate | `368ccfb` | [PASS](acceptance/exemplars/seurat-integrate/S3_RECHECK_m3m4.md) | 是 |
| seurat-markers | `4965f88` | [PASS WITH NOTES](acceptance/exemplars/seurat-markers/S3_RECHECK_m3m4.md) | 是 |
| seurat-modulescore | `af90ed1` | [PASS WITH NOTES](acceptance/exemplars/seurat-modulescore/S3_REVIEW_m3m4.md) | 是 |
| scater-qc | `eb534a8` | [PASS WITH NOTES](acceptance/exemplars/scater-qc/S3_REVIEW_m3m4.md) | 是 |
| scran-cluster | `eb534a8` | [PASS WITH NOTES](acceptance/exemplars/scran-cluster/S3_REVIEW_m3m4.md) | 是 |
| batchelor-integrate | `0ea3a07` | [PASS WITH NOTES](acceptance/exemplars/batchelor-integrate/S3_REVIEW_m3m4.md) | 是 |
| scran-markers | `0ea3a07` | [PASS WITH NOTES](acceptance/exemplars/scran-markers/S3_REVIEW_m3m4.md) | 是 |
| aucell-score | `b08f144` | [PASS](acceptance/exemplars/aucell-score/S3_RECHECK_m3m4.md) | 是 |
| singler-annotate | `cecae16` | [PASS](acceptance/exemplars/singler-annotate/S3_RECHECK_m3m4.md) | 是 |
| muscat-pseudobulk | `3213029` | [PASS WITH NOTES](acceptance/exemplars/muscat-pseudobulk/S3_REVIEW_m3m4.md) | 是 |
| speckle-propeller | `f3099dd` | [PASS WITH NOTES](acceptance/exemplars/speckle-propeller/S3_REVIEW_m3m4.md) | 是 |
| cellchat-communication | `b08f144` | [PASS WITH NOTES](acceptance/exemplars/cellchat-communication/S3_REVIEW_m3m4.md) | 是 |
| monocle3-trajectory | `cecae16` | [PASS WITH NOTES](acceptance/exemplars/monocle3-trajectory/S3_REVIEW_m3m4.md) | 是 |
| slingshot-trajectory | `f3099dd` | [PASS WITH NOTES](acceptance/exemplars/slingshot-trajectory/S3_REVIEW_m3m4.md) | 是 |
| wgcna-network | `2de30d7` | [PASS WITH NOTES](acceptance/exemplars/wgcna-network/S3_RECHECK_m3m4.md) | 是 |
| maftools-landscape | `049b9b4` | [PASS](acceptance/exemplars/maftools-landscape/S3_RECHECK_m3m4.md) | 是 |
| immunedeconv-infiltration | `049b9b4` | [PASS WITH NOTES](acceptance/exemplars/immunedeconv-infiltration/S3_RECHECK_m3m4.md) | 是 |

协调者两项可由 owner 撤销的决定：①单细胞逐细胞 gene-set activity → AUCell，
bulk/pseudobulk 样本级 score → GSVA；两者均不是套件“标准”。②中性 R 后端保留
上游 `front_end_ecosystem`，写 `backend_ecosystem: neutral`，跨 Python→R 是
信息型 `OS_ECOSYSTEM_CROSSING`；前端换生态仍 `OS_ECOSYSTEM_MIXED` 拒绝。
本车道只同步路由/文档，不改后端行为。

R 镜像升级为 `omicstat-r:2026.10.1`，锁定 R4.6.1 / Bioconductor3.23，新增
scrapper、presto，并把非 root basilisk 环境放在 `/opt/omicstat/basilisk`。
镜像环境报告列出14新增包：ALL、BiocStyle、ConsensusClusterPlus、DEGreport、
GPArotation、Rigraphlib、bookdown、dendextend、ggdendro、logging、mnormt、
presto、psych、scrapper；原530包记录保持不变。
它关闭旧 M3b 的 SingleR wilcox anchor、CellChat 默认 presto、AnnData 非 root
访问阻塞；CellChat 原生 Wilcoxon 支持分支也保留。Python 镜像仍2026.09.1。
详情见 [环境报告](docs/build/BUILD_REPORT_env_rebuild.md) 和
[独立复验](docs/build/S3_RECHECK_REPORT_m3m4.md)。

待 owner / 调用方处理的开放项（安装不替代科学裁决）：

- [Seurat](docs/build/BUILD_REPORT_build_m3a_seurat.md)：研究 QC/物种/线粒体定义、
  normalization/HVG/PC/邻居/resolution、批次和整合、marker检验/比较/assay/筛选、
  gene-set成员/来源/物种与控制背景；没有通用 module-score 阈值。
  Slide-seq PMID38110959 适用范围、cc.genes 与 updated.2019 区别仍需保留。
- [Bioconductor](docs/build/BUILD_REPORT_build_m3a_bioc.md)：研究阈值、批次、排序/展示，
  scran-markers六篇非聚类研究的文献分母、batchelor适用范围与 S0 lane A 开放项。
  AUCell 原示例GMT限制已由修复/复验关闭，可用许可干净且明确来源的自定义GMT；
  通用打分标准由上面可撤销决定处理，不能误报旧阻塞仍开放。
- [中性后端](docs/build/BUILD_REPORT_build_m3b.md)：参考/标签、独立样本/比较组、
  embedding、轨迹root及生物依据、CellChat物种/数据库。Slingshot旧PACK V/D与部分L3
  仍待核验。Monocle reachable-root/partition选择和20-gene graph_test冒烟范围，
  Slingshot相对伪时序、CellChat单网络描述均不证明因果/重复条件效应。
  pin无projectData，raw.use=FALSE仍不支持。
- [M4](docs/build/BUILD_REPORT_build_m4.md)及复验：WGCNA power/预处理/排除/性状家族；
  稠密树及全grey可选原生分支不证明“因果hub”。MAF caller/build/filter与callable
  territory；浸润TPM/物种/方法/tumor/mRNA scaling/基因排除/签名许可。
  当前八种offline方法已修复并验收，旧仅quanTIseq限制已关闭；CIBERSORT必须用户
  合法供应源码/签名，stub/interface成功不是licensed生物学成功证据。
- [Python核验](docs/build/VERIFY_GPTPRO_REPORT.md)及原S3/复验：S0-C抽取遗漏、生态错误、
  L3仍需独立整理；PBMC600和两epoch synthetic只验证工程，不证明收敛、整合质量
  或标签准确率。完整BMMC/purifiedPBMC/cross-platform/agent盲测仍开放。
- [原S3范围](docs/build/S3_REPORT_m3m4.md)：全部研究科学参数须先reference_advise/
  reference_search再明确选择；没有文献多数默认。Seurat markers7023与旧7019是
  owner已接受差异；sva A6a仍已知失败。38模块装机不意味着manuscript-ready。
- 本次逐图复核保留原图层外观owner项：共享fixture的oncoplot末端Multi_Hit图例、
  Wald两基因小热图的底端Row z-score图例裁切，以及GO长标签重叠/密集MA标签。
  数值与现有figure测试结论不替代这些人工观察；详见S5报告的图审计说明。

最终套件数值、逐项skip、全部变更与reference逐模块/列映射详见
[本次S5报告](docs/build/S5_REPORT_m3m4.md)。参考服务仅更新离线bundle，不部署。

## UMAP display workflow (2026-10-07)

Added scanpy-annotate (descriptive panel naming), scanpy-purity (explicit neighbour/island flags), and scanpy-ingest (fixed-reference query projection). scvi-integrate gains latent reuse and optional Leiden in a new column; scanpy-cluster can use an existing representation. Scientific thresholds are explicit user choices. Purity curation, balanced cell-list selection and ingest are display only and cannot feed proportions, pseudobulk, markers or DE. Figure-only group caps leave numerical outputs unchanged.

ENGINEERING_PLAN 3.7: optional paths leave existing numerical tables and goldens unchanged; default embedding labels and render metadata remain unchanged. New rendering choices record explicit label coordinates, display caps and seeded registries. Final acceptance, seal counts and visual review are recorded in docs/build/UMAP_DISPLAY_REPORT.md.

## Defaults adjudication (2026-10-11, lock 7)

Eight locked defaults that the monthly literature comparison flagged were adjudicated by the owner. No item had a reproducible statistical error, so ENGINEERING_PLAN 3.7 lock 7 ("no change of estimator or default without a reproducible error") still holds: nothing was switched to a literature-majority value. Each decision is one of keep-and-document (B), remove the default and make the option required (C) or comparison artifact (D). Evidence counts come from the reviewed S0 supplement; the full reasoning is in docs/build/defaults_adjudication_worklog.md and the module PACK/worklog appendices.

| Module and option | Locked default | Literature | Verdict | Change |
|---|---|---|---|---|
| wgcna-network `--network-type` | unsigned | signed 9, not reported 14 of 23 (39% is not a majority); the package author recommends a signed variety and calls the unsigned default historical | C | required since 1.1.0; unsigned remains available; the anchor replay passes it explicitly |
| scvi-integrate `--n-latent` | 10 | 30 (6 papers), 10 (2), 64 (2), 50, 52, 6: no majority | C | required when training, not with `--latent-from-run`, since 1.2.0; the shared anchor helper already passes `--n-latent 5` |
| scvi-integrate `--n-layers` | 1 | 2 in 11 of 12, mostly restating the harmonization tutorial (`n_layers=2, n_latent=30, gene_likelihood=nb`, called non-default) | B | default kept; the tutorial triple is documented as a named configuration |
| scanpy-markers `--test` | t-test | Wilcoxon 16 of 21 (scverse-only 13 of 16); the tutorial uses wilcoxon; Pullin and McCarthy 2024 (PMID 38409056) find Wilcoxon, t-test and logistic regression all effective | B | documentation only (1.0.1); no shared Python file touched |
| seurat-markers `--logfc-threshold` 0.1, `--min-pct` 0.01 | locked Seurat 5.5.1 defaults | 0.25 and 0.1 are the Seurat 4.4.0 and earlier defaults (reporting papers ran Seurat 2.3.4 to 4.3.0.1); both are pre-test speed-ups | D | module not changed, not resealed |
| seurat-markers `--display-lfc-filter` | 0 (off) | study-specific post-hoc display thresholds | D | module not changed, not resealed |
| scran-cluster `--cluster-method` | walktrap | 5 of 11 rows are Seurat-side or scanpy-side values of mixed-ecosystem papers that the pack never pools; Bioconductor-only values are too few | D | module not changed, not resealed |

Golden files and `golden_manifest.csv` of the three changed modules are byte-identical (module smoke prints the golden comparison as PASS, not SKIP; `git diff --stat` on golden paths is empty). Module locks regenerated in the pinned images (wgcna-network 1.1.0 in omicstat-r:2026.10.1; scvi-integrate 1.2.0 and scanpy-markers 1.0.1 in omicstat-py:2026.09.1): module_lock.json sha256 3826474d6f19..., d6c3bbb04a56..., f3768839f577...

Reference service (not redeployed; ships with the next deploy): `defaults.py` no longer pools values noted as another ecosystem ("Seurat-side value (mixed)") into a module comparison (counted as `n_excluded_cross_ecosystem`), reports `n_unparsed`, and attaches an owner verdict from the new `s0_evidence/default_adjudications.json`; an adjudicated flag moves from `flagged` to `adjudicated` in the `reference_advise` `default_context`, and the digest section C has an owner-verdict column. `option_defaults.json` and the S0 bundle were regenerated with `import_s0_evidence.py` so the two C items leave the comparison.


## Convergence reseal (2026-10-20, step S5, image omicstat-r:2026.10.4)

One reseal on the frozen core image `omicstat-r:2026.10.4` (id sha256:16b79c344a57901f34a4c81039da9233578a76da13c1f8f2e4d24a70ff0e421e; Python lane `omicstat-py:2026.09.1` unchanged). Owner approvals of 2026-10-20: sealing resumed for this one reseal; the 13 baseline modules whose figures changed (deseq2-lrt, deseq2-qc, deseq2-wald, edger-qlf, gsva-score, limma-array, limma-camera, limma-dupcor, limma-voom, scater-qc, seurat-qc, sva-batch, wgcna-network) have their figure goldens regenerated (figure_spec, PNG, figure-caption lines of draft/methods_results.md); every table and JSON result row of those manifests is byte-identical to the sealed baseline (`git diff` of the 13 manifests shows figure and caption rows only). All other baseline modules keep their goldens unchanged; only `module_lock.json` is rewritten (environment 2026.10.4, image id above). The 16 modules listed as candidates at the time of S5 get a golden (byte hashes of the deterministic outputs of the canonical acceptance run, identical between the run and its `--spec` replay; `tools/canonical_golden.py`) and a `module_lock.json`; their status stays `candidate`. Tolerances and numerical assertions were not changed.

<!-- candidates:begin -->
## 标准化候选模块（自动生成）

当前没有 candidate 模块。已接受模块及入口见路由表。
<!-- candidates:end -->

## Production promotion and module acceptance (2026-10-20)

Owner approved the repository production R pointers at `omicstat-r:2026.10.4` (`sha256:16b79c344a57901f34a4c81039da9233578a76da13c1f8f2e4d24a70ff0e421e`) and accepted all 16 S5 candidates. `tools/sync_registry.py` generates 59 accepted routes, registry counts, 57 reference method-map entries, matching literature schema/discovery inventory and the six-tool MCP manifest. New reference search profiles are explicitly weak and have no screened corpus. Historical S5 status statements above describe the pre-promotion snapshot. Existing explicit `--development-mode` acknowledgements in these engines remain part of their sealed CLI contract. No golden, tolerance, image tag, deployment or service was changed. The main session must reconcile the deployed reference cursor at S6.
