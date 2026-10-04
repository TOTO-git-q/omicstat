# scater-qc: independent S3 request
Run in `omicstat-r:2026.09.1` from suite root:
`OMICSTAT_TEST_TMP=/scratch Rscript skills/scater-qc/tests/run_smoke_test.R`
Then `Rscript tools/make_module_lock.R scater-qc --check`.

Checked: SHA256-verified Zeisel EH2580/1/2, printed scater overview shape 20006 genes x 3005 cells and ERCC/repeat altExps; exact native QC metrics/filter replay (`nmads=3`, 2874 retained); entry and `--from-run`; main table golden; three figure PNGs opened, suite figure lint passed. Source: lane A `L1_bioc3.23/scater/vignettes/overview` and scuttle userguide; replay retention is not a historical printed value.
Outputs: `/home/<user>/omic-sol61/build_m3a_bioc/scater-qc-smoke/anchor/`; log `scater-qc-smoke.log` in the same lane scratch.

Limitations: compatibility APIs warn about deprecation; scrapper 1.6.3 is now installed in 2026.10.1, and the existing compatibility workflow is replayed unchanged. Scientific thresholds/annotation remain caller choices; no doublet detection. Named native JSON argument options use package defaults and primary flags override them. Legacy static call scanner does not recognize function objects passed via this wrapper; use registry and execution checks, not a claim of static scanner coverage.
Proposed router row: `| SCE per-cell QC / scater 单细胞质控 | scater-qc | scripts/run_scater_qc.R |`.
Proposed publication rule: advisory `XQ-CHOICES`: declare mitochondrial IDs, mode, thresholds and batch column; do not imply doublets were removed.
Awaiting independent S3; no S3/S5 performed.
