# Method basis

Sources are the read-only evidence in /home/<user>/omic-s0-a/acceptance/exemplars/seurat-cluster/L1_cran2026-09-15 and this module's PACK T/F/W/C/D/X. Seurat 5.5.1 / SeuratObject 5.4.0 are locked in env/pkg_lock.csv. The parameter policy dated 2026-09-29 takes precedence over unfrozen PACK drafts and historic paper counts. No literature majority is used to select parameters.

QC source: Seurat/vignettes/pbmc3k_tutorial.Rmd, "QC and selecting cells for further analysis". Normalization and clustering source: "Normalizing the data", "Identification of highly variable features", "Run linear dimensional reduction", "Cluster the cells", "Run non-linear dimensional reduction (UMAP/tSNE)". Integration: harmony/Seurat.Rmd and Seurat integration guide. Scoring: Seurat/vignettes/cell_cycle_vignette.Rmd. Relevant locked Rd and container formals are authoritative for fixed arguments.
