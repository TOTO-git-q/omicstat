# 本机继续构建指南

本文件写给在自己电脑或小主机 GT103 上接手 omicstat 的人（或 agent），说明从拉取代码到建出第一批分析模块的全部步骤。
项目的权威设计文档是 [`docs/handoff/ENGINEERING_PLAN.md`](handoff/ENGINEERING_PLAN.md)；当前进度见 [`SUITE.md`](../SUITE.md)。

## 0. 当前状态（截至本分支最后一次提交）

| 部分 | 状态 |
|---|---|
| 出图系统（`skills/_shared/scripts/fig_*.R`，规范 `skills/_shared/docs/FIGURE_STYLE.md`；31 种单图 + 组合图，含统计标注、色觉检查） | 完成，测试通过 |
| MCP 服务（`mcp/`，5 个工具） | 完成；原生引擎的端到端测试通过；容器引擎的测试要等镜像建好 |
| 共享件：结果表、`--from-run` 交接、调用登记检查、参数规范、设计校验、警告捕获 | 完成，测试通过 |
| 环境自检模块 `omicstat-selftest` | 完成 |
| **锁定 R 环境**（`env/`，金标准） | **只有定义，尚未构建**：云端访问不了 CRAN / Bioconductor（见 `docs/build/CLOUD_BLOCKERS_2026-09-27.md`）；GitHub 包已钉到 commit |
| 开发层 R 环境（`env/conda/`） | 在云端建好并测试通过（R 4.5.3 / Bioconductor 3.22），只用于开发 |
| 分析模块 | **1 / 33**：`deseq2-wald`（样板：锚点与 vignette 打印值一致；金标准待在容器里重新生成；文献层 L3/L4 待补） |

## 1. 拉取代码

```bash
git clone -b claude/gallant-fermat-ifhpkl https://github.com/TOTO-git-q/omic-MCP.git omic-MCP
cd omic-MCP
```

`reference/` 是交接包里的设计参照源码，只读，不参与运行。

## 2. 构建 R 环境（二选一）

### 方案 A：Docker 镜像（推荐；金标准所在环境）

需要 Docker 和外网。Linux 或 GT103 上直接执行：

```bash
bash env/gt103.sh
```

这一条命令依次完成：
1. 把 monocle3、CellChat、immunedeconv 钉到具体 commit；
2. 构建 `omicstat-r:2026.09.1`；
3. 在镜像里跑全部测试，包括需要 `gt` 的 `test_render.R`；
4. 重新生成出图画廊；
5. 以 `--strict` 运行环境自检；
6. 写 `env/BUILD_RECORD.md` 并提交推送。

**判定标准**：最后退出码为 0，并且 `env/BUILD_RECORD.md` 里 selftest 的退出码是 0。

Windows 机器用 WSL2 + Docker Desktop：在 WSL 的 Linux 终端里执行上面的命令。之后 MCP 会通过 `bin/omicstat-r-route.ps1` 调用 `wsl -e docker`。

只想构建、不想自动提交时，分步执行：

```bash
bash env/pin_github.sh      # 第一次需要；之后提交 env/layers/github_pins.txt
bash env/build.sh           # -> env/pkg_lock.csv、env/image_id.txt
bash env/test.sh            # -> env/test_report.txt
```

### 方案 B：不用 Docker 的隔离本地库

需要本机装有 R 4.6.x。

```bash
Rscript env/native/setup_native.R        # 装到 <repo>/.omicstat-r/library，并写 .omicstat-r/native-env.json
OMICSTAT_R_NATIVE=1 bash bin/omicstat-r-route.sh Rscript skills/omicstat-selftest/scripts/run_omicstat_selftest.R --outdir /tmp/st --strict
```

原生库只保证与容器“视觉一致”，字节级金标准以容器为准（ENGINEERING_PLAN §3.5）。

## 3. 验证

```bash
pip install -r mcp/requirements.txt
bash tools/run_tests.sh
```

在镜像内（`bash env/test.sh`）应当全部 PASS，没有 SKIP。在普通机器上，缺包的测试会显式标 SKIP。

## 4. 注册 MCP

**Claude Code**（项目根目录的 `.mcp.json`，或 `claude mcp add`）：

```json
{
  "mcpServers": {
    "omicstat": {
      "command": "python",
      "args": ["<仓库绝对路径>/mcp/server.py"],
      "env": { "OMICSTAT_WORKSPACE": "<你的数据目录>" }
    }
  }
}
```

**Codex**（`~/.codex/config.toml`）：

```toml
[mcp_servers.omicstat]
command = "python"
args = ["<仓库绝对路径>/mcp/server.py"]
env = { OMICSTAT_WORKSPACE = "<你的数据目录>" }
```

路由 skill 在 `skills/omicstat/`，各模块 skill 在 `skills/<module>/`，链接或复制到你的 skills 目录即可。

注册后应看到 5 个工具。用 `omicstat_run(module="omicstat-selftest", args={"strict": true})` 验证整条链路。
其他环境变量（`OMICSTAT_RUNS_ROOT`、`OMICSTAT_IMAGE`、`OMICSTAT_NATIVE_ENV`）的说明见 `mcp/README.md`。

## 5. 建设分析模块（M1 → M4）

**先读 `docs/build/MODULE_BUILD_BRIEF.md`**（每个模块的完整步骤和检查清单），并以 `skills/deseq2-wald/` 和 `acceptance/exemplars/deseq2-wald/PACK.md` 为样板。第一件事是补 `deseq2-wald` 的 L3/L4，并在容器里重新生成它的金标准。

建议顺序：先做 **M1 bulk 差异表达**（`deseq2-qc`、`deseq2-wald`、`deseq2-lrt`、`edger-qlf`、`limma-voom`、`limma-array`、`limma-dupcor`、`sva-batch`）。它不依赖单细胞生态，后面的富集和 pseudobulk 模块都要复用它的引擎。

每个模块走 ENGINEERING_PLAN 第七部分的 S0–S5。下表列出每一步对应的现成工具：

| 步骤 | 做什么 | 工具 / 位置 |
|---|---|---|
| S0 采集 | ① **L1**：锁定版本随包附带的 vignette、Rd、NEWS。在镜像里用 `system.file("doc", package = "DESeq2")` 导出，或从 `https://github.com/bioc/<包名>` 的 `RELEASE_3_23` 分支读取。<br>② **L3 / L4**：高质量期刊的方法段与参数取值，通过 Europe PMC / PubMed 检索，PMID 必须用 efetch 回显核对。可复制 `reference/medstat-reference/` 的采集代码为 omicstat 自己的实例（只借代码，不依赖 medstat 运行） | 产出 `acceptance/exemplars/<module>/PACK.md`（T / F / W / V / C / D / X 七节） |
| S1 冻结 | 由你审定 PACK，裁决 D 节里“函数默认值 / vignette 推荐 / 范本多数派”三方不一致的参数 | PACK 末尾写“S1 审定附录” |
| S2 建设 | 生成骨架，然后按 PACK 填写引擎、`calls_registry.json`、QC 规则、SKILL.md、references、冒烟测试 | `python tools/new_module.py deseq2 wald` → `skills/deseq2-wald/`；图一律调用 `_shared/scripts/fig_*.R` |
| S2 自检 | 调用登记与默认值漂移、参数文档覆盖率、默认值一致性、R 代码 lint | `Rscript tools/check_calls.R skills/<m>`；`python tools/check_flag_docs.py skills/<m>`；`python tools/check_defaults.py skills/<m>`；`python tools/lint_r.py` |
| S3 验收 | 由没有参与构建的 agent 核对锚点、表格、文字、机械检查，并**亲眼看每一张图** | 对照 PACK 各小节 |
| S5 装机 | 生成金标准哈希与 `module_lock.json`；在路由器 `skills/omicstat/SKILL.md` §1 加一行；在 `module_rules_v1.json` 加一条记录；在 SUITE 记一节 | MCP 会自动从 §1 读到新模块 |

**纪律**（ENGINEERING_PLAN 第三部分）：
- 所有影响结果的参数都在调用处显式写出；
- 随机性一律接受 `--seed`；
- 没有可复现的统计错误，不改估计方法和默认值；
- 调研报告 `docs/research/plotting-software-survey.md` 中标“需要证据”的建议，必须先在 PACK 里找到依据。

## 6. 模块之后

- **M5**：路由评测集（≥ 60 条问题，首选命中 ≥ 90%）；端到端流水线测试（两条单细胞生态线都要跑）。
- **M6**：一次统一审计 → 一次集中整改 → 全部门禁（ENGINEERING_PLAN 第八部分）。
- **M7**：在 GT103 上部署参考伴随服务 `omicstat_reference`。
