# omicstat

以“R 包中的一个分析部分”为模块单元的生信标准化分析体系：固定 R 引擎 + 自有 R 环境 + 统一出图 + MCP 调用。MCP、出版规则、合同等基础设施的架构借鉴自 medstat，但 omicstat **完全独立运行**：自己的 R 环境（[`env/`](env/)）、自己的共享层，不调用、不安装、不假设任何 medstat 组件。

- 权威设计：[`docs/handoff/ENGINEERING_PLAN.md`](docs/handoff/ENGINEERING_PLAN.md)（模块、冻结、skill、路由、门禁）与 [`docs/handoff/IMPLEMENTATION_SPEC.md`](docs/handoff/IMPLEMENTATION_SPEC.md)（基础设施分叉，§0/3/4/5/7 有效）
- 建设记录：[`SUITE.md`](SUITE.md)
- **出图规范：[`skills/_shared/docs/FIGURE_STYLE.md`](skills/_shared/docs/FIGURE_STYLE.md)**，示例画廊：[`docs/figure-gallery/`](docs/figure-gallery/)

## 当前状态：M0 地基完成，分析模块尚未建设

| 里程碑 | 状态 |
|---|---|
| M0 地基（MCP、合同、出版规则、`_shared` 组学件、**图形层**、脚手架与检查工具、环境自检模块） | ✅ 完成 |
| 独立 R 环境 `omicstat-r:2026.09.1`（R 4.6.1 + Bioconductor 3.23，定义与测试已完成） | ⏳ 待在 GT103 执行 `bash env/gt103.sh` 实际构建（本云端环境无法访问 CRAN/Bioconductor） |
| M1 bulk DE 8 个 · M2 富集 6 个 · M3a/M3b 单细胞 16 个 · M4 网络/突变/浸润 3 个 | ⏳ 未开始：每个模块需先走 S0 文献采集（PACK）→ S1 审定 → S2 建设 → S3 验收 → S5 装机 |
| M5 路由评测 · M6 审计发布 · M7 参考伴随服务 | ⏳ 未开始 |

## 出图为什么会“稳定且符合期刊惯例”

所有模块的图只能经 `skills/_shared/scripts/fig_*.R` 生成，模块里不允许出现任何颜色、字号、线宽、形状或位置的字面量。

| 层面 | 固定下来的内容 |
|---|---|
| 尺寸 | Nature / Cell / Science / generic 预设（单栏 89 mm、双栏 183 mm……），按印刷尺寸绘制，超高报错 |
| 字体字号 | Liberation Sans（与 Arial 等宽）；面板字母 8 pt 粗体、轴标题 7 pt、刻度 6 pt、数据标签 5.5 pt，下限 5 pt（lint 拦截） |
| 线条 | 轴 0.5 pt、数据线 0.75 pt、阈值线 0.5 pt 灰色虚线在数据层下、引线 0.25 pt；无网格无底色 |
| 形状 | 特征点 16 号 0.6 mm；样本点 21 号 2.2 mm 白描边；第二变量 21/24/22/23/25；截断值画三角 |
| 配色 | 上调 `#B2182B` / 下调 `#2166AC` / 不显著 `#BDBDBD` / 参照组 `#666666` 全系统固定；条件用 Okabe–Ito，类别 23 色，连续量 viridis，z-score 用 RdBu 对称 ±2 |
| 跨图一致 | 颜色登记表随 `--from-run` 传递：同一细胞类型在 UMAP、比例图、marker 图、热图注释里颜色相同 |
| 文字位置 | 面板字母左上外侧；图例右侧顶对齐；火山图计数在顶角且标签不会压到它；UMAP 左下角箭头轴、类别名写在中位点；热图行名在右、列名在下竖排 |
| 标签选择 | 每方向 padj 最小的 10 个，确定性并列规则，ggrepel 固定种子 + 白色光晕；基因名斜体；真减号 “−” |
| 可复现 | 同一输入重跑：PNG/SVG/`figure_spec.json` 逐字节相同，PDF 内容哈希相同（`test_figures.R` 150 项检查） |
| 图注 | 由画图用的同一份数据自动生成（阈值、计数、截断数、方法），组合图自动拼成 “**a**, … **b**, …” |

用法（模块作者）：

```r
source("skills/_shared/scripts/fig_all.R")
p <- os_volcano(feature_table, padj_threshold = 0.05, lfc_threshold = 1, contrast_label = "Treated vs control")
os_finalize_figure(p, "out/figures/volcano", width = "single")   # -> .pdf .png .figure_spec.json
```

## 目录

```
bin/            omicstat-r-route.ps1（Windows→WSL/Docker 或原生隔离库）与 .sh（Linux/macOS）
env/            独立 R 环境：omicstat-env.json（唯一版本来源）、分层包清单、Dockerfile、原生隔离库安装、GT103 一键脚本
mcp/            MCP 服务（5 个工具：omicstat_list_modules / describe / run / read / validate_publication）
skills/_shared/ scripts（fig_* 图形层、feature_table、handoff、calls_check、effect_table、报告渲染、
                args / engine_run / design_check 引擎合同）
                schemas、publication、docs（FIGURE_STYLE.md、CONVENTIONS.md…）、tests
skills/omicstat/ 路由器 SKILL.md（§1 路由表目前只有环境自检）
skills/omicstat-selftest/ 环境自检模块：检查 R/Bioc 版本、字体、线程、库隔离，并出一张标准图
templates/      新模块模板；tools/new_module.py 据此生成 skills/<pkg>-<part>/
tools/          new_module.py、check_calls.R、check_flag_docs.py、check_defaults.py、lint_r.py、qc_prefixes.json、run_tests.sh
docs/           handoff（设计文档）、fork（重命名日志）、figure-gallery（示例图）
reference/      交接包中的设计参照源码（只读文档，不参与任何运行）
```

## 运行测试

```bash
bash env/gt103.sh                                   # GT103：构建环境 + 容器内全部测试 + 画廊
bash env/test.sh                                    # 已有镜像时：容器内全部测试
bash tools/run_tests.sh                             # 任意机器：缺包的测试显式 SKIP
Rscript skills/omicstat-selftest/scripts/run_omicstat_selftest.R --outdir /tmp/selftest --strict   # 环境自检（8 条检查，写 environment_report.md）
Rscript skills/_shared/tests/make_figure_gallery.R  # 重新生成画廊，改动 token 后必须目视检查
```

## 2026-09-26 裁决记录

| 事项 | 裁决 |
|---|---|
| 与 medstat 的关系 | 不绑定：删除 medstat 临床统计共享件（forest / survey_design / var_typing / spec）及其测试；MCP 不再写死任何 R 安装路径；路由器 §4 改为“临床统计不在范围内，只导出打分表”；MCP 测试改用自有的 `omicstat-selftest` 模块 |
| R 环境 | 新建 `env/`：Bioconductor 官方镜像 `RELEASE_3_23-R-4.6.1` 按 digest 锁定（实拉核对 R 4.6.1 / Bioc 3.23 / Ubuntu 24.04）；CRAN 固定到 2026-09-15 日期快照；分 8 层安装；GitHub 包首次构建时钉 SHA；另提供不依赖 docker 的原生隔离库（只看得见 omicstat 库 + R 基础库） |
| 容器占位值（原待裁决 3） | 同上；ggrastr、gt 纳入 L7；monocle3 / CellChat / immunedeconv 的 SHA 在 GT103 首次构建时由 `pin_github.sh` 解析并提交 |
| 大数据 PDF（原待裁决 5） | > 50,000 点时只把点图层栅格化为 600 dpi（ggrastr），文字 / 坐标轴 / 图例保持矢量，图注自动披露；6 万细胞 UMAP 的 PDF 为 1.1 MB，且重跑内容一致 |
| 需要 `gt` 的测试（原待裁决 4） | 放到 GT103 的容器里跑（`env/gt103.sh`）；其他机器上缺包时显式 SKIP |

## 仍待确认

1. “全部显著”退化判据在只导出显著行、或只检验 1 个特征时也会触发；是否按行数设下限，留到 M1 用真实数据决定。
2. 期刊尺寸为常见公开值，投稿前请对照目标期刊当期要求核对。
3. 注册（`.mcp.json`、skill junction、Codex config）按规定由你执行；配置片段见 `mcp/README.md`。


## Release note

This tree is a clean export of the private development repository at `integrate/final`.
The vendored literature-retrieval clients (`vendor/`, used only by `tools/lit` during evidence collection) and the
medstat reference snapshots (`reference/`) are not included; the analysis modules, the MCP shell, the locked
environment recipes and the acceptance evidence do not depend on them. Host names, user names and session
identifiers of the development machines were replaced by placeholders.
