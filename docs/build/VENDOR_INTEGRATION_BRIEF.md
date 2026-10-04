# 任务书：接入 Claude Science 检索组件，补齐文献、注释与锚点数据层（2026-09-27）

写给云端会话。背景：`CLOUD_BLOCKERS_2026-09-27.md` 记录的网络拦截，由用户在环境设置里放行域名来解决（清单见 §5）；同时用户决定把本机 Claude Science 的检索组件原样搬进仓库，让 omicstat 自己用上这套检索能力。组件在分支 `vendor/claude-science-bio-tools` 的 `vendor/claude_science/`，**先读它的 README.md**（来源、许可、使用规则）。

## 0. 硬规则

- 仓库已经转为**私有**；`vendor/claude_science/bio_tools/` 没有开源许可，只能内部使用。不要把它复制到任何公开位置。
- vendor 文件**只读**：一律在外面包一层来调用。确实要改，就在 vendor README 里写明改动和理由，并更新 `SHA256SUMS.txt`。
- 许可门控保持开启：不接 KEGG、CADD、PanglaoDB、DepMap。
- 这些 Python 组件只用于 S0 采集和构建期取数，**不做分析引擎**。分析模块运行时照旧离线（ENGINEERING_PLAN §1.4）。
- 文献纪律照 ENGINEERING_PLAN §2.2：只取开放获取全文；PMID/DOI 必须实测回显核对；持久化只保存 ≤25 词的片段、节定位和哈希；**不凭记忆写任何引用**。
- 其余纪律照 `MODULE_BUILD_BRIEF.md` 和 worklog 续跑协议。

## 1. 先做：网络与组件实测

1. 把分支 `vendor/claude-science-bio-tools` 合进你的工作分支（它只新增 `vendor/` 和本文件，不改动现有文件）。
2. 对 §5 的每个域名做一次 `curl` 探测，结果记进 `docs/build/NETWORK_CHECK_<日期>.md`。仍被拦截的列出来，报告给用户。
3. 按 `vendor/claude_science/requirements.txt` 装好依赖，对每组组件各做一次真实调用：PubMed 检索 + efetch、Europe PMC 全文、OpenAlex、CrossRef 的 `verify_dois`、mygene、QuickGO、Reactome、GEO、ArrayExpress、CellGuide，并记下结果。

## 2. 文献层（S0 L3/L4）：这次的重点

1. 在 `tools/` 下建 omicstat 自己的采集工具，调用 vendor 客户端，实现 ENGINEERING_PLAN §2.2：
   - Europe PMC 分节检索（按方法节检索）；
   - ISSN 期刊白名单（`journals.json`，每个 ISSN 实测核验）；
   - 每个模块一份检索画像（`discovery_profiles.json`，检索式写包名 + 分析部分特征词）；
   - 方法节正文信号正则；
   - PMID efetch 回显核对；
   - 许可规则。
   - 设计上照 `reference/medstat-reference/` 的做法（只借结构，不依赖 medstat 运行）。
2. 先用 `deseq2-wald` 试跑：补 PACK 的 L3（8–10 篇精读）、L4（20–30 篇广度），填 V 节和 D 节第 ③ 列。按 S1 附录逐条复核之前的裁决；多数派与现值不同的参数列入"待裁决"交给用户，**不自行改默认值**。
3. 再按族推进 M1 其余 7 个模块的 L1–L4 采集。

## 3. 注释与参考数据层

- 引擎用的注释照旧走 Bioconductor 数据包（OrgDb、GO.db、msigdbr 等），域名放行后改用正式版本，**淘汰 2016 年的 GO.db 替身**。
- vendor 的注释客户端（mygene、BioMart、Ensembl REST、QuickGO、OLS、Reactome、UniProt）用于：
  - ID 映射规则的交叉核对（CONVENTIONS §8）；
  - 登记参考数据的版本和来源（`env/refdata_registry.json`：ID、版本、URL、许可、sha256）；
  - 单细胞注释模块的 marker 参照（CellGuide）。
- 这些数据接入容器的哪一层、接入方式是否偏离 ENGINEERING_PLAN §3.1，先写进"待裁决"，不自行决定。

## 4. 锚点数据

用 `geo_meta` / `arrayexpress_experiments` 查找并登记各模块锚点要用的公共数据集。优先顺序：vignette 自带的数据 → 官方 workflow 用的数据 → 其他公共数据。每个数据集进入 `acceptance/data/fetch_anchor_data.sh` 时都带登录号、URL 和 sha256。

## 5. 需要用户放行的域名（用户在环境设置 → Network access 中操作）

```
# 文献
www.ebi.ac.uk
eutils.ncbi.nlm.nih.gov
www.ncbi.nlm.nih.gov
api.openalex.org
openalex.org
api.crossref.org
doi.org
api.biorxiv.org
ror.org
# 注释
mygene.info
rest.ensembl.org
www.ensembl.org
rest.uniprot.org
reactome.org
cellguide.cellxgene.cziscience.com
# 锚点数据文件
ftp.ncbi.nlm.nih.gov
ftp.ebi.ac.uk
# R 包与 Bioconductor 数据（CLOUD_BLOCKERS §4 A）
cloud.r-project.org
packagemanager.posit.co
p3m.dev
bioconductor.org
git.bioconductor.org
experimenthub.bioconductor.org
annotationhub.bioconductor.org
bioconductorhubs.blob.core.windows.net
zenodo.org
```

## 6. GT103 锁定容器的现状（供参考）

- 小主机按 `env/gt103.sh` 建好了 `omicstat-r:2026.09.1`：锁定 530 个包，镜像 ID `sha256:410f4c27e708…`，`omicstat-selftest --strict` 退出码为 0。
- 构建用的是提交 `89f3696`（比 `642a1c8` 落后 13 个提交）。之后 GitHub 包钉的 commit 没有变，只由 `--from-lock` 补钉了 BPCells、speedglm 两个传递依赖。
- 容器内 R 测试全部通过。MCP 的 Python 测试有 4 项没过（1 个失败、3 个报错），都出在读取仓库状态和来源记录，报错为 `test repository state is unavailable`。推测是容器里读不到 git 状态，尚未核实。请你查原因并修测试或修脚本。
- 锁文件和测试报告还在小主机的工作区里，没推送（小主机没配 git 身份，远端又已前进）。本机会话会另行处理。金标准照旧在容器里重新生成。

## 7. 回报

完成后在 `SUITE.md` 记一节，并在对话里给用户中文回报：
- 网络探测结果；
- 各组件实测结果；
- `deseq2-wald` 的 L3/L4 结论与待裁决项；
- M1 采集进度；
- 偏离之处（没有就写"无"）。
