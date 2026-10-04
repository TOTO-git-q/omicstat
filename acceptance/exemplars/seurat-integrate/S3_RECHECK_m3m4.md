# seurat-integrate 独立复验

审查实现 commit：`bb60144f325085c4b400e408887a1be7fe4eabd9`，分支 `s3/recheck`。只写审查输出；未修改源代码、golden 或 lock，不执行提交/推送，外部 helper 使用 lane worklog 提交。

## 可重放命令

`python3 /home/<user>/omic-sol61/recheck/run.py seurat-integrate`。运行器和完整逐命令 argv 存于 lane scratch；固定 `docker run --rm --network none --user 1000:1000`，镜像 `omicstat-r:2026.10.1`，源码与 acceptance library 只读，scratch 可写，`OMICSTAT_TEST_TMP=/scratch`。未设置 WRITE_GOLDEN。R image ID 为 `sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7`；Python `OMICSTAT_PY_IMAGE_ID=sha256:dedf331e03f3832cbd069bd3c75af3ac1a6f4f1daf88eea6f72204a3b114b96f`；线程与种子固定。

容器内：

```text
Rscript skills/seurat-integrate/tests/run_smoke_test.R
Rscript tools/make_module_lock.R seurat-integrate --check
```

两个 exit 均为 0，smoke 的 golden PASS（非 SKIP）；lock 输出：`module_lock seurat-integrate 1.0.0: OK (15 files)`。

## 原封闭修复清单逐项

1. **PASS**：`scripts/run_seurat_integrate.R:8` 的 --harmony-project-dim（locked TRUE）进入 `scripts/seurat_integrate_core.R:9` 的原生 RunHarmony project.dim；`:20` 保存 resolved chain state，`:25` 用于 Methods。`tests/run_smoke_test.R:21-30` 实际执行 TRUE/FALSE 两次 CLI，并与各自直接 RunHarmony loadings 比较。输出 `PASS project.dim TRUE native loadings`、`PASS project.dim FALSE native loadings`、`PASS project.dim changes loading output`、`PASS resolved project.dim Methods`。另直接读取 integrate_no_projection/provenance/provenance.json，chain_state.project.dim 为 false。

## Slim 回归

官方 pbmc_stim 原生 Harmony 路径和 HarmonyIntegration layer 路径通过，2000 cells；raw RNA 保留；real QC→cluster→integrate handoff PASS。SKILL 和 options 保留 reference service/scientific choices/defaults；原生对象及表保留，Methods 用实际 project.dim。

## Golden 与断言

与原 S3 baseline 比较 golden/manifest 无变更；原 smoke 的严格 native embeddings/golden 断言保留，新增 loading/Methods 比较未弱化容差。

## 图与限制

本次全部 18 PNG、13 个不同字节内容均已通过逐图索引 contact sheets 打开；字节相同的重复图共享检查。索引 `/home/<user>/omic-sol61/recheck/seurat-integrate/visual_inventory.json`，图见 `visual_*.jpg`。检查图非空、标签/轴、裁切、展示内容；caption/spec 与实际 n/参数一起核对。suite builders/theme/finalizer 保留。

图均可读。stim QC 的 percent.mt 为 0 是原 anchor/diagnostic carrier 的现状，图正确显示零值，不作为生物线粒体结论。

日志、命令、exit：`/home/<user>/omic-sol61/recheck/seurat-integrate/{smoke,lock}.{log,command.json,status.json}`；编号源代码 `source_numbered.txt`，独立基线比较 `golden_test_diff.txt`。原 S3 修复项均已关闭；未闭合修复清单：无。

独立静态回归：`Rscript tools/check_calls.R skills/seurat-integrate`（含 locked default drift）、`python3 tools/check_defaults.py skills/seurat-integrate`、`python3 tools/check_flag_docs.py skills/seurat-integrate`、`python3 tools/lint_r.py skills/seurat-integrate/scripts`，固定 R 镜像内全部 exit 0，registry/default/docs/lint 无问题；完整 argv/output 在本模块 static.command.json/static.log。

VERDICT: PASS
