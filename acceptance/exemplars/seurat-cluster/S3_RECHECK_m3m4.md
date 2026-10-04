# seurat-cluster 独立复验

审查实现 commit：`bb60144f325085c4b400e408887a1be7fe4eabd9`，`s3/recheck`。未改实现、golden、lock；提交由外部 helper 处理。

## 命令与结果

统一运行器 `/home/<user>/omic-sol61/recheck/run.py` 固定 `docker run --rm --network none --user 1000:1000`，R 镜像 `omicstat-r:2026.10.1` / `sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7`；源码、acceptance library 只读，`OMICSTAT_TEST_TMP=/scratch` 对应本模块 lane scratch；未设置 WRITE_GOLDEN。

- `python3 /home/<user>/omic-sol61/recheck/run.py seurat-cluster`：smoke exit 0；golden PASS；lock exit 0、OK (16 files)。容器内分别为 `Rscript skills/seurat-cluster/tests/run_smoke_test.R` 和 `Rscript tools/make_module_lock.R seurat-cluster --check`。
- `python3 /home/<user>/omic-sol61/recheck/probe_cluster.py`：独立 CLI 探针 exit 0。容器命令 `Rscript /scratch/cli_probe.R`；全部参数见 `cli_probe.R`，完整 docker argv 见 `cli_probe.command.json`。

## 封闭修复清单逐项

1. **PASS**：`scripts/seurat_cluster_core.R:13` 将 initial.membership/node.sizes 传入原生 FindClusters；`:16` 记录 resolved controls，`:21` 进入 Methods；entry provenance 保存 chain_state。独立探针实际 CLI 给 200 个 1 起始 membership/单位 node sizes、algorithm=4；与直接 FindClusters 的 labels identical，Methods/provenance 均含实际绑定。输出 `PASS independent CLI/native/Methods/provenance LogNormalize`。
2. **PASS**：core `:2` 命名函数解析、`:10` 将 mean.function/dispersion.function/reference.SCT.model/residual.features 传入原生函数，`:16` 记录值及 reference hash。独立 CLI 的 mean.var.plot/FastExpMean/FastLogVMR HVG 与直接 native 相同；SCT 参考模型和 100 residual features 的 scale.data 与直接 SCTransform all.equal；reference SHA 和 features 在 Methods/provenance 检查通过。输出 `PASS independent CLI/native/Methods/provenance SCTransform`。锁定 NULL/default 及文档绑定保留；`tests/run_binding_test.R` 的 native 检查也通过。

## Slim 回归与 golden

官方 PBMC Normalize→HVG→Scale→PCA→neighbors→clusters→UMAP 流程仍由原生包执行。实际 2638 cells、9 communities、95927 edges；2000 HVGs；native PCA/labels replay PASS；真实 seurat-qc→cluster 交接通过。原生 Seurat RDS、HVG/cluster/PCA 表保留。SKILL/options 保留 required scientific inputs、reference_advise/reference_search、S0 key 映射。实际默认与两个替代路线 Methods/原生结果一致。

与原 S3 commit 比较，此模块 golden 文件/manifest 无变更；旧数值断言、容差保留。新增检查增加绑定覆盖，没有弱化旧 anchor。

已打开所有 12 PNG（包括本次独立 CLI 两路线新增图），索引 `visual_inventory.json`，`visual_00.jpg`～`visual_02.jpg`。UMAP、elbow、QC violin/scatter 均非空，未见明显裁切；图注/spec 记录 n/阈值，使用 suite figure builders。SCTransform 参考由原生 poisson vst 拟合，仅用于工程验证，不声称新生物学结论。

原始证据：`/home/<user>/omic-sol61/recheck/seurat-cluster/{smoke,lock,cli_probe}.log`、对应 `.command.json` / `.status.json`；编号源码 `source_numbered.txt`。

未闭合修复项：无。

独立静态回归：`Rscript tools/check_calls.R skills/seurat-cluster`（含 locked default drift）、`python3 tools/check_defaults.py skills/seurat-cluster`、`python3 tools/check_flag_docs.py skills/seurat-cluster`、`python3 tools/lint_r.py skills/seurat-cluster/scripts`，固定 R 镜像内全部 exit 0，registry/default/docs/lint 无问题；完整 argv/output 在本模块 static.command.json/static.log。

VERDICT: PASS
