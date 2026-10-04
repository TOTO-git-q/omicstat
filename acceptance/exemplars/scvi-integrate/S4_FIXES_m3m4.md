# scvi-integrate S4_FIXES_m3m4

| 修复项 | 改动（file:line） | 已验证证据 |
|---|---|---|
| setup covariates/size_factor、constructor、train、neighbors/UMAP 参数 | `skills/scvi-integrate/scripts/scvi_integrate_core.py:15`；`skills/scvi-integrate/scripts/run_scvi_integrate.py:15` | `skills/_shared/py/tests/s4_option_replay.py:99`；在同一小型 fixture 中直接独立训练默认结构与 n_layers=2、gene_likelihood=nb 的 tutorial_structure；另改 covariates、size factor、dispersion、latent_distribution、split/plan/datasplitter、metric/UMAP，并比较潜变量、图和 UMAP。 |
| 五模块环境与 figure 源文件锁失效 | `tools/make_module_lock.py:63`；`skills/scvi-integrate/module_lock.json` | 最终重新生成及独立 --check；module_lock scvi-integrate: OK (67 files)。未为消除锁漂移修改数值。 |

CLI/默认/注册表/参考服务：`skills/scvi-integrate/scripts/run_scvi_integrate.py:15`；`skills/scvi-integrate/scripts/calls_registry.json`；`skills/scvi-integrate/references/options.md`；`skills/scvi-integrate/SKILL.md:70`。每个新选项映射 S0 extraction key 或 none。capture_locked_defaults.py --replace 在核对锁定 API 签名和保留的教程调用值后使用，用于新增绑定与原生 accessor，不用于另选默认值；`/home/<user>/omic-sol61/fix_py/default-review.log`、capture.log/capture-final.log 保存证据。

generate_golden.sh 第 1 次：完整执行 numeric smoke → 脚本生成 golden → 第二次 smoke 严格比较 golden → seal → --check，全部通过。日志：`/home/<user>/omic-sol61/fix_py/scvi-integrate-generate-1.log`。
generate_golden.sh 第 2 次：完整执行 numeric smoke → 脚本生成 golden → 第二次 smoke 严格比较 golden → seal → --check，全部通过。日志：`/home/<user>/omic-sol61/fix_py/scvi-integrate-generate-2.log`。

Golden：上游 cluster 默认变化影响 before graph 与 UMAP 指标；分 stage 比较已确认 after graph/UMAP 差值为 0，latent/training_history 不变；默认 SCVI 结构及原始 counts 保留。 golden 精确层 CSV 改变/新增：无；golden numeric.npz 中超出原有 tolerance 的字段：batch_mixing__normalized_batch_entropy, batch_mixing__same_batch_weight_fraction, embedding_comparison__x, embedding_comparison__y。完整逐字段前后比较见 `/home/<user>/omic-sol61/fix_py/golden_comparison.json`。

图形：在 R 镜像渲染 8 个请求，全部 exit 0；已打开 16 张 PNG（6 个 SHA256 内容；相同内容去重），visual sheets [4, 5]。非空，标签可读、不裁切；caption/spec 记录细胞/基因/样本数及参数。渲染命令和日志见 `/home/<user>/omic-sol61/fix_py/render_inventory.json`；逐 PNG 索引见 `visual/inventory.json`。

最终静态检查：check_calls（含 default drift）、check_defaults、check_flag_docs 全过。static-final.log；runner-static.log 包含 env/py/test.sh / tools/run_tests_py.sh 所用静态 gates（image --static、环境配置、check_calls unit、scaffold、build contracts）。未声称执行完整 suite runner；本任务五模块 numerical smoke 由各自 generate_golden.sh 验证。

遗留修复项：无。小型两 epoch fixture 仅验证工程行为；不构成模型收敛、整合质量或注释准确率证据。
