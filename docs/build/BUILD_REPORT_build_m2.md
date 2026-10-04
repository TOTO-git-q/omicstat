# build_m2 S2 建设报告（2026-09-28）

工作树 `/home/<user>/omic-build-m2`，分支 `build/m2`。本报告仅覆盖 clusterprofiler-ora、clusterprofiler-gsea、clusterprofiler-compare；fgsea-prerank、gsva-score、limma-camera 已由所有者移交 M2b。三个模块均完成 S2，金标准与 `module_lock.json` 均由锁定容器 `omicstat-r:2026.09.1` 生成，并各自提交。未开展独立 S3 或安装 S5。

## 需要所有者处理的事项（优先）

1. **离线参考数据 M1-3**：`env/refdata_registry.json` 的 `go_annotation` 条目尚无容器资产散列与最终许可/再分发证据。容器中实际安装 org.Hs.eg.db 和 GO.db 3.23.1；三个模块只使用已登记且安装的 GO。MSigDB、Reactome、KEGG 没有经本轮批准的离线集合，相关请求均返回 `OS_REFDATA_MISSING`；未内置 KEGG 内容。`enrichit` 0.2.1 已同时见于 `env/pkg_lock.csv` 和容器，M2-2 的版本存在性得到核实，来源构建证据仍由基础设施验收负责。
2. **ORA/compare 全表口径**：两个模块为保留所有可检验的 term，在计算调用中同时设 `pvalueCutoff = 1`、`qvalueCutoff = 1`，原始 P、BH adjusted P、q-value 分列，另标 BH 0.05。请裁决此做法与 PACK D-O5、D-C3 所列函数默认 0.05/0.2 的衔接。零重叠、未映射或大小过滤后的集合未受检验，草稿已说明。
3. **GSEA 下游参数 API**：锁定版 clusterProfiler 4.20.0 的 `GSEA`/`gseGO` 均未将 `...` 传给 `enrichit::gsea_gson`。因此 enrichit 的 `eps = 1e-10`、`sampleSize = 101`、`nPermSimple = 1000`、`scoreType = "std"`、`weight = NULL`、`seed = FALSE` 是容器锁定默认，不能经当前 wrapper 在调用点显式指定。本模块在 `gseGO` 前 `set.seed(20260925)`；enrichit 的 `seed = FALSE` 路径从 R RNG 抽取种子，两次新进程运行主表和 PNG 逐字节一致。请裁决该版本限制是否接受，或是否需调整 API；`eps` 未当作容差。
4. **DE 排名交接**：本分支的 deseq2-wald 1.1.0 交接文件未列 `ranked_list`，与 lane 任务说明不一致。GSEA 优先读取有类型和散列校验的 `ranked_list`；缺失时仅对 deseq2-wald/limma 的单一方向 contrast，从 `feature_table` 提取全部有限 `stat`，不按显著性筛选。合并上游分支时请核对交接字段。
5. **compare 范例原始背景**：PACK C 所引 `gcSample` 书中调用没有可追溯的合格背景。S2 回放把每个 `gcSample` 列表限制到 DOSE `geneList` 资格全集后使用该明确背景；不声称复现原书默认全注释背景下的数值。若需原书数值验收，须补其原始可选基因总体。

## 各模块 S2 状态与锚点

| 模块 / S2 提交 | 锚点、来源、结果 | 容器测试与金标准 | 图件与开放点 |
|---|---|---|---|
| `clusterprofiler-ora` / `437c741` | PACK C、`ANCHOR_REGISTRY.md` 第 9 行；DOSE `geneList`，`abs(score)>2` 入选，全部 12,495 个 rankable ID 为显式资格背景。输入 207，OrgDb 映射背景 12,439，GO 有效输入 194、有效背景 11,525；检验 2,588 term，BH 0.05 下 154。首行 GO:0140014，padj `1.69548321341e-16`。同会话 `enrichGO` 回放 PASS。 | registry/formals/defaults/flag 文档/R lint PASS；缺背景、缺 KEGG、ALL 缺 pool、篡改上游均类型化拒绝；`--from-run` 与直接输入一致；主表和 PNG spec 回放逐字节一致；独立非写入 smoke 的 golden PASS；lock 核对 PASS。 | `ora_dotplot.png` 已打开：15 个 term 标签和图例可读、无遮挡或裁切；图注/spec 有阈值与数量。待裁决全表 cutoff 和 GO 资产证据。S3 请求见 `acceptance/exemplars/clusterprofiler-ora/S3_REQUEST.md`。 |
| `clusterprofiler-gsea` / `e69bdc6` | PACK C、`ANCHOR_REGISTRY.md` 第 10 行；DOSE `geneList` 全部 12,495 个带名称、方向的排序 ID，GO BP、enrichit multilevel。检验 5,299 set，BH 0.05 下 715；首行 GO:0000819，NES `2.89486744`、padj `8.02878788e-09`。同会话 `gseGO` 回放 PASS。 | registry/formals/defaults/flag 文档/R lint PASS；排序缺方向、LRT/F 无方向统计量、缺 KEGG、篡改上游拒绝；`ranked_list` 交接匹配直接输入；探索性 BH 0.25 与 20 基因最小集合 flag 有效；主表和两个 PNG 新进程逐字节相同；独立非写入 golden PASS；lock 核对 PASS。 | `gsea_dotplot.png` 与 `gsea_curve.png` 已打开：标签、图例、三个曲线轨道可读，无重叠或裁切；图注/spec 有阈值、排名基因数、集合数。待裁决 wrapper 下游参数、上游交接和 GO 资产。S3 请求见 `acceptance/exemplars/clusterprofiler-gsea/S3_REQUEST.md`。 |
| `clusterprofiler-compare` / `7dd27c2` | PACK C、`ANCHOR_REGISTRY.md` 第 11 行的 `gcSample` 八列表，经 DOSE `geneList` 显式资格背景构造 fixture；每列表有效 GO 背景 11,525。直接 `compareCluster` 同会话回放：29,874 条 list-term，BH 0.05 下 247 条，八列表中四个有显著 term，PASS。 | registry/formals/defaults/flag 文档/R lint PASS；不同背景走独立 `enrichGO`，CX-01 触发且无合并比较图；ALL 缺 pool、缺 KEGG、列表充当自身背景类型化拒绝；主表与 PNG 回放逐字节一致；独立非写入 golden PASS；lock 核对 PASS。 | `compare_dotplot.png` 已打开：八列表全部显示，四个空列保留；标签/图例可读，无重叠或裁切；图注/spec 说明 BH 0.05、列表数及**未检验列表间富集差异**。待裁决原书背景、全表 cutoff 和 GO 资产。S3 请求见 `acceptance/exemplars/clusterprofiler-compare/S3_REQUEST.md`。 |

## 共享代码变更

- `skills/_shared/scripts/enrich_io.R`：三模块共用的确定性 CSV 输出、GO 登记/安装检查、canonical enrichment 表；对 ORA 的 `geneID` 成员排序以消除 AnnotationDbi 不稳定枚举次序，不改变成员或统计量。
- `skills/_shared/scripts/fig_mod_enrich.R`：仅加入三个 M2 模块的共享出图 wrapper；compare 图保留零显著列表的空列，图注明确没有列表间检验。全部调用 `os_finalize_figure` 并通过其图件 lint。
- `skills/_shared/docs/FIGURE_STYLE.md`：新增三模块图件说明。未修改 M1 的 `fig_mod_bulk.R`、`bulk_io.R` 或其它共享分析逻辑。

## 偏离与未完成项

- 与 PACK C 书中未给背景的 compare 调用相比，锚点采用显式 DOSE 资格背景并限制列表；数值是这个可审计 fixture 的回放。
- GSEA 下游 enrichit 参数无法穿透锁定 wrapper；只登记其已核实的 formals 默认与 R RNG 种子路径，未声称参数已在 `gseGO` 调用点显式传入。
- 三模块非 GO 集合尚无批准的容器离线资产，返回 `OS_REFDATA_MISSING`；无 KEGG 产物。
- 按 `build_common.md`，独立 S3、router 行与 `module_rules_v1.json` 安装（S5）不由本 lane 自行执行。各 `S3_REQUEST.md` 给出待审锚点、输出位置、提议 router 行及规则记录。
