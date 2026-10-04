# M3/M4 十三模块独立 S3 复验报告

审查实现基线 `bb60144f325085c4b400e408887a1be7fe4eabd9`（`s3/recheck`，两个 fix lane 已合并）。阅读原 S3 封闭修复清单、S4_FIXES 与 lane 报告后，以本 lane 的独立执行/source/实际输出判定；没有把修复报告当作通过证据。只修改十三份 S3_RECHECK、本报告和 lane worklog；未修改代码、golden、lock，未执行 git commit/push，外部 helper 按 worklog 提交。

## 结论与 S5 边界

十三模块数值 smoke/golden 全 PASS（无 SKIP）；八个 R lock --check OK，五个 Python lock --check 均 FAIL。复验 verdict 计数：`{'PASS': 5, 'PASS WITH NOTES': 3, 'FAIL': 5}`。五个 Python 的功能修复/native parity/Methods/图已通过，但最终合并树的 seal 失配，不能进入 S5。本 lane 复验工作完成，失败项留给修复方；不执行 S5。

| 模块 | smoke / golden | lock --check | verdict | 本次证据重点 |
|---|---|---|---|---|
| [seurat-cluster](../../acceptance/exemplars/seurat-cluster/S3_RECHECK_m3m4.md) | PASS / PASS | OK | PASS | 两条闭合项通过；附加 CLI/native/Methods/provenance |
| [seurat-integrate](../../acceptance/exemplars/seurat-integrate/S3_RECHECK_m3m4.md) | PASS / PASS | OK | PASS | project.dim TRUE/FALSE native loadings 与实际记录 |
| [seurat-markers](../../acceptance/exemplars/seurat-markers/S3_RECHECK_m3m4.md) | PASS / PASS | OK | PASS WITH NOTES | base/mean.fxn 两路线；保留 owner 已接受 printed 差异 |
| [aucell-score](../../acceptance/exemplars/aucell-score/S3_RECHECK_m3m4.md) | PASS / PASS | OK | PASS | 自定义 GMT/source/licence gate 与 native AUC |
| [singler-annotate](../../acceptance/exemplars/singler-annotate/S3_RECHECK_m3m4.md) | PASS / PASS | OK | PASS | actual overrides→native/Methods/results/captions/provenance |
| [wgcna-network](../../acceptance/exemplars/wgcna-network/S3_RECHECK_m3m4.md) | PASS / PASS | OK | PASS WITH NOTES | 五函数 controls、bicor/Pearson/TOMDenom、BH/none；稠密树备注 |
| [maftools-landscape](../../acceptance/exemplars/maftools-landscape/S3_RECHECK_m3m4.md) | PASS / PASS | OK | PASS | 区域 TMB native identical，完整 variants 保留 |
| [immunedeconv-infiltration](../../acceptance/exemplars/immunedeconv-infiltration/S3_RECHECK_m3m4.md) | PASS / PASS | OK | PASS WITH NOTES | 八 offline 方法与 absolute interface；licensed 范围备注 |
| [scanpy-qc](../../acceptance/exemplars/scanpy-qc/S3_RECHECK_m3m4.md) | PASS / PASS | FAIL | FAIL | 原生选项/实际输出通过；共享 figure builder stale seal |
| [scanpy-cluster](../../acceptance/exemplars/scanpy-cluster/S3_RECHECK_m3m4.md) | PASS / PASS | FAIL | FAIL | 原生选项/实际输出通过；共享 figure builder stale seal |
| [scanpy-markers](../../acceptance/exemplars/scanpy-markers/S3_RECHECK_m3m4.md) | PASS / PASS | FAIL | FAIL | 原生选项/实际输出通过；共享 figure builder stale seal |
| [scvi-integrate](../../acceptance/exemplars/scvi-integrate/S3_RECHECK_m3m4.md) | PASS / PASS | FAIL | FAIL | 原生选项/实际输出通过；共享 figure builder stale seal |
| [scanvi-annotate](../../acceptance/exemplars/scanvi-annotate/S3_RECHECK_m3m4.md) | PASS / PASS | FAIL | FAIL | 原生选项/实际输出通过；共享 figure builder stale seal |

## 剩余封闭修复清单

五个 Python 模块均只剩重新封锁同一个合并后共享文件的任务。完整 read-only lock build 比较只有 `skills/_shared/scripts/fig_mod_sc_backend.R`：stored SHA256=`24939587e244d791ba37c794f0037820bbfd2d2adfa26028ac1cba692c0685ec`；merged actual SHA256=`fae00f116899bcd982c9b763396a1bdd7e3e63d568e381ba32fd7def0ee870ce`。environment/packages/image ID、其他 files 一致；原来环境定义和四个新增 fig_mod 文件问题已处理，此处是另一次合并后的共享 SingleR builder hash。`git show bb60144^2:skills/_shared/scripts/fig_mod_sc_backend.R` 计算出的 hash 恰是存储旧值，最终 merge 的文件是实际新值。

| 模块 | 失配位置 | 修复及独立关闭条件 |
|---|---|---|
| scanpy-qc | `skills/scanpy-qc/module_lock.json:46` | 最终 merged tree 的 smoke/golden/R render 通过后，用锁工具重新生成；正确 PY image ID 的新非 root/offline 容器执行 `python tools/make_module_lock.py scanpy-qc --check` → OK |
| scanpy-cluster | `skills/scanpy-cluster/module_lock.json:46` | 最终 merged tree 的 smoke/golden/R render 通过后，用锁工具重新生成；正确 PY image ID 的新非 root/offline 容器执行 `python tools/make_module_lock.py scanpy-cluster --check` → OK |
| scanpy-markers | `skills/scanpy-markers/module_lock.json:46` | 最终 merged tree 的 smoke/golden/R render 通过后，用锁工具重新生成；正确 PY image ID 的新非 root/offline 容器执行 `python tools/make_module_lock.py scanpy-markers --check` → OK |
| scvi-integrate | `skills/scvi-integrate/module_lock.json:46` | 最终 merged tree 的 smoke/golden/R render 通过后，用锁工具重新生成；正确 PY image ID 的新非 root/offline 容器执行 `python tools/make_module_lock.py scvi-integrate --check` → OK |
| scanvi-annotate | `skills/scanvi-annotate/module_lock.json:46` | 最终 merged tree 的 smoke/golden/R render 通过后，用锁工具重新生成；正确 PY image ID 的新非 root/offline 容器执行 `python tools/make_module_lock.py scanvi-annotate --check` → OK |

每项遵循 PACK C/D/F 与原 S3 sealing 修复要求：不得手写 hash，不得因锁漂移改数值 golden，不得放宽 assertion/tolerance。命令、exit1/OS_LOCK_MISMATCH、逐文件/environment 完整诊断在各模块 scratch `lock.command.json` / `lock.log` / `lock.status.json` / `lock_diagnosis.json`；具体闭合项见五份 FAIL 卡。八个 R 模块原封闭修复项均已关闭。

## 三生态实际链

| 生态 | 实际 producer→consumer | 本次结果与重放命令 |
|---|---|---|
| Seurat | seurat-qc→seurat-cluster→seurat-markers | markers smoke 实际执行全部 producer；2638 cells，native all/contrast parity、upstream_runs=3，PASS。`python3 /home/<user>/omic-sol61/recheck/run.py seurat-markers`；另 base/mean CLI probe 两路线 PASS。 |
| Bioconductor | scater-qc→scran-cluster→scran-markers | 真实 Grun anchor 的显式 400-cell 诊断子集；QC/cluster exit0、golden PASS；marker native scoreMarkers identical、golden PASS。两个容器依次 `Rscript skills/scran-cluster/tests/run_smoke_test.R`、`Rscript skills/scran-markers/tests/run_smoke_test.R`，共同 OMICSTAT_TEST_TMP=/scratch；完整命令/exit/log 在 bioc-chain。 |
| Python | scanpy-qc→scanpy-cluster→scanpy-markers→scvi-integrate→scanvi-annotate | 官方 synthetic_iid 96×160，两 batch；五次真实 CLI 和 hash-verified 模型交接，最终 upstream_runs=5、96 cells、scverse label 保留，PASS。`python /scratch/python_chain.py`（lane run.py 非 root Python 镜像）；各 argv/engine log、chain.log/chain.summary.json 在 python-chain。 |

Python 全链额外在 R 镜像渲染五个请求，全 exit0；Bioconductor 的 mt carrier 与 permissive thresholds、Python MT-空匹配均仅是工程诊断，不作为线粒体/生物分群判断。两 epochs 模拟模型不证明真实队列收敛、批次去除效果或标签准确率。

## Golden 改变的独立核验

- 八个 R golden/manifest 与原 S3 commit `d7355bec` 全部相同；原断言保留，新增修复绑定/文字/interface 检查。
- scanpy-qc 虽经修复方脚本再生成，全部 CSV/NPZ 实测不变。
- scanpy-cluster：本 lane 单独用 direct native 旧 compulsory scale + arpack/Euclidean 复算，与旧 golden 的 PCA/UMAP/labels 匹配；新 default scale=off 的独立 replay 也通过。旧 five clusters 226/149/138/73/14 → 新 seven clusters 156/114/92/81/58/57/42，HVG 表不变，PCA/variance/graph/labels/UMAP 改变合法。命令/结果在 old_native_probe.*。
- scanpy-markers：上游 labels 从5到7 groups，13769 genes 的表从68845到96383 rows；dot rows100到175。额外 native CSV 逐列/顺序/值与原生 dataframe 一致。默认 native marker test 未改变。
- scvi-integrate：逐 stage NPZ 比较只有 before embedding/batch_mixing 改变；after 每个差值为0，latent/training_history exact 不变，符合上游 cluster 默认变化。
- scanvi-annotate：annotations、probabilities（含 numeric NPZ）exact 不变，只 crosstab 从4到3 rows，反映同一 synthetic input 的 upstream labels；不是修改默认模型掩盖失败。

本 lane 从 git 读取原始 golden 到自己的 scratch，以脚本比较，没有写新 golden。test_changes.diff 已核对：Python 旧 replay 的 scale 改为显式条件、PCA solver 跟随 locked None；旧 numerical assertions 未删/未弱化，ATOL=RTOL=1e-6 保留，markers 更严格原生值比较仍在。全部 per-module golden_audit/golden_numeric_audit 和 scVI stage audit 是本次实测证据。

## Slim 回归、图和运行约束

所有十三模块保留 native engine/object/table、options/default 与 reference_advise/reference_search 指导；已从 actual output 核对 Methods/provenance。R 独立 calls/default drift/defaults/flag docs/lint 全 exit0；Python smoke 的相应静态 gates 全通过。全部本次 177 PNG（全局 103 个不同 SHA256）已逐图打开，重复字节共享视觉检查；包含补充 CLI 和三生态链。图非空，未见影响验收的裁切；caption/spec 的 n/阈值/实际参数与 suite builder/theme/finalizer/lint 一并检查。各目录 visual_inventory.json 保存完整路径/SHA/尺寸/opened 标记，visual_*.jpg 为查看索引；另 Python chain 两张 UMAP 已单独原尺寸打开。

保留已接受备注：Seurat markers 7023 vs旧打印7019；WGCNA 全基因树信息密集、small alternative all-grey 与 native 一致；CIBERSORT 只证明自编合法 interface forwarding，不声称 licensed CIBERSORT 生物学执行；scVI/scANVI 保留有限模拟验证范围。maftools 原生 oncoplot 是已批准 suite 字体/配色例外。

全部运行 `docker run --rm --network none --user 1000:1000`，R=`omicstat-r:2026.10.1` / `sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7`，Python=`omicstat-py:2026.09.1` / `OMICSTAT_PY_IMAGE_ID=sha256:dedf331e03f3832cbd069bd3c75af3ac1a6f4f1daf88eea6f72204a3b114b96f`。源码/library 只读，输出/logs 在 `/home/<user>/omic-sol61/recheck/`；无需下载/安装或触碰其他 lane/vendor/受限内容。初次 Python scratch harness PATH 误用 R venv，保留 initial logs；纠正为 /opt/omicstat/venv-py/bin 后所有 numerical smoke 通过。最终五个 stale seal 错误另经正确 interpreter/image 复现，与已纠正 launch 问题不同。

## 更新的 S5 资格名单

共 19 个模块；前十一项沿用原 S3 PASS WITH NOTES 的限定范围，加上本次八个通过的 R 模块：

`seurat-qc`, `seurat-modulescore`, `scater-qc`, `scran-cluster`, `batchelor-integrate`, `scran-markers`, `muscat-pseudobulk`, `speckle-propeller`, `slingshot-trajectory`, `monocle3-trajectory`, `cellchat-communication`, `seurat-cluster`, `seurat-integrate`, `seurat-markers`, `aucell-score`, `singler-annotate`, `wgcna-network`, `maftools-landscape`, `immunedeconv-infiltration`。

五个 Python 模块在最终合并树重新封锁并独立 --check OK 前，无 S5 资格。没有其他未完成的 lane 审查步骤；剩余五项 sealing repair 已明确留给修复方。
