# limma-array 独立 S3 验收

Pinned: `build/m1-limma@874bc949606e9dfa20fd2a0f84074e5de1c0ef88`；ready `ffa1980`；模块 1.0.0。

## 检查表与证据

- [x] 阅读 PACK T/W/C、S1 附录、S3_REQUEST、build_worklog。
- [x] 锚点：当前仅部分 probes/arrays 的 direct-call replay；源指南有 printed，未断言（F1）。
- [x] 表格：a0 feature_table 标准十四列、3867 rows，full 表只有行名/logFC/AveExpr/t/P.Value/adj.P.Val/B；符号空白，没有 Entrez 或 decideTests summary（F3）。技术重复明确验证后才平均，`core.R:35`–`:43`，输出 probe_mapping；默认不按 symbol 折叠。
- [x] 文字：a0 5000 input、3867 tested、142=110+32、corn/saline 各5，与 JSON/表相符；trend=TRUE/robust=TRUE 明确。实际背景过滤 k/归一化来源/是否平均缺失（F2）。
- [x] 机械：`bash /home/<user>/omic-s3-runs/run_locked.sh limma-array smoke Rscript skills/limma-array/tests/run_smoke_test.R`，`_s3/smoke.log` SMOKE PASSED / EXIT 0；calls/drift/defaults/docs/lint、golden PASS 非 SKIP、spec 表/PNG/spec 字节一致、treat/display/trend/robust/background-k/avereps、typed errors、from-run/tamper、无 Rplots.pdf 均通过。辅助输入没散列（F4）。
- [x] S1 P-1：core `:15`–`:18` 非 Agilent 无预设时 typed refusal，显式选择后画 SA；Agilent TRUE/TRUE、可覆盖；eBayes proportion/stdev limits/span/winsor/legacy 及 treat 参数在 `:45`–`:62` 与 registry 逐项相符。P-2 明确控制探针/0-1背景且 k 必填，归一化后建模前过滤，技术 ID 需声明验证；P-3 本轮不重采，未声称 N=30。
- [x] 亲眼打开 a0 全部 volcano/md PNG，并看 other/sa_diagnostic。标签、轴清晰、无裁切/重叠；caption 给 3867/142、BH .05、上下调数；SA 是均值对 sqrt(residual SD) 的散点诊断。未把别的平台自动套 Agilent 预设。

## 独立源代码探针

`bash /home/<user>/omic-s3-runs/run_locked.sh limma-array probe Rscript _s3/probe.R`：直接按指南 read.maimages 读 SDRF 的全部数组，不 source fixture/engine。`GUIDE dim(x): 44254 19`；`Annotation available: FALSE`；原探针201为 `A_42_P642757`；引擎 full columns 为 `X logFC AveExpr t P.Value adj.P.Val B`。指南 `usersguide.rendered.txt:6680`–`:6681` 的输入尺寸可以直接断言，不依赖注释包。最终 printed DE 依赖缺失的 RnAgilentDesign028282.db，当前不能谎称已覆盖。

## 闭口返修清单

- **F1 — PACK C**：`tests/fixtures/make_gse33005.R:20` 起截前5000探针/10个数组，`tests/run_smoke_test.R:31` 起只在相同子集重建引擎；未断言 PACK 的 27024×19、Down756/NotSig24734/Up1534、RT1-Bb logFC9.33。源指南 `L1_bioc3.23/limma/vignettes/usersguide.rendered.txt:6732`、`:6752`–`:6759` 有这些打印值，`:6681` 还有可用的原始44254×19。应增加可用 printed 断言并回放指南原设计/过滤；注释缺口须通过授权的验收层补齐后完成最终 printed 锚点，或取得明确 PACK 修订。不能用任意子集数值替代。这里判的是必需锚点未完成，不要求本审查安装包。
- **F2 — PACK W、S1 P-2**：`scripts/limma_array_core.R:64` 与共享 `limma_io.R` 的实际 draft 只写“Controls removed or declared removed”“before optional technical-ID averaging”，不写本次 k=4/背景检测规则、实际是否 avereps、输入 normexp+quantile 来源。应据实生成操作/参数及可追踪预处理说明；未提供的预处理信息应明确未知而非臆造，并在 averaging 路径清楚报告映射/数量。
- **F3 — PACK T、S1 P-2**：`skills/_shared/scripts/limma_io.R:43` 起始终把 symbol 设为空，full 表无 symbol/Entrez；无 PACK 的 decideTests 方向汇总。fixture 以 probe_XXXXX 替换原 ProbeName 且没有保留原探针→基因映射。应接受/保存明确的注释映射，在主/补充表保留原 probe ID、symbol、Entrez（缺失明确标记），技术平均保持映射，并产出所审 contrast 的 Down/NotSig/Up 汇总。
- **F4 — PACK S1 P-2（输入身份），ENGINEERING_PLAN §3.2/§3.5**：`scripts/run_limma_array.R:54` 只把 matrix/samples 传入 provenance；实读 a0 provenance.inputs 也仅两项。改变 control-ids、above-background、technical-ids 会改变结果，却没有输入散列。应登记所有实际使用辅助文件的 SHA-256；验证辅助文件变更可由 provenance 检出，重跑相关锁/金标准。

## 所有者事项

非 Agilent 预设待定时要求显式选择，安全且已记录；背景契约为严格对齐的0/1矩阵+k，并已回报，未静默解释未定义字段。SA 使用套件图层表达相同诊断量，不因不是 base graphics 的 plotSA 外观而单独判失败。

NEXT STEP: S4 修复 F1–F4；缺失最终锚点证据不能记作 PASS。

VERDICT: FAIL
