# scanpy-markers S4_FIXES_m3m4

| 修复项 | 改动（file:line） | 已验证证据 |
|---|---|---|
| reference/groups/mask_var/rankby_abs/corr_method/tie_correct/n_genes | `skills/scanpy-markers/scripts/scanpy_markers_core.py:33`；`skills/scanpy-markers/scripts/run_scanpy_markers.py:15` | `skills/_shared/py/tests/s4_option_replay.py:65`；默认与 named_reference 路径直接复算；后者 Wilcoxon、命名参考组、highly_variable mask、rankby_abs=True、bonferroni、tie_correct=True、n_genes=25。 |
| 保留原生 dataframe 的列、值和排序 | `skills/scanpy-markers/scripts/scanpy_markers_core.py:38`；`skills/scanpy-markers/scripts/run_scanpy_markers.py:15` | `skills/_shared/py/tests/s4_option_replay.py:71`；原生 CSV 与直接 sc.get.rank_genes_groups_df 的列顺序、行顺序、数值逐一比较；原生 AnnData uns 与 suite feature_table 同时保留。 |
| 协调员 02:10 Methods/Results 参数化措辞 | `skills/scanpy-markers/scripts/scanpy_markers_core.py:61`；`skills/scanpy-markers/scripts/run_scanpy_markers.py:15` | `skills/_shared/py/tests/s4_option_replay.py:198`；正文从解析后的参考组、groups、mask、排序、校正、tie 与 n_genes 填入；默认及命名参考分支 smoke 检查正文，禁用旧固定 BH/remaining-cells 说法；n_clusters 按实际 tested groups 统计。 |
| 五模块环境与 figure 源文件锁失效 | `tools/make_module_lock.py:63`；`skills/scanpy-markers/module_lock.json` | 最终重新生成及独立 --check；module_lock scanpy-markers: OK (67 files)。未为消除锁漂移修改数值。 |

CLI/默认/注册表/参考服务：`skills/scanpy-markers/scripts/run_scanpy_markers.py:15`；`skills/scanpy-markers/scripts/calls_registry.json`；`skills/scanpy-markers/references/options.md`；`skills/scanpy-markers/SKILL.md:70`。每个新选项映射 S0 extraction key 或 none。capture_locked_defaults.py --replace 在核对锁定 API 签名和保留的教程调用值后使用，用于新增绑定与原生 accessor，不用于另选默认值；`/home/<user>/omic-sol61/fix_py/default-review.log`、capture.log/capture-final.log 保存证据。

generate_golden.sh 第 1 次：完整执行 numeric smoke → 脚本生成 golden → 第二次 smoke 严格比较 golden → seal → --check，全部通过。日志：`/home/<user>/omic-sol61/fix_py/scanpy-markers-generate-1.log`。
generate_golden.sh 第 2 次：完整执行 numeric smoke → 脚本生成 golden → 第二次 smoke 严格比较 golden → seal → --check，全部通过。日志：`/home/<user>/omic-sol61/fix_py/scanpy-markers-generate-2.log`。

Golden：新原生 CSV 是新增交付物；上游默认 cluster 不再强制 scale，聚类数/成员改变，故 marker/feature/dot 表随之改变；marker 默认检验仍为锁定默认。 golden 精确层 CSV 改变/新增：feature_table.csv, marker_details.csv, marker_dot_data.csv, rank_genes_groups_native.csv；golden numeric.npz 中超出原有 tolerance 的字段：无。完整逐字段前后比较见 `/home/<user>/omic-sol61/fix_py/golden_comparison.json`。

图形：在 R 镜像渲染 9 个请求，全部 exit 0；已打开 13 张 PNG（6 个 SHA256 内容；相同内容去重），visual sheets [1, 3, 4]。非空，标签可读、不裁切；caption/spec 记录细胞/基因/样本数及参数。渲染命令和日志见 `/home/<user>/omic-sol61/fix_py/render_inventory.json`；逐 PNG 索引见 `visual/inventory.json`。

最终静态检查：check_calls（含 default drift）、check_defaults、check_flag_docs 全过。static-final.log；runner-static.log 包含 env/py/test.sh / tools/run_tests_py.sh 所用静态 gates（image --static、环境配置、check_calls unit、scaffold、build contracts）。未声称执行完整 suite runner；本任务五模块 numerical smoke 由各自 generate_golden.sh 验证。

遗留修复项：无。默认及显式替代路径均通过封闭清单要求的原生复算。
