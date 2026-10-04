# troubleshooting -- deseq2-wald

Format: symptom (verbatim) -> cause -> fix.

## Errors

- **`OS_QC_BLOCKER: DW-01 triggered on the input`** -> the count matrix holds non-integer values (TPM, FPKM, CPM, normalized or batch-corrected data, or estimated counts from a transcript quantifier). -> Supply the raw integer count matrix (e.g. featureCounts, htseq-count). Estimated counts from Salmon/kallisto belong in a tximport-based import, which this module v1 does not provide (Known limitations in SKILL.md).
- **`OS_INVALID_DESIGN: matrix columns and sample table disagree`** -> sample ids differ in spelling, case or suffix (e.g. `treated1fb` vs `treated1`). -> Make the `--sample-col` values identical to the matrix column names; the module never matches by position.
- **`OS_INVALID_DESIGN: the design ~ batch + condition is not full rank`** -> every sample of one condition is also in one batch (confounded), or a covariate level has no sample. -> Drop the confounded covariate; if batch and condition are fully confounded, the condition effect cannot be separated from the batch effect by any model.
- **`OS_INVALID_PARAMETER: ... are not syntactic R names`** -> a level such as `single-read` or `2h` cannot become part of a DESeq2 coefficient name. -> Rename the levels in the sample table (`single_read`, `h2`).
- **`OS_INVALID_PARAMETER: level 'ctrl' is not a value of column 'condition'`** -> `--reference` / `--target` misspelled. -> Use a value printed in the message.
- **`OS_DEGENERATE: only 1 feature(s) pass the pre-filter`** -> counts are tiny or `--min-count` / `--min-samples` too strict. -> Lower them, or check that the matrix is not transposed.
- **`OS_MISSING_PARAMETER: give --counts with --samples, or --from-run.`** -> no input given.
- **`OS_MISSING_PARAMETER: the design is not a simple two-group design (...)`** -> `--covariates` were given, or the condition column has more than two levels, and `--min-samples` was left at 0 -> give the pre-filter rule explicitly, e.g. `--min-samples 3` (features need a count >= `--min-count` in at least 3 samples); the automatic smallest-group rule is only defined for two-group designs (S1 P-3).

## Messages and warnings (in `qc/engine_warnings.csv`)

- **`-- note: fitType='parametric', but the dispersion trend was not well captured by the function: y = a/x + b, and a local regression fit was automatically substituted.`** (a message, rule DW-11) -> DESeq2 fell back to `fitType = "local"`. -> Report it; rerun with `--fit-type local` to make the choice explicit.
- **Features that did not converge** (rule DW-12; DESeq2 prints nothing with `quiet = TRUE`) -> a few genes with extreme counts; `mcols(dds)$betaConv` is FALSE for them. -> Usually harmless; check them in `tables/deseq2_results_full.csv`.
- Any other R warning raised inside DESeq2 or apeglm triggers DW-09 and is printed to stderr as `OS_ENGINE_WARNING: [compute] ...`.

## Expected harmless console output

- None expected: `DESeq(quiet = TRUE)` silences "estimating size factors" / "estimating dispersions" / "fitting model and testing", and `lfcShrink(quiet = TRUE)` silences its "please cite" message (the citation is in `references/method-basis.md`).
