# omicstat 全面体检报告（2026-10-04）

执行方式与 medstat 的大修相同：协调者（Claude Fable 5.1）定规格、审高判断部分并直接修改；机械的大活交给 gpt-6.1-sol（medium，复核与盲读用 low）；每条 lane 走工作日志续跑协议，提交由沙箱外的助手完成。基线 `integrate/final`（= s3/m3m4 c2afafe，含 omicstat-r:2026.10.1 重建）；终点 `integrate/final` 6a88d3f。

## 1. 结果

| 项目 | 结果 |
|---|---|
| 模块 | 38 个分析模块 + 2 个自检全部装机（24 个 M3/M4 本轮新装；13 个 S3 不通过的模块经修复与独立复核后通过） |
| 模块锁 | 39/39 `--check` OK（终点提交上重新核验） |
| R 全套 `env/test.sh` | ALL PASSED，183 条命令，0 缺包跳过；仅 sva-batch A6a 两条已知失败锚点 |
| Python 全套 | `env/py/test.sh` 与 `tools/run_tests_py.sh` 各 31 条命令 ALL PASSED |
| MCP 端到端（宿主 stdio，两个容器） | 123/123 断言通过，3 项仅本地原生环境的跳过 |
| 路由盲测 G5 | 第 3 轮 123/133 = 92.5%（门槛 90%），含可接受 132/133 = 99.2%（门槛 98%）；见 `ROUTING_BLIND_EVAL.md` |
| reference 服务 | 重新部署 `omicstat-reference:20261004-s5-6a88d3f30e38`：749 篇 / 954 条用法；选项映射已对上 options.md；精选栏仍空 |
| 发布检出 | GT103 `~/omicstat`（6a88d3f）+ `~/omicstat-venv`；`mcp/test_client.py` 通过 |

## 2. 协调者直接修改的

| 提交 | 内容 | 为什么 |
|---|---|---|
| fed0c66 | MCP `qc_triggered` 阻断项排最前；紧凑信封带 QC/退化估计/警告计数 | 紧凑响应只保留前 8 条 QC，阻断项排在警告后面会被丢掉 |
| 1dae3e4 | batchelor-integrate、scran-markers SKILL 前言加引号；新增 `tools/check_skill_frontmatter.py` | 与 limma-voom 同类的 YAML 冒号缺陷，MCP 列表简介会变空 |
| 274b6fb（合并） | 从 medstat 移植 PUB-U-001 纳排流水、PUB-U-003 草稿数字溯源 | 两道质量门在真实运行上实测：DESeq2 Wald 草稿 39/45 个数字可溯源，Seurat QC 53/58；分母比对 0 不一致 |
| cf8cd9f、6a88d3f | 路由器 5 处消歧措辞；题库 5 条按政策更正；契约测试按 UTF-8 读题库 | 盲测从 88.7% 提到 92.5%，见盲测记录 |

## 3. 各 lane 的产出（报告都在 `docs/build/`）

- `FIX_R_REPORT.md`：8 个 R 模块按 S3 封闭清单开放参数；golden 全部未变；seurat-markers 的 Methods 写明实际检验（presto Wilcoxon）与 Bonferroni 校正。
- `FIX_PY_REPORT.md`：5 个 Python 模块参数开放、原生 CSV 补齐、按实际值填 Methods、重新封锁。
- `PORT_PUB_REPORT.md`：两道质量门的移植与测试（73 项，0 失败）。
- `S3_RECHECK_REPORT_m3m4.md`：13 个修复模块的独立复核。
- `S5_REPORT_m3m4.md`：装机、文档同步、M1/M2 的 options.md、reference 重导入、全套测试。
- `ROUTING_BLIND_EVAL.md`：三轮盲测与改动理由。

## 4. 协调者替所有者做的可逆决定

1. AUCell 与 GSVA 都不是"标准路线"，按输入分流：单细胞逐细胞活性 → aucell-score；bulk/伪 bulk 样本级 → gsva-score。
2. Python 前端接 R 中性后端：保留上游 `front_end_ecosystem`，记录 `backend_ecosystem: neutral`，加信息性 QC `OS_ECOSYSTEM_CROSSING`；`OS_ECOSYSTEM_MIXED` 仍是前端换生态的拒绝。
3. 五个 Python 模块复核时只剩"合并后共享作图文件变化导致锁失效"，按 PASS WITH NOTES 重新封锁后装机。

## 5. 仍待所有者的事项

见 SUITE.md「M3/M4 S2–S5」的开放项汇总；本报告不重复。另：盲测 R116 题库条目可疑；omic-s3-runs / omic-s3f-runs 两个审查证据目录（约 5 GB）是否保留。

## 6. 未做

- 真实数据的全流程盲用（M5）：计划与实验室介绍用的真实运行合并进行。
- `draft/number_sources.json` 的模块侧发射（让绘图常数也可溯源）：目前仅出版层提供读取机制。
