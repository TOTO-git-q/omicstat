# Parameter defaults and conditions

All original defaults stay unchanged. New choice values are explicit, with no recommendations.

| Flag | Default | Meaning |
|---|---|---|
| --mode | required | Train or externally validate frozen coefficients |
| --from-run | required | Verified expression handoff |
| --signature-run | null | Frozen cox_signature run for validation |
| --clinical | required | Clinical table |
| --unit-col | required | Unique biological subject identity |
| --time-col | required | Positive right-censored follow-up |
| --event-col | required | Explicit zero censored one event |
| --time-unit | required | Declared units, frozen across cohorts |
| --genes | required | Ordered prespecified gene IDs |
| --covariates | required | Gene-only signature boundary |
| --expression-scale | required | Declared identical preprocessing scale |
| --min-events | required | Minimum observed event count |
| --folds | null | Training CSV unit,fold; exact biological matching |
| --standardize | null | Training glmnet standardization |
| --nlambda | null | Training path grid size |
| --lambda-min-ratio | null | Training path extent |
| --selection | null | Penalty selection rule |
| --lambda | null | Fixed penalty value within fitted path |
| --cv-measure | null | Cross-validation objective |
| --cv-grouped | null | Cox CV risk-set evaluation |
| --max-iter | null | Training optimizer maximum passes |
| --thresh | null | Training convergence threshold |
| --cox-ties | null | Explicit version-stable Breslow ties |
| --cutoff | null | Training risk split to freeze |
| --cutpoint | null | Prespecified training risk cutoff |
| --roc-times | required | Sorted IPCW ROC horizons |
| --risk-times | required | Sorted KM risk times |
| --ci-level | required | KM marginal CI |
| --journal | required | Figure style |
| --study-contract | none | Optional validated contract |
| --development-mode | false | Explicit candidate execution |
| --seed | required | Recorded seed; folds never silently regenerated |
| --outdir | required | New empty output directory |
| --prediction-workup | "none" | Optional source-copy prediction workup; none preserves original behavior |
| --dataset-name | null | Dataset name for every workup figure; no identifying subject details |
| --planning-source | null | Citation for external prior Riley planning assumptions; never derived from this fitted cohort |
| --planning-parameters | null | All prespecified candidate parameters, at least every candidate gene |
| --planning-cs-r2 | null | Prior anticipated Cox-Snell R-squared, strictly between zero and target shrinkage |
| --planning-shrinkage | null | Prespecified target shrinkage strictly below one; no automatic recommendation |
| --planning-rate | null | Prior event rate per declared time unit, strictly positive |
| --planning-horizon | null | Positive planning horizon equal to the primary calibration horizon |
| --planning-mean-followup | null | Positive prior mean follow-up in the same declared time unit |
| --bootstrap-B | null | Requested bootstrap budget; source floor200, explicit serial technical cap2000 |
| --bootstrap-seed | null | Explicit reproducible bootstrap seed, no inferred seed |
| --bootstrap-fit-policy | null | Acknowledge repeating original penalized CV/fit with original biological folds |
| --baseline-estimator | null | Acknowledge training-only baseline at frozen original coefficients, no unpenalized model replacement |
| --calibration-horizon | null | Primary positive event-risk horizon inside training support, frozen externally |
| --calibration-min-bin | null | Minimum original subjects per aggregate KM calibration bin |
| --calibration-max-bins | null | Requested maximum bins; no smoothing or invented bin values |
| --calibration-slope-fit | null | Acknowledge source-native Cox slope diagnostic, distinct from prediction coefficients |
| --spec | null | Resolved spec replay |

<!-- registry:begin -->
| Flag | Default | Source |
|---|---|---|
| --mode | "required" | prespecified candidate entry contract |
| --from-run | "required" | prespecified candidate entry contract |
| --signature-run | null | prespecified candidate entry contract |
| --clinical | "required" | prespecified candidate entry contract |
| --unit-col | "required" | prespecified candidate entry contract |
| --time-col | "required" | prespecified candidate entry contract |
| --event-col | "required" | prespecified candidate entry contract |
| --time-unit | "required" | prespecified candidate entry contract |
| --genes | "required" | prespecified candidate entry contract |
| --covariates | "required" | prespecified candidate entry contract |
| --expression-scale | "required" | prespecified candidate entry contract |
| --min-events | "required" | prespecified candidate entry contract |
| --folds | null | prespecified candidate entry contract |
| --standardize | null | prespecified candidate entry contract |
| --nlambda | null | prespecified candidate entry contract |
| --lambda-min-ratio | null | prespecified candidate entry contract |
| --selection | null | prespecified candidate entry contract |
| --lambda | null | prespecified candidate entry contract |
| --cv-measure | null | prespecified candidate entry contract |
| --cv-grouped | null | prespecified candidate entry contract |
| --max-iter | null | prespecified candidate entry contract |
| --thresh | null | prespecified candidate entry contract |
| --cox-ties | null | prespecified candidate entry contract |
| --cutoff | null | prespecified candidate entry contract |
| --cutpoint | null | prespecified candidate entry contract |
| --roc-times | "required" | prespecified candidate entry contract |
| --risk-times | "required" | prespecified candidate entry contract |
| --ci-level | "required" | prespecified candidate entry contract |
| --journal | "required" | prespecified candidate entry contract |
| --study-contract | "none" | prespecified candidate entry contract |
| --development-mode | false | prespecified candidate entry contract |
| --seed | "required" | prespecified candidate entry contract |
| --outdir | "required" | prespecified candidate entry contract |
| --prediction-workup | "none" | P0-13B4 explicit source-copy adaptation contract |
| --dataset-name | null | P0-13B4 explicit source-copy adaptation contract |
| --planning-source | null | P0-13B4 explicit source-copy adaptation contract |
| --planning-parameters | null | P0-13B4 explicit source-copy adaptation contract |
| --planning-cs-r2 | null | P0-13B4 explicit source-copy adaptation contract |
| --planning-shrinkage | null | P0-13B4 explicit source-copy adaptation contract |
| --planning-rate | null | P0-13B4 explicit source-copy adaptation contract |
| --planning-horizon | null | P0-13B4 explicit source-copy adaptation contract |
| --planning-mean-followup | null | P0-13B4 explicit source-copy adaptation contract |
| --bootstrap-B | null | P0-13B4 explicit source-copy adaptation contract |
| --bootstrap-seed | null | P0-13B4 explicit source-copy adaptation contract |
| --bootstrap-fit-policy | null | P0-13B4 explicit source-copy adaptation contract |
| --baseline-estimator | null | P0-13B4 explicit source-copy adaptation contract |
| --calibration-horizon | null | P0-13B4 explicit source-copy adaptation contract |
| --calibration-min-bin | null | P0-13B4 explicit source-copy adaptation contract |
| --calibration-max-bins | null | P0-13B4 explicit source-copy adaptation contract |
| --calibration-slope-fit | null | P0-13B4 explicit source-copy adaptation contract |
| --spec | null | prespecified candidate entry contract |
<!-- registry:end -->
