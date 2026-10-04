# build_m4 构建交接报告

待裁决：WGCNA 的软阈值 power、表达预处理与样本排除需用户明确，教程值不是通用建议；MAF 的 caller/build/filter 与 callable capture territory 必须提供；浸润方法、TPM 来源、tumor、mRNA scaling 和基因排除应由调用者结合参考服务选择。各模块 SKILL.md 指引先查询 reference_advise/reference_search，缺乏适用证据时展示教程例子并询问用户。不得用文献频次决定默认值。浸润扩大方法集合、其他物种、签名或 solver 需另行验证；本版仅提供离线 GPL-3 TIL10 quanTIseq。EPIC 的已安装许可证限制学术非商业用途、再分发及用户同意，不纳入可调用方法；MCP-counter 在离线运行中试图获取网上签名，也不纳入。

三个模块均完成 S2，等待独立 S3；未安装、未注册路由、未执行 S3 验收。按重启协议保留已完成 WGCNA，从 maftools 的首次未完成步骤续跑。所有科学测试、golden 和 module_lock 在 omicstat-r:2026.09.1 生成。

| 模块 | 锚点与来源 | 测试、图形、状态 |
|---|---|---|
| wgcna-network | FemaleLiver 官方教程 part1/part2：134 样本、3600 probes；power6、unsigned、deepSplit2、minModuleSize30、merge0.25；18 个已分配模块及 grey99，共19标签，尺寸34–609；每个 assignment 与官方代码一致，完整 other_fat 性状复算通过 | 既有 worklog 记录26项 locked-container smoke 通过，四张 PNG 已审阅，本次不重做已完成模块；最终 module_lock --check OK（15文件）。教程镜像来源限制见 S3_REQUEST。 |
| maftools-landscape | 锁定 maftools2.28.0 vignette/包内 TCGA-LAML MAF：193 样本、1241 genes、1732 non-silent、475 silent；原生 TMB192行（零 eligible mutation 样本被原生函数省略），300 interaction pairs；临床200行中7行未匹配 | 14项 smoke：原生对象和表、193样本绘图分母、from-run/spec、登记/default/文档/lint/golden 均通过；oncoplot、variant_summary、TMB、interaction 四图已打开且可读，图注声明 n、territory、无显著性/高低阈值。最终 lock OK。修复 from-run NULL clinical 的 provenance 和 factor 样本ID导致 oncoplot 分母翻倍的问题，主数值表未改变。 |
| immunedeconv-infiltration | 锁定源码 dataset_racle.rda SHA256 7a3e69c89b16df3986e4d02f3dbba949be3c61321d2173a7356c1ac67ce2bef0；32467 genes×4 melanoma samples，11 cell types；官方 deconvolute quantiseq 全精度复算一致（CSV往返1e-14），各样本fractions和为1；网页补充 B cell 两位小数 .02/.43/.02/.49 复现 | 19项 smoke通过；from-run/spec 主表哈希相同；licence/unavailable方法与 counts scale typed refusal；登记/default/docs/lint/golden通过；一张fraction热图已打开，可读无裁切；lock --check OK（9文件）。网页未绑定commit，不当作锁定数值权威。 |

输出及日志在 `/home/<user>/omic-sol61/build_m4/`：wgcna-smoke/anchor、maf-smoke/anchor、id-smoke/anchor；对应 smoke日志、final_checks.log；浸润 API/许可证/离线 probe 日志也保留。各模块 acceptance/exemplars 下已写 S3_REQUEST.md，包含执行方式、限制、建议 router row 和 publication rules。golden_manifest.csv 与 module_lock.json 在模块目录。

共享代码：只使用本车道 m4_io.R 与 fig_mod_m4.R 承载输入/交接/表格/报告和 M4 图形；新增 TMB、interaction、infiltration ggplot builders，全部经 suite style/finalize/lint。oncoplot 传入原生 factor 样本 ID 前显式转 character，确保193样本分母及27% FLT3。试验性的非车道 fig_network.R 轴改动已撤销；最终未改变其原实现。共享扩展图测试 ALL EXTENDED FIGURE CHECKS PASSED。未修改 method_map/router/run_tests、vendor 或其他只读证据。

偏离：immunedeconv 只启用已验证且许可清洁的 quanTIseq，其他方法 typed refusal，符合本车道方法门禁。原生 wrapper 的 method 同时是 backend 选择参数，无法通过 ... 同名覆盖 native solver；本版沿官方 lsei/TIL10路径固定，扩展在 SKILL/S3 中明确。TPM 可检查数值/上游声明，不能仅凭矩阵证明归一化真实性。无自动组间推断。两模块本地 PACK 已应用独立 §3 更正，重启时已存在的更正保留，未编辑原始 S0 worktree。

未完成项：独立 S3、S5 安装与路由登记由后续负责人执行，本任务明确不做；未声称投稿验收通过。按00:20更新，不尝试 git commit 或绕过沙箱；lane worklog 是提交记录，外部 helper 负责提交/推送。报告已写入工作树。
