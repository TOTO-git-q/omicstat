# scanpy-cluster 独立复验

审查实现 commit：`bb60144f325085c4b400e408887a1be7fe4eabd9`，分支 `s3/recheck`。只写审查输出；未修改源代码、golden 或 lock，不执行提交/推送，外部 helper 使用 lane worklog 提交。

## 可重放命令

`python3 /home/<user>/omic-sol61/recheck/run.py scanpy-cluster`。运行器和完整逐命令 argv 存于 lane scratch；固定 `docker run --rm --network none --user 1000:1000`，镜像 `omicstat-py:2026.09.1`，源码与 acceptance library 只读，scratch 可写，`OMICSTAT_TEST_TMP=/scratch`。未设置 WRITE_GOLDEN。R image ID 为 `sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7`；Python `OMICSTAT_PY_IMAGE_ID=sha256:dedf331e03f3832cbd069bd3c75af3ac1a6f4f1daf88eea6f72204a3b114b96f`；线程与种子固定。

容器内：

```text
python skills/scanpy-cluster/tests/run_smoke_test.py
python tools/make_module_lock.py scanpy-cluster --check
```

smoke exit 0，golden PASS（非 SKIP）；lock exit 1，输出：`Traceback (most recent call last):
  File "/omicstat/tools/make_module_lock.py", line 90, in <module>
    main()
  File "/omicstat/tools/make_module_lock.py", line 82, in main
    raise RuntimeError('OS_LOCK_MISMATCH: module sources, baseline or environment changed')
RuntimeError: OS_LOCK_MISMATCH: module sources, baseline or environment changed`。

## 原封闭修复清单逐项

1. **PASS**：`scripts/run_scanpy_cluster.py:51` scale default=off，core `:39-40` 只在 on 时调用 native scale。smoke 的独立 native replay (`skills/_shared/py/tests/sc_smoke_support.py:168-190`、`s4_option_replay.py:35-62/:157-170`) 默认 off、显式 on 和 alternative 都比较 PCA/HVG/graph/labels/UMAP；scaled caption 明确 scale=on，default=off。补充独立 `R` 渲染及检查 spec 通过。
2. **PASS**：closed list 逐函数 native bindings：normalize exclude_highly_expressed/max_fraction → core `:29-30`；log1p base → `:31`；HVG flavor/span/n_bins → `:33-36`；scale zero_center → `:40`；PCA solver/zero_center/dtype → `:41-44`；neighbors method/metric/metric_kwds/transformer → `:49-51`；Leiden n_iterations/use_weights/partition_type → `:52-54`；UMAP spread/maxiter/alpha/gamma/negative_sample_rate/init_pos/a/b → `:57-59`。所有值通过 N.resolve，`:67` returned native_options，shared sc_module.py `:292` 写 Methods JSON/provenance。alternatives 使用 cell_ranger、minkowski/gauss、Leiden 2 iterations/no weights/partition、UMAP 非默认优化，与直接 native 一致；输出 `PASS: S4 native default/alternative option parity...`。本 lane py_output_audit.py 独立确认 5 实际输出 Methods/results/provenance JSON 值完全相同。
3. **FAIL**：最终 merged tree 的锁仍 OS_LOCK_MISMATCH，只有共享 SingleR figure builder hash 漂移；原 S3 sealing 修复不能关闭。

## Slim 回归

官方 basic clustering 路径由 native normalize→log→HVG→PCA→neighbors→Leiden→UMAP 实现，显式可选 scale；AnnData 原生 graph/reduction/HVG/labels 保留（PCA sign/label canonicalization 是原有 transport 约定）。static calls/default drift/defaults/48 flags、typed errors、真实 QC upstream、spec determinism/native parity/golden 全通过；required dimensions/resolution 与 reference service guidance 保留。6 个有效 render requests 全 exit 0。

## Golden 与断言

独立 old_native_probe.py（`python /scratch/old_native_probe.py`；完整容器 argv old_native_probe.command.json）在相同真实 upstream 用旧 compulsory scale + arpack/Euclidean native 路径复算，旧 golden PCA/UMAP/labels 全在原 1e-6 容差内。旧五簇 counts=226/149/138/73/14，新 unscaled 七簇=156/114/92/81/58/57/42。golden_numeric_audit.json 证实 HVG exact 不变，PCA/variance/UMAP/labels 合理改变；新增 default dispatch None 的签名/default-drift 已核对。test_changes.diff 只将 replay scale 条件化并 PCA solver 改为 locked None，未移除任何数值 assertion，ATOL=RTOL=1e-6 不变。

## 图与限制

本次全部 11 PNG、9 个不同字节内容均已通过逐图索引 contact sheets 打开；字节相同的重复图共享检查。索引 `/home/<user>/omic-sol61/recheck/scanpy-cluster/visual_inventory.json`，图见 `visual_*.jpg`。检查图非空、标签/轴、裁切、展示内容；caption/spec 与实际 n/参数一起核对。suite builders/theme/finalizer 保留。

Python 初次 launch 的 wrong venv PATH 已纠正，初始日志保留；最终 numerical PASS。锁 hash 失败仍独立存在。图均非空、未见明显裁切；scale 两路线各自 caption 对应实际设置。

日志、命令、exit：`/home/<user>/omic-sol61/recheck/scanpy-cluster/{smoke,lock}.{log,command.json,status.json}`；编号源代码 `source_numbered.txt`，独立基线比较 `golden_test_diff.txt`。未闭合修复清单：

1. `skills/scanpy-cluster/module_lock.json:46` 的 `skills/_shared/scripts/fig_mod_sc_backend.R` 存储 hash 是 `24939587e244d791ba37c794f0037820bbfd2d2adfa26028ac1cba692c0685ec`，最终 merged source 的实际 hash 是 `fae00f116899bcd982c9b763396a1bdd7e3e63d568e381ba32fd7def0ee870ce`。PACK F/D 的锁定环境与 provenance/复现要求、原 S3 封锁修复仍不满足。先在最终合并树验证 numerical smoke/golden 和 R figure render，再运行本模块锁生成工具（不手写 hash），然后在正确 `OMICSTAT_PY_IMAGE_ID=sha256:dedf331e03f3832cbd069bd3c75af3ac1a6f4f1daf88eea6f72204a3b114b96f` 的独立非 root 离线容器执行 `python tools/make_module_lock.py scanpy-cluster --check` → OK。不得为 seal 漂移修改 numerical golden 或放宽断言/容差。lock_diagnosis.json 完整比较只有这一项，environment/packages/image/其他文件均相同。

VERDICT: FAIL
