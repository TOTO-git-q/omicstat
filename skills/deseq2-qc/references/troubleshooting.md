# troubleshooting -- deseq2-qc

Format: symptom (verbatim) -> cause -> fix.

## Errors

- **`OS_QC_BLOCKER: DQ-01 triggered on the input`** -> the count matrix holds non-integer values (TPM, FPKM, CPM, normalized or batch-corrected data, or estimated counts from a transcript quantifier). -> Supply the raw integer count matrix (e.g. featureCounts, htseq-count).
- **`OS_QC_BLOCKER: DQ-02 triggered on the input`** -> the matrix is not counts (log-transformed or centred data has negative values). -> Supply raw integer counts.
- **`OS_QC_BLOCKER: DQ-03 triggered on the input`** -> fewer than 3 samples were given. -> Add samples; a 2-sample PCA has no second principal component to plot.
- **`OS_INVALID_DESIGN: matrix columns and sample table disagree`** -> sample ids differ in spelling, case or suffix. -> Make the `--sample-col` values identical to the matrix column names; the module never matches by position.
- **`OS_INVALID_DESIGN: the design ~ batch + condition is not full rank`** -> every sample of one `--condition` level is also in one `--covariates` level (confounded), or a covariate level has no sample. -> Drop the confounded covariate.
- **`OS_MISSING_PARAMETER: --min-samples must be given explicitly`** -> the design has `--covariates`, or `--condition` has 3+ levels, so the pre-filter cannot auto-resolve "the smaller compared group". -> Pass `--min-samples` explicitly (e.g. the size of your smallest group of interest).
- **`OS_DEGENERATE: only 1 feature(s) pass the pre-filter`** -> counts are tiny or `--min-count` / `--min-samples` too strict. -> Lower them, or check that the matrix is not transposed.
- **`OS_MISSING_COLUMN: sample table has no condition column '...'`** -> `--condition` (or `--shape-col` / `--covariates`) names a column absent from `--samples`. -> Check the column name / `--sample-col`.

## Messages and warnings (in `qc/engine_warnings.csv`)

- **`-- note: fitType='parametric', but the dispersion trend was not well captured by the function: y = a/x + b, and a local regression fit was automatically substituted.`** (a message, rule DQ-06) -> DESeq2 fell back to `fitType = "local"` while estimating the dispersion trend used by the transform. -> Report it; rerun with `--fit-type local` to make the choice explicit.
- Any other R warning raised inside DESeq2 triggers DQ-07 and is printed to stderr as `OS_ENGINE_WARNING: [compute] ...`.

## Expected harmless console output

- `rlog` (`--transform rlog`) may print that it "may take a few minutes" / "a long time" for larger sample counts; this is DESeq2's own timing notice, not a warning, and is not written to `qc/engine_warnings.csv` (it is an R `message`, left to print normally per CONVENTIONS sec 15).
