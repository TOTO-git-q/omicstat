# S0 文献证据导入报告

## 待所有者处理

1. 尚未部署；须批准新镜像和生产卷变更后执行 `reference_service/DEPLOY_SEED.md`。本车道未启动、停止、重建或读取生产容器/卷，未改 `deploy_gt103.sh`。
2. 外层离线测试存在继承的配置重建失败：`test_config_matches_builder` 返回 `method_map.json` stale。该注册表与 HEAD 一致，本车道未修改注册表或伪造历史；GPT_BUILD_REPORT 的集成说明提到增加 entry_status。此项需独立复核后决定生产发布。
3. 当前本车道的 38 个模块均无 `skills/<module>/references/options.md`，3024 个观测参数保留 extraction key，映射全部 pending。构建车道交付后重跑 importer，审核差异并重跑测试；不据文献产生默认值。
4. 6 个唯一 PMID 缺少同模块 corpus 元数据，明确使用待补标题；相关使用记录的缺元数据计数共 7。PMID：34554929、34836963、36577520、38127790、39639049、42627896。不得将占位标题当作真实文章标题。

## 交付与安全边界

已继续原 worklog 的首个未完成步骤，没有重做步骤 1。导入器 `reference_service/import_s0_evidence.py` 读取四个工作树和独立核验结果；仅修剪值的空白/末尾标点，不换算单位、不合并值。参数和 coverage/context 按原记录分别保留，snippet 与 section_path 原样保存。分支、commit、文件 SHA-256、核验/返工状态在 provenance 与 inputs 清单记录。corpus 元数据生成唯一 PMID paper；usage 粒度为文章 × 模块，decisions 为空。

交付包 `app/s0_evidence/catalog.json` 装入镜像；管理员显式运行 `app/s0_loader.py --data-dir <离线或已批准目录>`，写服务现有的 reference.sqlite/reviewed_supplement 与 harvest.sqlite/candidates。实际离线演示目录为 `/home/<user>/omic-sol61/ref_seed/data`，通过 OMICSTAT_REFERENCE_DATA 指向该目录读取。没有写生产卷，没有自动启动加载。curated seed 保持 0 paper / 0 usage / 0 decision，execution_authorized 与 automatic_parameter_application 均为 false。

reviewed_supplement 仅在参数有逐字 snippet/section locator 且通过原有审核门槛时可进入 parameter_options；discovery 即使伪造审核状态也被列门禁拒绝。coverage 中的 not reported 不进入参数。建议结果仍是研究特定的观测，需要判断当前设计适用性。为避免 64 KB API 预算吞掉结果，advise 初始返回最多 3 条 supplement usage（usage_id 排序），同时报告总数与返回数；全量由 search/get 分页读取。未改变工具签名。搜索条目以 S0_verified_or_redone_supplement 标签说明导入来源，不冒称新人工 promotion；工作流文档同步说明 S0 列语义。

## 数量

唯一论文 749；文章 × 模块使用 954：reviewed_supplement 760，discovery 194，curated 0。观测参数 3024，not reported coverage 15963，可通过参数门槛的 reviewed usage 726。

| 模块 | curated | reviewed_supplement | discovery | 参数观测 | coverage | eligible usage | options.md / 映射 | 排除行 |
|---|---:|---:|---:|---:|---:|---:|---|---:|
| aucell-score | 0 | 14 | 0 | 73 | 459 | 14 | pending / pending | 624 |
| batchelor-integrate | 0 | 26 | 0 | 137 | 591 | 26 | pending / pending | 116 |
| cellchat-communication | 0 | 28 | 0 | 73 | 1103 | 23 | pending / pending | 86 |
| clusterprofiler-compare | 0 | 26 | 0 | 89 | 67 | 26 | pending / pending | 28 |
| clusterprofiler-gsea | 0 | 28 | 0 | 84 | 112 | 28 | pending / pending | 2 |
| clusterprofiler-ora | 0 | 30 | 0 | 100 | 140 | 30 | pending / pending | 0 |
| deseq2-lrt | 0 | 32 | 0 | 104 | 152 | 30 | pending / pending | 21 |
| deseq2-qc | 0 | 20 | 0 | 49 | 91 | 20 | pending / pending | 10 |
| deseq2-wald | 0 | 29 | 0 | 79 | 182 | 25 | pending / pending | 10 |
| edger-qlf | 0 | 23 | 0 | 77 | 107 | 23 | pending / pending | 63 |
| fgsea-prerank | 0 | 30 | 0 | 69 | 141 | 23 | pending / pending | 0 |
| gsva-score | 0 | 30 | 0 | 99 | 111 | 30 | pending / pending | 0 |
| immunedeconv-infiltration | 0 | 0 | 23 | 57 | 400 | 0 | pending / pending | 46 |
| limma-array | 0 | 13 | 0 | 30 | 61 | 12 | pending / pending | 17 |
| limma-camera | 0 | 30 | 0 | 97 | 113 | 30 | pending / pending | 160 |
| limma-dupcor | 0 | 30 | 0 | 85 | 125 | 30 | pending / pending | 0 |
| limma-voom | 0 | 24 | 0 | 102 | 90 | 24 | pending / pending | 54 |
| maftools-landscape | 0 | 0 | 25 | 18 | 577 | 0 | pending / pending | 130 |
| monocle3-trajectory | 0 | 30 | 0 | 93 | 1017 | 24 | pending / pending | 0 |
| muscat-pseudobulk | 0 | 14 | 0 | 69 | 169 | 14 | pending / pending | 126 |
| scanpy-cluster | 0 | 0 | 23 | 13 | 1378 | 0 | pending / pending | 476 |
| scanpy-markers | 0 | 0 | 22 | 1 | 302 | 0 | pending / pending | 185 |
| scanpy-qc | 0 | 0 | 29 | 34 | 792 | 0 | pending / pending | 75 |
| scanvi-annotate | 0 | 0 | 21 | 6 | 757 | 0 | pending / pending | 280 |
| scater-qc | 0 | 29 | 0 | 138 | 645 | 29 | pending / pending | 28 |
| scran-cluster | 0 | 23 | 0 | 202 | 534 | 23 | pending / pending | 231 |
| scran-markers | 0 | 19 | 0 | 84 | 467 | 19 | pending / pending | 330 |
| scvi-integrate | 0 | 0 | 24 | 19 | 732 | 0 | pending / pending | 215 |
| seurat-cluster | 0 | 27 | 0 | 166 | 509 | 27 | pending / pending | 78 |
| seurat-integrate | 0 | 26 | 0 | 96 | 450 | 25 | pending / pending | 88 |
| seurat-markers | 0 | 29 | 0 | 114 | 785 | 29 | pending / pending | 32 |
| seurat-modulescore | 0 | 29 | 0 | 76 | 330 | 29 | pending / pending | 15 |
| seurat-qc | 0 | 28 | 0 | 117 | 163 | 28 | pending / pending | 22 |
| singler-annotate | 0 | 29 | 0 | 51 | 703 | 24 | pending / pending | 27 |
| slingshot-trajectory | 0 | 0 | 27 | 85 | 1073 | 0 | pending / pending | 136 |
| speckle-propeller | 0 | 20 | 0 | 79 | 221 | 18 | pending / pending | 16 |
| sva-batch | 0 | 21 | 0 | 52 | 53 | 21 | pending / pending | 9 |
| wgcna-network | 0 | 23 | 0 | 107 | 261 | 22 | pending / pending | 119 |

## 排除与证据等级

| 原因 | 行数 | 处理 |
|---|---:|---|
| applies_false | 3652 | 逐行 applies=false 排除；不纳入 usage 的参数/coverage/context |
| verification_failed_record | 77 | 未返工模块的 verification.json 与报告 §2 指定错误行取并集，全部排除；没有导入被核验判错的值 |
| verification_section_3_alpha_only | 96 | 车道 C 的 settings_preset / mean_in_log_space 属于 α 版，按 §3 排除 |
| verification_section_3_not_applicable | 30 | scanpy-qc PMID 32832599 的全部适用行按 §3 排除 |

总排除 3855 行；逐行模块/PMID/parameter/行号/原因见 bundle.excluded。排除原因按先后优先级计一次：不适用、核验错误、§3 定点更正。immunedeconv 的非逐字 _applies 错误已被核验错误并集排除。未替未返工证据补写文献值。

M1/M2 的 14 个模块为 verified_S0；车道 A 的 10 个模块和 B 的 6 个返工模块为 redone_after_verification，进入 reviewed_supplement。slingshot 为 partially_redone，maftools/immunedeconv 与 C 的 5 个模块为 not_redone，全部留在 discovery。C 的前端生态标签仍存在核验指出的不确定性，仅作为原始来源标签展示，不据它判断当前研究适用性。seed/curated 不含任何 S0 内容。

## 测试与复现

使用 `docker run --rm --network none` 的 omicstat-r:2026.09.1，Python 为 `/opt/omicstat/venv/bin/python`；两套 unittest discover 均完整执行。

| 测试 | 结果 | skip |
|---|---|---:|
| reference_service/tests | 13 项：12 passed，1 inherited failure（method_map.json stale） | 0 |
| reference_service/app/tests | 122 项：122 passed | 0 |
| 真实四树 importer 两次运行 | 输出逐字节相同 | 0 |
| SQLite 同包重复加载 | 第二次 unchanged，版本不增加 | 0 |

新增测试覆盖全部 38 模块的列/参数/coverage/eligible 计数、排除行不可返回、discovery 门禁不可绕过、缺 snippet 拒绝、M1 deseq2-wald 与 M3 seurat-cluster 的真实三列搜索及有 citation 的建议、API 预算、空 seed、不自动执行、手工 demotion 在新包加载后保留。独立 importer 测试验证 pending→options.md 映射更新与重复运行。

首次外层测试遇到尚未登记的新增文件，更新 FORK_CHANGES.json 后解决。后续容器挂载缺 gitdir、容器 root 所有权检查的问题通过只读挂载原 gitdir 和宿主 UID/GID 解决，未设置 Codex/git 配置、未提交或绕过只读 .git。切换宿主 UID 后的一次 app 重跑遇到先前 root 创建的 scratch 目录权限错误（95 errors），日志保留在 tests-app-uid-scratch-error.log；改用新的宿主 UID scratch 目录重跑，不改测试断言。最终剩余失败仅为上述既有配置差异。app 初始 119 项全通过，添加 3 项 S0 测试后 122 项全通过。全部运行没有 skip；没有把失败记成通过。

完整日志在 `/home/<user>/omic-sol61/ref_seed/tests-root.log`、`tests-app.log`、`idempotence.log`；初始 app 日志为 `tests-app-initial.log`。外层完整命令挂载本车道路径与 `/home/<user>/omic-MCP/.git` 为只读，使用宿主 UID/GID，保证真实历史检查。

交付 bundle SHA-256：`804dda6e157b53cbf6a04e9b8b9225f2f18a086175d39476f4cc20adf62ef6f0`。输入哈希清单在 bundle.inputs。

## 部署与回滚待批准

DEPLOY_SEED.md 给出：固定批准 commit → fork provenance/stage → 新 tag build → 停本服务、保存旧 compose/image、完整静止卷 tar 与 checksum → 显式 loader → 离线核对 imported ID/status、三列计数、空 seed 与 advice → owner 切换 image 并核验健康/MCP → 如失败，停止本服务，校验备份，将失败卷移到保留目录，恢复旧卷和 compose/image。本车道没有执行这些操作，也未删除容器、镜像或数据。

## 范围、偏离和未执行项

服务改动仅为 S0 loader/bundle、supplement 观察检索和保守建议读取、测试与 fork 变更登记；未改分析模块、defaults、method_map/router 或其他共享分析代码。无部署；无网络下载；未触及许可闸门数据。缺失映射与元数据、继承测试失败已如实列出，发布验收待所有者。按 commit UPDATE 不执行 git commit/push；worklog 由外部助手用作提交记录。无其他偏离。
