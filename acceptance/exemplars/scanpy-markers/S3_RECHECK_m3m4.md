# scanpy-markers 独立复验

审查实现 commit：`bb60144f325085c4b400e408887a1be7fe4eabd9`，分支 `s3/recheck`。只写审查输出；未修改源代码、golden 或 lock，不执行提交/推送，外部 helper 使用 lane worklog 提交。

## 可重放命令

`python3 /home/<user>/omic-sol61/recheck/run.py scanpy-markers`。运行器和完整逐命令 argv 存于 lane scratch；固定 `docker run --rm --network none --user 1000:1000`，镜像 `omicstat-py:2026.09.1`，源码与 acceptance library 只读，scratch 可写，`OMICSTAT_TEST_TMP=/scratch`。未设置 WRITE_GOLDEN。R image ID 为 `sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7`；Python `OMICSTAT_PY_IMAGE_ID=sha256:dedf331e03f3832cbd069bd3c75af3ac1a6f4f1daf88eea6f72204a3b114b96f`；线程与种子固定。

容器内：

```text
python skills/scanpy-markers/tests/run_smoke_test.py
python tools/make_module_lock.py scanpy-markers --check
```

smoke exit 0，golden PASS（非 SKIP）；lock exit 1，输出：`Traceback (most recent call last):
  File "/omicstat/tools/make_module_lock.py", line 90, in <module>
    main()
  File "/omicstat/tools/make_module_lock.py", line 82, in main
    raise RuntimeError('OS_LOCK_MISMATCH: module sources, baseline or environment changed')
RuntimeError: OS_LOCK_MISMATCH: module sources, baseline or environment changed`。

## 原封闭修复清单逐项

1. **PASS**：`scripts/scanpy_markers_core.py:16/:33-37` reference/groups/mask_var/rankby_abs/corr_method/tie_correct/n_genes 为 CLI 解析值并进入 native rank_genes_groups。`skills/_shared/py/tests/s4_option_replay.py:65-81/:171-179` 分别复算默认和 named_reference（Wilcoxon、reference=0、其他 groups、highly_variable mask、rankby_abs=True、bonferroni、tie_correct=True、n_genes=25），结果匹配。
2. **PASS**：core `:38` sc.get.rank_genes_groups_df，`:59` 额外输出 rank_genes_groups_native.csv；原 AnnData uns 仍保留。replay `:71-81` 检查原生列顺序、行顺序、字符串、数值（1e-12/1e-10）和保存 uns 的 names/scores/logfoldchanges/pvals/pvals_adj，严格通过。coordinator Methods/Results 参数化附加要求也经 replay `:206-223` 实际检查；tested group count 按 result dtype.names，避免错误 all groups 声明。本 lane py_output_audit.py 对 4 输出独立解析 Methods 的 JSON，等于 results/provenance resolved native_options。
3. **FAIL**：final merged tree 的独立 --check exit1、OS_LOCK_MISMATCH；diagnosis 只有 fig_mod_sc_backend.R stale hash，封锁项未关闭。

## Slim 回归

实际 QC→cluster→markers producer 链、官方 native marker 检验和 AnnData/table 保存通过；suite feature_table 与原生 dataframe 并存；条件推断拒绝、typed errors、--spec determinism/native golden/static calls/defaults/flags 通过。比较参数/defaults 与 reference service guidance 保留，正文按实际 comparison/correction/ties/n_genes 生成。6 个有效 R render requests exit0。

## Golden 与断言

独立 golden_numeric_audit.json：feature_table/marker_details 从 68845 到 96383 rows，正好 13769 genes ×旧5/新7 groups；dot data 从100到175 rows，随上游 cluster 改变。原生 CSV 是新增交付物，已与 direct native 全列/顺序/值验证；numeric.npz 没有字段改变。old_native_probe 已确认旧 cluster golden 对应强制 scale，新 unscaled upstream 的 native replay 通过，marker 默认检验保持 locked default，故新 golden 的理由真实。ATOL/RTOL 和旧 marker strict assertions 未弱化。

## 图与限制

本次全部 7 PNG、6 个不同字节内容均已通过逐图索引 contact sheets 打开；字节相同的重复图共享检查。索引 `/home/<user>/omic-sol61/recheck/scanpy-markers/visual_inventory.json`，图见 `visual_*.jpg`。检查图非空、标签/轴、裁切、展示内容；caption/spec 与实际 n/参数一起核对。suite builders/theme/finalizer 保留。

默认与命名 reference 图均可读；named_reference plot 包括参考组用于表达展示，推断表只包含实际 tested groups。初次 Python wrong-venv launch 已纠正并保留日志，最终数值/图通过；seal 仍失败。

日志、命令、exit：`/home/<user>/omic-sol61/recheck/scanpy-markers/{smoke,lock}.{log,command.json,status.json}`；编号源代码 `source_numbered.txt`，独立基线比较 `golden_test_diff.txt`。未闭合修复清单：

1. `skills/scanpy-markers/module_lock.json:46` 的 `skills/_shared/scripts/fig_mod_sc_backend.R` 存储 hash 是 `24939587e244d791ba37c794f0037820bbfd2d2adfa26028ac1cba692c0685ec`，最终 merged source 的实际 hash 是 `fae00f116899bcd982c9b763396a1bdd7e3e63d568e381ba32fd7def0ee870ce`。PACK F/D 的锁定环境与 provenance/复现要求、原 S3 封锁修复仍不满足。先在最终合并树验证 numerical smoke/golden 和 R figure render，再运行本模块锁生成工具（不手写 hash），然后在正确 `OMICSTAT_PY_IMAGE_ID=sha256:dedf331e03f3832cbd069bd3c75af3ac1a6f4f1daf88eea6f72204a3b114b96f` 的独立非 root 离线容器执行 `python tools/make_module_lock.py scanpy-markers --check` → OK。不得为 seal 漂移修改 numerical golden 或放宽断言/容差。lock_diagnosis.json 完整比较只有这一项，environment/packages/image/其他文件均相同。

VERDICT: FAIL
