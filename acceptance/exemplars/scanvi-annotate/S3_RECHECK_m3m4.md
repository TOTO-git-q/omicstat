# scanvi-annotate 独立复验

审查实现 commit：`bb60144f325085c4b400e408887a1be7fe4eabd9`，分支 `s3/recheck`。只写审查输出；未修改源代码、golden 或 lock，不执行提交/推送，外部 helper 使用 lane worklog 提交。

## 可重放命令

`python3 /home/<user>/omic-sol61/recheck/run.py scanvi-annotate`。运行器和完整逐命令 argv 存于 lane scratch；固定 `docker run --rm --network none --user 1000:1000`，镜像 `omicstat-py:2026.09.1`，源码与 acceptance library 只读，scratch 可写，`OMICSTAT_TEST_TMP=/scratch`。未设置 WRITE_GOLDEN。R image ID 为 `sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7`；Python `OMICSTAT_PY_IMAGE_ID=sha256:dedf331e03f3832cbd069bd3c75af3ac1a6f4f1daf88eea6f72204a3b114b96f`；线程与种子固定。

容器内：

```text
python skills/scanvi-annotate/tests/run_smoke_test.py
python tools/make_module_lock.py scanvi-annotate --check
```

smoke exit 0，golden PASS（非 SKIP）；lock exit 1，输出：`Traceback (most recent call last):
  File "/omicstat/tools/make_module_lock.py", line 90, in <module>
    main()
  File "/omicstat/tools/make_module_lock.py", line 82, in main
    raise RuntimeError('OS_LOCK_MISMATCH: module sources, baseline or environment changed')
RuntimeError: OS_LOCK_MISMATCH: module sources, baseline or environment changed`。

## 原封闭修复清单逐项

1. **PASS**：`scripts/scanvi_annotate_core.py:19/:48-52` train_size/validation_size/shuffle_set_split/adversarial_classifier/plan_kwargs/datasplitter_kwargs 为 native resolved 值；`:53-56` 两种 predict 都传 use_posterior_mean；`:76` 返回 summary，Methods/provenance 保存。`skills/_shared/py/tests/s4_option_replay.py:122-141/:192-197` 从已 hash 验证上游 SCVI 模型构建并重新 train SCANVI，再对默认和 alternative native_split_predict（0.8/0.2、shuffle False、adversarial False、plan lr=.002、datasplitter drop_last False、posterior mean False）比较 hard labels、soft probabilities 及概率列顺序。输出 `PASS: S4 native default/alternative option parity...`。`sc_smoke_support.py:303-314` tampered model-file hash → OS_HANDOFF_MISMATCH PASS。本 lane py_output_audit.py 对4 actual outputs 独立确认 Methods Native arguments JSON = results = provenance。
2. **FAIL**：最终 merged tree 的独立 --check exit1、OS_LOCK_MISMATCH，only fig_mod_sc_backend.R stale hash；封锁项不能关闭。

## Slim 回归

实际 upstream cluster→SCVI→SCANVI 接口、native counts/ordered features/model serialization、native labels/probabilities 保存；default/alternative 模型 parity、spec determinism、label display flag effectiveness、scientific refusal 和 hash guards、golden/static checks 全通过。SKILL/Methods 保留 required labels/unlabeled/train budget/reference service guidance 与有限验证范围。6 个有效 R requests exit0。另本 lane 完整 qc→cluster→markers→scvi→scanvi 从实际 producer 依次执行、最终 upstream_runs=5、96 cells/scverse 标签保留，通过 chain.log/chain.summary.json。

## Golden 与断言

独立 golden_numeric_audit.json：annotations/label_probabilities CSV exact 不变，全部 numeric.npz 字段 exact 不变（probability max delta=0）；仅 cluster_annotation_crosstab 从4到3 rows，随同一 synthetic input 的上游 unscaled cluster labels 改变，core `:70` 直接按实际 obs native crosstab。默认 SCANVI 参数未改，原始 counts/reference labels 未改；旧严格模型/numeric assertions 和 ATOL=RTOL=1e-6 未放宽。

## 图与限制

本次全部 12 PNG、8 个不同字节内容均已通过逐图索引 contact sheets 打开；字节相同的重复图共享检查。索引 `/home/<user>/omic-sol61/recheck/scanvi-annotate/visual_inventory.json`，图见 `visual_*.jpg`。检查图非空、标签/轴、裁切、展示内容；caption/spec 与实际 n/参数一起核对。suite builders/theme/finalizer 保留。

96×160 simulator、两 epochs 只验证工程运行/序列化/交接，不等于真实队列分类准确率或收敛；概率明确 uncalibrated。图非空可读，alternative posterior sampling 仍与 native 一致。初次 wrong-venv launch 已纠正并保留日志，最终 stale seal 仍独立存在。

日志、命令、exit：`/home/<user>/omic-sol61/recheck/scanvi-annotate/{smoke,lock}.{log,command.json,status.json}`；编号源代码 `source_numbered.txt`，独立基线比较 `golden_test_diff.txt`。未闭合修复清单：

1. `skills/scanvi-annotate/module_lock.json:46` 的 `skills/_shared/scripts/fig_mod_sc_backend.R` 存储 hash 是 `24939587e244d791ba37c794f0037820bbfd2d2adfa26028ac1cba692c0685ec`，最终 merged source 的实际 hash 是 `fae00f116899bcd982c9b763396a1bdd7e3e63d568e381ba32fd7def0ee870ce`。PACK F/D 的锁定环境与 provenance/复现要求、原 S3 封锁修复仍不满足。先在最终合并树验证 numerical smoke/golden 和 R figure render，再运行本模块锁生成工具（不手写 hash），然后在正确 `OMICSTAT_PY_IMAGE_ID=sha256:dedf331e03f3832cbd069bd3c75af3ac1a6f4f1daf88eea6f72204a3b114b96f` 的独立非 root 离线容器执行 `python tools/make_module_lock.py scanvi-annotate --check` → OK。不得为 seal 漂移修改 numerical golden 或放宽断言/容差。lock_diagnosis.json 完整比较只有这一项，environment/packages/image/其他文件均相同。

VERDICT: FAIL
