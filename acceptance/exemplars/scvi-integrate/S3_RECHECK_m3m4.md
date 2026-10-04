# scvi-integrate 独立复验

审查实现 commit：`bb60144f325085c4b400e408887a1be7fe4eabd9`，分支 `s3/recheck`。只写审查输出；未修改源代码、golden 或 lock，不执行提交/推送，外部 helper 使用 lane worklog 提交。

## 可重放命令

`python3 /home/<user>/omic-sol61/recheck/run.py scvi-integrate`。运行器和完整逐命令 argv 存于 lane scratch；固定 `docker run --rm --network none --user 1000:1000`，镜像 `omicstat-py:2026.09.1`，源码与 acceptance library 只读，scratch 可写，`OMICSTAT_TEST_TMP=/scratch`。未设置 WRITE_GOLDEN。R image ID 为 `sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7`；Python `OMICSTAT_PY_IMAGE_ID=sha256:dedf331e03f3832cbd069bd3c75af3ac1a6f4f1daf88eea6f72204a3b114b96f`；线程与种子固定。

容器内：

```text
python skills/scvi-integrate/tests/run_smoke_test.py
python tools/make_module_lock.py scvi-integrate --check
```

smoke exit 0，golden PASS（非 SKIP）；lock exit 1，输出：`Traceback (most recent call last):
  File "/omicstat/tools/make_module_lock.py", line 90, in <module>
    main()
  File "/omicstat/tools/make_module_lock.py", line 82, in main
    raise RuntimeError('OS_LOCK_MISMATCH: module sources, baseline or environment changed')
RuntimeError: OS_LOCK_MISMATCH: module sources, baseline or environment changed`。

## 原封闭修复清单逐项

1. **PASS**：setup covariates/size_factor_key → `scripts/scvi_integrate_core.py:40-41`；constructor n_hidden/n_layers/dropout_rate/dispersion/gene_likelihood/use_observed_lib_size/latent_distribution → `:42-44`；train split/early_stopping/plan_kwargs/datasplitter_kwargs → `:45-49`；neighbors/UMAP metric/method/spread/init/optimization → `:56-61`。CLI N.resolve `:15` 保留 locked defaults，summary `:88` 被 shared runtime 写入 Methods/provenance。
   smoke 调用 `skills/_shared/py/tests/s4_option_replay.py:100-119/:180-191`，同一个 96×160 fixture 独立训练默认结构和 tutorial_structure（n_layers=2/gene_likelihood=nb，其他 covariates/size-factor/dispersion/latent/split/plan/metric/UMAP 非默认），比较 latent、graph 和 UMAP，原 1e-6 tolerance PASS。既非 reload-only，也非 engine-vs-itself；直接 native 新训练见 replay 源码。输出 `PASS: S4 native default/alternative option parity...`。独立 py_output_audit.py 检查 4 actual outputs Methods/results/provenance resolved JSON 相同。
2. **FAIL**：独立 final --check exit1；完整 diagnosis 只有共享 fig_mod_sc_backend.R hash mismatch，seal 项未关闭。

## Slim 回归

原生 SCVI setup/fit/latent/model save、native AnnData 原始 counts 和原 cluster labels 保留；2 batches/2 epochs engineering fixture、latent effectiveness/spec determinism、ecosystem/hash/lineage refusal、golden 和 static gates 全通过。SKILL/options 的 required budget/batch/features/scientific inputs、reference guidance 和 finite-validation 说明保留。5 个有效 R figure requests 渲染 exit0。

## Golden 与断言

独立 golden_numeric_audit.json 与 golden_stage_audit.py：embedding_comparison/batch_mixing 只 before 部分变（旧 upstream cluster→新默认 unscaled）；after 的最大绝对差逐字段都是0；latent/training_history exact 不变。数值差异字段与 fix lane 的理由一致；CSV 精确层全 unchanged。ATOL=RTOL=1e-6 及原 assertions 保留，未为 lock 漂移覆盖任何 numerical golden。

## 图与限制

本次全部 10 PNG、6 个不同字节内容均已通过逐图索引 contact sheets 打开；字节相同的重复图共享检查。索引 `/home/<user>/omic-sol61/recheck/scvi-integrate/visual_inventory.json`，图见 `visual_*.jpg`。检查图非空、标签/轴、裁切、展示内容；caption/spec 与实际 n/参数一起核对。suite builders/theme/finalizer 保留。

96×160 synthetic_iid、两 epochs 足以验证接口/序列化/原生训练一致性，不验证真实队列收敛、batch removal 或分类准确率。图非空且可读；默认与 tutorial structure 均保留原始 labels。初次 wrong-venv launch 已纠正，最终 seal mismatch 独立存在。

日志、命令、exit：`/home/<user>/omic-sol61/recheck/scvi-integrate/{smoke,lock}.{log,command.json,status.json}`；编号源代码 `source_numbered.txt`，独立基线比较 `golden_test_diff.txt`。未闭合修复清单：

1. `skills/scvi-integrate/module_lock.json:46` 的 `skills/_shared/scripts/fig_mod_sc_backend.R` 存储 hash 是 `24939587e244d791ba37c794f0037820bbfd2d2adfa26028ac1cba692c0685ec`，最终 merged source 的实际 hash 是 `fae00f116899bcd982c9b763396a1bdd7e3e63d568e381ba32fd7def0ee870ce`。PACK F/D 的锁定环境与 provenance/复现要求、原 S3 封锁修复仍不满足。先在最终合并树验证 numerical smoke/golden 和 R figure render，再运行本模块锁生成工具（不手写 hash），然后在正确 `OMICSTAT_PY_IMAGE_ID=sha256:dedf331e03f3832cbd069bd3c75af3ac1a6f4f1daf88eea6f72204a3b114b96f` 的独立非 root 离线容器执行 `python tools/make_module_lock.py scvi-integrate --check` → OK。不得为 seal 漂移修改 numerical golden 或放宽断言/容差。lock_diagnosis.json 完整比较只有这一项，environment/packages/image/其他文件均相同。

VERDICT: FAIL
