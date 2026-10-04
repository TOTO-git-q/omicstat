# scanpy-cluster S4_FIXES_m3m4

| 修复项 | 改动（file:line） | 已验证证据 |
|---|---|---|
| 缩放显式选项，教程默认不强制缩放 | `skills/scanpy-cluster/scripts/scanpy_cluster_core.py:39`；`skills/scanpy-cluster/scripts/run_scanpy_cluster.py:15` | `skills/_shared/py/tests/s4_option_replay.py:35`；默认 scale=off 和显式 scale=on 分别直接复算 PCA、距离图、连接图、Leiden 标签和 UMAP；替代组合另验证 cell_ranger、minkowski/gauss、Leiden iterations/weights/partition 与 UMAP 优化参数。 |
| normalize/log1p/HVG/scale/PCA/neighbors/Leiden/UMAP 全部封闭清单参数 | `skills/scanpy-cluster/scripts/scanpy_cluster_core.py:14`；`skills/scanpy-cluster/scripts/run_scanpy_cluster.py:15` | `skills/_shared/py/tests/s4_option_replay.py:35`；所有原生参数从已解析值传入；flag、锁定默认值、registry、S0 key 和实际参数记录均保留。 |
| 五模块环境与 figure 源文件锁失效 | `tools/make_module_lock.py:63`；`skills/scanpy-cluster/module_lock.json` | 最终重新生成及独立 --check；module_lock scanpy-cluster: OK (67 files)。未为消除锁漂移修改数值。 |

CLI/默认/注册表/参考服务：`skills/scanpy-cluster/scripts/run_scanpy_cluster.py:15`；`skills/scanpy-cluster/scripts/calls_registry.json`；`skills/scanpy-cluster/references/options.md`；`skills/scanpy-cluster/SKILL.md:70`。每个新选项映射 S0 extraction key 或 none。capture_locked_defaults.py --replace 在核对锁定 API 签名和保留的教程调用值后使用，用于新增绑定与原生 accessor，不用于另选默认值；`/home/<user>/omic-sol61/fix_py/default-review.log`、capture.log/capture-final.log 保存证据。

generate_golden.sh 第 1 次：完整执行 numeric smoke → 脚本生成 golden → 第二次 smoke 严格比较 golden → seal → --check，全部通过。日志：`/home/<user>/omic-sol61/fix_py/scanpy-cluster-generate-1.log`。
generate_golden.sh 第 2 次：完整执行 numeric smoke → 脚本生成 golden → 第二次 smoke 严格比较 golden → seal → --check，全部通过。日志：`/home/<user>/omic-sol61/fix_py/scanpy-cluster-generate-2.log`。

Golden：去掉强制 scale，PCA solver/neighbor metric 改为已核对的锁定 None 分发，故 PCA/方差、邻居图、聚类/UMAP 改变；HVG 不变，保留显式 scaled 分支。 golden 精确层 CSV 改变/新增：cell_metadata.csv, pca_variance.csv；golden numeric.npz 中超出原有 tolerance 的字段：cell_metadata__x, cell_metadata__y, pca__PC1, pca__PC10, pca__PC2, pca__PC3, pca__PC4, pca__PC5, pca__PC6, pca__PC7, pca__PC8, pca__PC9。完整逐字段前后比较见 `/home/<user>/omic-sol61/fix_py/golden_comparison.json`。
600 细胞默认聚类：修复前 {'0': 226, '1': 149, '2': 138, '3': 73, '4': 14}（5 簇）；修复后 {'0': 156, '1': 114, '2': 92, '3': 81, '4': 58, '5': 57, '6': 42}（7 簇）。

图形：在 R 镜像渲染 9 个请求，全部 exit 0；已打开 14 张 PNG（9 个 SHA256 内容；相同内容去重），visual sheets [1, 2, 3]。非空，标签可读、不裁切；caption/spec 记录细胞/基因/样本数及参数。渲染命令和日志见 `/home/<user>/omic-sol61/fix_py/render_inventory.json`；逐 PNG 索引见 `visual/inventory.json`。 默认与 scaled 分支的 caption 分别明确 scale=off/on。

最终静态检查：check_calls（含 default drift）、check_defaults、check_flag_docs 全过。static-final.log；runner-static.log 包含 env/py/test.sh / tools/run_tests_py.sh 所用静态 gates（image --static、环境配置、check_calls unit、scaffold、build contracts）。未声称执行完整 suite runner；本任务五模块 numerical smoke 由各自 generate_golden.sh 验证。

遗留修复项：无。默认及显式替代路径均通过封闭清单要求的原生复算。
