# sva-batch 独立 S3 验收

Pinned: `build/m1m2@2ddf174fb36cbaa3c280af00b52b92fe7f039d04`。恢复旧 WIP 后按任务更新重新 pin 最终 HEAD；旧 WIP 无裁决。

- [x] PACK C / L1：核读 sva.rendered.txt:138–145 的 leek=2，:203–226 的 SV 入模型打印表，:299 起模拟计数。A3=2、A4=1 实测通过；A4 的源 1 是手设 n.sv，不能证明自动估计正确。A5 用源模拟与带 group 调用独立回放，矩阵一致。A1 明示改用保护 cancer 的设计，并非指南 intercept-only 原调用；A2 只检查 n.sv=9 与控制台，未验证 SV 矩阵/入模型链。见 F1。
- [x] PACK T：corrected_matrix、sv_table、batch_report 均产生，批次交叉表和展示用途清楚；参数和模型公式未完整输出，见 F3。此模块无 DE feature_table 是合理的。
- [x] PACK W：读取实际 a1/a2/a3/a4/a5 草稿及 JSON；样本/特征/SV 数一致，未对校正矩阵作 DE 声称；方法参数不全，见 F3。
- [x] Mechanical/S1：逐项核 core:195–226 与 registry，ComBat/ComBat_seq/num.sv/sva/svaseq 的冻结参数显式；静态 registry、default drift、defaults、flag docs、lint 全 PASS；类型错误、spec 表/JSON/PNG 字节回放、from-run、Wald 拒绝校正矩阵、golden PASS、无 Rplots.pdf。联合设计探针失败见 F2。
- [x] Figures：亲眼打开 A1–A5 全部五张 batch_pca.png，文字/图例未裁切，图注含样本数、特征数和 display-only。无推断阈值适用于这些描述图。ComBat prior diagnostic 缺失见 F4。

运行证据：`/home/<user>/omic-s3-runs/run_locked.sh sva-batch review-final Rscript skills/sva-batch/tests/run_smoke_test.R`；`_s3/review-final.log` 为 SMOKE PASSED / EXIT 0，golden 是 PASS 非 SKIP。证据目录 `/home/<user>/omic-s3-runs/sva-batch/`；`_s3/design_probe.R`、`design-probe.log`、`covariate-probe.log` 为独立探针。

## 闭口返修清单

1. **F1 — PACK C / S1 P-4**：`skills/sva-batch/tests/run_smoke_test.R:89`（A2）只断言 SV 数，未验“SV 入模型”链；源 `L1_bioc3.23/sva/vignettes/sva.rendered.txt:203` 有 usable printed topTableF 数值（例如 207783_x_at 的 C1=-13.45607、P=1.207560e-69），未断言。补独立指南原流程的 printed anchor 与 SV 入 full/null 的回放（保留源设计，与套件预设测试分开）；比对 SV/下游结果，版本差异须逐值解释。保护设计的 ComBat replay 可以保留，但不能替代指南原代码回放。
2. **F2 — PACK S1 P-2**：`scripts/sva_batch_core.R:152` 只检查 batch + study，不含 covariates；:165 的 partial 也没有目标 contrast 可估性检查。CLI 用现有 syn_samples 的 cov1（等于 batch）和 `--method combat --batch batch --study-var grp --covariates cov1`，先认为 confounding=ok，再以包原始错误退出（无 OS_*）。在调用前验证含所有保护变量的联合设计，非可估情形类型化拒绝；partial 不得未经验证写“contrast remains estimable”（report:134）。补对应端到端断言。
3. **F3 — PACK T/W / S1 P-2/P-3**：`scripts/sva_batch_report.R:77,109,133` 与 `references/reporting-templates.md` 未输出实际 full/null 公式和 ComBat par.prior/mean.only/ref.batch、ComBat_seq shrink/full_mod、num.sv B/seed/vfilter、sva 迭代与 display removeBatchEffect 参数。按实际路径填入 batch report、JSON 与 Methods，保留版本与用途说明；不能只在源代码/registry 留存。
4. **F4 — PACK F**：`scripts/sva_batch_core.R:197` 固定关闭 prior.plots，且无统一图层的 prior-density diagnostic。S3_REQUEST 的“deferred”属明确披露但不等于满足 PACK。提供合约内的等价诊断及图注，或先取得明确的 PACK 范围修订；补图形检查且无 Rplots.pdf。

所有者项：ComBat_seq 连续研究变量当前 OS_UNSUPPORTED_DESIGN，安全且记录，不因待定本身判失败。SV 的 removeBatchEffect 仅用于展示、保护 mod，没有下游推断声称；其交叉引用解释保留供所有者确认。

NEXT STEP: S4 按闭口清单修复；本审查未修改引擎。
VERDICT: FAIL
