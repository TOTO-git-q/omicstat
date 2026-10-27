# Longitudinal validation and scope

ported_from: TOTO-git-q/medstat@12292d020ef4a8575a3a1db880b81786ee3547fa:skills/longitudinal-change/scripts/longitudinal_core.R

- Source `LONG-balanced-cells` uses the original seed151, 80 biological units and three visits, and independently computes B minus A at visit3 from base-R sums/counts. Preserve its original absolute tolerance1e-5. This is synthetic source numerical validation only.
- The same fitted model must reproduce source EMMs, raw/adjusted contrasts, joint tests and keyed adjustment joins. The old within-by adapter must be unchanged with longitudinal mode off. Compare the exported tables and preserve initial failures.
- KR and Satterthwaite require their exact independently available dependencies. Every returned df must be finite and positive; identical df numbers across different hypotheses are not asserted. Shared mean/contrast covariance is model-derived; no substitute t-tests are allowed.
- Duplicate unit/time, group changes, empty cells, undeclared order, unsupported correction, missing interaction, limit breach, wrong contract and degenerate fit remain typed refusals.
- Source automatic alternative model and global option changes are deliberately absent. Native API/formals and R4.6.1 execution are still pending.
- Proposed real owner example: nlme::Soybean, 412 rows of soybean plot growth in the official dataset, with Plot, Variety, Year, Time, weight. The source is https://stat.ethz.ch/R-manual/R-devel/library/nlme/html/Soybean.html. Exact package/data hashes, eligible prespecified subset, registration and fresh owner sheet remain pending; no input rows are distributed or claimed verified here.

Primary API references read for design review: https://rvlenth.github.io/emmeans/reference/joint_tests.html and https://rvlenth.github.io/emmeans/reference/emmeans.html. The published documentation may be newer than the pinned2.0.4 API, so it is not a claim of installed-formals capture. joint_tests compares EMM functions on a reference grid; weighting/covariates affect the hypothesis. This bounded adapter explicitly passes the same declared weights and df arguments to both calculations.
