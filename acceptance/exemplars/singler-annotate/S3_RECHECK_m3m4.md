# singler-annotate 独立复验

审查实现 commit：`bb60144f325085c4b400e408887a1be7fe4eabd9`，分支 `s3/recheck`。只写审查输出；未修改源代码、golden 或 lock，不执行提交/推送，外部 helper 使用 lane worklog 提交。

## 可重放命令

`python3 /home/<user>/omic-sol61/recheck/run.py singler-annotate`。运行器和完整逐命令 argv 存于 lane scratch；固定 `docker run --rm --network none --user 1000:1000`，镜像 `omicstat-r:2026.10.1`，源码与 acceptance library 只读，scratch 可写，`OMICSTAT_TEST_TMP=/scratch`。未设置 WRITE_GOLDEN。R image ID 为 `sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7`；Python `OMICSTAT_PY_IMAGE_ID=sha256:dedf331e03f3832cbd069bd3c75af3ac1a6f4f1daf88eea6f72204a3b114b96f`；线程与种子固定。

容器内：

```text
Rscript skills/singler-annotate/tests/run_smoke_test.R
Rscript tools/make_module_lock.R singler-annotate --check
```

两个 exit 均为 0，smoke 的 golden PASS（非 SKIP）；lock 输出：`module_lock singler-annotate 1.0.0: OK (16 files)`。

## 原封闭修复清单逐项

1. **PASS**：`scripts/singler_annotate_core.R:32` 返回 actual opts_singler/opts_prune；report `:5-6` 用 resolved min.diff.med/min.diff.next 绘图，`:13-15` 实际参数填 Methods/results；entry `:54` 保存 resolved_native。共享 `skills/_shared/scripts/fig_mod_sc_backend.R:3/:16` builder 参数和 caption/spec 绑定实际值。smoke `:103-120` CLI convenience de-method=classic 被 native override wilcox、quantile=.5、nmads=2、min.diff.med=.01、min.diff.next=.05 覆盖；独立 SingleR/pruneScores labels 与 pruned labels identical，同时检查 Methods、两个 caption、provenance。输出 `PASS: pancreas overrides native labels/pruning, actual Methods/results/captions/provenance`。

## Slim 回归

官方 pancreas 1718 cells、59 pruned；打印十类 label counts 与 native replay 通过；synthetic classic/--spec deterministic、from-run/typed refusals 通过；原生 prediction SCE/score 表保留。SKILL/options 仍说明 required reference/scientific choice 与 reference service，Methods/图注不再用被覆盖的 convenience 值。

## Golden 与断言

golden/manifest 与原 S3 baseline 完全不变；旧 printed label/pruned checks、golden 和 determinism 严格断言保留，新增实际 override 检查。

## 图与限制

本次全部 12 PNG、7 个不同字节内容均已通过逐图索引 contact sheets 打开；字节相同的重复图共享检查。索引 `/home/<user>/omic-sol61/recheck/singler-annotate/visual_inventory.json`，图见 `visual_*.jpg`。检查图非空、标签/轴、裁切、展示内容；caption/spec 与实际 n/参数一起核对。suite builders/theme/finalizer 保留。

未发现影响本次封闭修复验收的问题。

日志、命令、exit：`/home/<user>/omic-sol61/recheck/singler-annotate/{smoke,lock}.{log,command.json,status.json}`；编号源代码 `source_numbered.txt`，独立基线比较 `golden_test_diff.txt`。原 S3 修复项均已关闭；未闭合修复清单：无。

独立静态回归：`Rscript tools/check_calls.R skills/singler-annotate`（含 locked default drift）、`python3 tools/check_defaults.py skills/singler-annotate`、`python3 tools/check_flag_docs.py skills/singler-annotate`、`python3 tools/lint_r.py skills/singler-annotate/scripts`，固定 R 镜像内全部 exit 0，registry/default/docs/lint 无问题；完整 argv/output 在本模块 static.command.json/static.log。

VERDICT: PASS
