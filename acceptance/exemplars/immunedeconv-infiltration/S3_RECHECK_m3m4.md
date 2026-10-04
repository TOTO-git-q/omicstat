# immunedeconv-infiltration 独立复验

审查实现 commit：`bb60144f325085c4b400e408887a1be7fe4eabd9`，分支 `s3/recheck`。只写审查输出；未修改源代码、golden 或 lock，不执行提交/推送，外部 helper 使用 lane worklog 提交。

## 可重放命令

`python3 /home/<user>/omic-sol61/recheck/run.py immunedeconv-infiltration`。运行器和完整逐命令 argv 存于 lane scratch；固定 `docker run --rm --network none --user 1000:1000`，镜像 `omicstat-r:2026.10.1`，源码与 acceptance library 只读，scratch 可写，`OMICSTAT_TEST_TMP=/scratch`。未设置 WRITE_GOLDEN。R image ID 为 `sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7`；Python `OMICSTAT_PY_IMAGE_ID=sha256:dedf331e03f3832cbd069bd3c75af3ac1a6f4f1daf88eea6f72204a3b114b96f`；线程与种子固定。

容器内：

```text
Rscript skills/immunedeconv-infiltration/tests/run_smoke_test.R
Rscript tools/make_module_lock.R immunedeconv-infiltration --check
```

两个 exit 均为 0，smoke 的 golden PASS（非 SKIP）；lock 输出：`module_lock immunedeconv-infiltration 1.1.0: OK (9 files)`。

## 原封闭修复清单逐项

1. **PASS**：`scripts/run_immunedeconv_infiltration.R:15-16` 的 named method-args JSON 和独立 cibersort-abs-method；`scripts/immunedeconv_infiltration_core.R:51-62` 解析、保留 dedicated 参数、将 actual abs_method 与其他 native 参数通过 deconvolute 转发；`:63` 保存 resolved arguments；entry `:44/:48` Methods/provenance 填实际值。
   smoke `:60-85` 合法自编 synthetic interface/source + fake signature（不含受限内容）分别用 sig.score/no.sumto1、perm=7，与直接 immunedeconv native wrapper 相同；实际 Methods/provenance 检查通过，独立 abs-method flag 与 locked sig.score default 通过。输出 `PASS: native interface forwarding sig.score/no.sumto1`、`PASS: actual method provenance`、`PASS: actual method Methods`、`PASS: dedicated abs-method resolved`。用户源码/矩阵/licence acknowledgement gate 未移除。

## Slim 回归

quanTIseq/MCP-counter/EPIC/xCell/TIMER/ABIS/ConsensusTME/ESTIMATE 八种真实 offline native 方法的 full-table parity、shape/golden 全通过；42 个原 checks 通过，scale/licence/user-file/refusal 与 spec/from-run 保留。结果保持各 native unit，score figure within-row z-score 声明；SKILL/reference guidance/options 保留。

## Golden 与断言

八方法 golden/manifest 与原 S3 baseline 无变更；旧 native 1e-14/1e-12 等容差及形状、licence asserts 保留。新增 interface 有 sample variation，未声称 licensed algorithm 成功。

## 图与限制

本次全部 13 PNG、9 个不同字节内容均已通过逐图索引 contact sheets 打开；字节相同的重复图共享检查。索引 `/home/<user>/omic-sol61/recheck/immunedeconv-infiltration/visual_inventory.json`，图见 `visual_*.jpg`。检查图非空、标签/轴、裁切、展示内容；caption/spec 与实际 n/参数一起核对。suite builders/theme/finalizer 保留。

PASS 的 CIBERSORT 部分仅是用户可提供源码的参数接口；真实 licensed CIBERSORT 生物学验证仍需合法用户文件。三张 synthetic interface 图可读且有 sample 变化。

日志、命令、exit：`/home/<user>/omic-sol61/recheck/immunedeconv-infiltration/{smoke,lock}.{log,command.json,status.json}`；编号源代码 `source_numbered.txt`，独立基线比较 `golden_test_diff.txt`。原 S3 修复项均已关闭；未闭合修复清单：无。

独立静态回归：`Rscript tools/check_calls.R skills/immunedeconv-infiltration`（含 locked default drift）、`python3 tools/check_defaults.py skills/immunedeconv-infiltration`、`python3 tools/check_flag_docs.py skills/immunedeconv-infiltration`、`python3 tools/lint_r.py skills/immunedeconv-infiltration/scripts`，固定 R 镜像内全部 exit 0，registry/default/docs/lint 无问题；完整 argv/output 在本模块 static.command.json/static.log。

VERDICT: PASS WITH NOTES
