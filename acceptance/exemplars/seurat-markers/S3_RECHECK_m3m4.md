# seurat-markers 独立复验

审查实现 commit：`bb60144f325085c4b400e408887a1be7fe4eabd9`，分支 `s3/recheck`。只写审查输出；未修改源代码、golden 或 lock，不执行提交/推送，外部 helper 使用 lane worklog 提交。

## 可重放命令

`python3 /home/<user>/omic-sol61/recheck/run.py seurat-markers`。运行器和完整逐命令 argv 存于 lane scratch；固定 `docker run --rm --network none --user 1000:1000`，镜像 `omicstat-r:2026.10.1`，源码与 acceptance library 只读，scratch 可写，`OMICSTAT_TEST_TMP=/scratch`。未设置 WRITE_GOLDEN。R image ID 为 `sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7`；Python `OMICSTAT_PY_IMAGE_ID=sha256:dedf331e03f3832cbd069bd3c75af3ac1a6f4f1daf88eea6f72204a3b114b96f`；线程与种子固定。

容器内：

```text
Rscript skills/seurat-markers/tests/run_smoke_test.R
Rscript tools/make_module_lock.R seurat-markers --check
```

两个 exit 均为 0，smoke 的 golden PASS（非 SKIP）；lock 输出：`module_lock seurat-markers 1.0.0: OK (15 files)`。

## 原封闭修复清单逐项

1. **PASS**：`scripts/seurat_markers_core.R:14` contrast 原生 FindMarkers 绑定 base；locked 2 保留。smoke `:40-47` 对精确 exp(1) 与 native avg_logFC 比较，保留 base-dependent 列名。
2. **PASS**：core `:1-5` 解析 package::function，`:12` / `:14` 两路线传 mean.fxn；NULL 默认保留。smoke `:48-55` 对 Matrix::rowMeans 原生两路线比较通过。
3. 本次补充独立 CLI：`python3 /home/<user>/omic-sol61/recheck/probe_markers.py`（`Rscript /scratch/cli_probe.R`），all/contrast 都给 --markers-base 2.7182818284590451、--markers-mean-fxn Matrix::rowMeans；effect 列与直接 FindAllMarkers/FindMarkers all.equal，Methods 及 provenance command/chain_state 记录实际绑定。输出两行 `PASS independent CLI/native/Methods/provenance all/contrast`；完整 argv 与日志在 cli_probe.command.json/cli_probe.log。core `:21-24` 的 native_controls/details 被保存。coordinator 要求的 test/prefilter/presto/Bonferroni 文字也通过 smoke `:59`。

## Slim 回归

原生 FindAllMarkers/FindMarkers 和 Seurat RDS/表保留；默认 11648 rows、7023 above log2FC1；真实 QC→cluster→markers 链 PASS。SKILL/options 的 locked defaults、reference service guidance 保留；Methods 显著计数明确 p_val_adj Bonferroni，未误称 FDR。

## Golden 与断言

golden_audit.json 确认 golden/manifest 无变更；基线旧 native/anchor/数值断言保留，新比较未弱化。

## 图与限制

本次全部 14 PNG、12 个不同字节内容均已通过逐图索引 contact sheets 打开；字节相同的重复图共享检查。索引 `/home/<user>/omic-sol61/recheck/seurat-markers/visual_inventory.json`，图见 `visual_*.jpg`。检查图非空、标签/轴、裁切、展示内容；caption/spec 与实际 n/参数一起核对。suite builders/theme/finalizer 保留。

已知 7023 vs 旧打印 7019 差异按 owner 接受。补充探针初次要求 JSON numeric 与 exp(1) 二进制精确相同，因公共 provenance digits=10 序列化而失败；保留 cli_probe.initial.log，改检查 provenance command 中完整精确 CLI 字符串及实际 native effect。没有改变实现或生产测试容差。

日志、命令、exit：`/home/<user>/omic-sol61/recheck/seurat-markers/{smoke,lock}.{log,command.json,status.json}`；编号源代码 `source_numbered.txt`，独立基线比较 `golden_test_diff.txt`。原 S3 修复项均已关闭；未闭合修复清单：无。

独立静态回归：`Rscript tools/check_calls.R skills/seurat-markers`（含 locked default drift）、`python3 tools/check_defaults.py skills/seurat-markers`、`python3 tools/check_flag_docs.py skills/seurat-markers`、`python3 tools/lint_r.py skills/seurat-markers/scripts`，固定 R 镜像内全部 exit 0，registry/default/docs/lint 无问题；完整 argv/output 在本模块 static.command.json/static.log。

VERDICT: PASS WITH NOTES
