# GPT Pro 构建的锁定容器核验（verify_gptpro）

本报告针对 `origin/build/gptpro`（源码 dd1ee0b、报告 ebbb0a2）的声明，记录在 GT103 两个锁定镜像中的实际执行。源码提交和既有 sandbox 报告不是数值通过的证据。本轮不做独立 S3 接受或 S5 安装；无断言删除、无容差放宽、无手写 golden。完整原始命令、失败输出及成功输出保留在 `/home/<user>/omic-sol61/verify_gptpro/`。

## 待裁决与边界（先列所有者事项）

- QC 阈值、HVG/PC/邻居数、Leiden resolution、训练 epochs、参考标签及展示置信度需显式指定；不能由文献多数派推导默认。五模块已加入逐选项 `reference_advise` / `reference_search` 指引及 `references/options.md` 的 S0 参数键映射。
- S0-C 的文献抽取漏项、生态误判和 L3 细读问题仍按独立核验报告 §3/§4.3 处理。本轮不改只读 S0，不把有缺陷的 V 计数作为参数决策。
- 小型 PBMC 子集/两 epoch synthetic_iid 回放证明执行与同平台确定性；不证明充分训练、注释准确率或生物学整合效果。完整 BMMC / purified PBMC 训练、跨平台 ARI/潜空间、独立双 agent、盲测及三生态下游等价性留给独立 S3/所有者。
- limma-voom 的既有单行 description 含 unquoted colon，YAML front matter 仍待其 owner 规范化；本 lane 不编辑保护模块，仅 MCP summary 的展示兼容读取，警告保留。
- `sva-batch` A6a 保持既有已知失败；封存完整性通过不表示该锚点已解决。另 13 个 M1/M2 模块未编辑。
- 19 个新增 R 模块是其他 build lanes 的工作；本轮不实现、不注册。AUCell/GSVA 路线及 Python→R 中立后端生态标签保持待裁决。

## GPT_BUILD_REPORT 声明逐项核对

状态只用 verified（当前证据确认）、wrong（不能用于当前真实仓库/错误判断）、fixed（实跑发现缺陷并修复）。历史云端环境的失败/缺包次数只能由其留存日志核对，不能视作 GT103 验收。

| GPT Pro 声明（章节） | 状态 | 本轮证据/结论 |
|---|---|---|
| 只新增五个 Python 分析模块，19 个 R 模块未实现；非全量交付（§1/6/10） | verified | 原始执行路由 19 分析入口 + 2 selftest；method map 38 规划条目；未实施 S3/S5。 |
| 在其沙箱没有 R/Docker/scverse，五模块未数值验收（§1/5/7） | verified | 原始默认登记 pending、无 Python golden/lock；本轮执行并封存，不能追认原来的静态检查为数值验收。 |
| ZIP/patch 604 文件 SHA 全一致（§1/2） | wrong | 当前仓库不提供原 ZIP/CHANGES.patch 或该项逐文件核验日志，不能独立确认此归档声明；不作为模块验收。wrong 表示证据不足，并非已证实 hash 不同。 |
| 原上传 ZIP 368 文件、输入 SHA、读取范围、原包缺 vendor/reference（§2） | wrong | 当前只有 git 源码，没有原上传 ZIP；无法独立确认文件计数、归档 SHA 与当时读取行为。仅对当前来源与执行范围负责，wrong 表示证据不足。 |
| acceptance/PACK/L1/文献/Guide 未打包，因此旧 smoke 与锁不能验收（§2/8.2/8.5/10） | wrong | GT103 有完整原证据；R smoke 与 14/14 seals 实跑可用，无编造 fixture。历史缺件情况不适用于当前 checkout。 |
| 四 overlay 合并、handoff.R 保留 R4/batch 来源并支持四生态（§4） | verified | 当前源码、四生态契约/转换测试与真实链；未修改 handoff.R/convert.R，保留所有 refusal 路径。 |
| R3 原 golden/lock 没有手写，五 Python 封存仍缺失（§3/5/10） | verified | 输入分支 R3 旧 SHA 与五模块缺失 manifest/lock 一致；本轮仅调用各模块自己的生成器，未填人工值。 |
| 五模块具 SKILL/core/report/QC/registry/五 references/fixture/generator（§5） | verified | 完整源码与每模块检查脚本存在；运行的调用/默认值/docs/help检查、golden生成验证，另加 options.md。 |
| shared 支持 --spec/--from-run/StudyContract/hash/轴/counts/生态/来源/警告（§5） | verified | 独立官方 API、规格重放、恶意哈希/生态/批次来源、flag-effect及 typed refusal 的原断言通过；对应共享单元/客户端详数如下。 |
| QC/HVG/PC/neighbors/resolution/epochs等显式用户选择，无多数派默认（§5/9） | verified | 源码 SPEC/CLI/registry 一致；174 L1 MATCH 与 required 参数文档，追加逐选择 reference 服务指引。 |
| PBMC3k SHA、synthetic_iid、小规模 fixture 仅运行验收、模拟注册仍 pending（§5） | verified | 四次各模块原 API 回放与 fixture.source.json；未伪造临床结果。ANCHOR_REGISTRY 未改，独立 S3 可依据现有 source.json 更新科学接受记录。 |
| 同平台原容差/ARI=1、marker 更严比较，跨平台/双agent未通过（§5） | verified | 本轮四快照跨两脚本比对满足原 exact / tolerances；不扩大为跨平台或独立 S3。 |
| 原出版规则 21 模块/28规则、runner覆盖R/Python且不加pytest依赖（§4/7） | verified | 当前规则/runner契约与完整套件；两个 pinned 镜像零安装，未改 runner或publication/router注册表。 |
| 原参考配置11PASS/1历史skip、人工Git基线1FAIL、SDK导致内核117/4errors（§7） | verified | 历史 sandbox summary/config/core 日志；当前另用真实原历史只读 mount，core119/config12通过，历史失败不计为本轮通过。 |
| 沙箱Python3.13.5/torch2.10不同于pins，继承BUILD_RECORD/DEPLOYMENT不是本次证据（§7） | verified | 历史留存材料与env pins分开；本轮只引用当前lane日志，不追认历史部署。 |
| 原MCP publication/client被SDK阻塞、没有远程部署（§7/10） | verified | 历史导入失败日志；本轮locked SDK真实stdio，未部署或触碰参考服务容器。 |
| §8预备fetch/install/其它R模块重生命令是未运行建议（§8） | fixed | 遵循common修订：复用已下载数据/只读acceptance与image cache，不执行fetch/install、不改另13模块或其golden；真实命令helpers在lane scratch。 |
| limma-camera 四阶段集合数、逐集合选择账本、单 roast（§3 R3） | verified | 原 smoke 54 PASS + 2 stale golden FAIL；合法生成后 56 PASS，collection/matched=2、selected/tested=1；表/JSON/Methods/Results/图注一致。 |
| limma-camera 原 golden/lock 待重生（§3 R3） | fixed | 自己的 generate_golden.sh 生成；两 smoke 各 56 PASS，golden PASS（非 SKIP），R lock 1.1.1 OK。 |
| R4 的 env 转发/真实 R 取值尚未执行（§3） | verified | 真实 MCP 容器链 UUID 到 R handoff；run_id 不为 ws；两个 UUID 构成 downstream upstream_runs。 |
| MCP 紧凑 manifest 保留全部交接信息（§3/4，隐含接口承诺） | fixed | 初次真实链第二档预算压缩丢 upstream_runs；server._fit_budget 加一字段，预算测试增强，重跑真实链通过。 |
| /.omicstat-acceptance 被忽略且 provenance 可用（§3 R5） | verified | git check-ignore 与真实 _dirty_worktree_identity 成功，r5-provenance.log。 |
| sva-batch 文件未改，A6a 仍已知失败（§3/8.5） | verified | 本轮不编辑该模块；全套日志保留 KNOWN-FAILING ANCHOR。 |
| overlay R/Python 分发、五个主分析 MCP 工具（§4） | fixed | 首次完整 R suite 的 list_modules 一行 summary 空：受保护 limma-voom 文档 unquoted colon 导致 YAML 错误；只修 MCP 的 display-only plain-line 摘要兼容，未改保护模块或增主工具。 |
| 方法表 38 规划模块不代表全部可执行（§4） | verified | code-derived availability 与历史顺序检查；路由只含实际入口。 |
| 19 分析模块的封存目前 0 通过（§4） | wrong | 完整 acceptance/exemplars 下初查 13/14 M1/M2 通过；limma-camera 真 stale；重生后 14/14 通过，gate 无需修改。 |
| PUB-LOCK-001 阻塞缺失/篡改锁（§4） | verified | 正反例与出版契约；真实源文件封存审计。 |
| 133 路由题 ID/目标/覆盖合法，未盲测（§4） | verified | inventory 契约；本轮也不声明 90%/98% 准确率通过。 |
| scanpy-qc raw counts、显式 QC/双细胞选项及保留账本（§5） | verified | 两次 golden 脚本、四数值 smoke，独立计数回放、阈值有效性及 scrublet score。 |
| scanpy-cluster 官方标准流程能执行（§5） | fixed | log1p/scale 必须位置输入；PCA mask_var 与弃用 use_highly_variable 冲突；最小修复后独立 PCA/Leiden 回放和同平台确定性通过。 |
| scanpy-markers 完整描述性 marker 与条件推断拒绝（§5） | fixed | 独立 rank_genes_groups 回放、严格原有容差、t-test/Wilcoxon 有效性和 OS_PSEUDOREPLICATION；R render 的 mean_log 枚举错拼改为 log_mean。 |
| scvi-integrate CPU SCVI、潜空间及原 counts/cluster 保留（§5） | fixed | model.history 是 property，不可类级 .items formals 探针；logger=False 又导致空 history CSV；采用 native SimpleLogger/default logger=None 和稳定表头，训练/保存模型重载回放。 |
| scanvi-annotate 已验证模型/标签/概率/交叉表（§5） | fixed | 来自 scvi-integrate 的真实 --from-run；预测重载回放；标签保留与展示阈值不改预测；图例 raw key 改 human-readable Predicted label。 |
| 所有统计调用已覆盖锁定 API 参数（§5） | fixed | 原有登记遗漏八个新 optional formals；显式 None（锁定默认）并更新 registry；174 个可对照 L1 formals 全 MATCH。 |
| 模块版本进入全部产物（§5 provenance 承诺） | fixed | shared sc_module 原写死 1.0.0；新增 module_version 参数，cluster/scvi 1.0.1 进入 JSON/handoff/request/provenance。 |
| generate_golden.sh 可重复生成并验证（§8.3） | fixed | 初次第二跑 OS_OUTPUT_EXISTS；capture 工具重查完全一致值时只读返回，变化仍拒绝，--replace 需明确复审。 |
| Python 图通过共享 R renderer 可读（§5/8.4） | fixed | QC off-range 大阈值使图扁平，metric_labels map 需 named vector；保留完整 cutoff 在 spec/caption，只画范围内线；实跑/逐张看图。 |
| reference 配置与历史生成器一致（§4/7/8.6） | fixed | 完整方法表是合法 integration 扩展；新增只读 checker，保持其余历史资产逐字节核对并核 38 条状态、顺序和当前 hash；config 12 PASS。 |
| reference 内核在原沙箱四 errors，不可全通过（§7） | verified | 历史记录保留；GT103 locked MCP venv 离线 119 PASS/0 skip；未触碰运行服务容器。 |
| 原沙箱静态 97 R lint、107 Python AST、61 JSON、5 schemas、23 shell（§7） | verified | 原 lint_r.log/static_integrity.json 可复查；本轮 R parser 的全仓 352 文件另记，不能以 lint 代 parser。 |
| 原沙箱 32 数据契约、12 源码契约、3 identity、20+1 tools 等（§7） | verified | 以原 `sandbox_tests/summary.json` 和原日志为历史证据；当前完整套件单列实测，绝不将原缺包 skip 当成当前 pass。 |
| Figure requests 不等于已渲染出版图（§8.4） | verified | 本轮另行 R render、lint、每 PNG 目视及 caption 检查，记录见下。 |
| 未来 S3、跨平台、三生态后端、完整发布门禁仍未完成（§9/10） | verified | 本轮验证范围及每模块 S3_REQUEST 明示，未替所有者决策。 |

## 每个修复的命令与原始失败

命令 helper `run-r.sh` / `run-py.sh` 均存于 lane scratch，包含完整 mounts、UID、环境与锁定镜像。所有执行均 `docker run --rm`，未安装任何包，未调用运行中的 reference 服务。

| 修复 | 失败命令及日志 | 原始输出与改动 |
|---|---|---|
| 重复 capture | `run-py.sh bash skills/scanpy-qc/tests/generate_golden.sh`；scanpy-qc-second-initial.log | `OS_OUTPUT_EXISTS`；仅相同已捕获值允许只读验证，变化仍拒绝；增加 capture 重复/漂移测试。 |
| scVI history accessor | `run-py.sh python tools/capture_locked_defaults.py scvi-integrate`；scvi-integrate-capture.log | `AttributeError: 'property' object has no attribute 'items'`；registry 移到 accessors，实际字典迭代保持。 |
| 遗漏 locked API formals | omitted-formals.py / omitted-formals.log | normalize_total.obsm、HVG.filter_unexpressed_genes、scale.mask_obs、pca.obsm、neighbors.distances、umap.key_added；后两项同时用于 SCVI。均显式 None。 |
| 位置输入 | `run-py.sh bash skills/scanpy-cluster/tests/generate_golden.sh`；原 pass1/pass2.log | `TypeError: log1p requires at least 1 positional argument`；输入对象位置传入、其余 options 仍 keyword；checker 只接受已登记 required input，并在 locked drift 校验位置名字；新增五正反例（含签名位置顺序）。 |
| PCA API 冲突 | 同上；scanpy-cluster-fixed-pass1.log | `ValueError: These arguments are incompatible`；mask_var=None 负责已筛 HVG 矩阵全部列，弃用 use_highly_variable=None；原独立回放未改。 |
| QC renderer | scanpy-qc-render-initial.log 与原初 PNG（保留） | 大上限拉平分布；只画观测范围内 cutoff，spec/caption 全保存；JSON metric_labels 变 named vector。 |
| marker 颜色/百分比 | 实际 marker_dotplot PNG、render_warnings.csv、marker_dot_data.csv | 8 个 pct_exp=100.00000000000013/100.0000000000002 被 R size scale 删除；改 sum/n*100；原 raw mean 被错误声明 z-score，改 scaled=False；完整重生 computed golden，不改比较断言。 |
| marker request 枚举 | `render-module.py scanpy-markers` / marker-render-exit-probe.log | `OS_INVALID_PARAMETER: mean_definition`；mean_log→log_mean，匹配平均 log-normalized expression，不修改计算值。 |
| SCVI history CSV | `run-py.sh bash skills/scvi-integrate/tests/generate_golden.sh`；scvi-integrate-initial-history.log | `pandas.errors.EmptyDataError`；locked Trainer 源码证实 logger=None 才创建 native SimpleLogger；保留 history，稳定四列表头，不改 snapshot 比较。 |
| SCANVI 图例 | 最初四张已打开 PNG；scanvi-annotate-before-title-pass1/2.log | raw scanvi_label 改显示列 Predicted label，保留 category 字符串与原 colour family；最终两次脚本及八张 PNG 重跑/打开。 |
| 版本记录 | code/default probe 和输出检查 | core 1.0.1 vs shared 固定 1.0.0；最小 additive 参数，默认保持旧接口；现有模块无需迁移。 |
| MCP lineage | mcp-chain.py；mcp-chain-initial.log / mcp-chain-final.log | budget 第二档省略 upstream_runs；保持字段并增强现有 budget unittest。 |
| MCP 模块摘要 | `bash env/test.sh` 的 mcp/test_client.py；full-r-initial.log | 76 assertions / 75 PASS / 1 FAIL / 3 SKIP；limma-voom unquoted colon 导致空摘要。MCP 只恢复 legacy 单行 description 展示，保留 YAML 警告，不读取其他 metadata；所有行摘要断言增强 + 新回归；publication 60 tests OK（2 Windows skips）。完整 R suite 从头重跑。 |
| reference config | locked offline config tests；reference-config-initial.log / mounted.log / final.log | 未挂 git 时无法取历史；补只读 mount 后 method map integration 与旧 builder 不同；不修改 generator/registry，新增只读 integration checker 保留所有历史检查。 |

## 模块、锚点与数值门禁

每次 `tests/generate_golden.sh` 内含默认探针、写 golden smoke、比较 golden smoke、写锁、check。每模块完整执行两次，因此每模块四个数值 smoke；所有原 tolerances（atol/rtol=1e-6、同平台 ARI=1、marker atol=1e-12/rtol=1e-10）不变。

| 模块 | 数值 / 封存 | 实测末次锚点 cells × genes | 图形 |
|---|---|---|---|
| scanpy-qc | 两脚本 / 四数值 smoke PASS；golden PASS / lock OK | 600 × 13769；samples=1 | 4 PNG 全打开 |
| scanpy-cluster | 两脚本 / 四数值 smoke PASS；golden PASS / lock OK | 600 × 13769；samples=1 | 8 PNG 全打开 |
| scanpy-markers | 两脚本 / 四数值 smoke PASS；golden PASS / lock OK | 600 × 13769；samples=1 | 4 PNG 全打开 |
| scvi-integrate | 两脚本 / 四数值 smoke PASS；golden PASS / lock OK | 96 × 160；samples=2 | 8 PNG 全打开 |
| scanvi-annotate | 两脚本 / 四数值 smoke PASS；golden PASS / lock OK | 96 × 160；samples=2 | 8 PNG 全打开 |

最终 seal 审计：19/19 OK（其中 M1/M2 14/14）；`seals-final.json` 保留逐模块结果。默认审计 174 MATCH / 0 REVIEW；8 个 L1 未包含的新可选 formals 另外与 installed signature 对照。

补充 PACK C 原文件检查：pack-inputs.log 记录 BMMC 两输入 SHA 与教程 reader 打印 shape `(8785,36601)` / `(8340,36601)`、合并 17125 cells；PurifiedPBMC 原文件 SHA、官方 reader `(42919,21932)` 与 labels。只核原文件和读入路径，不将其冒充完整训练锚点。PBMC3k 每次数值 smoke 由注册 SHA 的原数据产生前 600 cells fixture；SCVI/SCANVI 用 locked synthetic_iid。fixture `.source.json` 完整保存，S3_REQUEST 指向实际输出。

## 完整测试、精确计数和所有 skip

| 执行 | 精确计数（不把不同口径相加） | skip 条目 | runner 结论 |
|---|---|---:|---|
| full-r | 63 命令组；2028 PASS 行；108 [ok]；97 unittest total / 2 skipped | 15 | == done: ALL PASSED (0 skipped for missing packages) |
| full-py-env | 24 命令组；392 PASS 行；0 [ok]；13 unittest total / 0 skipped | 1 | == done: ALL PASSED |
| full-py-direct | 24 命令组；392 PASS 行；0 [ok]；13 unittest total / 0 skipped | 1 | == done: ALL PASSED |
| full-e2e | 1 命令组；92 PASS 行；0 [ok]；0 unittest total / 0 skipped | 3 | exit=0；MCP assertions 见下 |
| reference core / config（离线） | 119 / 12 unittest；全 PASS | 0 / 0 | OK |
| 独立 R parse / shared / convert / renderer | 352 parse / 31 PASS / 98 PASS / 31 PASS | 0 | PASS |

`full-*.log` 是完整输出；`suite-counts.json` 保留机器计数。PASS 行是测试程序公开的检查粒度，不冒充内部全部 numerical assertion；同一套件经两个入口重复执行分别列数。

### full-r 逐组原始计数

| 命令 | PASS 行 | [ok] 检查 | unittest 个数 | assertion summary |
|---|---:|---:|---:|---|

| `python3 env/test_env_config.py` | 88 | 0 | 0 total / 0 skipped |  |

| `Rscript env/r/test_layer_lib.R` | 6 | 0 | 0 total / 0 skipped |  |

| `Rscript skills/_shared/tests/test_figures.R` | 237 | 0 | 0 total / 0 skipped |  |

| `Rscript skills/_shared/tests/test_figures_ext.R` | 169 | 0 | 0 total / 0 skipped |  |

| `Rscript skills/_shared/tests/test_omics_shared.R` | 31 | 0 | 0 total / 0 skipped |  |

| `Rscript skills/_shared/tests/test_convert.R` | 98 | 0 | 0 total / 0 skipped |  |

| `Rscript skills/_shared/tests/test_effect_table.R` | 0 | 70 | 0 total / 0 skipped |  |

| `Rscript skills/_shared/tests/test_render.R` | 0 | 38 | 0 total / 0 skipped |  |

| `Rscript skills/_shared/tests/test_engine_contract.R` | 68 | 0 | 0 total / 0 skipped |  |

| `python3 env/py/test_py_env_config.py` | 178 | 0 | 0 total / 0 skipped |  |

| `python3 skills/_shared/py/tests/test_ospy.py` | 85 | 0 | 0 total / 0 skipped |  |

| `python3 tools/test_check_calls.py` | 19 | 0 | 0 total / 0 skipped |  |

| `python3 tools/test_new_module_py.py` | 18 | 0 | 0 total / 0 skipped |  |

| `python3 tools/test_build_contracts.py` | 0 | 0 | 13 total / 0 skipped |  |

| `Rscript skills/_shared/tests/test_render_figure_request.R` | 31 | 0 | 0 total / 0 skipped |  |

| `python3 tools/test_tools.py` | 0 | 0 | 21 total / 0 skipped |  |

| `python3 tools/lint_r.py` | 0 | 0 | 0 total / 0 skipped |  |

| `Rscript skills/clusterprofiler-compare/tests/run_smoke_test.R` | 41 | 0 | 0 total / 0 skipped |  |

| `Rscript skills/clusterprofiler-gsea/tests/run_smoke_test.R` | 42 | 0 | 0 total / 0 skipped |  |

| `Rscript skills/clusterprofiler-ora/tests/run_smoke_test.R` | 57 | 0 | 0 total / 0 skipped |  |

| `Rscript skills/deseq2-lrt/tests/run_smoke_test.R` | 82 | 0 | 0 total / 0 skipped |  |

| `Rscript skills/deseq2-qc/tests/run_smoke_test.R` | 70 | 0 | 0 total / 0 skipped |  |

| `Rscript skills/deseq2-wald/tests/run_smoke_test.R` | 62 | 0 | 0 total / 0 skipped |  |

| `Rscript skills/edger-qlf/tests/run_smoke_test.R` | 73 | 0 | 0 total / 0 skipped |  |

| `Rscript skills/fgsea-prerank/tests/run_smoke_test.R` | 36 | 0 | 0 total / 0 skipped |  |

| `Rscript skills/gsva-score/tests/run_smoke_test.R` | 53 | 0 | 0 total / 0 skipped |  |

| `Rscript skills/limma-array/tests/run_smoke_test.R` | 57 | 0 | 0 total / 0 skipped |  |

| `Rscript skills/limma-camera/tests/run_smoke_test.R` | 56 | 0 | 0 total / 0 skipped |  |

| `Rscript skills/limma-dupcor/tests/run_smoke_test.R` | 60 | 0 | 0 total / 0 skipped |  |

| `Rscript skills/limma-voom/tests/run_smoke_test.R` | 69 | 0 | 0 total / 0 skipped |  |

| `Rscript skills/omicstat-selftest/tests/run_smoke_test.R` | 34 | 0 | 0 total / 0 skipped |  |

| `Rscript skills/sva-batch/tests/run_smoke_test.R` | 94 | 0 | 0 total / 0 skipped |  |

| `python3 skills/omicstat-selftest-py/tests/run_smoke_test.py` | 33 | 0 | 0 total / 0 skipped |  |

| `python3 skills/scanpy-cluster/tests/run_smoke_test.py` | 1 | 0 | 0 total / 0 skipped |  |

| `python3 skills/scanpy-markers/tests/run_smoke_test.py` | 1 | 0 | 0 total / 0 skipped |  |

| `python3 skills/scanpy-qc/tests/run_smoke_test.py` | 1 | 0 | 0 total / 0 skipped |  |

| `python3 skills/scanvi-annotate/tests/run_smoke_test.py` | 1 | 0 | 0 total / 0 skipped |  |

| `python3 skills/scvi-integrate/tests/run_smoke_test.py` | 1 | 0 | 0 total / 0 skipped |  |

| `python3 tools/check_defaults.py skills/clusterprofiler-compare` | 0 | 0 | 0 total / 0 skipped |  |

| `python3 tools/check_defaults.py skills/clusterprofiler-gsea` | 0 | 0 | 0 total / 0 skipped |  |

| `python3 tools/check_defaults.py skills/clusterprofiler-ora` | 0 | 0 | 0 total / 0 skipped |  |

| `python3 tools/check_defaults.py skills/deseq2-lrt` | 0 | 0 | 0 total / 0 skipped |  |

| `python3 tools/check_defaults.py skills/deseq2-qc` | 0 | 0 | 0 total / 0 skipped |  |

| `python3 tools/check_defaults.py skills/deseq2-wald` | 0 | 0 | 0 total / 0 skipped |  |

| `python3 tools/check_defaults.py skills/edger-qlf` | 0 | 0 | 0 total / 0 skipped |  |

| `python3 tools/check_defaults.py skills/fgsea-prerank` | 0 | 0 | 0 total / 0 skipped |  |

| `python3 tools/check_defaults.py skills/gsva-score` | 0 | 0 | 0 total / 0 skipped |  |

| `python3 tools/check_defaults.py skills/limma-array` | 0 | 0 | 0 total / 0 skipped |  |

| `python3 tools/check_defaults.py skills/limma-camera` | 0 | 0 | 0 total / 0 skipped |  |

| `python3 tools/check_defaults.py skills/limma-dupcor` | 0 | 0 | 0 total / 0 skipped |  |

| `python3 tools/check_defaults.py skills/limma-voom` | 0 | 0 | 0 total / 0 skipped |  |

| `python3 tools/check_defaults.py skills/omicstat-selftest-py` | 0 | 0 | 0 total / 0 skipped |  |

| `python3 tools/check_defaults.py skills/omicstat-selftest` | 0 | 0 | 0 total / 0 skipped |  |

| `python3 tools/check_defaults.py skills/scanpy-cluster` | 0 | 0 | 0 total / 0 skipped |  |

| `python3 tools/check_defaults.py skills/scanpy-markers` | 0 | 0 | 0 total / 0 skipped |  |

| `python3 tools/check_defaults.py skills/scanpy-qc` | 0 | 0 | 0 total / 0 skipped |  |

| `python3 tools/check_defaults.py skills/scanvi-annotate` | 0 | 0 | 0 total / 0 skipped |  |

| `python3 tools/check_defaults.py skills/scvi-integrate` | 0 | 0 | 0 total / 0 skipped |  |

| `python3 tools/check_defaults.py skills/sva-batch` | 0 | 0 | 0 total / 0 skipped |  |

| `python3 skills/_shared/publication/test_publication_rules.py` | 0 | 0 | 0 total / 0 skipped |  |

| `python3 mcp/test_package_identity.py` | 0 | 0 | 3 total / 0 skipped |  |

| `python3 mcp/test_publication.py` | 0 | 0 | 60 total / 2 skipped |  |

| `python3 mcp/test_client.py` | 76 | 0 | 0 total / 0 skipped | 76 assertions, 76 passed, 0 failed, 3 skipped |


跳过项（完整原文）：

- `python3 skills/_shared/py/tests/test_ospy.py`: `SKIP: torch parts of set_seed (torch not installed)`
- `python3 skills/_shared/py/tests/test_ospy.py`: `SKIP: scvi parts of set_seed (scvi-tools not installed)`
- `python3 skills/omicstat-selftest-py/tests/run_smoke_test.py`: `SKIP: AnnData parts (anndata not importable in this interpreter; PY-10 reports it)`
- `python3 skills/omicstat-selftest-py/tests/run_smoke_test.py`: `SKIP: environment verdict (unmanaged interpreter: PY-02/PY-06 fail by design)`
- `python3 skills/omicstat-selftest-py/tests/run_smoke_test.py`: `SKIP: R render step (no Rscript here; covered by mcp/test_client.py)`
- `python3 skills/scanpy-cluster/tests/run_smoke_test.py`: `SKIP: numerical anchor / model / golden tests require locked image; OS_ENVIRONMENT_MISMATCH: OMICSTAT_PY_CONTAINER=1 is required; use the supplied container image; Python 3.12.3 != 3.12.13; scanpy None != 1.12.4; anndata None != 0.13.3.post0; scvi-tools None != 1.5.1; torch None != 2.14.0+cpu`
- `python3 skills/scanpy-markers/tests/run_smoke_test.py`: `SKIP: numerical anchor / model / golden tests require locked image; OS_ENVIRONMENT_MISMATCH: OMICSTAT_PY_CONTAINER=1 is required; use the supplied container image; Python 3.12.3 != 3.12.13; scanpy None != 1.12.4; anndata None != 0.13.3.post0; scvi-tools None != 1.5.1; torch None != 2.14.0+cpu`
- `python3 skills/scanpy-qc/tests/run_smoke_test.py`: `SKIP: numerical anchor / model / golden tests require locked image; OS_ENVIRONMENT_MISMATCH: OMICSTAT_PY_CONTAINER=1 is required; use the supplied container image; Python 3.12.3 != 3.12.13; scanpy None != 1.12.4; anndata None != 0.13.3.post0; scvi-tools None != 1.5.1; torch None != 2.14.0+cpu`
- `python3 skills/scanvi-annotate/tests/run_smoke_test.py`: `SKIP: numerical anchor / model / golden tests require locked image; OS_ENVIRONMENT_MISMATCH: OMICSTAT_PY_CONTAINER=1 is required; use the supplied container image; Python 3.12.3 != 3.12.13; scanpy None != 1.12.4; anndata None != 0.13.3.post0; scvi-tools None != 1.5.1; torch None != 2.14.0+cpu`
- `python3 skills/scvi-integrate/tests/run_smoke_test.py`: `SKIP: numerical anchor / model / golden tests require locked image; OS_ENVIRONMENT_MISMATCH: OMICSTAT_PY_CONTAINER=1 is required; use the supplied container image; Python 3.12.3 != 3.12.13; scanpy None != 1.12.4; anndata None != 0.13.3.post0; scvi-tools None != 1.5.1; torch None != 2.14.0+cpu`
- `python3 mcp/test_publication.py`: `test_safe_join_and_finalizer_reject_windows_junction (__main__.PublicationContractTests.test_safe_join_and_finalizer_reject_windows_junction) ... skipped 'Windows junction test'`
- `python3 mcp/test_publication.py`: `test_unsafe_walker_evidence_becomes_blocking_review_finding (__main__.PublicationContractTests.test_unsafe_walker_evidence_becomes_blocking_review_finding) ... skipped 'Windows junction test'`
- `python3 mcp/test_client.py`: `SKIP   real run on engine container  -- docker unavailable ([Errno 2] No such file or directory: 'docker')`
- `python3 mcp/test_client.py`: `SKIP   python module on engine native  -- native-env.json has no usable "python" key (bash env/py/setup_native.sh)`
- `python3 mcp/test_client.py`: `SKIP   python module on engine container  -- docker unavailable ([Errno 2] No such file or directory: 'docker')`


已知失败（原样记录）：

- `KNOWN-FAILING ANCHOR: A6a PRINTED: the vignette's own num.sv(edata,mod,method="leek") in this session gives n.sv = 4; printed 2 (sva.rendered.txt:141). Cause (S4_FIXES.md): leek counts eigenvalues of a projected matrix above a threshold a*(jn)^(-1/3)*57 that starts at a = 0, and 3 of them are exact zeros in theory (rank of mod) that come out as +/-1e-16 rounding noise; 1e-12 input perturbations give 2/4/5 `
- `KNOWN-FAILING ANCHOR: A6a PRINTED: the vignette's verbatim sec 4-6 chain with its in-session n.sv = 4 reproduces the printed topTableF (sva.rendered.txt:203-226, 10 rows x 7 columns at printed precision); top row got 207783_x_at C1 = -13.50399 `

### full-py-env 逐组原始计数

| 命令 | PASS 行 | [ok] 检查 | unittest 个数 | assertion summary |
|---|---:|---:|---:|---|

| `python env/py/selftest_image.py --functional` | 22 | 0 | 0 total / 0 skipped |  |

| `python env/py/test_py_env_config.py` | 178 | 0 | 0 total / 0 skipped |  |

| `python skills/_shared/py/tests/test_ospy.py` | 87 | 0 | 0 total / 0 skipped |  |

| `python tools/test_check_calls.py` | 19 | 0 | 0 total / 0 skipped |  |

| `python tools/test_new_module_py.py` | 18 | 0 | 0 total / 0 skipped |  |

| `python tools/test_build_contracts.py` | 0 | 0 | 13 total / 0 skipped |  |

| `python tools/check_calls.py skills/omicstat-selftest-py` | 0 | 0 | 0 total / 0 skipped |  |

| `python tools/check_defaults.py skills/omicstat-selftest-py` | 0 | 0 | 0 total / 0 skipped |  |

| `python skills/omicstat-selftest-py/tests/run_smoke_test.py` | 34 | 0 | 0 total / 0 skipped |  |

| `python tools/check_calls.py skills/scanpy-cluster` | 0 | 0 | 0 total / 0 skipped |  |

| `python tools/check_defaults.py skills/scanpy-cluster` | 0 | 0 | 0 total / 0 skipped |  |

| `python skills/scanpy-cluster/tests/run_smoke_test.py` | 7 | 0 | 0 total / 0 skipped |  |

| `python tools/check_calls.py skills/scanpy-markers` | 0 | 0 | 0 total / 0 skipped |  |

| `python tools/check_defaults.py skills/scanpy-markers` | 0 | 0 | 0 total / 0 skipped |  |

| `python skills/scanpy-markers/tests/run_smoke_test.py` | 7 | 0 | 0 total / 0 skipped |  |

| `python tools/check_calls.py skills/scanpy-qc` | 0 | 0 | 0 total / 0 skipped |  |

| `python tools/check_defaults.py skills/scanpy-qc` | 0 | 0 | 0 total / 0 skipped |  |

| `python skills/scanpy-qc/tests/run_smoke_test.py` | 6 | 0 | 0 total / 0 skipped |  |

| `python tools/check_calls.py skills/scanvi-annotate` | 0 | 0 | 0 total / 0 skipped |  |

| `python tools/check_defaults.py skills/scanvi-annotate` | 0 | 0 | 0 total / 0 skipped |  |

| `python skills/scanvi-annotate/tests/run_smoke_test.py` | 7 | 0 | 0 total / 0 skipped |  |

| `python tools/check_calls.py skills/scvi-integrate` | 0 | 0 | 0 total / 0 skipped |  |

| `python tools/check_defaults.py skills/scvi-integrate` | 0 | 0 | 0 total / 0 skipped |  |

| `python skills/scvi-integrate/tests/run_smoke_test.py` | 7 | 0 | 0 total / 0 skipped |  |


跳过项（完整原文）：

- `python skills/omicstat-selftest-py/tests/run_smoke_test.py`: `SKIP: R render step (no Rscript here; covered by mcp/test_client.py)`

### full-py-direct 逐组原始计数

| 命令 | PASS 行 | [ok] 检查 | unittest 个数 | assertion summary |
|---|---:|---:|---:|---|

| `python env/py/selftest_image.py --functional` | 22 | 0 | 0 total / 0 skipped |  |

| `python env/py/test_py_env_config.py` | 178 | 0 | 0 total / 0 skipped |  |

| `python skills/_shared/py/tests/test_ospy.py` | 87 | 0 | 0 total / 0 skipped |  |

| `python tools/test_check_calls.py` | 19 | 0 | 0 total / 0 skipped |  |

| `python tools/test_new_module_py.py` | 18 | 0 | 0 total / 0 skipped |  |

| `python tools/test_build_contracts.py` | 0 | 0 | 13 total / 0 skipped |  |

| `python tools/check_calls.py skills/omicstat-selftest-py` | 0 | 0 | 0 total / 0 skipped |  |

| `python tools/check_defaults.py skills/omicstat-selftest-py` | 0 | 0 | 0 total / 0 skipped |  |

| `python skills/omicstat-selftest-py/tests/run_smoke_test.py` | 34 | 0 | 0 total / 0 skipped |  |

| `python tools/check_calls.py skills/scanpy-cluster` | 0 | 0 | 0 total / 0 skipped |  |

| `python tools/check_defaults.py skills/scanpy-cluster` | 0 | 0 | 0 total / 0 skipped |  |

| `python skills/scanpy-cluster/tests/run_smoke_test.py` | 7 | 0 | 0 total / 0 skipped |  |

| `python tools/check_calls.py skills/scanpy-markers` | 0 | 0 | 0 total / 0 skipped |  |

| `python tools/check_defaults.py skills/scanpy-markers` | 0 | 0 | 0 total / 0 skipped |  |

| `python skills/scanpy-markers/tests/run_smoke_test.py` | 7 | 0 | 0 total / 0 skipped |  |

| `python tools/check_calls.py skills/scanpy-qc` | 0 | 0 | 0 total / 0 skipped |  |

| `python tools/check_defaults.py skills/scanpy-qc` | 0 | 0 | 0 total / 0 skipped |  |

| `python skills/scanpy-qc/tests/run_smoke_test.py` | 6 | 0 | 0 total / 0 skipped |  |

| `python tools/check_calls.py skills/scanvi-annotate` | 0 | 0 | 0 total / 0 skipped |  |

| `python tools/check_defaults.py skills/scanvi-annotate` | 0 | 0 | 0 total / 0 skipped |  |

| `python skills/scanvi-annotate/tests/run_smoke_test.py` | 7 | 0 | 0 total / 0 skipped |  |

| `python tools/check_calls.py skills/scvi-integrate` | 0 | 0 | 0 total / 0 skipped |  |

| `python tools/check_defaults.py skills/scvi-integrate` | 0 | 0 | 0 total / 0 skipped |  |

| `python skills/scvi-integrate/tests/run_smoke_test.py` | 7 | 0 | 0 total / 0 skipped |  |


跳过项（完整原文）：

- `python skills/omicstat-selftest-py/tests/run_smoke_test.py`: `SKIP: R render step (no Rscript here; covered by mcp/test_client.py)`

### full-e2e 逐组原始计数

| 命令 | PASS 行 | [ok] 检查 | unittest 个数 | assertion summary |
|---|---:|---:|---:|---|

| `full-e2e` | 92 | 0 | 0 total / 0 skipped | 92 assertions, 92 passed, 0 failed, 3 skipped |


跳过项（完整原文）：

- `full-e2e`: `SKIP   real run on engine native  -- no Rscript on PATH`
- `full-e2e`: `SKIP   native-only checks (legacy status, --strict, validate_publication, default outdir)  -- native engine unavailable`
- `full-e2e`: `SKIP   python module on engine native  -- no native environment file`

直接 Python runner 的首次入口因 wrapper 与 run-py 重复 `--network none` 而 exit125（full-py-direct-initial.log）；改 lane-only helper 调用 absolute docker。首次 host e2e 59 assertions / 57 PASS / 2 FAIL / 3 SKIP（full-e2e-initial.log），R wrapper 的 root override 造成 R 产物目录不可读；只把 root/cache override 限于完整 R suite，MCP R/render 保留 calling UID，并用 lane 独立 e2e scratch。断言/runner 均未修改，两个入口完整重跑。

R conversion 最初以 calling-user HOME 无法找到 image 内 root 的预建 basilisk 环境：该错误仅是执行配置，不改 convert.R；以 image 原 HOME/UID 重跑后 0 skip。完整 R suite 的 lane-only docker wrapper 提供 acceptance 只读 mount 与预建 cache；不修改 runner/registry。首次 R/Python UID 不同导致 scratch per-test copy 权限警告，完整 stdout 仍保存；lane-only verbose helper 后改为按 UID 的目录，未改断言。该 wrapper 和 verbose-tests.sh 保留每组完整输出，方便计数，未改变测试断言。

最终四个入口均 exit=0（`suite-status.txt`；首次失败另存 `suite-status-initial.txt`）。R 容器未安装 Python 分析栈、也不嵌套启动 Docker，因此其 15 个 skip 包括 10 个 Python/环境分支、2 个 Windows junction、3 个 MCP 非当前引擎分支；对应 Python 数值与跨容器运行已在指定 Python image 和 host e2e 实跑。R 缺包 skip 为 0，A6a 两条已知失败仍保留。受版本控制的三份 test_report/e2e_report 仅移除终端 ANSI 颜色和行尾空格供阅读；scratch 的完整原始输出未改。

## 看过的图片

逐文件路径和 SHA256 清单：`/home/<user>/omic-sol61/verify_gptpro/figure-review-inventory.json`，五模块共 32 张最终 PNG；另补齐 limma-camera smoke 的 49 张（含 upstream fixture 图），合计 81 张。以下各 anchor 的 `figures/` 下列出文件均已打开：

| 模块 | anchor 目录（lane scratch/python-smoke/ 下） | 文件 |
|---|---|---|
| scanpy-qc | `scanpy-qc_o0yqj318`, `scanpy-qc_hoaaeq0g`, `scanpy-qc_qqm8hr2a`, `scanpy-qc_3_81ax3j` | `qc_metrics.png` |
| scanpy-cluster | `scanpy-cluster_ohqdamo_`, `scanpy-cluster_urw0n96n`, `scanpy-cluster_0xd66is_`, `scanpy-cluster_vff_vfsp` | `umap_clusters.png`, `umap_samples.png` |
| scanpy-markers | `scanpy-markers_07dqo773`, `scanpy-markers_qbtiuomz`, `scanpy-markers_z1c9m30y`, `scanpy-markers_8wphrym0` | `marker_dotplot.png` |
| scvi-integrate | `scvi-integrate_py0vpee3`, `scvi-integrate_w5zwiiax`, `scvi-integrate_7xozlcg9`, `scvi-integrate_h4kvdsxl` | `umap_after.png`, `umap_before.png` |
| scanvi-annotate | `scanvi-annotate_4p3sugzh`, `scanvi-annotate_3u86hb8w`, `scanvi-annotate_4k0y234u`, `scanvi-annotate_27_j1_6r` | `prediction_probability.png`, `umap_annotations.png` |

QC violin：分布清晰、全阈值在 caption；cluster UMAP：五簇和 sample 颜色可辨；marker dotplot：原漏画八点恢复、mean 图例正确；SCVI before/after：batch 图例可读；SCANVI：Predicted label 与 probability 图例清晰，低概率范围如实显示。limma-camera smoke 全部 49 张 PNG 逐张打开；barcode、gene-set bar、MD、upstream MDS/volcano/voom trend 均可读，没有空图、裁切或标签碰撞。`limma-pngs.txt` 为路径清单，`limma-figure-review.json` 为逐图 SHA/目视记录。目录计数：`a1`=4, `a1_guide_era`=4, `a2`=4, `cameraPR`=3, `cameraPR_voom`=3, `camera_dupcor_ack`=4, `camera_voom`=4, `dupcor_run`=4, `fromrun`=4, `fry`=4, `fry_dupcor`=4, `mroast`=4, `roast`=3。

所有 spec caption 确认细胞数/基因数/生物样本分母和实际阈值/参数；保存的 PNG SHA 与 figure_spec 一致。lint info（如灰度颜色接近）如实保留，不删除、不降低 severity。PNG 逐文件打开；不是用 hash 比较替代目视。

## 所有共享修改和偏离

- `skills/_shared/py/ospy/sc_module.py`：module_version 的 additive 传递；marker percentage 用正值细胞整数计数/n，避免稀疏 mean 的 >100 舍入而漏画 8 个 dots。
- `skills/_shared/scripts/render_figure_request.R`：QC metric label 类型与越界 cutoff 的展示修复，语义和完整 cutoff 保留。
- `mcp/server.py`、`mcp/test_publication.py`：预算 envelope 保持 lineage；legacy plain description 的只读展示兼容；增强 lineage、全部 module 摘要与 colon 回归断言。
- `tools/capture_locked_defaults.py`、`tools/test_build_contracts.py`：重复 capture 只读校验及真实漂移拒绝测试。
- `tools/check_calls.py`、`tools/test_check_calls.py`：singledispatch required 输入位置绑定与签名验证，统计选项必须命名规则保留。
- `tools/check_reference_integration.py`、`reference_service/tests/test_config.py`：历史生成资产 + 完整当前 map 的只读检查；未编辑 method_map/router/生成器。
- 五 Python 模块的 registry、版本及相应文档、goldens/locks/S3_REQUEST；limma-camera 仅其生成器合法刷新 golden/lock（GPT Pro R3 代码已经在输入）。
- 提交方式遵守 common 00:20 更新：不执行 git commit、不绕开只读 .git。外部 helper 每 10 分钟提交，lane worklog 的精确完成行就是提交记录；不自行 push。
- 偏离：无自主扩大实现范围。测试执行路径改到 lane scratch；不把绝对 symlink 目标在容器不可见或 HOME 选择错误当科学失败。无下载、无包安装；S0/verify/vendor 只读。

## 未做的工作

独立 S3/S5、全量教程科学有效性、跨平台/agent/盲测、三生态中立下游与其他 19 R 模块均超出本 lane；保留 owner items，并提交 S3_REQUEST。本 lane 要求的实跑、修复、锁定、图形和离线集成验证按上述日志交付。
