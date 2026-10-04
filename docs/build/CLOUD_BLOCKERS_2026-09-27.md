# 云端碰壁记录（2026-09-25 至 09-27）

**结论**：这个云端会话的网络策略拦截了 R 生态的官方软件源、Bioconductor 的数据中心，以及全部文献数据库。所以锁定容器建不了，S0 的文献检索（L3/L4）也做不了。底座（开发环境、共享层、工具、样板模块 `deseq2-wald`）已经用能访问的来源搭完；剩下的 32 个模块按你的决定，等本机做完文献检索后再建。

## 1. 被拦截的地址（实测）

判定依据：`curl` 返回 000 或 403，代理日志记为 `connect_rejected`（策略拒绝）。

| 地址 | 原本用来做什么 | 受影响的环节 |
|---|---|---|
| `cloud.r-project.org`（CRAN） | 装 CRAN 包 | 锁定容器构建（`env/build.sh`） |
| `packagemanager.posit.co`（Posit PM 日期快照） | 锁定环境的 CRAN 来源（快照 2026-09-15） | 同上 |
| `bioconductor.org`、`git.bioconductor.org` | Bioconductor 3.23 软件包与数据包 | 同上；bioconda 数据包的安装后下载也失败 |
| `depot.galaxyproject.org`、`bioarchive.galaxyproject.org` | bioconda 数据包的两个备用下载源 | airway、pasilla、org.Hs.eg.db、GO.db、celldex 等在 conda 环境里装不上 |
| `experimenthub.bioconductor.org`、`bioconductorhubs.blob.core.windows.net` | ExperimentHub / AnnotationHub 数据 | celldex 参考集、scRNAseq、muscData、TENxPBMCData、GSVAdata 等单细胞与示例数据 |
| `zenodo.org` | msigdbr 第一次使用时下载基因集 | MSigDB 基因集 |
| `current.geneontology.org`、`purl.obolibrary.org`、`ftp.ebi.ac.uk`、`ftp.ensembl.org`、`reactome.org`、`rest.kegg.jp`、`www.gsea-msigdb.org`、`data.broadinstitute.org`、`maayanlab.cloud`、`omnipathdb.org` | 注释与基因集原始数据 | 没法在云端自建注释库 |
| `www.ebi.ac.uk`（Europe PMC REST） | L3/L4 范本检索（ENGINEERING_PLAN §2.2） | **S0 文献层完全做不了** |
| `eutils.ncbi.nlm.nih.gov`（PubMed efetch）、`ftp.ncbi.nlm.nih.gov`（GEO） | PMID 验真；GEO 数据 | 同上；没有一条引用能按规定验真 |
| `cf.10xgenomics.com`、`seurat.nygenome.org`（SeuratData）、`figshare.com`、`huggingface.co` | 单细胞公共数据 | 单细胞锚点数据 |
| `quay.io`、`api.anaconda.org` | BioContainers 镜像；anaconda 搜索 API | 找不到带完整注释数据的现成构建 |
| `github.com` 网页和 `api.github.com`（curl 直接访问） | 浏览仓库、查 tag | 不影响 `git clone`，见下 |

网页抓取工具（WebFetch）访问 Europe PMC 和 NCBI 同样被拒绝；网页搜索（WebSearch）能用，但只返回标题和链接，达不到“PMID 用 efetch 回显核对”的要求，所以没有用它充当文献证据。

## 2. 能用的来源，以及用它们做了什么

| 可用来源 | 用途 |
|---|---|
| `conda.anaconda.org`（conda-forge、bioconda） | 开发层 R 环境：R 4.5.3 + Bioconductor 3.22 全部软件包（`env/conda/`） |
| `git clone https://github.com/...`、`raw.githubusercontent.com` | CellChat、immunedeconv 及其 5 个依赖、NMF 0.28 按固定 commit 安装；数据包从 `github.com/bioc/<包名>` 镜像安装（airway、pasilla、parathyroidSE）；HDO.db 从 YuLab 官方仓库安装；约 30 个参考仓库（nf-core、rnaseqGene、RNAseq123、OSCA、Seurat 等）用于设计参考 |
| Docker Hub（`registry-1.docker.io`） | 官方 BioContainers 镜像 `bioconductor-go.db:v3.4.0`：取出 GO.sqlite，做成 GO.db 替身，**只为让 clusterProfiler 能加载** |
| AWS S3 `s3-us-west-2.amazonaws.com/10x.files/` | 10x pbmc3k、pbmc4k（`acceptance/data/fetch_anchor_data.sh`，校验 sha256） |
| 已安装包自带的文档 | L1 证据（vignette 原文和渲染后的打印值、Rd、NEWS、CITATION）：`tools/collect_l1.R` |

## 3. 仍然存在的影响

1. **锁定容器没有构建**：金标准环境（R 4.6.1 / Bioconductor 3.23）还没出现过。`deseq2-wald` 的金标准哈希是在开发层写的，环境签名为 `dev|R 4.5.3|Bioc 3.22`。容器建好后必须重新生成；签名不同时，测试会显式 SKIP，不会误报失败。
2. **S0 文献层（L3/L4）为空**：`deseq2-wald` 的 PACK 里 V 节（变体频次）和 D 节第 ③ 列（范本多数派）都标着“未采集”。现在所有默认值都依据软件包的官方文档和官方工作流；S1 裁决（例如 `alpha = 0.05`）都记在 PACK 末尾，等文献采集完需要逐条复核。
3. **注释数据缺失**：开发层没有 OrgDb 和 MSigDB 数据，GO.db 是 2016 年的替身。依赖它们的测试只在容器里跑。**替身 GO.db 绝不能用来出结果。**
4. **单细胞示例数据缺失**：celldex、scRNAseq、muscData 在云端都拿不到；以后建单细胞模块时，锚点要改用 10x 的 S3 数据或包自带的模拟器。
5. **32 个分析模块没有建**：按你的决定，文献检索完成后在本机建设（步骤见 `docs/build/MODULE_BUILD_BRIEF.md`）。

## 4. 两种解决办法

**A. 放行域名，让云端继续做。** 在这个云端环境的设置里修改 Network access（会话标题栏里的环境菜单 → Edit），可以提高访问级别，也可以只把下面这些域名加入允许列表：

```
cloud.r-project.org
packagemanager.posit.co
bioconductor.org
git.bioconductor.org
experimenthub.bioconductor.org
annotationhub.bioconductor.org
bioconductorhubs.blob.core.windows.net
zenodo.org
www.ebi.ac.uk
eutils.ncbi.nlm.nih.gov
ftp.ncbi.nlm.nih.gov
```

前 7 个用来建锁定容器和取注释数据，后 4 个用来检索和验真文献。

**B. 回本机做**（你选的路线）：

1. 小主机 GT103 上运行 `bash env/gt103.sh`：建锁定容器，在容器里跑全部测试（包括 `gt`），并运行 `--strict` 自检。
2. 在容器里重新生成 `deseq2-wald` 的金标准：`OMICSTAT_WRITE_GOLDEN=1 Rscript skills/deseq2-wald/tests/run_smoke_test.R`，然后 `Rscript tools/make_module_lock.R deseq2-wald`。它会先用 `check_default_drift` 核对 Bioconductor 3.23 里的函数默认值有没有变。
3. 做 S0 的 L3/L4：Europe PMC 分节检索 → 期刊白名单 → PMID efetch 验真。先补 `deseq2-wald` 的 PACK（V 节、D 节第 ③ 列），复核 S1 裁决；再做其余模块。
4. 按 `docs/build/MODULE_BUILD_BRIEF.md` 建剩下的 32 个模块，以 `skills/deseq2-wald/` 为样板。
