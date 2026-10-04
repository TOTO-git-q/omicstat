# slingshot-trajectory S3 request
Run `bash /home/<user>/omic-sol61/build_m3b/docker_run.sh Rscript skills/slingshot-trajectory/tests/run_smoke_test.R`; use `OMICSTAT_WRITE_GOLDEN=1` only to regenerate container goldens.

PACK C/L1: slingshotExample 140×2 bifurcating coordinates, 140 cluster labels, native pseudotime with 2 lineages PASS. Direct/from-run main tables identical and front-end ecosystem retained. tradeSeq.Rmd exact countMatrix/crv recipe uses RNGversion(3.5.0), seed=7 and 6 knots: **240 converged genes PASS**. Engine uses official cached crv for that branch and retains native GAM/associationTest columns. Container goldens for tradeSeq pseudotime + association tables generated; calls/default drift/R lint pass; final module lock --check OK (9 files).

Outputs: `/home/<user>/omic-sol61/build_m3b/slingshot-trajectory-smoke/{direct,chain,tradeseq}/`, log `slingshot-smoke.log`. All three trajectory PNGs opened: nonblank/readable/unclipped. Existing coordinates preserved; curves from native Slingshot objects; colour lineage 1 with unassigned grey, all lineage pseudotimes kept. Captions state n and no display cutoff.

Limits: the 140-cell coordinate fixture has no expression; an unused carrier assay is explicitly identified and fitGAM is off. The separate real tradeSeq fixture tests GAM fitting and printed convergence. No exact assertion against the unseeded single-lineage simulation summary (PACK C explains why). Slingshot S0 PACK V/D counts and L3 notes remain partly stale; defaults come from locked formals, option evidence keys from corrected extraction.jsonl. Required start-cluster allows deliberate `auto`=NULL; biological root orientation still requires user judgement/reference service. JSON options include method-specific S4 controls and local RDS matrices; method default inventory was captured in the locked container.

Proposed router: `| Lineages and pseudotime / Slingshot, tradeSeq | slingshot-trajectory | scripts/run_slingshot_trajectory.R |`.
Publication proposal: describe existing embedding, root rationale, curve/GAM options, seed/RNG and native association test; pseudotime is relative and does not establish causal progression. Python-to-R label pending.

2026.10.1 environment correction: non-root offline h5ad full smoke PASS, native table equals original RDS route. Converter preserves embedding order and singleton axes/categories through native AnnData/pandas operations with strict regression. Validation used a disposable fixed environment; final tagged-image check awaits owner load exception.

Final 2026.10.1 live-image validation supersedes the provisional image notes above: full smoke PASS as non-root with --network none and OMICSTAT_TEST_H5AD=1; actual h5ad input native tables match the RDS path/golden. Image ID sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7. Independent S3 remains pending.
