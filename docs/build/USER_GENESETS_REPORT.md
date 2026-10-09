# 用户自备本地基因集（user-supplied gene-set collections）报告

分支 `feat/user-genesets`（自 `origin/integrate/final` 4db080f），工作树 GT103 `~/omic-usersets`，scratch `~/omic-sol61/user_genesets/`。未合并，等协调员审阅。

## 1. 做了什么

omicstat 仍然**不打包、不下载** KEGG / CADD / PanglaoDB / DepMap / MSigDB 内容；新增的是一条“用户自己下载的本地文件”通道：用户提供 GMT（scanpy-annotate 为 marker-panel JSON），外加 web app 下载工具写出的 provenance JSON，或在命令行显式给出 source / version / ID 类型。套件在运行时计算 sha256、核对 provenance、检查 ID 类型 / 物种 / 重叠度，并把记录写入 `provenance/` 与 Methods。注册集合（registered collections）、GO 默认路径和所有默认运行完全不变。

### 1.1 共享契约

| 文件:行 | 内容 |
|---|---|
| `skills/_shared/scripts/user_genesets.R:26-27` | 常量：重叠下限 10%（`OS_USER_GENESETS_MIN_OVERLAP`），ID 形态一致比例 90% |
| `skills/_shared/scripts/user_genesets.R:38` | `os_user_geneset_flags()`：统一声明 `--gene-sets`、`--gene-sets-provenance/-source/-version/-id-type/-species/-name/-terms`、`--feature-id-type` |
| `skills/_shared/scripts/user_genesets.R:70` | `os_user_genesets_not_bundled()`：未打包集合的拒绝文字（说明需本地文件、可用 web app 公共数据工具或 KEGG REST 学术条款、用户自负条款责任） |
| `skills/_shared/scripts/user_genesets.R:97` | `os_user_gmt_read()`：GMT 格式检查（≥3 列、无空行、term ID 非空不重复、每行至少一个基因）；**不**做 KEGG 名称排除 |
| `skills/_shared/scripts/user_genesets.R:126` | `os_user_provenance_read()`：provenance 键 `source, name, version_or_release, download_time, urls, sha256, terms, terms_url, id_type, species`；必需 `source, version_or_release, sha256, id_type` |
| `skills/_shared/scripts/user_genesets.R:151` | `os_user_genesets_resolve()`：无 provenance 时强制三个显式字段；显式字段与 provenance 冲突即拒绝；运行时 sha256 与 provenance 比对；GMT 成员 ID 形态与声明的 id_type 一致性（≥90%） |
| `skills/_shared/scripts/user_genesets.R:212` | `os_user_genesets_check()`：id_type == 分析键类型（不静默转换）；已知物种一致（hsa/human/Homo sapiens/9606、Mus_musculus 等同义词归一）；重叠度 <10% 拒绝；记录 overlap |
| `skills/_shared/scripts/user_genesets.R:247,259` | Methods 句子生成并插在 Results 标题前 |
| `skills/_shared/scripts/user_genesets.R:281` | TERM2GENE / TERM2NAME 构造（clusterProfiler 通用函数用） |
| `skills/_shared/scripts/user_genesets.R:292` | `os_user_dotplot_floor()`：仅用户集合的点图设最低高度（见 §6） |
| `skills/_shared/py/ospy/user_genesets.py:39-195` | Python 对应实现（flags/given/read_provenance/resolve/check/methods_sentence） |
| `skills/_shared/py/ospy/sc_module.py:339-341,387,397-399` | 通用钩子：`res["methods_extra"]` 追加到 Methods；`--gene-sets-provenance` 进入 provenance inputs；`user_gene_sets` 进 provenance.json 并写 `provenance/user_gene_sets.json`。默认运行无这些键，行为不变 |
| `skills/_shared/scripts/enrich_rank_io.R:1-4,25-30` | 注明 KEGG term-ID 排除只针对注册集合；未注册集合的拒绝文字增加 `--collection user` 路线说明（错误码不变） |
| `skills/_shared/scripts/calls_check.R:18-23,61-62` | 同一函数两种参数集（compareCluster `fun="enrichGO"` 与 `fun="enricher"`）：registry 条目可带 `site_requires` / `site_excludes`，C1/C3 按条目成立；无这两个字段的 registry 行为完全不变 |

### 1.2 各模块

| 模块 | 文件:行 | 改动 |
|---|---|---|
| clusterprofiler-ora | `run_clusterprofiler_ora.R:24,34,44-48,64-71`；`clusterprofiler_ora_core.R:55-56,90-108`；`clusterprofiler_ora_report.R:4-12,24-25`；`reporting-templates.md`（`methods_custom`/`results_custom`） | `--database custom` → `clusterProfiler::enricher(TERM2GENE, TERM2NAME)`；单一 BH 家族，标签 `"<source> (user-supplied)"`；`--ontology/--pool/--simplify` 与 custom 冲突拒绝；`--database KEGG` 等仍为 `OS_REFDATA_MISSING`，但文字说明本地文件路线 |
| clusterprofiler-gsea | `run_clusterprofiler_gsea.R:20,29,39-42`；`clusterprofiler_gsea_core.R:50-51,66-77`；`clusterprofiler_gsea_report.R:2-16` | `clusterProfiler::GSEA`，多层级参数与 GO 路线相同；signed 点图 / ridge 图注改写为用户集合名 |
| clusterprofiler-compare | `run_clusterprofiler_compare.R:15,24,30-33`；`clusterprofiler_compare_core.R:38-39,69-95`；`clusterprofiler_compare_report.R:33-35`；`calls_registry.json` | 同一群体：`compareCluster(fun = "enricher", source_from = "clusterProfiler")`；群体不同：每个 list 单独 `enricher` |
| fgsea-prerank | `run_fgsea_prerank.R:28,36-37`（及 collection 读取段） | `--collection user --gene-sets <gmt> --feature-id-type`；fgseaMultilevel 调用不变 |
| gsva-score | `run_gsva_score.R:32,47-48`（及 collection 读取段） | 同上，GSVA 调用不变 |
| limma-camera | `run_limma_camera.R:42,60-61`（及 collection 读取段） | 同上；ranked list 与表达矩阵两种 universe |
| aucell-score | `aucell_score_core.R:7-24`；`run_aucell_score.R` | 已接受任意用户 GMT；新增 provenance 契约（`--sets-source` 作为 source）。**未声明**文件的 KEGG/CADD/PanglaoDB/DepMap 名称闸门保留（原测试仍通过），经契约声明的文件解除该闸门并记录 |
| seurat-modulescore | `seurat_modulescore_core.R:7-24`；`run_seurat_modulescore.R` | 同 aucell；`--set-organism` 与 provenance species 同义词比较，chain organism 作为分析物种 |
| scanpy-annotate | `scanpy_annotate_core.py:27-35,…`；`run_scanpy_annotate.py` | marker panel（如 PanglaoDB 衍生）只加 provenance 记录；面板计算不变 |

文档：9 个模块的 `SKILL.md`（新节 “User-supplied gene sets”）、`references/parameters.md`、`references/options.md`、`references/troubleshooting.md`；`skills/_shared/docs/CONVENTIONS.md`（§3 新错误码 + 末节契约说明）；router `skills/omicstat/SKILL.md` §2/§4/§7；routing eval 新增 7 题（G001-G004、O001-O003，原 139 题不变，总 146）；`tools/test_build_contracts.py:120-121` 计数 139→146（精确等式保持）；`reference_service/app/method_map.json` 只更新 router 的 `source_sha256`（由 `tools/check_reference_integration.py --write` 生成）。

## 2. 新旗标

| 旗标 | 适用 | 说明 |
|---|---|---|
| `--database custom` | clusterprofiler-ora/-gsea/-compare | 新 enum 值；默认仍 `GO` |
| `--gene-sets <gmt>` | clusterprofiler-* 新增；fgsea/gsva/camera 原有（帮助文字扩展） | 用户 GMT |
| `--collection user` | fgsea-prerank、gsva-score、limma-camera | string 值 `user` 触发用户通道 |
| `--gene-sets-provenance <json>` | 全部 9 个模块 | provenance JSON |
| `--gene-sets-source`、`--gene-sets-version`、`--gene-sets-id-type` | 全部 | 无 provenance 时必需，绝不猜测 |
| `--gene-sets-species`、`--gene-sets-name`、`--gene-sets-terms` | 全部 | 可选 |
| `--feature-id-type ENTREZID\|SYMBOL\|ENSEMBL` | fgsea、gsva、camera、aucell、modulescore、scanpy-annotate | 分析特征 ID 类型（clusterProfiler 模块用原 `--key-type`） |

新旗标均无默认值，因此默认运行的 canonical argv / resolved_spec 不变。

## 3. 拒绝信息

| 情况 | 错误码 | 信息要点 |
|---|---|---|
| 无 provenance 且缺 source/version/id_type | `OS_MISSING_PARAMETER` | "a user GMT without --gene-sets-provenance needs --gene-sets-version, --gene-sets-id-type; source, version and identifier type are never guessed." |
| sha256 与 provenance 不符 | `OS_REFDATA_MISMATCH` | "the GMT's sha256 (…) differs from the provenance JSON sha256 (…); the file changed after download or the provenance belongs to another file." |
| 显式旗标与 provenance 不一致 | `OS_CONFLICTING_PARAMETERS` | "--gene-sets-version 'x' disagrees with the provenance JSON value 'y'." |
| GMT 成员 ID 形态与声明不符 | `OS_GENE_SET_ID_MISMATCH` | "only 0.0% of the N unique GMT gene IDs have the form of SYMBOL identifiers …" |
| 基因集 ID 类型 ≠ 分析键类型 | `OS_GENE_SET_ID_MISMATCH` | "the user gene sets use ENTREZID identifiers but the analysed features are SYMBOL (--key-type); omicstat does not convert identifiers silently." |
| 物种不符 | `OS_GENE_SET_SPECIES_MISMATCH` | "the user gene sets are for Homo sapiens but the analysis is Mus musculus" |
| 重叠 <10% | `OS_GENE_SET_LOW_OVERLAP` | "only 6 of 186 unique gene-set genes (3.2%) are present in …; under 10% usually means the wrong identifiers (type, version suffix or species)." |
| GMT 格式错误 | `OS_INVALID_INPUT` | 行号 + 原因（少于三列 / 空行 / 重复 term / 无基因） |
| 无本地文件请求 KEGG | `OS_REFDATA_MISSING` | "KEGG gene sets are not bundled with omicstat and are never downloaded by it. Supply them as a local file you obtained yourself (… web app's public-data tool, or … KEGG REST API under its academic terms) and run with --database custom --gene-sets <file.gmt> …" |
| 契约旗标用于非用户通道 | `OS_CONFLICTING_PARAMETERS` | "--gene-sets-*, --gene-sets apply only to --database custom." |

## 4. Methods 示例（来自 ORA 冒烟测试的实际运行，合成夹具）

> Gene sets: KEGG-like pathways (synthetic test fixture) (Homo sapiens), retrieved from KEGG REST on 2026-10-09T00:00:00Z, release synthetic-test-1, used under academic use terms of the source (synthetic fixture); supplied by the user, not bundled with omicstat. The GMT file (SHA-256 aa501446642e481f1f02ac519e12441c257d3844937a6084875e7197376a5405) held 6 sets of ENTREZID identifiers. 249 of 249 unique set genes (100.0%) were present in the eligible universe.

真实 KEGG 文件的句子形如："Gene sets: KEGG pathways (hsa) (Homo sapiens), retrieved from KEGG REST on 2026-10-09, release <release>, used under KEGG academic terms; supplied by the user, not bundled with omicstat. …"

## 5. 测试

- 共享单元测试：`skills/_shared/tests/test_user_genesets.R`（24 项，含 site_requires/site_excludes）与 `skills/_shared/py/tests/test_user_genesets.py`（2 组），均已加入 `tools/run_tests.sh` / `tools/run_tests_py.sh`。
- 测试夹具：`skills/_shared/tests/user_genesets_testkit.R`——基因全部取自各模块自身 anchor，term ID 为 `hsa04110` 式外加一个 `KEGG_APOPTOSIS`（MSigDB 式，证明注册集合的 KEGG 名称排除对用户文件不生效；`os_gmt_read` 对同一文件仍拒绝）。无任何 KEGG 内容。
- 每个触及模块的冒烟测试新增：用户 GMT 在其 anchor 上运行，并与独立的直接调用重放比对（ORA `enricher`、GSEA `GSEA`、compare `compareCluster(fun="enricher")`、`fgseaMultilevel`、`gsva`、`camera`、`AUCell_calcAUC`、`AddModuleScore`、scanpy-annotate 面板表逐字节相同）；ID 类型不符、sha256 不符、低重叠三类拒绝；provenance/user_gene_sets.json、provenance.json 与 Methods 句子的断言；ORA/GSEA/fgsea 另测 `--spec` 字节级重放。
- 冒烟测试结果（锁定镜像内，单独运行）：clusterprofiler-ora、-gsea、-compare、fgsea-prerank、gsva-score、limma-camera、aucell-score、seurat-modulescore、scanpy-annotate 全部 SMOKE PASSED，既有 golden 检查均 PASS。

## 6. Golden、封存与全套测试

- **Golden**：仓库内全部 95 个受版本控制的 golden 文件（44 个 `golden_manifest.csv` 及 `tests/golden/*`）在全套测试后 `git diff --quiet HEAD` 逐字节不变；未编辑、未重生成任何 golden。各触及模块冒烟测试中原有 golden 检查均 PASS（ORA 结果 JSON、fgsea/gsva/camera 的 PNG 等）。为保持 golden 字节一致，模块版本号未改。
- **封存**：用官方工具重封 8 个 R 模块（`tools/make_module_lock.R`，镜像 `omicstat-r:2026.10.1`，`OMICSTAT_IMAGE_ID` 显式设为该镜像 ID）：clusterprofiler-ora/-gsea/-compare、fgsea-prerank、gsva-score、limma-camera、aucell-score、seurat-modulescore；8 个 Python 模块（`tools/make_module_lock.py`，`omicstat-py:2026.09.1`，`OMICSTAT_PY_IMAGE_ID` 显式）全部重封——scanpy-annotate 因自身改动，其余 7 个因共享 `ospy/`（sc_module.py 钩子与新 user_genesets.py）及 `_shared/py/tests` 文件哈希变化；锁内 environment/packages 未变，差异只在文件哈希。之后对全部 **42 个锁（34 R + 8 Python）逐个 `--check`：42 OK / 0 BAD**（日志 `~/omic-sol61/user_genesets/logs/reseal.log`）。
- **R 全套** `bash env/test.sh`：198 条命令，`== done: ALL PASSED (0 skipped for missing packages)`；sva-batch 仍只有 2 条已记录的 A6a KNOWN-FAILING anchor（未触及该模块）。日志 `logs/r_suite.log`、`art_r/logs/`。
- **Python 全套** `bash env/py/test.sh`：`== done: ALL PASSED (44 commands)`（原 43 + 新 `test_user_genesets.py`）。日志 `logs/py_suite.log`。
- **Host MCP e2e** `env/py/test_e2e.sh`（`OMICSTAT_E2E_PYTHON=$HOME/omic-venv/bin/python`，`OMICSTAT_RUNS_ROOT` 与 `OMICSTAT_MCP_SCRATCH` 同为 `~/omic-sol61/user_genesets/e2e_runs`）：99 assertions，99 passed，0 failed，3 skipped（native 引擎不可用，与既往相同）。日志 `logs/e2e.log`。
- **Reference**（router 改动影响 `method_map.json` 的 `source_sha256`）：`check_reference_integration.py --write` 后复查 PASS（6 configs，41-module map）；`reference_service/tests` 13/13 OK，`reference_service/app/tests` 122/122 OK，`smoke_reference_stdio.py` passed，`smoke_omicstat_entry.py` 正常输出，`fork_status.py` problems 为空。日志 `logs/reference_suites.log`。
- 静态检查：9 个模块 `check_defaults` / `check_flag_docs` 0 问题，`check_calls` 0 registry / 0 default-drift 问题（新 `enricher`、`GSEA`、`compareCluster(fun="enricher")` 条目的 function_default 均由锁定容器 formals 校验），`lint_r` 160 文件 0 问题，SKILL front matter 44/0。

## 7. 已看过的图

- ORA custom（KEGG-like 合成夹具）点图：`~/omic-sol61/user_genesets/example_png/ora_custom_dotplot.png`。三个显著集合（hsa04110、p53、KEGG_APOPTOSIS），标签换行可读，图注写明 "Over-representation analysis (KEGG REST (user-supplied))"。首个探针运行只有 1 个显著集合时，共享点图 builder 按行数定高，尺寸图例底部被裁切；因此仅对用户集合点图加了最低高度（`os_user_dotplot_floor`，等于共享 builder 8 行时的高度），修复后图例完整。GO 默认路径未改（见 §8）。
- GSEA custom signed 点图：图注为用户集合名，非 "GO"。

## 8. 遗留 / 待协调员裁决

1. 共享 `os_enrich_dotplot`（`fig_enrich.R`）在显著项很少（约 ≤3 行）时会裁掉尺寸图例——GO 路线同样存在。改 `fig_*.R` 会触动 Python seals 和既有 golden 的 figure_spec，本 lane 未改，仅在用户集合路径加了下限高度。
2. fgsea/gsva/camera/aucell 不知道分析物种，故只记录物种、不比较；clusterProfiler 模块绑定 org.Hs.eg.db，按 Homo sapiens 比较；modulescore 用 chain organism；scanpy-annotate 用 `--species`。
3. 10% 重叠下限和 90% ID 形态下限为固定守卫常量（未做成旗标，以免改变默认运行的 resolved_spec）。
4. aucell/R bioc 与 Python 模块的 "resolved options" 草稿/JSON 列表现在会多出值为 null 的新旗标键（非 golden，分析结果不变）。
5. 新 routing eval 7 题未做盲读评分（只做了结构测试）。
6. 模块版本号未提升（结果 JSON 带 `module_version` 且在 golden 中，提升会破坏 golden 字节一致）。
