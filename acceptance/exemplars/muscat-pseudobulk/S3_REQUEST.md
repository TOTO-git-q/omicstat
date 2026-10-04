# muscat-pseudobulk S3 request
Run `OMICSTAT_WRITE_GOLDEN=1 bash /home/<user>/omic-sol61/build_m3b/docker_run.sh Rscript skills/muscat-pseudobulk/tests/run_smoke_test.R`; omit the env flag to verify goldens. Locked R image only.

PACK C / L1 muscat analysis.Rmd Kang18 EH2259 recipe: 7118 genes × 26820 filtered cells, 8 pseudobulk assays; B cells ctrl101 NOC2L=12, ISG15=13; stim101 ISG15=1362. ISG15 logFC rounds to 5.47346, P to 3.0e-21; all asserted at their printed precision, no tolerance widened. Native result table columns preserved, within-cluster/global adjusted P retained. Direct and --from-run table hashes agree, ecosystem retained; calls/default drift and R lint pass. Golden main table generated in container; final module lock --check OK (9 files).

Outputs: `/home/<user>/omic-sol61/build_m3b/muscat-pseudobulk-smoke/{direct,chain}/`; log `muscat-smoke.log`. Figures: proportions and eight cluster volcanoes through suite builders; captions specify n and display-only FDR/logFC thresholds. Native pseudobulk SCE and pbDS list in objects/native.rds.

Replicates: at least two independent samples per selected condition; cells never count as replicates. Default vignette ~group_id analysis is unpaired; paired designs require explicit --ds-design / --ds-contrast or coefficient. QC filtering is anchor fixture preparation, not a chosen module default. Method options edgeR/DESeq2/limma-trend/limma-voom/DD; other methods require independent S3 coverage. TMB/glmmTMB version warning from locked image retained in logs. All judgement options consult reference service; Python-to-R label pending.

Proposed router: `| Replicated differential expression within cell types / pseudobulk | muscat-pseudobulk | scripts/run_muscat_pseudobulk.R |`.
Publication proposal: sample-level inference, exact design/contrast/method/version and adjusted-P scope required; figures use full native tables and explicit display thresholds.

2026.10.1 basilisk correction validation: non-root (`uid 1000`), offline (`--network none`) actual h5ad input smoke PASS, native result equals existing RDS/golden table. This was validated in a disposable container with the proposed relocation fix; replacing the lane-created tag still awaits owner exception. Final image check remains pending.

Final 2026.10.1 live-image validation supersedes the provisional image notes above: full smoke PASS as non-root with --network none and OMICSTAT_TEST_H5AD=1; actual h5ad input native tables match the RDS path/golden. Image ID sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7. Independent S3 remains pending.
