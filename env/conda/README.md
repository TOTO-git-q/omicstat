# 开发层环境（dev tier）

`env/conda/` 定义一套 conda（micromamba）R 环境，用来**在建不了锁定容器的机器上开发和测试模块**。例如云端会话访问不了 CRAN / Bioconductor，但能访问 conda.anaconda.org 和 GitHub。

| | 锁定容器（金标准） | 开发层 |
|---|---|---|
| 定义 | `env/omicstat-env.json`、`env/container/` | `env/conda/omicstat-dev.explicit.txt`、`setup_dev.sh` |
| R / Bioconductor | 4.6.1 / 3.23 | 4.5.3 / 3.22（bioconda） |
| GitHub 包 | `env/layers/github_pins.txt` | 同一批 commit |
| 注释数据 | 构建期固化（`refdata_registry.json`） | Bioconductor 3.22 正式数据包（GO.db、org.Hs.eg.db、org.Mm.eg.db、celldex）；msigdbr 基因集与 celldex 参考集缓存在用户目录（`refdata_registry.json` 中 `tier = dev` 的条目） |
| 金标准哈希 | 以此为准 | 只作开发期回归；S5 在容器里重新生成 |

## 构建

```bash
bash env/conda/setup_dev.sh            # 默认装到 /opt/mm/env/omicstat-dev
export PATH=/opt/mm/env/omicstat-dev/bin:$PATH
Rscript env/conda/check_dev.R          # 最后一行应为 DEV TIER OK
bash tools/run_tests.sh
```

## 注释与参考数据（2026-09-27 起，网络放开后）

| 数据 | 版本 | 来源 | 放在哪里 |
|---|---|---|---|
| GO.db | 3.22.0（go-basic.obo 2025-07-22） | bioconda `bioconductor-go.db`，安装后从 bioconductor.org 下载，md5 校验 | R 库 |
| org.Hs.eg.db / org.Mm.eg.db | 3.22.0（NCBI Gene 2025-Sep24） | bioconda，同上 | R 库 |
| celldex | 1.20.0 | bioconda，同上 | R 库 |
| celldex 参考集（hpca、blueprint_encode、monaco_immune、mouse_rnaseq、immgen） | gypsum 版本 2024-02-26（celldex 1.20.0 的默认值） | gypsum.artifactdb.com | `gypsum::cacheDirectory()`（环境变量 `GYPSUM_CACHE_DIR`，默认 `~/.cache/gypsum`） |
| msigdbr 基因集 | MSigDB 2026.1（由 msigdbr 26.1.1 钉定） | zenodo 记录 18968178，msigdbr 自己校验 md5 | `tools::R_user_dir("msigdbr", "cache")`（默认 `~/.cache/R/msigdbr`） |

- 版本、URL、许可、sha256 都登记在 `env/refdata_registry.json`（`tier = dev` 的条目）。
- **GO.db 替身已淘汰**：2016 年的替身（GO.db 3.4.0 数据）已删除，`setup_dev.sh` 第 5 步不再构建它；`check_dev.R` 发现版本低于 3.22.0 的 GO.db 就报 MISSING。
- 第 5 步的顺序：正常情况下第 1 步的 bioconda 安装后下载就装好了；没装上时先 `micromamba install --force-reinstall` 这几个 bioconda 构建，再不行就从 bioconductor.org 下 3.22 源码包，按登记表的 sha256 校验后 `R CMD INSTALL`。
- 两个缓存按用户存放，换用户或换 HOME 就要重新下载（`setup_dev.sh` 第 6 步）。下载一次之后离线可用（已用失效代理实测）。
- msigdbr 的数据版本写死在 msigdbr 包里（zenodo URL 和 md5），钉住 msigdbr 的版本就钉住了数据。数据里含 KEGG_LEGACY、KEGG_MEDICUS 子集（C2:CP:KEGG_*），按许可门控必须排除。
- `celldex::*Data(ensembl = TRUE)` 要从 AnnotationHub 取 EnsDb，这部分没有登记。
- airway、pasilla、parathyroidSE 仍用 github.com/bioc 镜像的版本（`deseq2-wald` 开发层金标准用的是这个 pasilla）；HDO.db 仍用 YuLab 仓库的 0.99.1。

## 这一层仍然没有的

- scRNAseq、muscData、TENxPBMCData：bioconda 有 Bioconductor 3.22 的构建，但没有装；数据在第一次使用时从 ExperimentHub 下载。单细胞锚点目前仍用 10x Genomics 在 AWS S3 上的公开数据（`acceptance/data/fetch_anchor_data.sh`，逐个校验 sha256），或按 muscat vignette 的做法用 `muscat::simData` 从真实数据模拟。
- 开发层是 Bioconductor 3.22，锁定容器是 3.23：这里登记的版本和哈希只代表开发层，容器构建时要重新登记。

## 环境签名

在开发层写出的 `golden_manifest.csv` 记录 `env_tier=dev`、R 与 Bioconductor 版本。冒烟测试比较时环境签名不一致，就把逐字节检查标为 SKIP 并说明原因，不报 FAIL（ENGINEERING_PLAN §3.5）。
