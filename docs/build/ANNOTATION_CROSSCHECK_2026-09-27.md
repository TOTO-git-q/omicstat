# org.Hs.eg.db 与 mygene.info 的 ID 映射交叉核对（2026-09-27）

对应 CONVENTIONS §8（基因 ID）。范围按用户压缩后的预算做了一个 **100 个基因** 的快速核对，不是原定的 200 个。

## 方法

- 本地：开发层 `org.Hs.eg.db` 3.22.0（NCBI Gene 2025-Sep24、Ensembl 2025-Sep03）。在 `GENETYPE == "protein-coding"` 的 20,595 个 Entrez ID 里用 `set.seed(20260927); sample(pc, 100)` 抽样，取出 SYMBOL 和 ENSEMBL（116 行，1 对多）。
- 远端：vendor 的 `mygene_query.MyGeneQueryClient`（只读导入，`PYTHONDONTWRITEBYTECODE=1 /opt/retrieval-venv/bin/python`；请求里不带任何邮箱），`getgenes(ENTREZID, fields=symbol,ensembl.gene)` 和 `querymany(SYMBOL, scopes=symbol)`。mygene 数据版本：build 20260906，NCBI Gene 源 20260904，Ensembl 116。
- 比较口径：SYMBOL 逐字相等；ENSEMBL 以集合比较（每个 Entrez ID 的全部 Ensembl gene ID）；SYMBOL→ENTREZID 以集合比较。

## 结果

| 方向 | 一致 | 说明 |
|---|---|---|
| ENTREZID 在 mygene 中存在 | 100/100 | |
| ENTREZID → SYMBOL | 100/100 | |
| ENTREZID → ENSEMBL（集合完全相同） | 98/100 | 其中 4 个 `LOC` 基因两边都没有 Ensembl ID |
| SYMBOL → ENTREZID（集合完全相同） | 100/100 | |

## 两处不一致

1. **LGALS9C（Entrez 654346）**：org.Hs.eg.db 比 mygene 多一个 `ENSG00000168961`，mygene 把这个 ID 归给 **LGALS9**（Entrez 3965）。两边共有的另外 2 个 ID 一致。性质：旁系同源基因之间的一对多映射，org.Hs.eg.db 把另一个基因的 Ensembl ID 也挂了上来。
2. **LOC124906603（Entrez 124906603）**：org.Hs.eg.db 给了 7 个 Ensembl ID，mygene 一个都没有。这 7 个 ID 在 mygene 里分别属于 SPDYE8、SPDYE9、SPDYE10、SPDYE11、SPDYE14、SPDYE15、SPDYE17（均为 protein-coding）。性质：多拷贝基因家族里的一对多映射。

## 对 CONVENTIONS §8 的含义（供 PACK 裁决，不在此自行定规则）

- 在这个样本里，SYMBOL 与 ENTREZID 双向完全一致；差异都出在 **ENTREZID → ENSEMBL 的一对多**上，而且集中在旁系同源基因或多拷贝家族。
- 抽样的 100 个基因里，有 10 个在 org.Hs.eg.db 里对应多个 Ensembl ID，4 个没有 Ensembl ID。以 Ensembl 为内部键（§8）时，一对多和缺失的处理规则会直接影响映射丢失率（> 5% 为 QC 警告），需要各模块的 PACK 裁决。
- 两边的数据时间不同（org 2025-09，mygene 2026-09），少量差异也可能来自版本差。
- 局限：样本只有 100 个，只抽了 protein-coding，只核对了人类。

原始数据在会话暂存目录，没有入库：`xc_org_fwd.csv`、`xc_org_rev.csv`、`xc_mygene_raw.json`。
