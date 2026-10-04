# M3/M4 S5 装机报告

2026-10-04，工作树 `/home/<user>/omic-s5`，分支 `s5/install`。从 `90dc33c`
独立复验交接继续；严格按 fin_s5 / fin_common 及03:20协调者更新执行。
提交由外部helper处理，未尝试commit/push。本报告范围是装机与离线bundle，不部署。

## 装机状态与五个Python重封

新增24模块（19 R、5 Python）全部装机；无未装机项。全套38分析模块、2自检。
原S3独立历史未改写；五Python原仅共享figure builder stale seal，被协调者授权
在本树先数值golden/native smoke、R渲染、工具重封、新容器check后按PASS WITH NOTES装机。
以下每个check实测exit0，Python镜像2026.09.1；33个golden数据文件、5个manifest和5个生成脚本共43文件SHA逐一保持不变。

| 模块 | 新容器封锁输出 | 本次R渲染PNG |
|---|---|---:|
| scanpy-qc | module_lock scanpy-qc: OK (66 files) | 6 |
| scanpy-cluster | module_lock scanpy-cluster: OK (67 files) | 14 |
| scanpy-markers | module_lock scanpy-markers: OK (67 files) | 13 |
| scvi-integrate | module_lock scvi-integrate: OK (67 files) | 16 |
| scanvi-annotate | module_lock scanvi-annotate: OK (66 files) | 20 |

69张PNG均已打开，可读、非空、无验收阻塞裁切。
数值/replay/golden/render/seal/fresh check日志分别在 `/home/<user>/omic-sol61/s5/<module>.*.log`。

| 模块 | S2交接commit | 最新S3与安装依据 | S5 |
|---|---|---|---|
| scanpy-qc | `b6a6ad5` | [原复验 FAIL（仅 stale seal）；协调者允许重封后 PASS WITH NOTES](../../acceptance/exemplars/scanpy-qc/S3_RECHECK_m3m4.md) | 是 |
| scanpy-cluster | `b141c6f` | [原复验 FAIL（仅 stale seal）；协调者允许重封后 PASS WITH NOTES](../../acceptance/exemplars/scanpy-cluster/S3_RECHECK_m3m4.md) | 是 |
| scanpy-markers | `b141c6f` | [原复验 FAIL（仅 stale seal）；协调者允许重封后 PASS WITH NOTES](../../acceptance/exemplars/scanpy-markers/S3_RECHECK_m3m4.md) | 是 |
| scvi-integrate | `e9a19f4` | [原复验 FAIL（仅 stale seal）；协调者允许重封后 PASS WITH NOTES](../../acceptance/exemplars/scvi-integrate/S3_RECHECK_m3m4.md) | 是 |
| scanvi-annotate | `9549f5a` | [原复验 FAIL（仅 stale seal）；协调者允许重封后 PASS WITH NOTES](../../acceptance/exemplars/scanvi-annotate/S3_RECHECK_m3m4.md) | 是 |
| seurat-qc | `8258a72` | [PASS WITH NOTES](../../acceptance/exemplars/seurat-qc/S3_REVIEW_m3m4.md) | 是 |
| seurat-cluster | `9dc4d3d` | [PASS](../../acceptance/exemplars/seurat-cluster/S3_RECHECK_m3m4.md) | 是 |
| seurat-integrate | `368ccfb` | [PASS](../../acceptance/exemplars/seurat-integrate/S3_RECHECK_m3m4.md) | 是 |
| seurat-markers | `4965f88` | [PASS WITH NOTES](../../acceptance/exemplars/seurat-markers/S3_RECHECK_m3m4.md) | 是 |
| seurat-modulescore | `af90ed1` | [PASS WITH NOTES](../../acceptance/exemplars/seurat-modulescore/S3_REVIEW_m3m4.md) | 是 |
| scater-qc | `eb534a8` | [PASS WITH NOTES](../../acceptance/exemplars/scater-qc/S3_REVIEW_m3m4.md) | 是 |
| scran-cluster | `eb534a8` | [PASS WITH NOTES](../../acceptance/exemplars/scran-cluster/S3_REVIEW_m3m4.md) | 是 |
| batchelor-integrate | `0ea3a07` | [PASS WITH NOTES](../../acceptance/exemplars/batchelor-integrate/S3_REVIEW_m3m4.md) | 是 |
| scran-markers | `0ea3a07` | [PASS WITH NOTES](../../acceptance/exemplars/scran-markers/S3_REVIEW_m3m4.md) | 是 |
| aucell-score | `b08f144` | [PASS](../../acceptance/exemplars/aucell-score/S3_RECHECK_m3m4.md) | 是 |
| singler-annotate | `cecae16` | [PASS](../../acceptance/exemplars/singler-annotate/S3_RECHECK_m3m4.md) | 是 |
| muscat-pseudobulk | `3213029` | [PASS WITH NOTES](../../acceptance/exemplars/muscat-pseudobulk/S3_REVIEW_m3m4.md) | 是 |
| speckle-propeller | `f3099dd` | [PASS WITH NOTES](../../acceptance/exemplars/speckle-propeller/S3_REVIEW_m3m4.md) | 是 |
| cellchat-communication | `b08f144` | [PASS WITH NOTES](../../acceptance/exemplars/cellchat-communication/S3_REVIEW_m3m4.md) | 是 |
| monocle3-trajectory | `cecae16` | [PASS WITH NOTES](../../acceptance/exemplars/monocle3-trajectory/S3_REVIEW_m3m4.md) | 是 |
| slingshot-trajectory | `f3099dd` | [PASS WITH NOTES](../../acceptance/exemplars/slingshot-trajectory/S3_REVIEW_m3m4.md) | 是 |
| wgcna-network | `2de30d7` | [PASS WITH NOTES](../../acceptance/exemplars/wgcna-network/S3_RECHECK_m3m4.md) | 是 |
| maftools-landscape | `049b9b4` | [PASS](../../acceptance/exemplars/maftools-landscape/S3_RECHECK_m3m4.md) | 是 |
| immunedeconv-infiltration | `049b9b4` | [PASS WITH NOTES](../../acceptance/exemplars/immunedeconv-infiltration/S3_RECHECK_m3m4.md) | 是 |

## 本次改动

路由器§1正式登记24模块，补三生态前端/中性后端/M4树与链式recipes。
method_map38目标均implemented_routed，integration checker更新status与当前source/plan hash，
build_contracts更新完整集合/40行；pretend-engine拒绝断言不变。publication40模块记录/47唯一rule IDs，
新增19 R依据各S3_REQUEST提案适配既有schema；五Python原已有记录。
MCP引擎按既有entry扩展名分发；client补逐条entry匹配，host验收逐个describe新增24。
两套runner覆盖所有入口smoke/defaults/calls/flagdocs；加入协调者frontmatter checker；
Python runner留逐命令日志，env/py/test传正确image ID及locked环境并允许scratch留档。

首次完整R运行完成182个命令后为FAILURES：R调用扫描器未识别现有
`os_bioc_call(pkg::fn, ...)`/`do.call(pkg::fn, ...)`，造成四个Bioconductor模块的C3误报；
R镜像还尝试导入仅Python镜像具有的scanpy/scvi。保留首次日志于scratch
`final-r-initial.log`/`final-r-initial-logs`，不把此运行计作最终通过。
工具层补wrapper调用点扫描，C1/C2/C3原断言不变；负例验证缺少命名参数、
未登记函数、stale记录和不可证明的动态参数仍拒绝。四模块静态复验均通过。
R runner对Python运行完整AST检查并明确SKIP签名导入；Python runner仍严格检查导入与默认。
env/test保留MCP输出供逐PNG打开。本次未修改科学引擎或共享builder。

首次host stdio调用将scratch置于runs root之外，路径守卫正确拒绝outdir，
62 assertions中58 PASS/4 FAIL/3 skip；日志保留`final-e2e-initial.log`。
将scratch与允许runs root设为同一lane目录后复跑，不修改MCP守卫或断言。

MODULE_BUILD_BRIEF§3补AnnData h5ad in/out、convert.R和非root `/opt/omicstat/basilisk`，
CONVENTIONS补转换错误码及crossing规则。M3b原brief在外部只读任务目录，因此在仓库
`docs/build/agent_briefs/M3B_BUILDER_BRIEF.md`提供chain_state补充，不修改外部lane。
ENGINEERING_PLAN仅顶部短v1.3注释，正文不重写。GSVA SKILL补逐cell AUCell/样本GSVA，
AUCell原SKILL已具同规则，未重复修改。两种模板布局均接受且check_defaults/check_flag_docs
说明各自读哪些来源；不重命名旧文件。14 M1/M2 options依据parameters/实际help/extraction，
共映射所有CLI flags，不能对应原生CLI的context/version键为none；只工具生成文档lock，
另因协调者后加frontmatter引号造成batchelor-integrate/scran-markers仅SKILL hash失配，
这两模块工具重封与新容器check均OK；其他31科学R seal无需改动。
未改任何M1/M2引擎、默认、测试或golden。SUITE补S2–S5与开放owner项。

实际变更文件（包含外部helper已提交的改动，相对于90dc33c）：

- `SUITE.md`
- `docs/build/MODULE_BUILD_BRIEF.md`
- `docs/build/S5_REPORT_m3m4.md`
- `docs/build/agent_briefs/M3B_BUILDER_BRIEF.md`
- `docs/build/s5_worklog.md`
- `docs/handoff/ENGINEERING_PLAN.md`
- `env/py/e2e_report.txt`
- `env/py/test.sh`
- `env/py/test_report.txt`
- `env/test.sh`
- `env/test_report.txt`
- `mcp/test_client.py`
- `reference_service/app/method_map.json`
- `reference_service/app/s0_evidence/catalog.json`
- `reference_service/import_s0_evidence.py`
- `reference_service/tests/test_s0_importer.py`
- `skills/_shared/docs/CONVENTIONS.md`
- `skills/_shared/publication/module_rules_v1.json`
- `skills/batchelor-integrate/module_lock.json`
- `skills/clusterprofiler-compare/module_lock.json`
- `skills/clusterprofiler-compare/references/options.md`
- `skills/clusterprofiler-gsea/module_lock.json`
- `skills/clusterprofiler-gsea/references/options.md`
- `skills/clusterprofiler-ora/module_lock.json`
- `skills/clusterprofiler-ora/references/options.md`
- `skills/deseq2-lrt/module_lock.json`
- `skills/deseq2-lrt/references/options.md`
- `skills/deseq2-qc/module_lock.json`
- `skills/deseq2-qc/references/options.md`
- `skills/deseq2-wald/module_lock.json`
- `skills/deseq2-wald/references/options.md`
- `skills/edger-qlf/module_lock.json`
- `skills/edger-qlf/references/options.md`
- `skills/fgsea-prerank/module_lock.json`
- `skills/fgsea-prerank/references/options.md`
- `skills/gsva-score/SKILL.md`
- `skills/gsva-score/module_lock.json`
- `skills/gsva-score/references/options.md`
- `skills/limma-array/module_lock.json`
- `skills/limma-array/references/options.md`
- `skills/limma-camera/module_lock.json`
- `skills/limma-camera/references/options.md`
- `skills/limma-dupcor/module_lock.json`
- `skills/limma-dupcor/references/options.md`
- `skills/limma-voom/module_lock.json`
- `skills/limma-voom/references/options.md`
- `skills/omicstat/SKILL.md`
- `skills/scanpy-cluster/module_lock.json`
- `skills/scanpy-markers/module_lock.json`
- `skills/scanpy-qc/module_lock.json`
- `skills/scanvi-annotate/module_lock.json`
- `skills/scran-markers/module_lock.json`
- `skills/scvi-integrate/module_lock.json`
- `skills/sva-batch/module_lock.json`
- `skills/sva-batch/references/options.md`
- `tools/calls_wrapper_sites.R`
- `tools/check_calls.R`
- `tools/check_calls_py_static.py`
- `tools/check_defaults.py`
- `tools/check_flag_docs.py`
- `tools/check_reference_integration.py`
- `tools/run_tests.sh`
- `tools/run_tests_py.sh`
- `tools/test_build_contracts.py`
- `tools/test_calls_wrapper_sites.R`

## Reference离线刷新

只生成 `reference_service/app/s0_evidence/catalog.json`。合并树包含M3/M4 extraction但不带
原corpus，原importer M12 glob误将其读取；限制M12源为14已知模块，A/B/C保留原lane与
证据列；回归fixture模拟已复制但无corpus的scanpy-cluster，确保不重复导入/不升级证据列。
749 papers / 954 usages，其中reviewed_supplement760、discovery194。
参数映射1621/3024，coverage7801/15963，context0/952；38 mapping文件均present。
每一个options表具对应key的observation均mapped，无该key仍pending；不伪造context映射。

| 模块 | 证据列 | usages | parameters 已映射/总数 | coverage 已映射/总数 | context 已映射/总数 |
|---|---|---:|---:|---:|---:|
| aucell-score | reviewed_supplement | 14 | 17/73 | 67/459 | 0/14 |
| batchelor-integrate | reviewed_supplement | 26 | 47/137 | 187/591 | 0/26 |
| cellchat-communication | reviewed_supplement | 28 | 27/73 | 953/1103 | 0/28 |
| clusterprofiler-compare | reviewed_supplement | 26 | 47/89 | 5/67 | 0/26 |
| clusterprofiler-gsea | reviewed_supplement | 28 | 60/84 | 52/112 | 0/28 |
| clusterprofiler-ora | reviewed_supplement | 30 | 78/100 | 102/140 | 0/30 |
| deseq2-lrt | reviewed_supplement | 32 | 80/104 | 80/152 | 0/32 |
| deseq2-qc | reviewed_supplement | 20 | 30/49 | 50/91 | 0/20 |
| deseq2-wald | reviewed_supplement | 29 | 46/79 | 128/182 | 0/29 |
| edger-qlf | reviewed_supplement | 23 | 42/77 | 50/107 | 0/23 |
| fgsea-prerank | reviewed_supplement | 30 | 52/69 | 68/141 | 0/30 |
| gsva-score | reviewed_supplement | 30 | 52/99 | 98/111 | 0/30 |
| immunedeconv-infiltration | discovery | 23 | 30/57 | 128/400 | 0/22 |
| limma-array | reviewed_supplement | 13 | 23/30 | 42/61 | 0/13 |
| limma-camera | reviewed_supplement | 30 | 80/97 | 40/113 | 0/30 |
| limma-dupcor | reviewed_supplement | 30 | 52/85 | 38/125 | 0/30 |
| limma-voom | reviewed_supplement | 24 | 60/102 | 36/90 | 0/24 |
| maftools-landscape | discovery | 25 | 6/18 | 240/577 | 0/25 |
| monocle3-trajectory | reviewed_supplement | 30 | 57/93 | 333/1017 | 0/30 |
| muscat-pseudobulk | reviewed_supplement | 14 | 29/69 | 111/169 | 0/14 |
| scanpy-cluster | discovery | 23 | 5/13 | 494/1378 | 0/23 |
| scanpy-markers | discovery | 22 | 1/1 | 127/302 | 0/22 |
| scanpy-qc | discovery | 29 | 30/34 | 363/792 | 0/29 |
| scanvi-annotate | discovery | 21 | 4/6 | 202/757 | 0/21 |
| scater-qc | reviewed_supplement | 29 | 14/138 | 15/645 | 0/29 |
| scran-cluster | reviewed_supplement | 23 | 60/202 | 193/534 | 0/23 |
| scran-markers | reviewed_supplement | 19 | 26/84 | 126/467 | 0/19 |
| scvi-integrate | discovery | 24 | 17/19 | 352/732 | 0/24 |
| seurat-cluster | reviewed_supplement | 27 | 104/166 | 274/509 | 0/27 |
| seurat-integrate | reviewed_supplement | 26 | 43/96 | 321/450 | 0/26 |
| seurat-markers | reviewed_supplement | 29 | 66/114 | 601/785 | 0/29 |
| seurat-modulescore | reviewed_supplement | 29 | 32/76 | 258/330 | 0/29 |
| seurat-qc | reviewed_supplement | 28 | 92/117 | 132/163 | 0/28 |
| singler-annotate | reviewed_supplement | 29 | 37/51 | 572/703 | 0/29 |
| slingshot-trajectory | discovery | 27 | 46/85 | 789/1073 | 0/26 |
| speckle-propeller | reviewed_supplement | 20 | 31/79 | 69/221 | 0/20 |
| sva-batch | reviewed_supplement | 21 | 27/52 | 15/53 | 0/21 |
| wgcna-network | reviewed_supplement | 23 | 71/107 | 90/261 | 0/23 |

六个仍缺corpus metadata的PMID：34554929、34836963、36577520、38127790、39639049、42627896。
排除applies_false3652、verification_failed_record77、alpha_only96、not_applicable30。
离线R镜像reference root13 tests、app122 tests全部OK，无skip；YAML41 front matters解析通过。
`check_reference_integration`6 configs/38 map PASS；build contracts13 tests OK。
部署由协调者按DEPLOY_SEED执行，本lane没有操作运行服务/容器/volume。

## 图审计说明

原共享figure fixture的oncoplot右端Multi_Hit图例有裁切（两个byte-identical副本），
unit lint/byte测试仍通过；属于未改动fixture的外观限制，保留给owner，不虚称所有图均无裁切。
既有GO长标签重叠/密集MA标签也保持人工检查备注；Wald `f2/figures/top_heatmap.png`
的两基因小图下缘Row z-score的≤−2图例裁切，作为原M1/M2图层外观owner项保留。
GSVA `poisson/figures/score_heatmap.png`右侧最长行标签、其voom上游fixture的
`figures/mds.png`横轴标题也贴边/裁切；热图样本标签在部分浸润小图底端贴边。
低计数S4 fixture的零显著volcano点集中在近零纵轴，是已验证的null结果而非空白渲染失败。
本lane不修改共享builder/既有golden。
共享figure测试用scratch R profile的.Last保存临时输出后复验，以便实际打开图；
未改变共享figure测试源或断言。最终保留1243个PNG路径、367个不同SHA，1243/1243路径已逐一view_image打开，全部不同SHA已人工审图；相同SHA复用已审画面判断。
PNG宽度2102–4322px，高度755–4015px，均是有效非零尺寸PNG。已知外观限制仍按上文交owner。

| scratch目录 | 保留PNG路径 |
|---|---:|
| python-smoke | 69 |
| final-r | 558 |
| final-r-rerun | 562 |
| figure-tests | 51 |
| e2e | 3 |

逐路径SHA/审查清单为 `/home/<user>/omic-sol61/s5/final-visual.json`，
打开ledger为 `opened-png-paths.json`，汇总为 `visual-summary.json`。初次失败R输出保留，
其PNG可供审计但不计入最终通过套件；最终R统计只读 `final-r-rerun/logs/index.tsv`。

## 最终套件

四个规定入口最终exit0。R `env/test.sh`为ALL PASSED（183 commands，0 skipped for missing packages）；
34个R入口（33分析模块、1自检）没有任何skip，6个Python入口的跨解释器skip逐项列于下表，已由Python镜像覆盖。
完整R日志为 `final-r-rerun.log`，MCP client为83 assertions/83 PASS/0 FAIL/3 skips。
SVA仅有两条既有A6a known-failing anchors（日志末尾重复汇总，不算四条）：
本session leek的n.sv=4而vignette打印2，1e-12扰动得到2/4/5；
同n.sv=4的verbatim链topTableF首行207783_x_at的C1=-13.50399。
固定n.sv=2的A6b printed anchor通过；未修改断言、容差或golden。
Python镜像`env/py/test.sh`及直接`tools/run_tests_py.sh`各31 commands ALL PASSED；
五个模块的pinned numerical smoke在两次运行中均PASS，各运行只有selftest的R render缺失skip，
跨镜像R渲染在独立R步骤及host stdio验证。
host `env/py/test_e2e.sh`最终exit0：123 assertions、123 passed、0 failed、3 skipped；
24新装模块describe逐一正确entry/help/options，40项list registry完整，R和Python容器run均通过，
Python figure request由R镜像实际render，provenance记录两个immutable image ID。
host的全部三skip：native R无Rscript；依赖native R的legacy status/strict/publication/default outdir组合检查；
native Python没有native environment file。两容器路径未skip。
日志为scratch `final-py.log`、`direct-py.log`、`final-e2e.log`；前两项有逐命令logs/index.tsv，host stdio保留完整client日志。


计数单位：command为runner逐项exit-status检查；PASS行是日志中以PASS开头的断言行，不等同生物学测试数。unittest另列实际Ran计数。完整逐命令记录在scratch suite-counts.json及各logs/index.tsv。

| 套件 | commands | PASS断言行 | unittest实际tests |
|---|---:|---:|---:|
| final-r | 183 | 2302 | 111 |
| final-py | 31 | 404 | 13 |
| direct-py | 31 | 404 | 13 |

各入口smoke的PASS行：

| 入口 | R镜像 | Python镜像env runner | Python镜像direct runner |
|---|---:|---:|---:|
| aucell-score.R | 12 | — | — |
| batchelor-integrate.R | 8 | — | — |
| cellchat-communication.R | 3 | — | — |
| clusterprofiler-compare.R | 41 | — | — |
| clusterprofiler-gsea.R | 42 | — | — |
| clusterprofiler-ora.R | 57 | — | — |
| deseq2-lrt.R | 85 | — | — |
| deseq2-qc.R | 70 | — | — |
| deseq2-wald.R | 62 | — | — |
| edger-qlf.R | 73 | — | — |
| fgsea-prerank.R | 36 | — | — |
| gsva-score.R | 53 | — | — |
| immunedeconv-infiltration.R | 54 | — | — |
| limma-array.R | 57 | — | — |
| limma-camera.R | 56 | — | — |
| limma-dupcor.R | 60 | — | — |
| limma-voom.R | 69 | — | — |
| maftools-landscape.R | 22 | — | — |
| monocle3-trajectory.R | 2 | — | — |
| muscat-pseudobulk.R | 2 | — | — |
| omicstat-selftest-py.py | 33 | 34 | 34 |
| omicstat-selftest.R | 34 | — | — |
| scanpy-cluster.py | 1 | 8 | 8 |
| scanpy-markers.py | 1 | 8 | 8 |
| scanpy-qc.py | 1 | 7 | 7 |
| scanvi-annotate.py | 1 | 9 | 9 |
| scater-qc.R | 12 | — | — |
| scran-cluster.R | 8 | — | — |
| scran-markers.R | 6 | — | — |
| scvi-integrate.py | 1 | 8 | 8 |
| seurat-cluster.R | 11 | — | — |
| seurat-integrate.R | 15 | — | — |
| seurat-markers.R | 16 | — | — |
| seurat-modulescore.R | 11 | — | — |
| seurat-qc.R | 19 | — | — |
| singler-annotate.R | 8 | — | — |
| slingshot-trajectory.R | 2 | — | — |
| speckle-propeller.R | 2 | — | — |
| sva-batch.R | 94 | — | — |
| wgcna-network.R | 37 | — | — |

共享/工具/MCP检查实际计数：

| 套件 | command | PASS行 | unittest tests |
|---|---|---:|---:|
| final-r | `python3 env/test_env_config.py` | 90 | — |
| final-r | `Rscript env/r/test_layer_lib.R` | 6 | — |
| final-r | `Rscript skills/_shared/tests/test_figures.R` | 237 | — |
| final-r | `Rscript skills/_shared/tests/test_figures_ext.R` | 169 | — |
| final-r | `Rscript skills/_shared/tests/test_omics_shared.R` | 31 | — |
| final-r | `Rscript skills/_shared/tests/test_convert.R` | 103 | — |
| final-r | `Rscript skills/_shared/tests/test_effect_table.R` | 0 | — |
| final-r | `Rscript skills/_shared/tests/test_render.R` | 0 | — |
| final-r | `Rscript skills/_shared/tests/test_engine_contract.R` | 68 | — |
| final-r | `Rscript tools/test_calls_wrapper_sites.R` | 1 | — |
| final-r | `python3 env/py/test_py_env_config.py` | 178 | — |
| final-r | `python3 skills/_shared/py/tests/test_ospy.py` | 91 | — |
| final-r | `python3 tools/test_check_calls.py` | 19 | — |
| final-r | `python3 tools/test_new_module_py.py` | 18 | — |
| final-r | `python3 tools/test_build_contracts.py` | 0 | 13 |
| final-r | `Rscript skills/_shared/tests/test_render_figure_request.R` | 31 | — |
| final-r | `python3 tools/test_tools.py` | 0 | 22 |
| final-r | `python3 tools/lint_r.py` | 0 | — |
| final-r | `python3 tools/check_skill_frontmatter.py` | 0 | — |
| final-r | `python3 tools/check_calls_py_static.py skills/omicstat-selftest-py` | 0 | — |
| final-r | `python3 tools/check_calls_py_static.py skills/scanpy-cluster` | 0 | — |
| final-r | `python3 tools/check_calls_py_static.py skills/scanpy-markers` | 0 | — |
| final-r | `python3 tools/check_calls_py_static.py skills/scanpy-qc` | 0 | — |
| final-r | `python3 tools/check_calls_py_static.py skills/scanvi-annotate` | 0 | — |
| final-r | `python3 tools/check_calls_py_static.py skills/scvi-integrate` | 0 | — |
| final-r | `python3 skills/_shared/publication/test_publication_rules.py` | 0 | — |
| final-r | `python3 mcp/test_package_identity.py` | 0 | 3 |
| final-r | `python3 mcp/test_publication.py` | 0 | 73 |
| final-r | `python3 mcp/test_client.py` | 83 | — |
| final-py | `python env/py/selftest_image.py --functional` | 22 | — |
| final-py | `python env/py/test_py_env_config.py` | 178 | — |
| final-py | `python skills/_shared/py/tests/test_ospy.py` | 93 | — |
| final-py | `python tools/test_check_calls.py` | 19 | — |
| final-py | `python tools/test_new_module_py.py` | 18 | — |
| final-py | `python tools/test_build_contracts.py` | 0 | 13 |
| final-py | `python tools/check_skill_frontmatter.py` | 0 | — |
| direct-py | `python env/py/selftest_image.py --functional` | 22 | — |
| direct-py | `python env/py/test_py_env_config.py` | 178 | — |
| direct-py | `python skills/_shared/py/tests/test_ospy.py` | 93 | — |
| direct-py | `python tools/test_check_calls.py` | 19 | — |
| direct-py | `python tools/test_new_module_py.py` | 18 | — |
| direct-py | `python tools/test_build_contracts.py` | 0 | 13 |
| direct-py | `python tools/check_skill_frontmatter.py` | 0 | — |

逐项skip（不把PASS文本中的“cannot be skipped”计作skip）：

- final-r / `python3 skills/_shared/py/tests/test_ospy.py`: SKIP: torch parts of set_seed (torch not installed); SKIP: scvi parts of set_seed (scvi-tools not installed)
- final-r / `python3 skills/omicstat-selftest-py/tests/run_smoke_test.py`: SKIP: AnnData parts (anndata not importable in this interpreter; PY-10 reports it); SKIP: environment verdict (unmanaged interpreter: PY-02/PY-06 fail by design); SKIP: R render step (no Rscript here; covered by mcp/test_client.py)
- final-r / `python3 skills/scanpy-cluster/tests/run_smoke_test.py`: SKIP: numerical anchor / model / golden tests require locked image; OS_ENVIRONMENT_MISMATCH: OMICSTAT_PY_CONTAINER=1 is required; use the supplied container image; Python 3.12.3 != 3.12.13; scanpy None != 1.12.4; anndata None != 0.13.3.post0; scvi-tools None != 1.5.1; torch None != 2.14.0+cpu
- final-r / `python3 skills/scanpy-markers/tests/run_smoke_test.py`: SKIP: numerical anchor / model / golden tests require locked image; OS_ENVIRONMENT_MISMATCH: OMICSTAT_PY_CONTAINER=1 is required; use the supplied container image; Python 3.12.3 != 3.12.13; scanpy None != 1.12.4; anndata None != 0.13.3.post0; scvi-tools None != 1.5.1; torch None != 2.14.0+cpu
- final-r / `python3 skills/scanpy-qc/tests/run_smoke_test.py`: SKIP: numerical anchor / model / golden tests require locked image; OS_ENVIRONMENT_MISMATCH: OMICSTAT_PY_CONTAINER=1 is required; use the supplied container image; Python 3.12.3 != 3.12.13; scanpy None != 1.12.4; anndata None != 0.13.3.post0; scvi-tools None != 1.5.1; torch None != 2.14.0+cpu
- final-r / `python3 skills/scanvi-annotate/tests/run_smoke_test.py`: SKIP: numerical anchor / model / golden tests require locked image; OS_ENVIRONMENT_MISMATCH: OMICSTAT_PY_CONTAINER=1 is required; use the supplied container image; Python 3.12.3 != 3.12.13; scanpy None != 1.12.4; anndata None != 0.13.3.post0; scvi-tools None != 1.5.1; torch None != 2.14.0+cpu
- final-r / `python3 skills/scvi-integrate/tests/run_smoke_test.py`: SKIP: numerical anchor / model / golden tests require locked image; OS_ENVIRONMENT_MISMATCH: OMICSTAT_PY_CONTAINER=1 is required; use the supplied container image; Python 3.12.3 != 3.12.13; scanpy None != 1.12.4; anndata None != 0.13.3.post0; scvi-tools None != 1.5.1; torch None != 2.14.0+cpu
- final-r / `python3 tools/check_calls_py_static.py skills/omicstat-selftest-py`: SKIP: Python signature/default imports delegated to the locked Python image suite
- final-r / `python3 tools/check_calls_py_static.py skills/scanpy-cluster`: SKIP: Python signature/default imports delegated to the locked Python image suite
- final-r / `python3 tools/check_calls_py_static.py skills/scanpy-markers`: SKIP: Python signature/default imports delegated to the locked Python image suite
- final-r / `python3 tools/check_calls_py_static.py skills/scanpy-qc`: SKIP: Python signature/default imports delegated to the locked Python image suite
- final-r / `python3 tools/check_calls_py_static.py skills/scanvi-annotate`: SKIP: Python signature/default imports delegated to the locked Python image suite
- final-r / `python3 tools/check_calls_py_static.py skills/scvi-integrate`: SKIP: Python signature/default imports delegated to the locked Python image suite
- final-r / `python3 mcp/test_publication.py`: test_safe_join_and_finalizer_reject_windows_junction (__main__.PublicationContractTests.test_safe_join_and_finalizer_reject_windows_junction) ... skipped 'Windows junction test'; test_unsafe_walker_evidence_becomes_blocking_review_finding (__main__.PublicationContractTests.test_unsafe_walker_evidence_becomes_blocking_review_finding) ... skipped 'Windows junction test'; OK (skipped=2)
- final-r / `python3 mcp/test_client.py`: SKIP   real run on engine container  -- docker unavailable ([Errno 2] No such file or directory: 'docker'); SKIP   python module on engine native  -- native-env.json has no usable "python" key (bash env/py/setup_native.sh); SKIP   python module on engine container  -- docker unavailable ([Errno 2] No such file or directory: 'docker')
- final-py / `python skills/omicstat-selftest-py/tests/run_smoke_test.py`: SKIP: R render step (no Rscript here; covered by mcp/test_client.py)
- direct-py / `python skills/omicstat-selftest-py/tests/run_smoke_test.py`: SKIP: R render step (no Rscript here; covered by mcp/test_client.py)

R unittest实际Ran111（其中publication73含2个Windows skip），其余109通过；
两次Python各Ran13，全部通过。PASS断言行统计不包含行首带进度文本的PASS，不把它当总断言数。

最后不变量检查PASS：43个Pythongolden文件SHA不变；M1/M2及其他科学引擎、
默认registry、module tests/goldens与独立S3资料相对90dc33c无变更；
ENGINEERING_PLAN正文逐字不变；所有保留PNG均打开、不同SHA均审查。

## Owner开放项与可撤销决定

见 [SUITE完整收集](../../SUITE.md)：研究阈值/设计/参考/比较/样本单位、S0-A文献分母及
Slide-seq适用范围、Slingshot旧PACK/L3、S0-C遗漏/生态/L3、完整BMMC/purifiedPBMC/
cross-platform/agent盲测、轨迹root/partition、CellChat数据库/单网络范围、WGCNA稠密树/
因果hub限制、MAF caller/build/filter/territory与浸润scale/许可均保持开放。
CIBERSORT仅合法用户提供文件，接口stub不能证明licensed生物学成功。
协调者决定3：逐cell AUCell、样本GSVA，两者都非标准；决定4：中性后端保留上游label，
backend neutral与信息型crossing，前端混生态仍拒绝。二者owner均可撤销，未擅自裁决科学问题。
2026.10.1新增scrapper/presto与可非root访问basilisk，已关闭旧依赖/AnnData阻塞；
AUCell自定义干净GMT、八offline浸润方法旧限制已由fix/S3关闭，不误列为仍开放。
Seurat markers7023/7019是已接受差异，sva A6a仍已知失败；装机不是manuscript-ready。
