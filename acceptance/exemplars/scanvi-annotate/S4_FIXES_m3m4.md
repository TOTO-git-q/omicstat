# scanvi-annotate S4_FIXES_m3m4

| 修复项 | 改动（file:line） | 已验证证据 |
|---|---|---|
| train split/adversarial/plan/datasplitter 与 predict use_posterior_mean | `skills/scanvi-annotate/scripts/scanvi_annotate_core.py:19`；`skills/scanvi-annotate/scripts/run_scanvi_annotate.py:15` | `skills/_shared/py/tests/s4_option_replay.py:117`；对同一 hash-verified 上游模型直接构建/训练 SCANVI，比较默认与 native_split_predict 的硬标签、软概率及列顺序；替代 split=0.8/0.2、shuffle=False、adversarial=False、plan/datasplitter 非默认、posterior mean=False；腐败上游 model 文件必须 OS_HANDOFF_MISMATCH。 |
| 五模块环境与 figure 源文件锁失效 | `tools/make_module_lock.py:63`；`skills/scanvi-annotate/module_lock.json` | 最终重新生成及独立 --check；module_lock scanvi-annotate: OK (66 files)。未为消除锁漂移修改数值。 |

CLI/默认/注册表/参考服务：`skills/scanvi-annotate/scripts/run_scanvi_annotate.py:15`；`skills/scanvi-annotate/scripts/calls_registry.json`；`skills/scanvi-annotate/references/options.md`；`skills/scanvi-annotate/SKILL.md:70`。每个新选项映射 S0 extraction key 或 none。capture_locked_defaults.py --replace 在核对锁定 API 签名和保留的教程调用值后使用，用于新增绑定与原生 accessor，不用于另选默认值；`/home/<user>/omic-sol61/fix_py/default-review.log`、capture.log/capture-final.log 保存证据。

generate_golden.sh 第 1 次：完整执行 numeric smoke → 脚本生成 golden → 第二次 smoke 严格比较 golden → seal → --check，全部通过。日志：`/home/<user>/omic-sol61/fix_py/scanvi-annotate-generate-1.log`。
generate_golden.sh 第 2 次：完整执行 numeric smoke → 脚本生成 golden → 第二次 smoke 严格比较 golden → seal → --check，全部通过。日志：`/home/<user>/omic-sol61/fix_py/scanvi-annotate-generate-2.log`。

Golden：上游 cluster 默认变化使 cluster-label crosstab 从 4 行变为 3 行；annotations 与 label_probabilities（包括概率数值）未变。原始 counts、参考标签及默认 SCANVI 参数保留。 golden 精确层 CSV 改变/新增：cluster_annotation_crosstab.csv；golden numeric.npz 中超出原有 tolerance 的字段：无。完整逐字段前后比较见 `/home/<user>/omic-sol61/fix_py/golden_comparison.json`。

图形：在 R 镜像渲染 10 个请求，全部 exit 0；已打开 20 张 PNG（8 个 SHA256 内容；相同内容去重），visual sheets [4, 5, 6]。非空，标签可读、不裁切；caption/spec 记录细胞/基因/样本数及参数。渲染命令和日志见 `/home/<user>/omic-sol61/fix_py/render_inventory.json`；逐 PNG 索引见 `visual/inventory.json`。

最终静态检查：check_calls（含 default drift）、check_defaults、check_flag_docs 全过。static-final.log；runner-static.log 包含 env/py/test.sh / tools/run_tests_py.sh 所用静态 gates（image --static、环境配置、check_calls unit、scaffold、build contracts）。未声称执行完整 suite runner；本任务五模块 numerical smoke 由各自 generate_golden.sh 验证。

遗留修复项：无。小型两 epoch fixture 仅验证工程行为；不构成模型收敛、整合质量或注释准确率证据。
