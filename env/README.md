# omicstat R 环境（独立，不依赖 medstat）

omicstat 的所有 R 引擎只在这里定义的环境里运行。唯一的版本来源是 [`omicstat-env.json`](omicstat-env.json)。

| 项 | 取值 | 依据 |
|---|---|---|
| R | 4.6.1 | Bioconductor 官方镜像 `RELEASE_3_23-R-4.6.1`（2026-08-11 发布）；2026-09-26 实拉镜像核对 `R.version.string` |
| Bioconductor | 3.23 | 当前 release（3.24 预计 2026 年 10 月）；镜像内 `BiocManager::version()` 核对 |
| 基础镜像 | `bioconductor/bioconductor_docker@sha256:821dbf9a…` | 按 digest 锁定，不随 tag 漂移；自带 Bioc 编译依赖、Ubuntu 24.04、Python 3.12 |
| CRAN | Posit Package Manager 日期快照 2026-09-15 | 基础镜像默认指向 `latest`，这里覆盖为固定日期 |
| GitHub 包 | monocle3、CellChat、immunedeconv | 首次构建时由 `pin_github.sh` 解析为 commit SHA 并提交，之后永不浮动；其传递依赖由 `--from-lock` 一并钉住 |
| 线程 | `OMP/OPENBLAS/MKL_NUM_THREADS=1` | 确定性（ENGINEERING_PLAN 锁 1） |
| 字体 | fonts-liberation（Liberation Sans = Arial 字宽） | 出图规范 FIGURE_STYLE.md §3 |

包按层安装（`layers/L0_base.txt` … `L7_figures.txt`），每层一个 Docker 层，安装后逐包自检。

## 两种形态

1. **容器 `omicstat-r:2026.10.4`（当前 owner 批准的生产 R 环境）**
   ```bash
   bash env/build.sh      # 读取 omicstat-env.json 构建；输出 env/pkg_lock.csv、env/image_id.txt
   bash env/test.sh       # 在镜像里跑全部测试 -> env/test_report.txt
   ```
   MCP 默认 `engine="container"`，经 `bin/omicstat-r-route.sh`（Linux/macOS）或 `.ps1`（Windows → WSL → docker）启动。
2. **原生隔离库（没有 docker 的机器）**
   ```bash
   Rscript env/native/setup_native.R     # 需 R 4.6.x；装到 <repo>/.omicstat-r/library
   ```
   引擎运行时由 `native/Rprofile.omicstat` 把库搜索路径限定为“omicstat 库 + R 基础库”，用户库、站点库（包括任何其他项目的 R 包）都不可见。MCP 用 `engine="native"`。原生形态只保证与容器“视觉一致”，字节级金标准以容器为准。

## 在小主机 GT103 上一键构建 + 测试

```bash
git clone -b claude/gallant-fermat-ifhpkl https://github.com/TOTO-git-q/omic-MCP.git ~/omic-MCP
cd ~/omic-MCP && bash env/gt103.sh
```

依次执行：钉住 GitHub 包 → 构建镜像 → 钉住传递依赖 → 容器内跑全部测试（含需要 `gt` 的 `test_render.R`）→ 容器内重新生成出图画廊 → 写 `env/BUILD_RECORD.md` 并提交推送。推送失败时，把 `env/pkg_lock.csv`、`env/layers/github_pins.txt`、`env/test_report.txt`、`env/BUILD_RECORD.md` 手动带回即可。

## 变更规则

改任何版本、层或包清单 → 升级 `env_version` 与 `image_tag` → 重建 → 重跑全部测试与各模块金标准 → 在 `SUITE.md` 记一节。
