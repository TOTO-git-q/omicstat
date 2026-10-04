# seurat-integrate independent S3 request

Run `Rscript skills/seurat-integrate/tests/run_smoke_test.R` in omicstat-r:2026.09.1 using the lane run.sh mounts, then `Rscript tools/make_module_lock.R seurat-integrate --check`.

PACK C: locked harmony Seurat vignette pbmc_stim payload SHA256 d85a18ce8ec9dcb4ac86c8e195ed53ff893c5952a7d6bf70035a17856c9dc0ef. Real QC -> clustering -> integration chain, 2000 cells (printed anchor), 20 Harmony dimensions; native RunHarmony replay matches at 1e-8 and raw counts retained. Both RunHarmony and IntegrateLayers(HarmonyIntegration) pass. Observed RunHarmony 10 communities/85396 undirected edges are locked-version observations, not historic printed expectations. Harmony2 generic dispatch needs object first; wrapper fixed accordingly. Golden: harmony.csv and batch_clusters.csv. Outputs /home/<user>/omic-sol61/build_m3a_seurat/integrate_anchor and integrate_layers; log integrate_smoke.log. Fourteen chain PNGs opened (eight integration, six upstream): readable, no clipping; zero mitochondrial signal is expected for this packaged feature list and explicitly opted in. Figure metadata records n and choices.

Caller chooses route, batch covariate, dimensions, graph/UMAP neighbors and resolution. Vignette examples: stim, 20 PCs, k=20, UMAP k=30, resolution 0.5, seed 42; these are not universal defaults. Layer route currently RNA/LogNormalize only; SCT users can choose RunHarmony. No biological integration quality claim or condition inference.

Router proposal: `| Seurat batch integration / 单细胞整合 | seurat-integrate | scripts/run_seurat_integrate.R |`.
Publication rule proposal: `{ "module":"seurat-integrate", "id":"SI-CHOICES", "category":"design_conditional", "rule":"Report integration route, covariates, dimensions, parameters and seed; raw counts remain uncorrected." }`.
