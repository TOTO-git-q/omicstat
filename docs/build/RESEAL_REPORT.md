# 合并树验证与 reseal 报告

工作树：`/home/<user>/omic-reseal`；分支：`review/fixes-merge`；比较基线：`e88c714`。本轮在 PR #1 与 PR #2 的合并树上完成四个指定测试入口。日志与核验记录保存在 `/home/<user>/omic-sol61/reseal/`。

## Seal 审计与 reseal

前后均枚举 `skills/*/module_lock.json`，逐个调用官方 `mcp.module_seal.verify_module_seal`。两次均为 **39/39 `ok=true`**，过期模块列表均为 **空**，失败文件列表均为 **空**。其中 38 个分析模块返回 `verified`；`omicstat-selftest` 按官方实现返回 `not_analysis_module`，不将其描述成科学分析哈希审计。证据：`seal_before.json`、`seal_after.json`。

第 1 步失败集合为空，因此第 4 步没有需要重新封存的模块；没有调用 lock/golden 生成工具，没有修改任何 lock。

## 四个测试入口

| 入口 | 实际执行环境 | 数量与结果 | 退出码 |
| --- | --- | --- | --- |
| `bash env/test.sh` | `omicstat-r:2026.10.1` | 184 个命令，ALL PASSED；runner 缺包跳过 0 | 0 |
| `bash env/py/test.sh` | `omicstat-py:2026.09.1` | 31 个命令，ALL PASSED | 0 |
| `tools/run_tests_py.sh` 独立执行 | `omicstat-py:2026.09.1` | 31 个命令，ALL PASSED | 0 |
| `env/py/test_e2e.sh`，指定 `$HOME/omic-venv/bin/python` | 宿主入口，实际调用两个固定镜像 | 99 assertions，99 passed，0 failed，3 skipped | 0 |

容器均通过 `docker run --rm`、非 root、`--network none` 执行。四次原始控制台日志、退出码及容器内逐命令日志分别为 `full-r-console.log` / `full-r.exit` / `full-r/logs/`，`full-py-console.log` / `full-py.exit` / `full-py/logs/`，`full-py-direct-console.log` / `full-py-direct.exit` / `full-py-direct/logs/`，`e2e-console.log` / `e2e.exit`。每个 `index.tsv` 给出命令到日志编号的对应关系。仓库测试报告由入口生成；仅去除报告行尾空白，原始日志保留。

R runner 中的 MCP 测试另有 83 assertions、83 passed、0 failed、3 skipped；publication 测试运行 74 项，OK，2 项 Windows 平台跳过。

## 全部跳过与已知失败

以下逐项列出测试内部跳过；runner 的“缺包跳过 0”不代表内部跳过为零。

| 来源 | 跳过内容与原因 | 覆盖证据 |
| --- | --- | --- |
| R `013.log` | `set_seed` 的 torch、scvi 两项：R 镜像没有这两个 Python 包 | 两个 Python-image suite 的 `003.log`：0 skipped |
| R `055.log`，selftest-py | AnnData 不可导入；非受管 Python 的环境 verdict；R render step（日志原文：`no Rscript here; covered by mcp/test_client.py`）；共 3 项 | Python-image selftest 覆盖 AnnData/环境；宿主 E2E 覆盖 Python→R 渲染 |
| R `056.log`–`060.log` | scanpy-cluster、scanpy-markers、scanpy-qc、scanvi-annotate、scvi-integrate 的数值 anchor/model/golden：要求 locked Python image，R 镜像 Python 为 3.12.3 而不是 3.12.13，缺少 scanpy/anndata/scvi-tools/torch 且无 `OMICSTAT_PY_CONTAINER=1` | 两次匹配 Python 镜像中全部数值 replay 和 golden PASS |
| R `123/129/132/135/138/150.log` | selftest-py 与上述 5 个 Python 分析模块的 signature/default imports 委托给 locked Python suite；静态扫描继续执行 | 两次 Python-image suite |
| R `183.log` | `test_safe_join_and_finalizer_reject_windows_junction`、`test_unsafe_walker_evidence_becomes_blocking_review_finding`：Windows junction test，当前为 Linux | 明确保留 2 个平台跳过 |
| R `184.log` | R container engine run 和 Python container engine run：容器内无 docker；Python native engine run：native-env.json 无可用 python key；共 3 项 | 宿主 E2E 实际运行两个 container engine；Python native 仍明确跳过 |
| 两个 Python suite 各自 `011.log` | selftest-py 的 R render step：Python 镜像没有 Rscript；各 1 项 | 宿主 E2E Python→R rendering PASS |
| 宿主 E2E | real run on native：PATH 无 Rscript；native-only checks（legacy status、strict、validate_publication、default outdir）：native engine unavailable；Python module on native：无 native environment file；共 3 项 | 两个 container engine 路径均 PASS；native 跳过未计成 PASS |

唯一测试断言失败是允许保留的 `sva-batch` A6a 两项，见 R `053.log:32,34`（118–119 行只是重复汇总）：

1. vignette 原始 `num.sv(..., method="leek")` 得到 `n.sv=4`，旧印刷输出为 2；日志说明零特征值的约 `1e-16` 数值噪声及 `1e-12` 输入扰动可使估计翻转。
2. 使用会话内 `n.sv=4` 的原始 sec 4–6 链不能复现旧印刷 `topTableF`；当前首行 `207783_x_at`，`C1=-13.50399`。

其严格断言保持原样，smoke 显示 `SMOKE PASSED (with 2 documented KNOWN-FAILING anchor(s), listed above)`，自身 golden PASS。无其他测试断言失败或非零测试命令。WGCNA 的小 fixture/native replay 还打印 6 次 `mergeCloseModules` 上游 warning：仅 grey module 导致空 color levels，原生函数返回 unmerged colors；对应原生 replay、结果与 golden 均 PASS（`054.log`），属于 warning，不是失败断言。

## 合并交互与 golden 证据

没有发现需要修复的 PR 交互；无需归因某个 PR 的假设失效，没有改源码、断言或容差。PR #1：Scran markers 19 个 PASS、Seurat markers 28 个 PASS，保留 sample/condition 分组拒绝、合法 cell-level 分组、缺失 sample 拒绝、原生数值 replay 与措辞回归（R `044.log`、`047.log`）；Scanpy markers 每次 9 个 PASS，涵盖 grouping/reference/missing-sample/native-score/caution（两个 Python suite 的 `019.log`）。PR #2：共享 scientific refusal suite 31 个 PASS（R `006.log`），包含排名方向、corrected lineage、生态标签、独立生物重复、GSVA owner gate、补充 JSON 保护原生控制项；在 PR #1 的共享改动下全部保持通过。

34 个 R smoke 中 33 个分析模块均有 golden PASS；另一个是环境 selftest，本来没有科学分析 golden。两个 Python suite 各运行 6 个 smoke，其中 5 个分析模块全部有 golden PASS；selftest-py 为环境验证。下表列出分析模块 golden 的原始日志行：

| 模块 | 匹配镜像日志证据 |
| --- | --- |
| `aucell-score` | `full-r/logs/021.log:18` |
| `batchelor-integrate` | `full-r/logs/022.log:16` |
| `cellchat-communication` | `full-r/logs/023.log:16` |
| `clusterprofiler-compare` | `full-r/logs/024.log:16` |
| `clusterprofiler-gsea` | `full-r/logs/025.log:22` |
| `clusterprofiler-ora` | `full-r/logs/026.log:23` |
| `deseq2-lrt` | `full-r/logs/027.log:84` |
| `deseq2-qc` | `full-r/logs/028.log:72` |
| `deseq2-wald` | `full-r/logs/029.log:61` |
| `edger-qlf` | `full-r/logs/030.log:72` |
| `fgsea-prerank` | `full-r/logs/031.log:189` |
| `gsva-score` | `full-r/logs/032.log:56` |
| `immunedeconv-infiltration` | `full-r/logs/033.log:126` |
| `limma-array` | `full-r/logs/034.log:87` |
| `limma-camera` | `full-r/logs/035.log:28` |
| `limma-dupcor` | `full-r/logs/036.log:31` |
| `limma-voom` | `full-r/logs/037.log:65` |
| `maftools-landscape` | `full-r/logs/038.log:17` |
| `monocle3-trajectory` | `full-r/logs/039.log:18` |
| `muscat-pseudobulk` | `full-r/logs/040.log:50` |
| `scater-qc` | `full-r/logs/042.log:59` |
| `scran-cluster` | `full-r/logs/043.log:6` |
| `scran-markers` | `full-r/logs/044.log:7` |
| `seurat-cluster` | `full-r/logs/045.log:16` |
| `seurat-integrate` | `full-r/logs/046.log:29` |
| `seurat-markers` | `full-r/logs/047.log:17` |
| `seurat-modulescore` | `full-r/logs/048.log:50` |
| `seurat-qc` | `full-r/logs/049.log:28` |
| `singler-annotate` | `full-r/logs/050.log:19` |
| `slingshot-trajectory` | `full-r/logs/051.log:105` |
| `speckle-propeller` | `full-r/logs/052.log:113` |
| `sva-batch` | `full-r/logs/053.log:116` |
| `wgcna-network` | `full-r/logs/054.log:47` |
| `scanpy-cluster` | `full-py/logs/015.log:29`；独立重复 `full-py-direct/logs/015.log:29` |
| `scanpy-markers` | `full-py/logs/019.log:22`；独立重复 `full-py-direct/logs/019.log:22` |
| `scanpy-qc` | `full-py/logs/023.log:13`；独立重复 `full-py-direct/logs/023.log:13` |
| `scanvi-annotate` | `full-py/logs/027.log:42`；独立重复 `full-py-direct/logs/027.log:42` |
| `scvi-integrate` | `full-py/logs/031.log:37`；独立重复 `full-py-direct/logs/031.log:37` |

运行前后对全部 `skills/*/tests/golden_manifest.csv` 及 `tests/golden/` 下文件计算 SHA-256：**73 → 73 个文件，新增、删除、内容改变均为 0**。证据：`golden_before.json`、`golden_after.json`、`golden_verification.json`。相对 `e88c714` 的 git diff 中 golden 与 lock 均无改动，没有运行任何 golden 生成脚本。

## PNG 检视与最终 diff

已打开并查看保留的 575 个 suite PNG 路径，按内容去重为 323 个，另查看宿主 E2E 本次生成的 3 个 PNG。使用逐图带路径的 contact sheet 检视重复内容；累计看过 324 种 suite PNG 内容（部分输出路径在运行中被覆盖）。清单为 `png_inventory.json`、`viewed_png_hashes.json` 与 `review-*.jpg`。未发现由此次合并引起的新图形问题。本计数只包含保留下来的产物；测试内部自动删除的临时 PNG 不在该清单内。

最终 `git diff --stat e88c714` 与文件列表记录于 scratch `diff_stat_final.txt`、`diff_names_final.txt`。`git diff` 仅列出已跟踪文件；本报告在本次检查时为未跟踪新文件，另由 `git status --short` 确认。完整变动范围为生成的 `env/test_report.txt`、`env/py/e2e_report.txt` 以及本任务要求的报告/工作日志；`env/py/test_report.txt` 已由入口生成但与基线相同。源码、lock、golden、vendor、配置与 acceptance 数据均未修改。`git diff --check e88c714` 通过。未尝试 git commit 或绕过只读 `.git`；提交由外部 helper 根据 lane worklog 完成。
