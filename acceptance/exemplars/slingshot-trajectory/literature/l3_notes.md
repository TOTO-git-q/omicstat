# Slingshot trajectory: L3 close-reading notes

Nine tier-A papers run a single-cell Slingshot trajectory and are applicable. A tenth tier-A article (PMC8640014) runs Slingshot on 1,106 bulk RNA-seq tissue samples and is excluded from this single-cell module. Exact Methods snippets of at most 25 words and section paths are in `extraction.jsonl`.

## PMC9834047 — developmental pseudotime

The Seurat front end supplies previously calculated clusters and UMAP coordinates to `getLineages`, followed by curve/pseudotime inference. The paper reports slingshot v1.2.0. Its UMAP input is an upstream embedding, not a locked slingshot default.

## PMC8674361 — lineage reconstruction

The Seurat-front-end study reports Slingshot 1.6.1 and principal-curve lineage inference. It also runs a separate force-directed SPRING pseudotime view. The distinct layouts and any DE threshold elsewhere in the paper were not assigned to Slingshot arguments.

## PMC10739728 — adipose iNKT differentiation

The mixed Seurat/scater front end uses UMAP coordinates and `getLineages`, explicitly setting Au-iNKT1 as the start cluster and Ac-iNKT1 as the end cluster. These are biological orientation choices for this lineage; version 1.4.0 is historical.

## PMC13518833 — oligodendrocyte lineage and genotype

The mixed Seurat/scuttle front end reports Slingshot 2.12.0 with preOPCs as start and mOLs as end, `dist.method="mnn"`, `extend="n"`, `stretch=0`, and `shrink=FALSE`. tradeSeq 1.18.0 fits 5,000 variable genes using `fitGAM(nknots=6, conditions=H3 status)` and runs `conditionTest(l2fc=log2(1.25))`. BH-adjusted P < 0.05 defines this study's differential genes. This is condition-specific trajectory modeling, not the default `associationTest`.

## PMC10733277 — Müller glia trajectories

This mixed Seurat/scvi-tools workflow passes UMAP coordinates to Slingshot and changes the biological root by analysis subset: Rest MG in one setting, the cluster nearest MGPCs in others, and a development cluster in the combined analysis. Such root changes alter direction and must be disclosed; no exact `start.clus` argument value is reported.

## PMC11630819 — VSN receptor lineages

Slingshot 1.8.0 receives the first 12 PCs and cell-type labels, with GBCs as start and V1R/V2R mVSNs as ends. tradeSeq 1.4.0 uses `evaluateK` on raw counts, Slingshot pseudotime and cell weights, chooses `nknots=5`, then applies `patternTest` across the two lineages. The five-knot result is a study choice following an evaluation, not a general default.

## PMC7730477 — independent trajectory check

The study reruns Slingshot on the single-cell data to check a Monocle 2 bifurcation. It reports a trajectory comparison but no exact start/end cluster or curve-control parameters. Thresholds of other analyses were not transferred to the Slingshot extraction.

## PMC10726524 — trafficking lineage

This scverse-front-end Methods section names Slingshot and tradeSeq `associationTest` for a lineage, and applies Bonferroni-corrected P < 0.05 plus mean log fold change > 3. It reports “Slingshot v3.18,” inconsistent with the pinned package's 2.x series; the report is retained as written and cannot define locked defaults.

## PMC7725805 — fibroblast progenitors

The Seurat-front-end study uses prCAFs as a starting cluster/progenitor based on prior biological findings, then fits smooth lineages. It does not report the curve iteration, shrinkage or distance arguments.

## Other corpus cautions

PMC13526022 uses Slingshot on bulk DNA-methylation sample PCs; PMC8640014 uses bulk RNA-seq sample PCs; PMC9684472 uses spatial transcriptomic tissue locations. All three are retained in the 30-paper corpus with `_applies=no` for this single-cell module. PMC9746914 describes using **sample names as cluster identifiers**; it is an actual Slingshot run, but S1 must validate cell-group semantics and cannot treat that choice as a default. PMC10264246 has plain v2.2.0 and a second flattened `v2.2.044` where reference 44 follows the version.
