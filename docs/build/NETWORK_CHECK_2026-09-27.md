# 网络与组件实测（2026-09-27，环境网络改为 Full 之后）

探测方法：从云端会话对 VENDOR_INTEGRATION_BRIEF §5 的每个域名做一次 `curl`（取前 200 字节）。200 / 206（部分内容）/ 30x = 可达。

## 1. 域名

| HTTP | URL | 结论 |
|---|---|---|
| 200 | `https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=DESeq2&format=json&pageSize=1` | 可达 |
| 200 | `https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=pubmed&id=25516281&retmode=json` | 可达 |
| 200 | `https://www.ncbi.nlm.nih.gov/` | 可达 |
| 429 | `https://api.openalex.org/works?search=DESeq2&per-page=1` | 可达（被限流：匿名请求被拒，需要 API key） |
| 403 | `https://openalex.org/` | 可达（站点本身返回 403；隧道已建立，不是代理拦截） |
| 200 | `https://api.crossref.org/works/10.1186/s13059-014-0550-8` | 可达 |
| 302 | `https://doi.org/10.1186/s13059-014-0550-8` | 可达 |
| 200 | `https://api.biorxiv.org/details/biorxiv/2020-01-01/2020-01-02/0` | 可达 |
| 206 | `https://ror.org/` | 可达 |
| 200 | `https://mygene.info/v3/gene/1017` | 可达 |
| 200 | `https://rest.ensembl.org/info/ping?content-type=application/json` | 可达 |
| 206 | `https://www.ensembl.org/` | 可达 |
| 206 | `https://rest.uniprot.org/uniprotkb/P04637.json` | 可达 |
| 206 | `https://reactome.org/ContentService/data/database/version` | 可达 |
| 200 | `https://cellguide.cellxgene.cziscience.com/` | 可达 |
| 200 | `https://ftp.ncbi.nlm.nih.gov/geo/` | 可达 |
| 200 | `https://ftp.ebi.ac.uk/pub/databases/` | 可达 |
| 206 | `https://cloud.r-project.org/src/contrib/PACKAGES` | 可达 |
| 200 | `https://packagemanager.posit.co/cran/2026-09-15/src/contrib/PACKAGES` | 可达 |
| 307 | `https://p3m.dev/` | 可达 |
| 206 | `https://bioconductor.org/packages/3.23/bioc/src/contrib/PACKAGES` | 可达 |
| 200 | `https://git.bioconductor.org/` | 可达 |
| 206 | `https://experimenthub.bioconductor.org/metadata/experimenthub.sqlite3` | 可达 |
| 206 | `https://annotationhub.bioconductor.org/metadata/annotationhub.sqlite3` | 可达 |
| 000 | `https://bioconductorhubs.blob.core.windows.net/experimenthub/muscData/Kang18_8vs8.rds` | 不通（网关 502） |
| 200 | `https://zenodo.org/` | 可达 |

补充说明：
- `bioconductorhubs.blob.core.windows.net` 返回 502，但它**已经不是** Bioconductor Hub 的存储地址：从 `experimenthub.sqlite3` 和 `annotationhub.sqlite3` 查到，现在的资源前缀是 `https://mghp.osn.xsede.org/bir190004-bucket01/{ExperimentHub,AnnotationHub}/`，实测可达（muscData/Kang18_8vs8.Rda 返回 206）。所以 ExperimentHub / AnnotationHub 数据可以下载。
- OpenAlex：`api.openalex.org` 能连通，但匿名请求返回 429；vendor 客户端本身要求 `OPENALEX_API_KEY`（README 写明匿名通道已经关闭）。没有 key 时，OpenAlex 这一路不可用，文献采集靠 Europe PMC + PubMed，DOI 靠 CrossRef。
- `openalex.org` 网页返回 403：站点自己拒绝脚本访问，不影响 API。

## 2. vendor 组件实测（`tools/lit/vendor_live_check.py`）

每组组件各做一次真实调用。运行时不在 vendor 目录写字节码，也不改动任何 vendor 文件；`SHA256SUMS.txt` 校验通过。

| 组件 | 结果 | 证据 |
|---|---|---|
| pubmed_search (esearch) | PASS | count=2 first=['41009942', '30395178'] |
| pubmed_fetch (efetch) | PASS | PMID 25516281 -> 'Moderated estimation of fold change and dispersion for RNA-seq data wi' / 'Genome biology' |
| europepmc_fulltext | PASS | PMC4302049 oa=True http=200 bytes=233850 sections=['Background', 'Results and discussion', 'Conclusions', 'Materials and methods', 'Acknowledgements', 'Abbreviations'] |
| openalex_works | SKIP | OPENALEX_API_KEY not set (vendored client requires a key) |
| literature-review verify_dois | PASS | {"10.1186/s13059-014-0550-8": "Moderated estimation of fold change and dispersion", "10.1093/bioinformatics/bty895": "Heavy-tailed prior distributions for sequence coun"} |
| mygene_query | PASS | [{"query": "TP53", "entrezgene": "7157"}, {"query": "DESI1", "entrezgene": "27351"}] |
| quickgo_annotations | PASS | P04637 BP annotations=155 keys=['query', 'params', 'total_items', 'n_records', 'complete', 'records'] |
| reactome_map | PASS | {"tool": "reactome-map", "reactome_version": "97", "id_type": "symbol", "species": "Homo sapiens", "n_input": 3, "genes": {"TP53": {"found": true, "n_lowlevel_pathways": 76, "pathways": [{"stId": "R-HSA-111448", "name":  |
| geo_meta | PASS | GSE52778 'Human Airway Smooth Muscle Transcriptome Changes in Response to Asthma' samples=16 |
| arrayexpress_experiments | PASS | records=5 keys=['total_hits', 'is_total_exact', 'records', 'params', 'truncated'] first=['E-MTAB-16003', 'E-MTAB-16580', 'E-MTAB-17688'] |
| mcp_cellguide | PASS | snapshot=1764612212 B cell description="{'description': 'B cells, also known as B lymphocytes, are a type of white blood" |

联系地址：发给 NCBI / EBI 的 `email` 参数和 User-Agent 读环境变量 `OMICSTAT_CONTACT_EMAIL`，默认是占位地址，不含个人邮箱。
