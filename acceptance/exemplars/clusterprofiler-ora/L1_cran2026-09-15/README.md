# L1 -- enrichit 0.2.1 (CRAN snapshot 2026-09-15 of the locked image)

In Bioconductor 3.23, DOSE 4.6.0 / clusterProfiler 4.20.0 no longer run the enrichment internally: DOSE
4.5.1 moved `enricher_internal` / `GSEA_internal` to the CRAN package **enrichit** (renamed
`ora_gson` / `gsea_gson`), and clusterProfiler's GSEA uses enrichit's own multilevel implementation.
The locked image resolves CRAN packages from the snapshot `env/omicstat-env.json` `cran_snapshot`
(2026-09-15), where enrichit is **0.2.1** (clusterProfiler requires >= 0.1.1). Files copied from the
source tarball (Artistic-2.0); `manifest.tsv` records the tarball URL and sha256.
