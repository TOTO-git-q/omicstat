---
name: msstats-diff
description: Experimental MSstats protein differential analysis. Numerical acceptance and environment rebuild pending; not a sealed executable release.
---

## Candidate local runtime verification (2026-10-15)

The original authoring status below is historical. Role A subsequently built and
executed the isolated `omicstat-r-exp:20261015` runtime. All five modules now pass
real R parsing, development/smoke tests, CLI, every documented scientific enum,
refusal paths, byte-identical table/PNG spec replay and output/handoff hash audits.
Official printed-value comparisons, tolerances and scope are in
`VALIDATION_STATUS.json`; installed formals are in `installed_api.json` and the
candidate L1 export. Figures are candidate baseline renders; Role B owns further
convention work. The modules remain unsealed, unregistered and publication-blocked.

## Status
Source implementation only. Numerical replay, official fixture acceptance, visual inspection and release sealing have NOT been run. Every generated run carries a blocking acceptance QC rule and a display-only handoff. No manuscript-ready claim or automatic downstream inference.

## When to use
Label-free L canonical peptide/transition long tables, two groups, independent or complete paired biological replicates; technical runs retained.

## Not supported
No protein-matrix-to-peptide fabrication, TMT, isotope-reference experiments, raw spectra, vendor-table converters, incomplete pairing or arbitrary covariates.

## Input and run
Rscript scripts/run_msstats_diff.R --input msstats_long.csv --design independent --reference control --target treated --normalization equalizeMedians --censored-int NA --mb-impute true --feature-id-type UniProt --outdir new-run

Inputs declare scale, normalization and biological identity; none are guessed from the distribution. See references/options.md for every flag. No --from-run input is exposed in this initial scope because no accepted upstream proteomics contract exists.

## Output
Full input-protein feature table with explicit excluded/not-estimable reasons; full engine result; model RDS; sample metadata; engine warnings; QC; results JSON; resolved spec and hashed provenance. Standard volcano uses the shared figure layer with nonitalic protein IDs. Plotting does not remove rows from the result table. The audit is explicitly experimental, not a publication draft.

## Acceptance and limitations
See tests/acceptance_status.json and the PACK. Run tests/run_smoke_test.R only inside the coordinator-built new environment. No golden_manifest.csv or module_lock.json exists because neither can truthfully be generated in an executor without R. The test fails if required packages or official fixtures are absent; this is not a passing skip. Model issue rows retain MSstats conventions, including oneConditionMissing; any issue blocks interpretation. A technical Run is never a biological replicate.

## Sources
- P1: [Bioconductor release metadata](https://bioconductor.org/packages/3.23/bioc/html/MSstats.html) (accessed 2026-10-15).
- P2: [Official workflow](https://bioconductor.org/packages/3.23/bioc/vignettes/MSstats/inst/doc/MSstatsWorkflow.html) (accessed 2026-10-15).
- P3: [Estimator API](https://raw.githubusercontent.com/Vitek-Lab/MSstats/master/R/dataProcess.R) (accessed 2026-10-15).
- P4: [Contrast API](https://raw.githubusercontent.com/Vitek-Lab/MSstats/master/R/groupComparison.R) (accessed 2026-10-15).

## When to use / when not

## Input requirements

## Run

## What gets produced

## Reading the results

## When a QC rule fires

## Known limitations

## Reference files
