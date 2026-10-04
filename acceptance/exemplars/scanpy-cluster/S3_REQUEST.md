# scanpy-cluster — S3_REQUEST (awaiting independent review)

## 核验范围
核对完整表/JSON/Methods/Results/图注一致、固定版本 API、必填科学选择、QC 阻断、StudyContract/生态/哈希/批次来源拒绝、`--spec` 重放、数值容差与封存。

## 已执行锚点与输出
- 运行输出：`/home/<user>/omic-sol61/verify_gptpro/python-smoke/scanpy-cluster_vff_vfsp/anchor`。
- 锁定数值 smoke：两个 generate_golden.sh 完整执行；每次含写 golden 与第二次比对；原有 atol/rtol=1e-6、ARI=1、marker 更严容差保留。
- 当前观察值：600 cells × 13769 genes；1 biological sample(s)。
- fixture 来源记录（实测）：`{"anchor": "F1", "fixture_rule": "first 600 cells in supplied order; all genes", "kind": "official tutorial input, replay anchor", "n_cells": 600, "n_genes": 32738, "source_sha256": "847d6ebd9a1ec9a768f2be7e40ca42cbfe75ebeb6d76a4c24167041699dc28b5"}`。
- 数值日志：`/home/<user>/omic-sol61/verify_gptpro/scanpy-cluster-final-pass1.log`、`/home/<user>/omic-sol61/verify_gptpro/scanpy-cluster-final-pass2.log`。
- 结果、完整表、交接、图请求：输出下 `results/`、`tables/`、`objects/`、`figure_data/`；R 渲染 PNG/PDF/spec 在 `figures/`。
- 不抄录教程打印值作为 golden；PBMC3k 为官方旧教程输入、前 600 cells 回放，SCVI/SCANVI 使用 locked synthetic_iid，属于独立同包计算/保存模型重载回放。

## L1 / 参数政策核对
- 对照只读 `/home/<user>/omic-s0-c/acceptance/exemplars/scanpy-cluster/L1_pypi2026-09-15/defaults.tsv`、`resolved_defaults.tsv`（若有）与 installed inspect.signature。
- 逐参数证据：`/home/<user>/omic-sol61/verify_gptpro/defaults-evidence-comparison.tsv`；没有用旧 PACK 的 alpha 默认、V 多数派或未重抽频数来选值。
- 科学判断未设经验默认：QC thresholds、HVG/PC/neighbors/resolution、训练 epochs、reference labels、display confidence 由用户显式给定。
- 本次固定参数：
- `annotation`: `anchor-provided-identifiers`
- `cluster-col`: `cluster`
- `counts-layer`: `counts`
- `hvg-batch-col`: `None`
- `journal`: `nature`
- `min-dist`: `0.5`
- `n-hvg`: `600`
- `n-neighbors`: `10`
- `n-pcs`: `10`
- `resolution`: `0.5`
- `sample-col`: `sample`
- `scale-max`: `None`
- `seed`: `20260925`
- `species`: `human`
- `target-sum`: `None`
- `upstream-object`: `None`

## 图与限制
全部本模块 acceptance anchor 图由 R renderer 生成并逐张打开；具体文件、caption、lint、SHA 在该目录 figure_spec.json 与 lane report。
数据子集和两轮训练只验证运行/重放，不证明生物学充分训练、整合有效性或注释准确率。跨平台 ARI/潜空间与完整 PACK C BMMC / purified PBMC 训练流程仍需独立 S3 扩展；本次另核原始文件完整性和教程读入路径。

## 待裁决
用户需预先确定该模块所要求的科学参数；Python→R 后端生态标记、完整教程大规模复现、训练充分性及跨平台确定性未自行裁决。scanvi 的软概率不是校准准确率；条件比较需 pseudobulk。

## 提议路由行（不写注册表）
| scanpy-cluster 的明确分析问题及 scverse 输入 | `scanpy-cluster` | `scripts/run_scanpy_cluster.py` |

## 提议 publication 记录（不写注册表）
沿用现有 `skills/_shared/publication/module_rules_v1.json` 中本模块记录；保留 PUB-LOCK-001，并要求 figure_render、完整参数/数据来源和上述限制可见。未实施 S3 接受或 S5 安装。
