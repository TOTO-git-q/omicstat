# wgcna-network 独立复验

审查实现 commit：`bb60144f325085c4b400e408887a1be7fe4eabd9`，分支 `s3/recheck`。只写审查输出；未修改源代码、golden 或 lock，不执行提交/推送，外部 helper 使用 lane worklog 提交。

## 可重放命令

`python3 /home/<user>/omic-sol61/recheck/run.py wgcna-network`。运行器和完整逐命令 argv 存于 lane scratch；固定 `docker run --rm --network none --user 1000:1000`，镜像 `omicstat-r:2026.10.1`，源码与 acceptance library 只读，scratch 可写，`OMICSTAT_TEST_TMP=/scratch`。未设置 WRITE_GOLDEN。R image ID 为 `sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7`；Python `OMICSTAT_PY_IMAGE_ID=sha256:dedf331e03f3832cbd069bd3c75af3ac1a6f4f1daf88eea6f72204a3b114b96f`；线程与种子固定。

容器内：

```text
Rscript skills/wgcna-network/tests/run_smoke_test.R
Rscript tools/make_module_lock.R wgcna-network --check
```

两个 exit 均为 0，smoke 的 golden PASS（非 SKIP）；lock 输出：`module_lock wgcna-network 1.0.0: OK (16 files)`。

## 原封闭修复清单逐项

1. **PASS**：逐函数核对 review 列表：goodSamplesGenes minFraction/minNSamples/minNGenes/tol/minRelativeWeight/weights → `scripts/wgcna_network_core.R:36-45`；pickSoftThreshold RsquaredCut/removeFirst/nBreaks/corFnc/corOptions/weights → `:51-66`；blockwiseModules corType/maxPOutliers/quickCor/pearsonFallback/cosineCorrelation/TOMDenom/replaceMissingAdjacencies/suppressTOMForZeroAdjacencies/suppressNegativeTOM/detectCutHeight/pamStage/minCoreKME/minCoreKMESize/minKMEtoStay/impute → `:67-120`；moduleEigengenes impute/nPC/align/excludeGrey/subHubs/scale → `:121-135`；cor method/use/weights/cosine → `:17-32`。全部为独立 CLI（entry `:9`）经 wg_option/命名函数解析后传 native；core `:155` 把同一 resolved 值返回，report `:33` 写 Supplementary Methods，entry provenance 保存 native_controls。
   smoke `:58-76` 在同一真实 200-probe subset 原生 replay Pearson/bicor + TOMDenom mean 的 colors/MEs，通过 BH/none 及 Pearson/Spearman 的直接 native 比较；`:78-85` 实际 CLI + Methods/caption PASS。本次独立读取 native-alternative 的 draft/native_parameters.md 与 provenance/native_controls 并 JSON 比较，全部函数值一致（例如 corType=bicor、TOMDenom=mean、各 NULL/default、minCoreKMESize=10）。静态 calls/default drift、65/65 docs、defaults/lint 全 exit 0，见 static.log。
2. **PASS**：core `:144` trait-p-adjust 传 stats::p.adjust，`:143` 保留 native p_value；`:155` 记录 family=nrow(assoc)。BH/none 与直接 stats::p.adjust identical；Methods 与 caption actual none 检查 PASS。

## Slim 回归

完整 FemaleLiver 3600 genes/134 samples 原生 anchor；19 printed sizes exact（18 assigned modules、grey99），tutorial module labels/correlation replay 通过；power effectiveness/spec byte determinism/from-run/refusals 通过。原生 network/MEs/完整表保留，required power rationale、reference service/options 映射保留。

## Golden 与断言

全部旧 golden/manifest 与原 S3 baseline 相同，包含主 Methods/figure specs；新增完整 resolved controls 在 draft/native_parameters.md，主 Methods 实际 correlation/adjustment 正确。旧 printed/strict correlation/byte determinism 未弱化。

## 图与限制

本次全部 24 PNG、12 个不同字节内容均已通过逐图索引 contact sheets 打开；字节相同的重复图共享检查。索引 `/home/<user>/omic-sol61/recheck/wgcna-network/visual_inventory.json`，图见 `visual_*.jpg`。检查图非空、标签/轴、裁切、展示内容；caption/spec 与实际 n/参数一起核对。suite builders/theme/finalizer 保留。

3600-leaf tree 信息密集，与原生社区展示一致；小 subset 图可读。200-probe mean-TOM alternative 全 grey，与 native 一致，仅工程验证，不解释为生物模块发现。

日志、命令、exit：`/home/<user>/omic-sol61/recheck/wgcna-network/{smoke,lock}.{log,command.json,status.json}`；编号源代码 `source_numbered.txt`，独立基线比较 `golden_test_diff.txt`。原 S3 修复项均已关闭；未闭合修复清单：无。

独立静态回归：`Rscript tools/check_calls.R skills/wgcna-network`（含 locked default drift）、`python3 tools/check_defaults.py skills/wgcna-network`、`python3 tools/check_flag_docs.py skills/wgcna-network`、`python3 tools/lint_r.py skills/wgcna-network/scripts`，固定 R 镜像内全部 exit 0，registry/default/docs/lint 无问题；完整 argv/output 在本模块 static.command.json/static.log。

VERDICT: PASS WITH NOTES
