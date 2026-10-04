# limma-camera — S3 独立验收

固定版本：`build/m2-rank@e36b77f44ac7e492adacb371c8c6922e7e23a256`。运行目录 `/home/<user>/omic-s3-runs/limma-camera`；代码行号相对此 checkout。仅审查，未改引擎。

- [x] 阅读 PACK T/W/C/F、S1 P-1–P-3、S3_REQUEST、build_worklog、BUILD_REPORT；核对原指南 §18.1.3–18.1.10。
- [x] 锁定容器 `bash /home/<user>/omic-s3-runs/run_locked.sh limma-camera review-final Rscript skills/limma-camera/tests/run_smoke_test.R`：`_s3/review-final.log` SMOKE PASSED / EXIT0，calls、drift、defaults、flags、lint、golden **PASS**、同 spec 主表和 PNG 字节一致。另 `_s3/lock-check.log` module_lock OK(14 files)，无 Rplots.pdf。
- [x] 锚点：F10/F11 hash校验、原 Targets86行、concentration 为 factor、总计数>50/完整注释过滤、TMM、两轮 voom/dupcor 均与源代码相符。16918 genes/86 samples；Y13 Up、X54 Down。mroast9999 的两项 P=1e-04 与指南相符。camera printed 数值未通过，见 F1。
- [x] T/W：全 primary 和 method_raw 双表，保留自包含的 mixed/prop 字段；有集合来源/version/hash、limma3.68.5、竞争/自包含的区别、BH。camera 的0.01明示 preset并说明与逐集合估计的取舍；mroast seed/RNG/nrot/midp 与不同 P 下限说明准确。实际 draft 漏掉设计、weights/block 和排名方向，见 F2。
- [x] mechanics/S1：单次只按预先给定问题运行一种方法；rank-only→cameraPR，自包含须指定方法，roast须指定单集合；nrot1999 标开发版，9999为发表预设。缺集合、校正矩阵、篡改 handoff、rank-only自包含及 camera 的nrot请求安全拒绝。模拟 expression/rank handoff 跑通，但不证明真实 Wald producer 可供 ranked_list。
- [x] PNG：打开 `_smoke/limma-camera-smoke/{a1,cameraPR,fry,roast,mroast}/figures/gene_set_bar.png` 五个不同图。a1、cameraPR、roast 标签轴/图例可读，无重叠；mroast/fry 图缺横轴标题与方向图例。各 caption 明示2/2（roast1/1）和 BH0.05。PACK 的 barcode/MD 图未实现，见 F3。

## 闭合修复清单

1. **F1 — PACK C，`skills/limma-camera/tests/run_smoke_test.R:25–43`；L1 `limma/vignettes/usersguide.rendered.txt:7497–7500`。** 指南 Y P/FDR=2.40e-262/4.80e-262，X P=5.58e-26；当前只断言新 replay 值 Y1.79122449658387e-262/FDR3.58244899316775e-262，X6.02018304198957e-26。独立 `_s3/guide_object_probe.R` 用原式 `camera(v,index,design,2)`（EList+权重）重放，得到相同新值；不是矩阵入口漏权重引起。builder 明说 printed anchor 未过，披露诚实，但不能用 SMOKE PASSED 代替 PACK验收。须追溯指南打印环境/数据/前处理/版本差异并恢复 printed 断言，或由 owner 据证据明示修改锚点；不得无依据放宽有效数字或改冻结 estimator 强行对齐。本次未证明差异根因。
2. **F2 — PACK T/W、S1 P-1/P-2，`skills/limma-camera/scripts/limma_camera_report.R:19–46`、`references/reporting-templates.md`。** 实际 camera/mroast draft 只写 expression_matrix 和 Male vs Female，未写 concentration 设计、voom权重、mroast cellline/correlation；cameraPR draft 更写“not applicable versus not applicable”，不写已提供的 mean_difference/positive means Male higher。须按方法报告真实输入尺度/权重、设计/contrast/重复单位与相关值、实际排名名称及方向、其他影响结果参数，并将真实设计可核查地保存。每条路线分别断言最终稿，不以 JSON/provenance 的局部字段替代 Methods。
3. **F3 — PACK F，`skills/limma-camera/scripts/limma_camera_report.R:8–14` 及 shared set-bar renderer。** 缺指南要求的 barcode/worm、集合高亮 MD；mroast/fry 实际 PNG 丢失轴标题与方向图例。补齐可从相应输入导出的图形、恢复所有路线的图例/轴标签，并逐张目视和 caption 验证；若缩范围需 owner 明示修订 PACK，不能仅把一个 bar图当完整 F验收。
4. **F4 — S1 P-1/P-2、ENGINEERING_PLAN §3.3，`skills/limma-camera/scripts/calls_registry.json:10–63` 及后续 calls。** 多数值登记为字面字符串“explicit”（如 use.ranks/directional/weights/set.statistic/legacy），没有登记冻结值或动态解析规则；function_default 不是实际分析取值。调用点目前对应 preset 正确，但 registry 不具备要求的结果参数审计语义。须写入实际固定值或明确的 flag/输入绑定，保留 defaults单独字段，并在检查中核对两者。
5. **F5 — S1 P-3，`acceptance/exemplars/limma-camera/S3_REQUEST.md` Owner items、`skills/limma-camera/tests/run_smoke_test.R:1–91`。** 显微镜 camera / FRY基因负例与 cameraPR阳性例目前仅文字提议，未找到独立可运行或可消费的评测样例。须把经语境核实的三例及预期路由保存为与频次语料分开的评测资产，交付路由验收；不改变29/30文献计数。

Owner / 跨模块：camera与dupcor共享 Yoruba 的 printed/locked来源问题，需并行追溯而非假定已证实版本原因；Hallmark缺离线hash安全拒绝。真实 Wald无ranked_list的生产者缺口归上游修复，本模块不能以合成 producer 测试宣称整链通过。

NEXT STEP: 无；等待闭合修复后重审。
VERDICT: FAIL
