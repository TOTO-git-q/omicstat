# scanpy-qc S4_FIXES_m3m4

| 修复项 | 改动（file:line） | 已验证证据 |
|---|---|---|
| Scrublet 九个原先固定的参数 | `skills/scanpy-qc/scripts/scanpy_qc_core.py:51`；`skills/scanpy-qc/scripts/run_scanpy_qc.py:15` | `skills/_shared/py/tests/s4_option_replay.py:84`；score/filter 与默认及替代 Scrublet 的分数和判定直接复算；替代值包含 sim_doublet_ratio=1.5、manhattan 距离及非默认布尔选项；filter 保留细胞与 score 的 predicted_doublet 完全对应。 |
| 五模块环境与 figure 源文件锁失效 | `tools/make_module_lock.py:63`；`skills/scanpy-qc/module_lock.json` | 最终重新生成及独立 --check；module_lock scanpy-qc: OK (66 files)。未为消除锁漂移修改数值。 |

CLI/默认/注册表/参考服务：`skills/scanpy-qc/scripts/run_scanpy_qc.py:15`；`skills/scanpy-qc/scripts/calls_registry.json`；`skills/scanpy-qc/references/options.md`；`skills/scanpy-qc/SKILL.md:75`。每个新选项映射 S0 extraction key 或 none。capture_locked_defaults.py --replace 在核对锁定 API 签名和保留的教程调用值后使用，用于新增绑定与原生 accessor，不用于另选默认值；`/home/<user>/omic-sol61/fix_py/default-review.log`、capture.log/capture-final.log 保存证据。

generate_golden.sh 第 1 次：完整执行 numeric smoke → 脚本生成 golden → 第二次 smoke 严格比较 golden → seal → --check，全部通过。日志：`/home/<user>/omic-sol61/fix_py/scanpy-qc-generate-1.log`。
generate_golden.sh 第 2 次：完整执行 numeric smoke → 脚本生成 golden → 第二次 smoke 严格比较 golden → seal → --check，全部通过。日志：`/home/<user>/omic-sol61/fix_py/scanpy-qc-generate-2.log`。

Golden：全部 CSV 与修复前逐字一致，数值未变。 golden 精确层 CSV 改变/新增：无；golden numeric.npz 中超出原有 tolerance 的字段：无。完整逐字段前后比较见 `/home/<user>/omic-sol61/fix_py/golden_comparison.json`。

图形：在 R 镜像渲染 6 个请求，全部 exit 0；已打开 6 张 PNG（2 个 SHA256 内容；相同内容去重），visual sheets [1]。非空，标签可读、不裁切；caption/spec 记录细胞/基因/样本数及参数。渲染命令和日志见 `/home/<user>/omic-sol61/fix_py/render_inventory.json`；逐 PNG 索引见 `visual/inventory.json`。

最终静态检查：check_calls（含 default drift）、check_defaults、check_flag_docs 全过。static-final.log；runner-static.log 包含 env/py/test.sh / tools/run_tests_py.sh 所用静态 gates（image --static、环境配置、check_calls unit、scaffold、build contracts）。未声称执行完整 suite runner；本任务五模块 numerical smoke 由各自 generate_golden.sh 验证。

遗留修复项：无。默认及显式替代路径均通过封闭清单要求的原生复算。
