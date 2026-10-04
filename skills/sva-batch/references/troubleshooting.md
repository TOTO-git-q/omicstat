# troubleshooting -- sva-batch

English, "symptom -> cause -> fix". Error codes: references/qc-rules.md (QC rows SB-01..SB-08)
and the typed-error list below (immediate stops, never a QC row).

## Typed errors

- `OS_MISSING_PARAMETER: --method combat needs a known --batch column.` -> combat/combat_seq
  correct a KNOWN batch. Fix: pass `--batch <column>`, or switch to `--method sva`/`svaseq` if the
  batch is actually unknown.
- `OS_CONFLICTING_PARAMETERS: --method sva estimates surrogate variables for an UNKNOWN source of
  variation; it does not take a known --batch column.` -> sva/svaseq never take `--batch` (that is
  the whole point of estimating surrogate variables). Fix: drop `--batch`, or switch to
  `--method combat`/`combat_seq` if the batch is in fact known.
- `OS_UNSUPPORTED_DESIGN: ComBat_seq splits the protected design into a categorical 'group' and a
  'covar_mod' matrix ...` -> `--method combat_seq` was given `--study-var-type continuous`. The
  PACK S1 appendix does not decide whether a continuous research variable goes into ComBat_seq's
  `group` or `covar_mod` (the appendix's own "待澄清" item); nothing is guessed. Fix: use
  `--method sva`/`svaseq` (their `mod`/`mod0` accept a continuous study variable directly), or
  re-express the study variable as categorical if that is scientifically defensible.
- `OS_INVALID_DESIGN: --batch is completely confounded with --study-var ...` -> every batch level
  maps to exactly one study-variable level (or vice versa); the correction cannot separate the
  batch effect from the biological effect. Fix: this is a design problem, not a software one --
  the study needs samples where batch and the study variable vary independently.
- `OS_INVALID_DESIGN: --batch and --study-var are partially confounded so that the study-variable
  coefficient(s) X (against the reference level) are NOT estimable jointly with the batch ...` ->
  (combat/combat_seq) level X occurs only inside batch(es) that no other level shares, so its
  difference from the other levels cannot be separated from the batch effect. The check rebuilds
  the design ComBat/ComBat_seq test internally (batch indicators + protected design) and tests
  each coefficient's estimability before the package is called. Fix: redesign, merge levels, or
  drop the samples of the non-estimable level.
- `OS_INVALID_DESIGN: --covariates X confounded with --batch ...` -> (combat/combat_seq) a
  protected covariate is a function of the batch (e.g. a "site" column identical to the batch
  column). ComBat/ComBat_seq would stop with their own "At least one covariate is confounded with
  batch!"; the module stops first with this typed error. Fix: drop the covariate -- the batch term
  already absorbs it.
- `OS_INVALID_DESIGN: covariate 'X' has a single level ...` -> a constant `--covariates` column
  carries nothing to protect. Fix: drop it from `--covariates`.
- `OS_INVALID_DESIGN: --study-var adds no independent information beyond --covariates ...` ->
  (sva/svaseq) the full model (`mod`) is not larger than the null model (`mod0`) once built; the
  study variable is collinear with (or identical to) the covariates. Fix: check `--study-var` and
  `--covariates` for a duplicated or derived column.
- `OS_INVALID_DESIGN: the null model (--covariates) is not full rank ...` / `the full model
  (--covariates + --study-var) is not full rank ...` -> an empty covariate level, or two
  covariates that are perfectly collinear. Fix: drop the empty level or the redundant covariate.
- `OS_BATCH_CORRECTED_INPUT` (raised by a DOWNSTREAM module's `read_handoff()`, not by sva-batch
  itself) -> a DE module was pointed at a sva-batch run with `--from-run`. This is by design (PACK
  S1 P-1): the corrected matrix is for display only. Fix: give the DE module the ORIGINAL
  uncorrected data (your own `--counts`/`--samples`, or an earlier deseq2-qc run) plus
  `--covariates <batch column>` (known batch) or the columns of sva-batch's `sv_table` object
  (unknown source of variation), added to the DE module's own design.

## Symptoms

- **The before/after PCA panels look identical.** -> `--method sva`/`svaseq` estimated 0
  surrogate variables (QC SB-06): nothing was regressed out, so the display matrix equals the
  input. This can be a correct finding (no detectable hidden batch structure), not a bug. Try
  `--num-sv-method leek` as a sensitivity check (PACK P-3) before concluding there is none.
- **"num.sv estimated N surrogate variable(s) ... (>= 1/3 of the samples)" (SB-07).** -> With few
  samples, `num.sv`'s permutation procedure can return a number of surrogate variables that leaves
  very few residual degrees of freedom for the downstream DE design. Inspect `tables/sv_table.csv`
  before adding all of them to a design with few samples.
- **A batch level has only 1 sample and the run stops (SB-04).** -> `ComBat`/`ComBat_seq` are run
  with `mean.only = FALSE` (the function default, PACK D-S4), which needs a per-batch variance;
  one sample cannot supply one. Fix: merge the singleton batch into another level, drop it, or (if
  truly needed) build a variant that sets `mean.only = TRUE` -- out of scope for v1 (known
  limitation), since D-S4 fixed the function default rather than exposing it as a flag.
- **Values in `tables/corrected_matrix.csv` are still integers after `--method combat_seq`.** ->
  Expected: ComBat-seq preserves the integer nature of the count matrix (vignette, "ComBat-Seq for
  batch adjustment on RNA-Seq count data"); this is not a sign the correction did nothing.
- **The console prints an `OS_ENGINE_WARNING` during a sva/svaseq run.** -> Read
  `qc/engine_warnings.csv` (SB-08); a common cause is a very small sample size relative to the
  number of features, which the iteratively re-weighted least squares procedure can flag.
