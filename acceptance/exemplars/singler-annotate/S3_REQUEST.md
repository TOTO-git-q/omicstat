# singler-annotate: independent S3 request (anchor rebuilt)
Run: `bash /home/<user>/omic-sol61/build_m3b/docker_run.sh Rscript skills/singler-annotate/tests/run_smoke_test.R`.

Checked in the locked container: classic synthetic 40-cell labels, flag effect, deterministic replay, typed input errors, --from-run ecosystem and hash checks, calls/default drift and R lint. Native SingleR prediction and annotated SCE are saved. Both synthetic PNG types were opened: readable, nonblank, unclipped; captions carry n and pruning thresholds.

Mandatory PACK C pancreas recipe is **PASS** in `omicstat-r:2026.10.1`: 1718 cells, acinar 723, alpha 228, beta 232, delta 65, duct 344, endothelial 15, epsilon 2, mesenchymal 69, pp 36, unclear 4; 59 pruned. Source: locked SingleR vignette. Raw EH fixtures now reproduce the official scRNAseq ERCC altExp split before normalization. First pancreas goldens and module lock created after exact anchor success; no tolerance relaxed.

Outputs/log: `/home/<user>/omic-sol61/build_m3b/singler-smoke/`, `singler-slim.log`. Every SingleR/pruneScores formal exposed by individual JSON option (locked defaults evaluated lazily); legacy convenience flags retained. Optional native JSON flags retain lazy defaults when absent; registry records native values separately from the absent CLI default. Final defaults check and non-root h5ad test will be included in environment validation.

Proposed router: `| Reference cell-type annotation / SingleR / 参考注释 | singler-annotate | scripts/run_singler_annotate.R |`.
Publication proposal: uncertainty/pruned labels must be explicit; score is not a probability; package version/reference identity/options required. Python-to-R ecosystem label 待裁决: upstream unchanged, QC crossing warning.

Environment rebuild outputs: `/home/<user>/omic-sol61/env_rebuild/singler/singler-smoke/`; `singler.log`. Existing synthetic checks and full official pancreas smoke PASS. Final basilisk image validation pending; no S3 acceptance performed.

Non-root offline pancreas h5ad logcounts-only input PASS in the proposed fixed environment; annotations and scores byte-identical to the exact printed-anchor RDS route. Original fixture counts are fractional, so no raw-integer counts role is claimed. Final live-image validation remains pending.

Final 2026.10.1 live-image validation supersedes the provisional image notes above: full smoke PASS as non-root with --network none and OMICSTAT_TEST_H5AD=1; actual h5ad input native tables match the RDS path/golden. Image ID sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7. Independent S3 remains pending.
