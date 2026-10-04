# scanpy-qc 独立复验

审查实现 commit：`bb60144f325085c4b400e408887a1be7fe4eabd9`，分支 `s3/recheck`。只写审查输出；未修改源代码、golden 或 lock，不执行提交/推送，外部 helper 使用 lane worklog 提交。

## 可重放命令

`python3 /home/<user>/omic-sol61/recheck/run.py scanpy-qc`。运行器和完整逐命令 argv 存于 lane scratch；固定 `docker run --rm --network none --user 1000:1000`，镜像 `omicstat-py:2026.09.1`，源码与 acceptance library 只读，scratch 可写，`OMICSTAT_TEST_TMP=/scratch`。未设置 WRITE_GOLDEN。R image ID 为 `sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7`；Python `OMICSTAT_PY_IMAGE_ID=sha256:dedf331e03f3832cbd069bd3c75af3ac1a6f4f1daf88eea6f72204a3b114b96f`；线程与种子固定。

容器内：

```text
python skills/scanpy-qc/tests/run_smoke_test.py
python tools/make_module_lock.py scanpy-qc --check
```

smoke exit 0，golden PASS（非 SKIP）；lock exit 1，输出：`Traceback (most recent call last):
  File "/omicstat/tools/make_module_lock.py", line 90, in <module>
    main()
  File "/omicstat/tools/make_module_lock.py", line 82, in main
    raise RuntimeError('OS_LOCK_MISMATCH: module sources, baseline or environment changed')
RuntimeError: OS_LOCK_MISMATCH: module sources, baseline or environment changed`。

## 原封闭修复清单逐项

1. **PASS**：`scripts/scanpy_qc_core.py:18/:51-58` 把 Scrublet sim_doublet_ratio/stdev_doublet_rate/synthetic_doublet_umi_subsampling/knn_dist_metric/normalize_variance/log_transform/mean_center/use_approx_neighbors/n_neighbors 解析并转发原生 sc.pp.scrublet；entry `:15-43` CLI 保留 locked defaults。smoke 调用 `skills/_shared/py/tests/s4_option_replay.py:84-97/:143-156`，默认/替代 score 原生复算（1.5/manhattan、非默认布尔及 subsampling）；filter cells 与原 score 判定完全对应。输出 `PASS: S4 native default/alternative option parity...`。独立 py_output_audit.py 检查 6 个实际输出的 Native arguments JSON 与 results/provenance resolved native_options 全相同。
2. **FAIL**：原封锁修复在最终 merge 后仍不满足独立 --check；exit 1、OS_LOCK_MISMATCH。诊断只发现 fig_mod_sc_backend.R hash，不是 numerical golden 或 package/image 漂移。

## Slim 回归

官方 PBMC first-600 anchor native QC/score/filter、AnnData counts/obs/var 表保留；required QC choices/reference_advise/reference_search/options key 保留；static calls/default drift/defaults/flags 与 typed/scientific refusal、--spec determinism 全通过。R 渲染 6 请求全 exit 0；Methods/provenance 数值绑定检查 PASS。

## Golden 与断言

独立 git baseline 与 golden_numeric_audit.json：所有原 CSV 字节相同、numeric.npz 的所有字段 exact/unchanged tolerance 内；无数值变化，无 weakened assertion（ATOL=RTOL=1e-6 保留）。

## 图与限制

本次全部 6 PNG、2 个不同字节内容均已通过逐图索引 contact sheets 打开；字节相同的重复图共享检查。索引 `/home/<user>/omic-sol61/recheck/scanpy-qc/visual_inventory.json`，图见 `visual_*.jpg`。检查图非空、标签/轴、裁切、展示内容；caption/spec 与实际 n/参数一起核对。suite builders/theme/finalizer 保留。

初次 scratch runner 误用 R venv PATH 导致 Python interpreter 无 locked packages，保留 smoke.initial/lock.initial；改 lane scratch runner 的 PATH=/opt/omicstat/venv-py/bin 后本次 numerical PASS。最终 lock 失败与该已纠正 launch 问题不同，必须修复 merge 后 seal。

日志、命令、exit：`/home/<user>/omic-sol61/recheck/scanpy-qc/{smoke,lock}.{log,command.json,status.json}`；编号源代码 `source_numbered.txt`，独立基线比较 `golden_test_diff.txt`。未闭合修复清单：

1. `skills/scanpy-qc/module_lock.json:46`中 `skills/_shared/scripts/fig_mod_sc_backend.R` 的 seal hash 仍为 `24939587e244d791ba37c794f0037820bbfd2d2adfa26028ac1cba692c0685ec`，最终合并文件为 `fae00f116899bcd982c9b763396a1bdd7e3e63d568e381ba32fd7def0ee870ce`。必须在最终合并树、正确 OMICSTAT_PY_IMAGE_ID 下，先通过本模块 numerical smoke/golden 与 R render，再用模块锁工具重新封锁并独立 `python tools/make_module_lock.py scanpy-qc --check` → OK。不修改 golden 数值，不放宽 assertion/tolerance。完整 diff 只有此 shared hash，environment/packages/image/其他 manifest 项一致，见 lock_diagnosis.json。

VERDICT: FAIL
