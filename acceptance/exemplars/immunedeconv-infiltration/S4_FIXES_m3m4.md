# immunedeconv-infiltration S4 闭合修复

method-specific native binding → scripts/run_immunedeconv_infiltration.R:15 method-args 离线 named JSON，:16 独立 cibersort-abs-method（locked sig.score，alternative no.sumto1）；scripts/immunedeconv_infiltration_core.R:51 解析并转发所选 method 原生参数，保留 top-level selector/input/absolute 专用选项；:56 abs_method 默认值，JSON 可覆盖；:63 保存真实 forwarding，entry:44 Methods/results 和 :48 provenance 写 actual values。calls_registry.json method_arguments/flag_defaults、options/SKILL reference-service guidance 同步。

Licence/user-file gates 保持：EPIC acknowledgement；CIBERSORT 两路线 acknowledgement、user source/signature 和 hash；没有 licensed CIBERSORT 源码、LM22 或下载。ABIS/ESTIMATE 的 locked top-level wrapper 不支持 ...，nonempty supplementary 参数明确 refusal。

证据（run.sh locked non-root/offline）：
- Rscript skills/immunedeconv-infiltration/tests/run_smoke_test.R → exit 0；原 42 checks PASS；quanTIseq/MCP-counter/EPIC/xCell/TIMER/ABIS/ConsensusTME/ESTIMATE 八方法 native full-table parity、形状及 unchanged golden PASS；原 licence/user-file/scale/unknown refusal PASS。id_smoke.log。
- 新 synthetic user-authorized CIBERSORT source/interface + fake signature（非 licensed 内容）验证 sig.score/no.sumto1：真实 immunedeconv wrapper 与 CLI 相同结果；Methods/provenance实际 abs_method/perm=7 PASS；独立 abs-method flag PASS；formals native sig.score default PASS。没有声称 licensed CIBERSORT 执行。
- 首次 interface fixture 每 sample 相同，row-standardized heatmap 只有中性色；fixture 改为 sample-varying values，并用 Rscript /scratch/id_interface_only.R 单独重跑新增全部 interface/default checks（id_interface.log）。不重跑已通过且未变的八方法，不改 golden 或容差。
- bash /scratch/check.sh immunedeconv-infiltration → calls/default drift/defaults/lint 0 problems；24/24 flags documented；lock/check OK (9 files)，id_checks.log。
- 全部 13 PNG：id_figures_0..2.jpg；十张八 native 方法/chain/spec 图可读，另外三张 synthetic interface 图在 fixture 改善后再打开；无明显裁切。
- golden 八行全部未修改；未闭合项：无。
