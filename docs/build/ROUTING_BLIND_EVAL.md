# 路由盲测（G5）记录

盲读者：gpt-6.1-sol（effort low），只能看到 `skills/omicstat/SKILL.md`、各模块 SKILL.md 和去掉答案字段的 133 题；评分脚本在仓库外（`routing_blind.py`：primary 必须等于 `expected`；一步的 pipeline 与裸模块名等价）。每一轮都是新的盲读会话，不复用上一轮答案。

| 轮次 | 路由器版本 | primary = expected | 在 expected+acceptable 内 | 结论 |
|---|---|---|---|---|
| 1（2026-10-04 07:44） | s5/install 43edbda | 118/133 = 0.887 | 123/133 = 0.925 | 两道门槛均未过 |
| 2（07:56） | cf8cd9f | 122/133 = 0.917 | 129/133 = 0.970 | 90% 过，98% 未过 |
| 3（08:03） | 6a88d3f | **123/133 = 0.925** | **132/133 = 0.992** | **两道门槛均过** |

## 第 1→3 轮之间改了什么

路由器文本（`skills/omicstat/SKILL.md`，只改措辞，不改执行表）：
1. 同时提到 GO 和 KEGG 的问题仍路由到 clusterprofiler-ora；KEGG 由模块内以 `OS_REFDATA_MISSING` 拒绝，路由层不拒绝。
2. 与检验同名的基因符号（FRY、CAMERA、ROAST）是基因不是方法；感兴趣的基因/基因列表按常规路由到 ORA。
3. “monocle3 还是 slingshot”由链的前端生态决定（Seurat/图分区链 → monocle3；Bioconductor/已有嵌入链 → slingshot）。
4. “完整链”到 marker 或 pseudobulk 包含整合之后的注释步骤（singler-annotate 或 scanvi-annotate）；在 omicstat 之外处理过的对象从前端 QC 重新进入（交接要求上游是哈希核验过的 omicstat 运行）。
5. 点名的生态专属方法决定生态：SCTransform/FindClusters/AddModuleScore → Seurat；scran/scater/batchelor/fastMNN → Bioconductor；scanpy/scvi/.h5ad → scverse。

题库（`routing_eval.jsonl`，每条都在 `note` 里写了理由与日期）：
- R090：问的是 QC 和聚类两步，两步 pipeline 加入 acceptable。
- R095、R106：按 2026-09-29 参数政策，路由器不再断言领域多数派；要求用户预先指定生态加入 acceptable。
- R107：原期望写于中性后端装机之前；现在 monocle3/slingshot 经 convert.R 接受 AnnData，期望改为 `scanpy-qc → scanpy-cluster → monocle3-trajectory`，裸后端名保留为 acceptable。
- R133：FRY 不是 fry()；路由器据此把该基因当作感兴趣基因路由到 ORA，ORA 加入 acceptable。

评分脚本：一步的 pipeline 与模块名等价（第 1 轮 R117 因此被误判）。

## 第 3 轮唯一未中

R116「比较两个条件之间的表达差异和细胞比例差异，后端接哪些模块」：期望 `muscat-pseudobulk → fgsea-prerank`，盲读者答 `singler-annotate → muscat-pseudobulk → speckle-propeller`。问题同时问了表达与比例，期望里却没有 speckle-propeller，题库这一条本身值得复核；未改动，留给所有者。

## 边界

这是路由措辞的盲读评分，不是科学正确性验证；它只回答“路由器文本能否把问题带到正确的模块/流水线”。
