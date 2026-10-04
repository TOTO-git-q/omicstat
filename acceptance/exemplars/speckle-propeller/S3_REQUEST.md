# speckle-propeller independent S3 request
Run `bash /home/<user>/omic-sol61/build_m3b/docker_run.sh Rscript skills/speckle-propeller/tests/run_smoke_test.R`; `OMICSTAT_WRITE_GOLDEN=1` only to regenerate container goldens.

PACK C / locked L1 speckle.Rmd CellBench seed=10 bootstrap: H1975 logit P.Value=0.01841045, FDR=0.05003357; asin P.Value=0.01578743. Assertions compare the printed 8-decimal strings exactly. Native ANOVA table has 3 cell types. Direct/from-run tables identical, chain ecosystem retained, calls/default drift/R lint pass. Figure lint is automatic through os_finalize_figure. Both proportions PNGs opened and readable/unclipped; n=2 samples per technology and total cells in caption.

Outputs: `/home/<user>/omic-sol61/build_m3b/speckle-propeller-smoke/{direct,chain}/`; log `speckle-smoke.log`. Native propeller result and transformed/untransformed proportions in objects/native.rds; CSV native columns retained. Golden differential table generated in locked container; module_lock --check required.

LIMITATION: CellBench bootstraps mimic sampling variation only and are not biological replicates or a biological differential claim. Real analyses require >=2 independent samples in every group; refuse without replication. Single-network propeller interface supports two-group t-test and multi-group ANOVA, not paired/covariate-adjusted models. Need a named source assay for conversion, although counts are not used in the proportion test. Official object dispatch assumes attached SingleCellExperiment; wrapper uses its documented explicit vectors to avoid that package namespace issue.

Proposed router: `| Cell-type proportion differences across replicated samples | speckle-propeller | scripts/run_speckle_propeller.R |`.
Publication proposal: name transform/trend/robust/version, sample unit and replication; report complete native P.Value/FDR table and descriptive proportions. Consult reference service for judgement choices; Python-to-R label 待裁决.

2026.10.1 basilisk relocation proposal: full non-root offline h5ad smoke PASS; native table equals RDS path. Disposable-container validation only; final tagged image awaits owner exception and validation.

Final 2026.10.1 live-image validation supersedes the provisional image notes above: full smoke PASS as non-root with --network none and OMICSTAT_TEST_H5AD=1; actual h5ad input native tables match the RDS path/golden. Image ID sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7. Independent S3 remains pending.
