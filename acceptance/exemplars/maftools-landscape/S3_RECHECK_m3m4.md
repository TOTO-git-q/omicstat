# maftools-landscape 独立复验

审查实现 commit：`bb60144f325085c4b400e408887a1be7fe4eabd9`，分支 `s3/recheck`。只写审查输出；未修改源代码、golden 或 lock，不执行提交/推送，外部 helper 使用 lane worklog 提交。

## 可重放命令

`python3 /home/<user>/omic-sol61/recheck/run.py maftools-landscape`。运行器和完整逐命令 argv 存于 lane scratch；固定 `docker run --rm --network none --user 1000:1000`，镜像 `omicstat-r:2026.10.1`，源码与 acceptance library 只读，scratch 可写，`OMICSTAT_TEST_TMP=/scratch`。未设置 WRITE_GOLDEN。R image ID 为 `sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7`；Python `OMICSTAT_PY_IMAGE_ID=sha256:dedf331e03f3832cbd069bd3c75af3ac1a6f4f1daf88eea6f72204a3b114b96f`；线程与种子固定。

容器内：

```text
Rscript skills/maftools-landscape/tests/run_smoke_test.R
Rscript tools/make_module_lock.R maftools-landscape --check
```

两个 exit 均为 0，smoke 的 golden PASS（非 SKIP）；lock 输出：`module_lock maftools-landscape 1.0.0: OK (9 files)`。

## 原封闭修复清单逐项

1. **PASS**：`scripts/run_maftools_landscape.R:27-38` 的 capture-regions/source 与 capture-size 二选一 required；`scripts/maftools_landscape_core.R:12` 直接传 maftools::tmb(captureRegions=...)，原生包用区域计算 callable size；`:26` 保存 source/path/hash/实际 Mb；entry `:62/:66` Methods/provenance 记录实际 territory。
   smoke `:36-52` 用本地 chr1 region 子集，经相同 CSV roundtrip 对照直接 maftools::tmb，表 identical；区域 TMB 改变、全 variants 保留、source/hash Methods/provenance 检查 PASS。日志 `PASS: native captureRegions TMB parity`、`PASS: region subset changes native TMB`、`PASS: region source/hash provenance`、`PASS: region hash Methods`；conflicting/missing territory 明确拒绝。

## Slim 回归

官方 TCGA-LAML MAF 路径、193 samples/192 TMB rows（native 排除零 non-silent sample）与原生 variants/summary/interactions 保留；real MAF producer→consumer/spec replay 通过。SKILL/options 的 offline region source/locked defaults/reference service 保留，TMB caption 用实际 territory/hash。

## Golden 与断言

golden/manifest 与原 S3 baseline 无变更；旧官方 shape/golden 断言未弱化，新增 native CSV identical 和 territory refusals。

## 图与限制

本次全部 16 PNG、5 个不同字节内容均已通过逐图索引 contact sheets 打开；字节相同的重复图共享检查。索引 `/home/<user>/omic-sol61/recheck/maftools-landscape/visual_inventory.json`，图见 `visual_*.jpg`。检查图非空、标签/轴、裁切、展示内容；caption/spec 与实际 n/参数一起核对。suite builders/theme/finalizer 保留。

原生 maftools oncoplot 属批准的 suite 字体/配色例外；其余图用 suite builders。区域接口只验证本地 diagnostic territory，不作为真实 capture kit 定义。

日志、命令、exit：`/home/<user>/omic-sol61/recheck/maftools-landscape/{smoke,lock}.{log,command.json,status.json}`；编号源代码 `source_numbered.txt`，独立基线比较 `golden_test_diff.txt`。原 S3 修复项均已关闭；未闭合修复清单：无。

独立静态回归：`Rscript tools/check_calls.R skills/maftools-landscape`（含 locked default drift）、`python3 tools/check_defaults.py skills/maftools-landscape`、`python3 tools/check_flag_docs.py skills/maftools-landscape`、`python3 tools/lint_r.py skills/maftools-landscape/scripts`，固定 R 镜像内全部 exit 0，registry/default/docs/lint 无问题；完整 argv/output 在本模块 static.command.json/static.log。

VERDICT: PASS
