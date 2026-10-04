# omicstat 构建报告：部分源码交付，非完整验收版

## 1. 结论与停止位置

**未完成全部 24 个新增模块。** 本包实际完成了 A/B 的源码整改与四个 overlay 合并，并新增了 **5 个 Python/scverse 模块的分析源码、文档、报告/QC、锚点回放测试和金标准/模块锁生成脚本**。其余 **19 个 R 模块没有实现**，未以 TODO、空函数或仅报错的脚手架冒充完成。

**5 个新模块也尚未通过锁定容器的数值验收，不是已冻结、可直接用于投稿的成品。** 本沙箱没有 R、Docker、Scanpy、AnnData 或 scvi-tools，也未能安装所需的 MCP SDK。不能将静态检查、数据契约单元测试或 `--help` 成功解释成科学计算成功。`complete_request=false` 已写入 `docs/build/BUILD_STATUS.json`。

执行至：A 的源码修复 → B 的四分支集成 → C 中 M3c 的五个 Python 模块源码及可执行检查。没有继续实现 M3a、M3b 和 M4 的 19 个 R 模块。**这是对用户允许的部分交付条款的使用，而不是完整系统完成声明。**

本 ZIP 包含整个修改后的源码树，不是只有差异文件。`CHANGES.patch` 已在输入源码的另一份独立解压副本上实际执行 `git apply --check` 和 `git apply`；应用后的 **604 个文件逐文件 SHA-256 与交付源码一致**。ZIP 名称按要求保留为 `omicstat_full_build.zip`，不表示全量需求已经完成。

## 2. 读取范围与输入基线

使用 Python 实际打开了上传的 ZIP：368 个非目录文件，顶层为 `REQUEST.md`、`omic-MCP/`、`overlays/`。输入 ZIP SHA-256：`45cbe5adba09e030baf4ca05f792cb17ce1cba617b0b565cab58efe96d1060ca`。

读取并据此实施：REQUEST、工程计划和基础设施规范、两个 builder brief、共享 R/Python 运行层、已有 DE/GSVA/limma-camera 模块、MCP、容器配置和锚点登记。四份 overlay 均实际应用。输入中没有 `vendor/` 或 `reference/`；没有重建这两个目录，也没有声称阅读过缺失的 medstat 参考快照。

还确认了一个影响验收的输入缺口：原始 limma-camera smoke 直接读取没有打包的 `acceptance/exemplars/limma-camera/` 文献/路由 fixture 和渲染后的 limma User's Guide；Yoruba fixture 的样本表也从该 Guide 提取。原始模块锁还绑定缺失的 PACK 文件。**没有编造这些文件，也没有删除其断言以获得通过。**

## 3. A：已完成的源码变更

### R3：limma-camera

核心版本改为 1.1.1。区分 collection、matched、selected、actually tested，并检验结果集合 ID 唯一且属于选中的集合；单次 roast 必须恰好返回一个被检验集合。

新增 `tables/gene_set_selection.csv`，逐集合记录 `collection_size`、`matched_size`、`matched`、`selected`、`tested` 和状态。未匹配、匹配但未选中、选中且完成检验互不混用。Methods/Results 使用同一个结果对象；结果 JSON 同时写入各阶段计数和 selected/tested/not-selected ID。原有图注通过同一结果对象获得实际检验的集合数。

补充了选择账本与 JSON/结果表一致性的 smoke 断言，将新账本加入 golden 文件集合。`tests/generate_golden.sh` 只在锁定 R/Bioc 版本下运行，明确检查原始未打包 fixture；缺失时报 `OS_ACCEPTANCE_EVIDENCE_MISSING`。

**没有手写或修改 golden JSON、golden 哈希、module_lock。** 原有 `golden_manifest.csv` 和 `module_lock.json` 保留，属于需要重新计算的旧记录。`results/limma_camera_results.json` 必须通过第 8 节真实运行重新产生。

### R4：run_id 与交接安全

保留 R 侧优先读取 `OMICSTAT_RUN_ID` 的修复，合并 MCP 的 `extra_env` 传递和 POSIX/PowerShell 路由转发；Python handoff 同样采用该 run ID。补充了元数据、相对路径、重复对象、哈希、符号链接越界、生态与 batch-corrected lineage 的拒绝路径。

实际通过的验证是：从原始 MCP 源码提取的进程启动函数启动真实 Python 子进程、原生 POSIX 路由转发，以及使用 argv 记录器验证 Docker 启动参数包含 `-e OMICSTAT_RUN_ID`。**记录器不是 Docker 容器，R 内部实际取值尚未执行验证。**

### R5 与既有失败

保留输入的 `/.omicstat-acceptance` 忽略项。`sva-batch/` 的 **17 个文件与输入逐字节一致**，包括 A6a 已知失败断言；没有改断言或放宽容差。

## 4. B：四份 overlay 与系统一致性

四份基础设施补丁均已合并。`handoff.R` 的冲突在保留 R4 和批次校正来源校验的基础上解决；生态集合同时包含 seurat、bioconductor、scverse、neutral。

主分析 MCP 仍只有原来的 5 个工具；没有新增主分析工具。R/Python 按入口扩展名分发，Python 出版图继续使用共享 R renderer。参考伴随服务是 overlay 自带的独立服务，不是给主分析 MCP 添加工具；本次未部署任何远程服务。

一份执行路由表仅注册实际存在的 **19 个分析入口 + 2 个 self-test 入口**。一份参考 `method_map.json` 覆盖全部 **38 个规划模块**，保留原有顺序，并添加 entry_status 区分已有源码、待锁定验收与未实现模块。不能把 method_map 中有条目解释为可运行。

测试驱动同时覆盖 R/Python；新增无第三方依赖的 `tools/test_build_contracts.py` 接入两个 runner。pytest 的 32 项契约测试在沙箱执行，未为了跑 pytest 擅自改变锁定镜像依赖。

增加只读模块封存校验 `mcp/module_seal.py`，出版审查把缺失/篡改锁记为 `PUB-LOCK-001` 阻塞项。实际检查的 19 个分析模块目前 **0 个能够通过完整文件绑定校验**：5 个新模块未封存，14 个原有锁至少缺失其绑定的 PACK，limma-camera 另有源码修改。未通过生成假锁掩盖此状态。SDK 缺失使此门禁与完整 MCP 出版流程的联动尚未运行；直接校验器的正反例通过。

133 条路由评测题已保留并验证 ID 唯一、目标合法、全部模块至少有 2 次覆盖。**没有执行盲读 agent 评测，未声称达到 90%/98% 门槛。** README 区分历史冻结哈希与本次未评级路由，并明确 primary 命中只能计 `expected`，可接受替代只进入第二个门槛。受新参数政策影响的历史题目仍需先复核。

## 5. C：五个新增模块的实际内容

| 模块 | 实际分析流程与产物 |
|---|---|
| scanpy-qc | 原始计数验证、QC 指标、显式阈值过滤、显式 Scrublet score/filter/skip 选择、细胞/基因保留账本、QC 图请求、原始计数交接。 |
| scanpy-cluster | total-count normalization、log1p、Seurat-flavor HVG、缩放、PCA、邻接图、Leiden、UMAP；保留 raw counts/logcounts，规范 PCA 符号与 cluster ID。 |
| scanpy-markers | 每簇相对其余细胞的 rank_genes_groups、完整 canonical feature table 与 marker 明细、点图数据；拒绝把逐细胞 marker 当作条件间推断。 |
| scvi-integrate | 原始计数 SCVI、CPU 确定性训练、潜在表示、整合前后嵌入与邻域批次混合描述、模型/特征清单交接；不把潜在空间校正冒充原始表达矩阵。 |
| scanvi-annotate | 从验证过的 SCVI handoff 加载模型，使用明确的已知标签/未标注类别训练 SCANVI，导出预测、概率和交叉表；保留原始标签，置信度不解释为准确率。 |

每个模块都有 SKILL、独立入口/core/report/QC、calls_registry、五类 references、smoke、fixture builder 和 golden/lock 生成脚本。共享层执行 `--spec`、`--from-run`、StudyContract 哈希、轴与计数检查、生态/来源校验、警告捕获、来源记录及 R figure request。

阈值、PC/HVG 数、邻居数、聚类 resolution、训练 epoch 和涉及科学判断的关键选择显式要求用户提供。默认值不声称来自文献多数派。所有计算调用的参数在源码和 registry 中显式列出；**锁定包的 `inspect.signature` 默认值尚未实测**，登记状态为 pending_locked_container，由 `capture_locked_defaults.py` 在真实镜像内读取，发现不接受的参数就失败。

锚点采用已有 SHA-256 锁定的 PBMC3k 下载文件及 scvi 包自身 synthetic_iid 模拟器。smoke 用 PBMC 子集控制成本，模拟数据只做可重复运行验收，不代表临床/生物学准确度。新增模拟锚点登记保留待生成哈希；没有填写虚构的样本结果或预测分数。

smoke 脚本包含官方 API 独立回放、`--spec` 重放、拒绝路径、参数有效性、完整表比较和嵌入/概率容差比较。预先规定的同平台数值容差为 atol/rtol=1e-6，聚类同平台 ARI=1；marker 直接回放另有更严断言。**这些比较尚未在所需镜像执行，不是已观测到满足容差。** 跨平台 ARI≥0.95、双独立 agent、三生态后端等价、所有 R 出版图与人工看图均未完成。

## 6. 全部 38 个模块状态

`built` 仅表示本次新增了实际分析源码与配套文件，**不表示冻结/验收通过**。`untouched` 对原有模块表示代码未改，对缺失模块表示没有实现；第三列明确区分。

| 模块 | 状态 | 说明 |
|---|---|---|
| `deseq2-wald` | `untouched` | 原有模块源码保留；本次未重新验证锁定环境数值 |
| `deseq2-qc` | `untouched` | 原有模块源码保留；本次未重新验证锁定环境数值 |
| `deseq2-lrt` | `untouched` | 原有模块源码保留；本次未重新验证锁定环境数值 |
| `edger-qlf` | `untouched` | 原有模块源码保留；本次未重新验证锁定环境数值 |
| `limma-voom` | `untouched` | 原有模块源码保留；本次未重新验证锁定环境数值 |
| `limma-array` | `untouched` | 原有模块源码保留；本次未重新验证锁定环境数值 |
| `limma-dupcor` | `untouched` | 原有模块源码保留；本次未重新验证锁定环境数值 |
| `sva-batch` | `untouched` | 原有模块源码保留；本次未重新验证锁定环境数值 |
| `clusterprofiler-ora` | `untouched` | 原有模块源码保留；本次未重新验证锁定环境数值 |
| `clusterprofiler-gsea` | `untouched` | 原有模块源码保留；本次未重新验证锁定环境数值 |
| `clusterprofiler-compare` | `untouched` | 原有模块源码保留；本次未重新验证锁定环境数值 |
| `fgsea-prerank` | `untouched` | 原有模块源码保留；本次未重新验证锁定环境数值 |
| `gsva-score` | `untouched` | 原有模块源码保留；本次未重新验证锁定环境数值 |
| `limma-camera` | `changed` | 1.1.1：集合计数与逐集合账本修复；R 运行和重新冻结待完成 |
| `seurat-qc` | `untouched` | 未实现；未添加空壳，也未注册为可执行模块 |
| `seurat-cluster` | `untouched` | 未实现；未添加空壳，也未注册为可执行模块 |
| `seurat-integrate` | `untouched` | 未实现；未添加空壳，也未注册为可执行模块 |
| `seurat-markers` | `untouched` | 未实现；未添加空壳，也未注册为可执行模块 |
| `seurat-modulescore` | `untouched` | 未实现；未添加空壳，也未注册为可执行模块 |
| `scater-qc` | `untouched` | 未实现；未添加空壳，也未注册为可执行模块 |
| `scran-cluster` | `untouched` | 未实现；未添加空壳，也未注册为可执行模块 |
| `batchelor-integrate` | `untouched` | 未实现；未添加空壳，也未注册为可执行模块 |
| `scran-markers` | `untouched` | 未实现；未添加空壳，也未注册为可执行模块 |
| `aucell-score` | `untouched` | 未实现；未添加空壳，也未注册为可执行模块 |
| `singler-annotate` | `untouched` | 未实现；未添加空壳，也未注册为可执行模块 |
| `muscat-pseudobulk` | `untouched` | 未实现；未添加空壳，也未注册为可执行模块 |
| `speckle-propeller` | `untouched` | 未实现；未添加空壳，也未注册为可执行模块 |
| `cellchat-communication` | `untouched` | 未实现；未添加空壳，也未注册为可执行模块 |
| `monocle3-trajectory` | `untouched` | 未实现；未添加空壳，也未注册为可执行模块 |
| `slingshot-trajectory` | `untouched` | 未实现；未添加空壳，也未注册为可执行模块 |
| `wgcna-network` | `untouched` | 未实现；未添加空壳，也未注册为可执行模块 |
| `maftools-landscape` | `untouched` | 未实现；未添加空壳，也未注册为可执行模块 |
| `immunedeconv-infiltration` | `untouched` | 未实现；未添加空壳，也未注册为可执行模块 |
| `scanpy-qc` | `built` | 新增完整 Python 源码与测试/生成脚本；数值、金标准、模块锁未验收 |
| `scanpy-cluster` | `built` | 新增完整 Python 源码与测试/生成脚本；数值、金标准、模块锁未验收 |
| `scanpy-markers` | `built` | 新增完整 Python 源码与测试/生成脚本；数值、金标准、模块锁未验收 |
| `scvi-integrate` | `built` | 新增完整 Python 源码与测试/生成脚本；数值、金标准、模块锁未验收 |
| `scanvi-annotate` | `built` | 新增完整 Python 源码与测试/生成脚本；数值、金标准、模块锁未验收 |

未实现的 19 个模块完整名单：`seurat-qc`、`seurat-cluster`、`seurat-integrate`、`seurat-markers`、`seurat-modulescore`、`scater-qc`、`scran-cluster`、`batchelor-integrate`、`scran-markers`、`aucell-score`、`singler-annotate`、`muscat-pseudobulk`、`speckle-propeller`、`cellchat-communication`、`monocle3-trajectory`、`slingshot-trajectory`、`wgcna-network`、`maftools-landscape`、`immunedeconv-infiltration`。

## 7. 实际测试与未测试项目

所有日志位于 `omic-MCP/docs/build/sandbox_tests/`；`summary.json` 是最终结果索引，`*.initial.log` 保留早期失败尝试，不用后来的静态通过掩盖它们。

| 检查 | 本次实际结果 |
|---|---|
| 新增 sc 数据/交接契约 pytest | 32 passed。 |
| 源码注册/launcher/run_id/模块封存测试 | 12 passed；不依赖 MCP SDK，不是完整 MCP/R 集成验收。 |
| package identity | 3 passed；初次缺少 OMICSTAT_TEST_TMP 的错误已通过正确设置测试隔离目录重跑，未改断言。 |
| tools/test_tools.py | 21 项：20 passed，1 项因 R 缺失而 skipped。 |
| 原有共享 ospy | 通过；scvi 相关随机种子部分明确 skipped。 |
| Python registry checker、模块 scaffolder、环境配置 | 均通过其可执行检查。 |
| 五个新模块 smoke | 调用登记、文档/默认值对应、help、未知参数拒绝均通过；数值 anchor/model/golden 全部明确 skipped。 |
| 出版规则 JSON | 21 模块记录、28 个规则 ID 有效。 |
| R 源码 lint | 97 个文件，0 问题；这是 Python lint，不是 R parser。 |
| 全树静态检查 | 107 个 Python AST、61 个 JSON、5 个 JSON schema、23 个 shell 语法检查，0 错误。 |
| reference 配置/分叉测试，交付归档布局 | 12 项：11 passed；需要原始 Git 历史的 1 项明确 skipped。 |
| reference 配置，在人为建立的输入 Git 基线上 | 原始来源 commit 不是当前 HEAD 的祖先，1 项 failed；未伪造历史。 |
| reference 内核完整测试集 | 报告 117 项、4 个 errors，错误涉及缺失 MCP SDK/其导入后的连带状态；不能称全通过。 |
| mcp/test_publication.py、mcp/test_client.py | 启动被 `ModuleNotFoundError: mcp` 阻塞。尝试安装 mcp==1.28.0 失败，记录保留。 |
| 补丁回放与完整源码 | `git apply --check`、实际 apply、604 个文件逐一 SHA-256 一致。 |

沙箱实际 Python 为 3.13.5、torch 为 2.10.0+cpu；这不等于请求的 Python 3.12.13/torch 2.14.0+cpu。未修改环境锁来迎合沙箱。没有运行 R/Bioconductor、R parse、真正 Docker 路由、科学数值、R/Python 跨容器作图、完整 stdio、远程部署或投稿 ready 验收。

输入/overlay 中已有的 `BUILD_RECORD.md`、`test_report.txt`、`DEPLOYMENT_LOG.md` 等是继承的历史材料，**不是本次运行证据**。不得把它们与本节日志混为一谈。

## 8. 锁定环境的准确执行顺序

以下是需要在拥有两个锁定镜像、所需原始 acceptance 证据和公开锚点的机器上执行的命令。**本次没有执行这些 Docker/R 命令，也没有保证其未运行的数值断言已经通过。** 命令针对现有 14 个 R 模块和新增 5 个 Python 模块，不存在 19 个未实现模块的验收命令。

### 8.1 在宿主机准备与确认镜像

```bash
cd omic-MCP
export R_IMAGE=omicstat-r:2026.09.1
export PY_IMAGE=omicstat-py:2026.09.1
docker image inspect "$R_IMAGE" "$PY_IMAGE" > /tmp/omicstat-image-inspect.json
mkdir -p .omicstat-acceptance/build-logs .omicstat-acceptance/python-smoke
# Explicit, separate data-preparation step; analysis engines do not download.
bash acceptance/data/fetch_anchor_data.sh 10x bulk
# Only when the original acceptance-data layer is not already installed:
docker run --rm --user "$(id -u):$(id -g)" -v "$PWD":/omicstat -w /omicstat   "$R_IMAGE" Rscript acceptance/data/install_acceptance_lib.R
```

不要下载许可闸门禁止的数据。上面的 fetch 分组来自输入原有登记；没有新增 KEGG、CADD、PanglaoDB、DepMap 下载。

### 8.2 R 解析、共享层与 R3

```bash
docker run --rm --network none -v "$PWD":/omicstat -w /omicstat "$R_IMAGE"   Rscript -e 'stopifnot(as.character(getRversion())=="4.6.1",as.character(BiocManager::version())=="3.23"); f <- list.files(c("skills","tools","env","acceptance"),pattern="[.]R$",recursive=TRUE,full.names=TRUE); invisible(lapply(f,parse)); cat(length(f),"R files parsed\n")'
docker run --rm --network none -v "$PWD":/omicstat -w /omicstat "$R_IMAGE"   Rscript skills/_shared/tests/test_omics_shared.R
docker run --rm --network none -v "$PWD":/omicstat -w /omicstat "$R_IMAGE"   Rscript skills/_shared/tests/test_convert.R
docker run --rm --network none -v "$PWD":/omicstat -w /omicstat "$R_IMAGE"   Rscript skills/_shared/tests/test_render_figure_request.R
# Requires the original withheld LC fixtures listed immediately below.
docker run --rm --network none -v "$PWD":/omicstat -w /omicstat   -e OMICSTAT_TEST_TMP=/tmp/omicstat-r3 "$R_IMAGE"   bash skills/limma-camera/tests/generate_golden.sh
```

最后一条会真正重新运行引擎，产生 `results/limma_camera_results.json`，更新真实 golden manifest，然后运行模块锁生成和校验。此前必须由所有者提供原始未打包证据：`routing_eval_limma_camera.jsonl`、`literature/corpus.jsonl`、`literature/extraction.jsonl`、`L1_bioc3.23/limma/vignettes/usersguide.rendered.txt`，均在 `acceptance/exemplars/limma-camera/` 下；完整原始锁校验还需要相应 PACK。脚本缺文件时失败，不自动生成替身。共享转换还需实际验证 zellkonverter 的 AnnData 读取版本与 Python 镜像的兼容性。

### 8.3 五个 Python 模块：真实 API 默认值 → 数值 → golden → module_lock

```bash
for m in scanpy-qc scanpy-cluster scanpy-markers scvi-integrate scanvi-annotate; do
  docker run --rm --network none --user "$(id -u):$(id -g)"     -v "$PWD":/omicstat -w /omicstat -e HOME=/tmp     -e OMICSTAT_PY_CONTAINER=1     -e OMICSTAT_PY_IMAGE_ID="$(docker image inspect "$PY_IMAGE" --format '{{.Id}}')"     -e OMICSTAT_TEST_TMP=/omicstat/.omicstat-acceptance/python-smoke     "$PY_IMAGE" bash "skills/$m/tests/generate_golden.sh" || exit "$?"
done
```

每个生成脚本依次执行 `capture_locked_defaults.py`、要求锁定环境的数值 smoke（写 golden）、第二次 smoke（比对 golden）、`make_module_lock.py`、`make_module_lock.py --check`。默认值捕获工具对已捕获记录拒绝静默覆盖；重复生成时先核查变更，只有明确复审后才使用其 `--replace`。不要删除断言或放宽容差来迁就结果。发现锁定 API 不符时，停下修正源码/登记并重跑。

### 8.4 Python 图形交给同一个 R 层

```bash
find .omicstat-acceptance/python-smoke -type f   -path '*/anchor/figure_data/figure_request.json' -print0 |
while IFS= read -r -d '' request; do
  run_dir="$(dirname "$(dirname "$request")")"
  docker run --rm --network none -v "$PWD":/omicstat -w /omicstat     "$R_IMAGE" Rscript skills/_shared/scripts/render_figure_request.R     --run-dir "/omicstat/$run_dir" || exit "$?"
done
```

逐张检查 PNG/PDF、n 的单位、图注阈值、图例/标签不裁切；随后做同参数重放和图形规范检查。生成 figure_request 不等于出版图已经渲染或通过人工审阅。本包不包含未运行的出版图。

### 8.5 原有 R 模块金标准/锁：只在完整原始验收证据齐全时

```bash
for m in deseq2-qc deseq2-wald deseq2-lrt edger-qlf limma-voom          limma-array limma-dupcor clusterprofiler-ora clusterprofiler-gsea          clusterprofiler-compare fgsea-prerank gsva-score; do
  test -f "acceptance/exemplars/$m/PACK.md" || exit 3
  docker run --rm --network none -v "$PWD":/omicstat -w /omicstat     -e OMICSTAT_WRITE_GOLDEN=1 "$R_IMAGE"     Rscript "skills/$m/tests/run_smoke_test.R" || exit "$?"
  docker run --rm --network none -v "$PWD":/omicstat -w /omicstat     "$R_IMAGE" Rscript "skills/$m/tests/run_smoke_test.R" || exit "$?"
  docker run --rm --network none -v "$PWD":/omicstat -w /omicstat     "$R_IMAGE" Rscript tools/make_module_lock.R "$m" || exit "$?"
  docker run --rm --network none -v "$PWD":/omicstat -w /omicstat     "$R_IMAGE" Rscript tools/make_module_lock.R "$m" --check || exit "$?"
done
# Keep the known failure visible. Do not hide it with '|| true'.
docker run --rm --network none -v "$PWD":/omicstat -w /omicstat   "$R_IMAGE" Rscript skills/sva-batch/tests/run_smoke_test.R
```

有些原有 smoke 还读取其他未打包验收材料；任何缺失都要据实际错误补齐原始材料，不能编造。日志出现 SKIP 不算通过完整发布门禁。sva-batch 的 A6a 保留；在其真实问题未经授权处理、全部断言通过前，不生成新的已验收锁。

### 8.6 全套测试、实际 stdio 与参考服务

```bash
# These wrappers are run on the HOST; they start the respective containers.
bash env/test.sh
bash env/py/test.sh
# Explicit pure Python/registry tests in the Python image, without adding pytest to its lock:
docker run --rm --network none -v "$PWD":/omicstat -w /omicstat "$PY_IMAGE"   bash tools/run_tests_py.sh
# Real host-level MCP stdio, using both containers and pinned MCP requirements:
bash env/py/test_e2e.sh
# Reference-service offline tests in the R image's pinned MCP Python environment:
docker run --rm --network none -v "$PWD":/omicstat -w /omicstat/reference_service   "$R_IMAGE" /opt/omicstat/venv/bin/python -m unittest discover -s tests -p 'test_*.py' -v
docker run --rm --network none -v "$PWD":/omicstat -w /omicstat/reference_service/app   "$R_IMAGE" /opt/omicstat/venv/bin/python -m unittest discover -s tests -p 'test_*.py' -v
```

`env/test.sh`/`env/py/test.sh` 是宿主机 Docker 包装器，不应在无 Docker 的镜像内部再调用。最后仍需要 source checkout、无 `.git` 安装包和最终安装位置的真实 stdio/出版验收。参考配置历史重建需要原始四个来源提交；交付归档只可运行当前配置的加载/验证，不代表历史生成器已复算通过。

## 9. 所有者待定事项与边界

1. AUCell 与 GSVA 谁作为标准单细胞打分路线：保持待定；对应 R 模块未实现。
2. Python 前端进入生态中立 R 后端时的 ecosystem 标签：未替所有者决定。转换基础设施已经合并，但新 Python 模块不绕过前端生态约束；R 后端链未实现/未验收。
3. QC 阈值、PC/HVG/邻居数量、聚类 resolution 等：作为显式参数，而非暗定经验阈值。PBMC 示例/小型 smoke 参数仅用于验收示例，不是通用科学推荐。
4. scVI/scANVI 模型训练终止配置、参考标签、未标注类别、展示置信度等由用户明确指定；CPU 规模/epoch 上限属于运行资源保护，不构成充分训练的科学保证。
5. scVI 跨平台确定性与容差、R 转换的三对象等价、未实现的后端分析和 19 个 R 模块：均未自行判为通过。
6. gsva-score 已有推断待定行为、其他已有 S1 未决项不在此包中重做裁决。

## 10. 对计划的偏离与剩余阻塞

**最大偏离是仅实现 M3c 五个新模块，而非 24 个全量新增模块。** 19 个 R 模块完整名单见第 6 节；没有交付其脚手架。未实现所有单细胞标准流水线、三生态后端一致性、M4、盲测或跨 agent 验收。

未执行 locked R/Python 数值、实际函数默认值导出、golden、module_lock、R parser 或人工看图。新增模块的默认值登记需要真实包探针确认；部分 Scanpy 指定版本网页未能核到相应页面，文档区分指定版本目标与可读取的官方稳定版参考，不把后者冒充已验证的 locked API。scvi 文档目标为 1.5.1。

输入缺失原始 PACK/L1/文献 fixture，导致旧锁和部分旧 smoke 不能从这个源码包独立验收。保留这些失败前提；没有把历史期望值再抄写成“本次计算值”。这意味着本包目前也不是一个可无条件离线跑完全部验收的发行包。

MCP SDK 无法在沙箱安装，完整 publication/stdin/参考工具测试受阻。新封存门禁仅直接校验器和来源函数测试通过，不宣称实际服务器联动通过。参考服务没有构建/启动/部署，历史配置生成器无法在缺失分支历史时复算；对 method_map 的状态合并是当前源码集成，不是假称历史构建完全一致。

没有更改 R/Python 环境 pins，没有修改 sva-batch 断言，没有重建 vendor/reference，没有下载禁止资源，没有新建主分析 MCP 工具，没有伪造任何 anchor 数字、金标准或模块锁。

**可用交付：完整源码树 + 可回放补丁 + 明确测试记录及未完成清单。不可宣称：38 模块完成、5 个新模块科学结果已复现、全测试通过、全部出版门禁 ready。**
