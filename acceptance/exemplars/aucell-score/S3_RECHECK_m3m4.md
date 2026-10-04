# aucell-score 独立复验

审查实现 commit：`bb60144f325085c4b400e408887a1be7fe4eabd9`，分支 `s3/recheck`。只写审查输出；未修改源代码、golden 或 lock，不执行提交/推送，外部 helper 使用 lane worklog 提交。

## 可重放命令

`python3 /home/<user>/omic-sol61/recheck/run.py aucell-score`。运行器和完整逐命令 argv 存于 lane scratch；固定 `docker run --rm --network none --user 1000:1000`，镜像 `omicstat-r:2026.10.1`，源码与 acceptance library 只读，scratch 可写，`OMICSTAT_TEST_TMP=/scratch`。未设置 WRITE_GOLDEN。R image ID 为 `sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7`；Python `OMICSTAT_PY_IMAGE_ID=sha256:dedf331e03f3832cbd069bd3c75af3ac1a6f4f1daf88eea6f72204a3b114b96f`；线程与种子固定。

容器内：

```text
Rscript skills/aucell-score/tests/run_smoke_test.R
Rscript tools/make_module_lock.R aucell-score --check
```

两个 exit 均为 0，smoke 的 golden PASS（非 SKIP）；lock 输出：`module_lock aucell-score 1.0.0: OK (9 files)`。

## 原封闭修复清单逐项

1. **PASS**：`scripts/run_aucell_score.R:14` 要求离线 sets-file/source/licence/ack；`scripts/aucell_score_core.R:4-9` 去掉单一 SHA 约束，保留禁止集合/permission gate，并读取用户 GMT；`:11-13` 原生 buildRankings/calcAUC，`:21` state 保存 source/licence/path/hash，entry `:47` provenance 保存 gene_sets。smoke `:40-53` 用 user_A/user_B 两自定义集合，CLI 成功且与直接 native AUC identical；Methods source 检查通过；直接查看 custom/provenance/provenance.json，source=user-derived brain subsets、licence=user permission、SHA256 与 custom.gmt 相符。输出 `PASS permitted custom GMT CLI`、`PASS two custom sets native AUC parity`、`PASS custom source Methods`、`PASS required licence acknowledgement`。

## Slim 回归

官方 brain anchor 120 cells 原生 ranking/AUC/对象/表通过；SKILL 明确 per-cell→AUCell、bulk/pseudobulk→GSVA，非唯一 standard；sets choice/reference_advise/reference_search 和 required declaration 保留。默认值及 Methods 与实际 AUC 一致。

## Golden 与断言

与原 S3 baseline golden/manifest 无变更；原始 native identical 和 golden assert 保留，新增 permitted custom GMT 与 permission refusal。

## 图与限制

本次全部 4 PNG、4 个不同字节内容均已通过逐图索引 contact sheets 打开；字节相同的重复图共享检查。索引 `/home/<user>/omic-sol61/recheck/aucell-score/visual_inventory.json`，图见 `visual_*.jpg`。检查图非空、标签/轴、裁切、展示内容；caption/spec 与实际 n/参数一起核对。suite builders/theme/finalizer 保留。

未发现影响本次封闭修复验收的问题。

日志、命令、exit：`/home/<user>/omic-sol61/recheck/aucell-score/{smoke,lock}.{log,command.json,status.json}`；编号源代码 `source_numbered.txt`，独立基线比较 `golden_test_diff.txt`。原 S3 修复项均已关闭；未闭合修复清单：无。

独立静态回归：`Rscript tools/check_calls.R skills/aucell-score`（含 locked default drift）、`python3 tools/check_defaults.py skills/aucell-score`、`python3 tools/check_flag_docs.py skills/aucell-score`、`python3 tools/lint_r.py skills/aucell-score/scripts`，固定 R 镜像内全部 exit 0，registry/default/docs/lint 无问题；完整 argv/output 在本模块 static.command.json/static.log。

VERDICT: PASS
