# method-basis -- sva-batch

Format: claim -> source. "Vignette" = the sva vignette shipped with the installed package
(`sva.Rnw` / its rendered text), exported with its sha256 to
`acceptance/exemplars/sva-batch/L1_bioc3.23/`. "Rd" = the installed package's own help page.
No reference here is written from memory; every quoted console message and vignette section
title below was grepped in `L1_bioc3.23/sva/vignettes/sva.rendered.txt`.

Versions at S0/S2: sva 3.60.0, limma 3.68.5 (Bioconductor 3.23; `env/pkg_lock.csv`). The
container re-checks every function default in `calls_registry.json` (`check_default_drift`); a
difference fails the smoke test until PACK section D is updated.

## Method

| Claim | Source |
|---|---|
| ComBat adjusts for known batch effects with an empirical Bayes framework (parametric or non-parametric); returns a corrected genomic measure matrix | Johnson WE, Li C, Rabinovic A (2007). Biostatistics 8(1):118-127 (`sva/Rd/ComBat.Rd` `\references`); vignette "Applying the ComBat function to adjust for known batches" |
| ComBat-seq is a negative-binomial-regression improvement of ComBat that specifically targets RNA-seq counts and preserves their integer nature | vignette "ComBat-Seq for batch adjustment on RNA-Seq count data" ("specifically targets RNA-Seq count data... The adjusted data preserve the integer nature of count matrix") |
| sva estimates surrogate variables for an unknown source of variation via a full/null model pair (`mod`/`mod0`) and iteratively re-weighted least squares | Leek JT, Storey JD (2007). PLoS Genetics 3:e161; Leek JT, Storey JD (2008). PNAS 105:18718-18723 (`sva/Rd/sva.Rd` `\references`); vignette "Applying the sva function to estimate batch and other artifacts" |
| svaseq applies a moderated log transform (`log(dat + constant)`) before estimating surrogate variables from RNA-seq counts | Leek JT (2014). svaseq preprint (`sva/Rd/svaseq.Rd` `\references`); vignette "sva for sequencing (svaseq)" |
| `num.sv` estimates the number of surrogate variables by a permutation procedure ("be", Buja and Eyuboglu 1992) or an asymptotic approach (Leek 2011, "leek") | `sva/Rd/num.sv.Rd` |
| Model matrices: the null model has the adjustment variables only, the full model adds the variable(s) of interest; both are built with `model.matrix` | vignette sec 2 "Basic Statistical Setup" and sec 3 "Setting up the data from an ExpressionSet" |
| A categorical adjustment variable with p levels needs p-1 indicator columns in the protected design (ComBat's `mod`) | vignette "Applying the ComBat function to adjust for known batches" ("if you are trying to adjust for a categorical variable with p different levels, you will need to give ComBat p-1 indicator variables") -- applied identically to ComBat_seq's `covar_mod` (its own vignette example builds `covar_mat <- cbind(cov1, cov2)`, one column per binary covariate) |
| `removeBatchEffect` fits a linear model including both batches/covariates and the protected design, then removes only the nuisance component; the `covariates` argument accepts a design matrix built from unwanted technical effects (e.g. surrogate variables), and `design` should never be left at its NULL (intercept-only) default when there is a real protected design | limma `removeBatchEffect.Rd` (`\details`, `\note`) |
| `removeBatchEffect` is for plotting/exploration, not for preparing data for `lmFit`; for testing, batch belongs in the linear model instead | limma `removeBatchEffect.Rd` `\note` |
| Adjusting for surrogate variables (or a known batch via ComBat) changes which features are called differentially expressed, because "these P-values and Q-values now account for the known batch effects" / surrogate variables become adjustment variables in both the full and null model | vignette secs 5-6 ("Adjusting for surrogate variables using the f.pvalue function", "...using the limma package") |

## Open-source implementations consulted (design, not evidence)

None beyond the package's own vignette and Rd pages: the reference module (deseq2-wald) and the
sva-batch PACK's L3/L4 literature review (`acceptance/exemplars/sva-batch/literature/`) already
cover exemplar usage patterns; no additional external repository was cloned for this module.

## Anchors (PACK section C)

- **A2/A3 (engine, locked-container values)**: bladderbatch (`bladderEset` via
  `os_acceptance_data(suite, "bladderbatch", "bladderdata")`), protected design `~ cancer`
  (sorted factor levels: Biopsy, Cancer, Normal). `--num-sv-method be` (PACK P-3 default,
  `B = 20`, `seed = 20260925`) estimates `n.sv = 9` -- not a vignette-printed value. `--num-sv-method
  leek` gives `n.sv = 2`, equal to the vignette sec 4 printed `[1] 2`, **but** (S4, see A6a) the
  vignette's own `num.sv(edata, mod, method = "leek")` run in memory in the same container gives
  4: the leek procedure (`num.sv` source, `method == "leek"` branch) counts eigenvalues of
  `t(R) %*% R / (jn) - P * sigbar` above `a * (jn)^(-1/3) * ncol` for a grid of `a` that starts at
  0, and `ncol(mod) = 3` of those eigenvalues are exact zeros in theory (the null space of the
  residual projector `P`) that come out as +/-1e-16 rounding noise. Their signs decide part of
  the count; 1e-12 perturbations of the input give 2, 4 or 5, and the engine's TSV round trip
  (cells differ by <= 5e-14) happens to give 2. The A3 equality is therefore a locked-container
  value, not evidence that the printed number is reproduced.
- **Printed anchor, vignette code in the test session** (A6, `tests/run_smoke_test.R`): the
  vignette's own sec 3-6 code (`sva.Rnw:63-141`; printed output `sva.rendered.txt:117-226`) runs
  verbatim on `bladderEset`: `mod`/`mod0`, `num.sv(..., method = "leek")`, `sva(edata, mod, mod0,
  n.sv = n.sv)`, `modSv`/`mod0Sv` (SVs in both the full and the null model), `f.pvalue`,
  `lmFit`/`contrasts.fit`/`eBayes`/`topTableF(eb, adjust = "BH")`.
  - A6a (verbatim, in-session `n.sv`): KNOWN FAILING in the locked container (n.sv = 4, not the
    printed 2; the topTableF then differs as a consequence) -- kept as a strict assertion,
    documented in `acceptance/exemplars/sva-batch/S4_FIXES.md`.
  - A6b (the vignette's chain from its own printed intermediate `n.sv = 2`): reproduces all 10
    printed topTableF rows x 7 columns (C1, C2, C3, AveExpr, F, P.Value, adj.P.Val) within half
    a unit of the last printed digit, e.g. `207783_x_at` C1 = -13.45607, P = 1.207560e-69.
  - A6c (replay for the module): the engine's `tables/sv_table.csv` (A3 leek, n.sv = 2; A2 be,
    n.sv = 9) equals a direct `sva()` call on the same matrix, and the engine's SVs entered into
    the vignette's `modSv`/`mod0Sv` give the same `f.pvalue` P-values for all features and the
    same topTableF as the direct SVs; for n.sv = 2 they reproduce the printed topTableF.
- **Replay anchor** (A1): the vignette's own `ComBat(dat = edata, batch = batch, mod = modcombat,
  par.prior = TRUE, prior.plots = FALSE)` call on bladderbatch (vignette sec 7) used
  `modcombat = model.matrix(~1)` (intercept only, protecting nothing) and has no printed numeric
  result in the rendered text; PACK P-2 requires a mandatory protected study variable, so this
  module's own call always uses `mod = model.matrix(~cancer)` instead. `tests/run_smoke_test.R`
  replays `ComBat()` directly with that same (protected) design in the same session and checks the
  engine's output is byte-identical to it -- confirming the engine invokes `ComBat()` correctly,
  not that it reproduces the vignette's simplified unprotected example.
- **Replay anchor** (A5): the vignette's ComBat_seq section (sec 8) uses a simulated `rnbinom`
  matrix with no fixed seed shown in the rendered text; the console messages ("Found 2 batches",
  "Using full model in ComBat-seq.", "Adjusting for 1 covariate(s) or covariate level(s)",
  "Shrinkage off - using GLM estimates for parameters") are reproduced verbatim by
  `tests/fixtures/make_combat_seq_sim.R` (a fixed `--seed`) and the engine's output is checked
  byte-identical to a direct `ComBat_seq()` call with the same arguments.
- **Printed value** (A4): zebrafishRNASeq (`zfGenes`), `--method svaseq` with the module's default
  `num.sv(method = "be")` independently estimates `n.sv = 1` for this 6-sample dataset -- matching
  the vignette sec 13's own (there manually fixed, not estimated) `n.sv = 1` -- and
  `svaseq(dat0, mod1, mod0, n.sv = 1)$sv` prints "Number of significant surrogate variables is: 1"
  verbatim, exactly as the vignette shows.

## ComBat prior diagnostic (PACK F; S4 F4)

| Claim | Source |
|---|---|
| ComBat standardises each feature (pooled variance, grand mean + covariate part), estimates per-batch additive (`gamma.hat`, least squares on the batch indicators) and multiplicative (`delta.hat`, within-batch variance of the standardised data) effects, and fits a normal prior (`gamma.bar`, `t2`) and an inverse-gamma prior (method of moments: `a = (2 s2 + m^2)/s2`, `b = (m s2 + m^3)/s2`) per batch | `deparse(sva::ComBat)`, `sva:::aprior`, `sva:::bprior` in the locked container (`acceptance/exemplars/sva-batch/_s4/probe1.log`); Johnson, Li, Rabinovic (2007) |
| `prior.plots = TRUE` draws the kernel density of `gamma.hat[1, ]` / `delta.hat[1, ]` against `dnorm(gamma.bar, sqrt(t2))` / `dinvgamma(a, b)` on 100 points spanning `density()$x` | same source; vignette sec 7 ("black as a kernel estimate ... red as the parametric estimate") |
| The module's `sb_combat_prior()` gives ComBat's own internals exactly (max difference 0 in the locked container) and ComBat's adjusted matrix is rebuilt from them with `sva:::it.sol` | `tests/run_smoke_test.R` A1 F4 (trace() capture) |
