# sva-batch S4 fixes

Branch `s4/sva-batch` (from `integrate/m1m2` @fb63e52). Module version 1.0.0 -> **1.1.0**.
Locked image `omicstat-r:2026.09.1` on GT103, run dir `~/omic-build-logs/s4/sva-batch`
(logs `~/omic-build-logs/s4/sva-batch-<tag>.log`; copies of the relevant logs in `_s4/`).
Work list: `S3_REVIEW_astra.md` F1-F4. Paths below are relative to `skills/sva-batch/` unless stated.

Final evidence:
- `sva-batch-gold.log` (OMICSTAT_WRITE_GOLDEN=1) then `sva-batch-final.log`: 94 PASS, 0 FAIL, 0 SKIP, golden
  **PASS**, `SMOKE PASSED (with 2 documented KNOWN-FAILING anchor(s))`, EXIT 0.
- `sva-batch-lock.log` / `sva-batch-lockcheck.log`: `module_lock sva-batch 1.1.0: OK (14 files)`.
- `sva-batch-pychecks.log`: check_defaults 0 problems; `sva-batch-lint.log`: lint_r 0 problems (in the container).
  The smoke test itself also runs check_calls, default drift, check_defaults, check_flag_docs and lint (PASS).

## F1 -- vignette "SVs into the model" chain (PACK C / S1 P-4)

What changed
- `tests/run_smoke_test.R` block A6 (lines ~194-290): the sva vignette's own sec 3-6 code runs **in the test
  session**, copied from `L1_bioc3.23/sva/vignettes/sva.Rnw:63-141` (pheno/edata, `mod = model.matrix(~as.factor(cancer))`,
  `mod0 = model.matrix(~1)`, `num.sv(...,"leek")`, `sva(edata,mod,mod0,n.sv)`, `modSv`/`mod0Sv`, `f.pvalue`, `lmFit`,
  the vignette's contrast matrix, `contrasts.fit`, `eBayes`, `topTableF(eb, adjust="BH")`); the printed table
  `sva.rendered.txt:203-226` (10 rows x C1, C2, C3, AveExpr, F, P.Value, adj.P.Val) is asserted value by value within
  half a unit of the last printed digit (`printed_tol()`). No engine or _shared helper is used except
  `os_acceptance_data()` to load bladderbatch 1.50.0. Source design (`~cancer`, `~1`) kept separate from the suite
  preset tests A1-A5.
  - **A6a (printed, verbatim, in-session n.sv)**: KNOWN FAILING, see below.
  - **A6b (printed anchor)**: the vignette chain from its own printed intermediate `n.sv = 2` (`sva.rendered.txt:141`
    -> `sva.Rnw:96`) reproduces all 70 printed values, e.g. `207783_x_at` C1 = -13.45607117 (printed -13.45607),
    P = 1.20756e-69 (printed 1.207560e-69), F = 8622.5176 (printed 8622.518).
  - **A6c (replay for the module)**: the engine's `tables/sv_table.csv` for A3 (leek, n.sv = 2) and A2 (be, n.sv = 9)
    equals a direct `sva(dat, mod, mod0, n.sv = k, controls = NULL, method = "irw", vfilter = NULL, B = 5,
    numSVmethod = "be")` on the same (TSV) matrix, max |diff| 4.87e-11 / 4.99e-11 (the 10-significant-digit CSV);
    the engine's SVs entered into the vignette's `modSv`/`mod0Sv` give the same `f.pvalue` P-values for all 22,283
    features and the same topTableF as the direct SVs; for n.sv = 2 they reproduce the printed topTableF. Engine SVs
    (TSV input) vs A6b SVs (in-memory data): max |diff| 4.87e-11.
- A3 re-labelled as a locked-container value (its equality with the printed "[1] 2" is not a reproduction, see below);
  assertion unchanged. `references/method-basis.md` "Anchors" rewritten accordingly.
- Probes: `_s4/probe_f1_f4.R`, `probe2_leek.R`, `probe3_chain.R` (logs `_s4/probe{1,2,3}.log`).

Value-by-value explanation of the difference (why A6a fails)
- Same versions as the vignette build (sva 3.60.0, limma 3.68.5; vignette compiled 2026-05-05 for Bioc 3.23), so
  this is not a version difference. In the locked container `num.sv(edata, mod, method = "leek")` gives **4**, the
  vignette printed **2**.
- Cause, from the `num.sv` source (`_s4/probe2.log`): the leek branch counts, for j = 1..10 row subsets,
  eigenvalues of `t(R) %*% R / (jn) - P * sigbar` above `a * (jn)^(-1/3) * 57` for `a` on `seq(0, 2, length = 100)`,
  i.e. starting at a threshold of exactly 0. Three of those eigenvalues are exact zeros in theory (the null space of
  the residual projector P, rank of `mod` = 3); numerically they are +/-1e-16 (`_s4/probe3.log`: e.g. j = 1:
  `2.365e-17 -5.798e-17 -7.147e-16`, count > 0 = 55; j = 7: count > 0 = 57). Their signs change the counts `rhat`,
  hence the variance profile and the mode. Perturbing the input by 1e-12 gives n.sv = 5, 4, 2, 5, 5; the TSV round
  trip (cells differ by <= 4.97e-14) gives 2 -- which is why the engine's A3 reports 2.
- Downstream, with n.sv = 4 the first row becomes 207783_x_at C1 = -13.50399 (printed -13.45607), F = 8551.258,
  P = 1.072143e-67; with the printed n.sv = 2 every printed value is reproduced (A6b). So the whole difference is
  the leek count, not sva(), f.pvalue or limma.

## F2 -- joint design check with all protected variables (PACK S1 P-2)

What changed
- `scripts/sva_batch_core.R` `sb_estimable_cols()` (:174) and `sb_joint_check()` (:185), called in
  `sva_batch_compute()` before any sva function (combat/combat_seq): rebuilds exactly the design ComBat/ComBat_seq
  test internally (`cbind(model.matrix(~ -1 + batch), mod)`, all-one columns dropped; sva 3.60.0 source in
  `_s4/probe1.log`, `probe2.log`) from batch + `--covariates` + `--study-var`, and tests the estimability of every
  coefficient via the null space. Typed `OS_INVALID_DESIGN` for: no study coefficient estimable (full confounding);
  some study coefficient not estimable (partial confounding that isolates a level; the message names it); all study
  coefficients estimable but the design rank deficient (a covariate confounded with the batch; the message names
  it). `sb_covariate_frame()` refuses a single-level covariate. `sb_mod_combat()` annotates column roles.
- "partial" now means: full-rank joint design, every study coefficient checked estimable, >= 1 empty batch x
  study cell (before: a rank deficit that always made ComBat stop). SB-05 text (`scripts/sva_batch_qc.R`), batch
  report, JSON `joint_design{estimability_check, study_estimable, rank, n_columns, empty_batch_study_cells}` and
  the Methods sentence state the actual check result; "contrast remains estimable" is no longer written.
- Docs: `references/qc-rules.md` SB-05 + typed-error list, `references/troubleshooting.md`, `SKILL.md`.

Evidence (`sva-batch-final.log`; first shown in `_s4/f2.log`)
- E9 (combat and combat_seq; `syn_samples` with `cov1` = batch, `--study-var grp --covariates cov1`):
  `OS_INVALID_DESIGN: --covariates cov1 confounded with --batch (... rank 3 of 4 columns ...)`, no raw package
  message, no output matrix.
- E10 (grp3 = a,a,b,b | c,c,c,c): `... coefficient(s) c (against the reference level) are NOT estimable ...`.
- E11 (grp3 = a,a,b,b | c,c,b,b): exit 0, status partial, SB-05 triggered, draft and batch report contain
  "rank 4 of 4 columns; all 2 study-variable coefficient(s) estimable" and "partially confounded (2 empty ...)".
- E12 single-level covariate -> typed error. E4/E5 unchanged PASS.
- A1 bladderbatch: batch x cancer has 8 empty cells (0/11/0; 0/14/4; 0/0/4; 5/0/0; 4/15/0) -> status **partial**
  (was "ok"), rank 7 of 7, both cancer coefficients estimable; SB-05 now fires on A1 (1 of 8 rules). The A1 ComBat
  replay is unchanged.

## F3 -- actual models and parameters in report, JSON, Methods (PACK T/W, S1 P-2/P-3)

What changed
- `scripts/sva_batch_core.R`: every sva/limma call takes its result-affecting arguments from one list recorded in
  `r$calls` (ComBat, ComBat_seq, num.sv, sva/svaseq, removeBatchEffect), so the text prints what the call received;
  `sb_model_formulas()` (:321) gives the protected design, fitted/full model and null model with the user's column
  names.
- `scripts/sva_batch_report.R`: `sb_param_lines()` (:48) -> batch report section "Models and parameters (the calls as
  run)"; JSON `models` + `calls`; `sb_template_values()` (:220) new slots `{model_sentence}`, `{parameter_sentence}`
  and a rewritten `{sv_sentence}` (includes the display removeBatchEffect arguments); `references/reporting-templates.md`
  template + slot table updated. It states that leek does not use B/seed, that numSVmethod is unused when n.sv is
  given, and the svaseq constant.
- `$` on the calls list was replaced by `[[` (partial matching `cl$sva` -> `cl$svaseq` would have mislabelled).

Evidence: `W` block of the smoke test (a1 combat, a2 sva/be, a3 sva/leek, a4 svaseq, a5 combat_seq, f2 sva with a
covariate): batch report, Methods and JSON each contain the path's actual strings/values, e.g.
`sva::ComBat(par.prior = TRUE, prior.plots = FALSE, mean.only = FALSE, ref.batch = NULL)`,
`sva::num.sv(method = "be", vfilter = NULL, B = 20, seed = 20260925) -> n.sv = 9`,
`sva::svaseq(..., B = 5, numSVmethod = "be", constant = 1, n.sv = 1)`,
`ComBat_seq was run with full_mod = TRUE, shrink = FALSE, shrink.disp = FALSE ... covar_mod = NULL`,
"The full model was ~ cov1 + grp and the null model ~ cov1". All PASS in `sva-batch-final.log`.

## F4 -- PACK F ComBat prior diagnostic

What changed
- `scripts/sva_batch_core.R` `sb_combat_prior()` (:269): recomputes, in base R and line for line after the sva
  3.60.0 `ComBat()` source (`deparse(sva::ComBat)`, `sva:::aprior`, `sva:::bprior`, `sva:::dinvgamma` in
  `_s4/probe1.log`), gamma.hat, delta.hat (genefilter rowVars, n - 1), gamma.bar, t2, a.prior, b.prior, including
  ComBat's zero-variance-within-batch row exclusion; prior curves on ComBat's own grid (100 points over
  `density()$x`): normal for gamma, inverse gamma for delta (log-scale evaluation, 0 for x <= 0). `prior.plots`
  stays FALSE (no base graphics). Registered in `scripts/calls_registry.json` (`derived_diagnostics`, and the
  `prior.plots` note).
- `scripts/sva_batch_report.R`: `figures/combat_prior` via the shared `os_prior_density()`; with more batches than
  fit the journal maximum height (the builder is 30 + 38 mm per batch; nature 170 mm -> 3 per figure) the batches
  are split over `combat_prior`, `combat_prior_2`, ... (`sb_prior_chunks()` :85; FIGURE_STYLE "split the figure");
  `tables/combat_prior.csv` (batch, n, gamma_bar, tau2, a_prior, b_prior, n_features, set-aside count); batch report
  section "ComBat prior diagnostic"; JSON `combat_prior`; Methods `{prior_sentence}`.
- Drawn ONLY on `--method combat` (par.prior = TRUE, mean.only = FALSE). combat_seq (shrink = FALSE: no prior is
  fitted) and sva/svaseq (no batch-effect prior): no figure/table, and the batch report says "Not applicable" with
  the reason.

Evidence (`sva-batch-final.log`, A1 F4 lines)
- ComBat's own internals captured with `trace()` at function exit: module gamma.hat / delta.hat (5 x 22,283) max
  |diff| **0.00e+00 / 0.00e+00**; gamma.bar, t2, a.prior (5.2651/7.41455/3.39789/3.10691/8.71633), b.prior
  (4.6831/6.43578/2.22776/2.61475/9.09342) equal.
- ComBat's adjusted matrix rebuilt from the module's estimates with `sva:::it.sol` and ComBat's back-transformation:
  max |diff| vs direct ComBat **0.00e+00**, and equal to the engine's corrected matrix.
- tables/combat_prior.csv equals the internals; the inverse-gamma curve equals `sva:::dinvgamma` on 500 grid points.
- Captions of both figures state method, batches and features; no `Rplots.pdf`.
- F4 a2/a4/a5: no combat_prior outputs, report says why.

## Figures looked at (Read tool, PNGs from `_smoke/sva-batch-smoke/`, run f34b; code unchanged after)
- a1 `combat_prior.png` (batches 1-3) and `combat_prior_2.png` (4-5): 2 columns (gamma / delta) per batch, black
  kernel vs red prior, legend at bottom, nothing clipped; batch 2 gamma is bimodal against the normal prior and the
  delta priors are narrower than the empirical densities -- a real, readable diagnostic.
- a1 `batch_pca.png`: colour = batch, shape = cancer, both legends; after-panel shows batches mixing.
- a2, a3 `batch_pca.png`: colour = cancer, SV removal display; legends present, nothing clipped.
- a4 `batch_pca.png` (svaseq) and e11 `batch_pca.png` (combat_seq): readable, legends present; axes in the
  hundreds/millions because the display PCA runs on raw counts (see Notes).
- a5 `batch_pca.png`: colour = batch, shape = group, legends present.

## Known failing anchors
- **A6a PRINTED (two assertions)**: the vignette's verbatim `n.sv = num.sv(edata,mod,method="leek")` gives 4 in the
  locked container (printed 2, `sva.rendered.txt:141`); consequently the verbatim chain's topTableF differs from the
  printed table (first row C1 -13.50399 vs -13.45607). Cause: floating-point sign noise of three theoretically zero
  eigenvalues at leek's a = 0 threshold (evidence above; `_s4/probe2.log`, `probe3.log`). Kept strict; printed as
  `KNOWN-FAILING ANCHOR:` lines at the end of the smoke output. The downstream chain itself is verified by A6b
  (printed) and A6c (replay). Owner decision needed on whether to register a revised anchor (e.g. treat the printed
  n.sv = 2 as the vignette's intermediate value, as A6b does); not decided here.

## Owner items (left pending)
- ComBat_seq with a continuous `--study-var`: still `OS_UNSUPPORTED_DESIGN` (S1 appendix clarify item).
- SV removal output (`removeBatchEffect(covariates = SVs, design = full model)`) remains display-only; its
  arguments are now reported (F3).
- A6a anchor revision (above).
- F2 changes the meaning of "partial": bladderbatch (A1) is now reported as partially confounded (8 empty cells,
  all cancer contrasts estimable) and SB-05 fires; confirm this reading of P-2 ("部分混杂报告，并检查目标 contrast 可估").
- Handoff: the corrected output keeps type `batch_corrected_matrix`. sva-batch does **not** set
  `batch_corrected_lineage = TRUE`: its `sv_table` is estimated from the uncorrected input and must stay usable by
  the DE design; only the corrected matrix is corrected (the type already enforces the refusal, D4 PASS).

## Shared needs (none blocking)
- `skills/_shared/scripts/fig_mod_bulk.R` `os_prior_density()`: `default_height_mm = 30 + 38 * n_batches` exceeds
  the nature maximum (170 mm) for more than 3 batches, so `os_finalize_figure()` stops with OS_FIG_TOO_TALL. The
  module splits the batches over several figures (F4). Optional shared improvement: accept a batch subset / page
  argument or state the per-figure batch limit. Facet strips read "1: additive (gamma hat)"; for numeric batch
  levels an optional `batch_label` (e.g. "batch 1") would read better.

## Notes for the final verifier
- F3 and F4 share the report functions and were committed together (commit "F3+F4") and verified together (run f34b,
  then gold/final).
- Display PCA for the count methods (combat_seq, svaseq) runs on the raw count scale (`os_batch_pca_pair()` ->
  `os_pca_scores()` without a transform), so PC1 is dominated by highly expressed genes (a4: PC1 94%). Not in the F
  list and not changed; flagged for the owner/coordinator.
- The smoke lines `A6a` print `KNOWN-FAILING ANCHOR:` and are not counted as failures; everything else must PASS.
- sva's own unbuffered "Iteration (out of 5 ):" print shares a line with the next PASS line in the log (cosmetic).
