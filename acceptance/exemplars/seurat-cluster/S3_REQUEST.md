# seurat-cluster independent S3 request

Run `Rscript skills/seurat-cluster/tests/run_smoke_test.R` in omicstat-r:2026.09.1 (suite /omicstat; writable lane /scratch), then `Rscript tools/make_module_lock.R seurat-cluster --check`.

Smoke builds the actual seurat-qc -> seurat-cluster chain from PBMC3k. Printed anchors from locked Seurat PBMC3k tutorial, PACK C: 2638 nodes, 95927 undirected SNN edges, nine communities; observed first five labels 2,3,2,1,6. Independent native-code replay verifies PCA and cluster assignments. Goldens bind main native cell metadata, HVG list and PCA standard deviations. Output: /home/<user>/omic-sol61/build_m3a_seurat/cluster_anchor; log cluster_smoke.log. Finalizer figure lint passed; cluster/sample UMAP and elbow opened.

Required caller choices: normalization, HVG/PC/neighbor counts, dimensions and resolution; PBMC example 2000 HVGs, 50 computed PCs, first 10 used, k=20, UMAP k=30, resolution=0.5. Advanced JSON controls expose native result-affecting settings. Optional hvg-batch-col uses the harmony vignette union of per-batch HVGs. No cell-type annotation or replicate inference. SCTransform is offered; the PBMC printed anchor tests LogNormalize.

Router proposal: `| Seurat normalization and clustering / 单细胞聚类 | seurat-cluster | scripts/run_seurat_cluster.R |`.
Publication rule proposal: `{ "module":"seurat-cluster", "id":"OSC-CHOICES", "category":"design_conditional", "rule":"Report normalization, HVG/PC/neighbor choices, resolution and seed; labels are descriptive clusters." }`.
