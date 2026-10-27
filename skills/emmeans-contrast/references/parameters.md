# Parameters

Choices are declared before examining outcomes. No contract hash can substitute for a real contract file.

| Flag | Default | Meaning |
| --- | --- | --- |
| `--from-run` | `required` | Verified lme4-lmm run |
| `--factor` | `required` | Categorical factor for pairwise contrasts |
| `--by` | `none` | Optional single categorical conditioning factor |
| `--weights` | `required` | Marginal averaging population |
| `--df-method` | `required` | Explicit degrees-of-freedom method |
| `--adjust` | `required` | Pairwise multiplicity within each by stratum |
| `--study-contract` | `none` | Optional validated study contract JSON |
| `--ci-level` | `required` | Prespecified confidence level |
| `--development-mode` | `off` | Explicitly permit unsealed development execution |
| `--seed` | `required` | Recorded reproducibility seed |
| `--outdir` | `required` | New or empty output directory |
| `--spec` | `none` | Replay resolved spec |
| `--study-contract-sha256` | `none` | shared StudyContract byte binding; see _shared/docs/STUDY_CONTRACT.md |
| `--help` | `off` | show this help and exit |

Actual source API signatures are preserved in ../installed_api.json. Source runtime versions are historical candidate evidence, not installed versions in every developer workspace.

<!-- registry:begin -->
| Flag | Default | Source |
|---|---|---|
| --study-contract | "none" | candidate entry script |
| --from-run | "required" | candidate entry script |
| --factor | "required" | explicit required CLI declaration |
| --weights | "required" | explicit required CLI declaration |
| --df-method | "required" | explicit required CLI declaration |
| --adjust | "required" | explicit required CLI declaration |
| --ci-level | "required" | explicit required CLI declaration |
| --seed | "required" | explicit required CLI declaration |
| --outdir | "required" | explicit required CLI declaration |
| --development-mode | "off" | actual CLI declaration; conditional guard reviewed |
| --longitudinal | false | Reviewed source-bound CLI literal and conditional guard; native help capture pending |
| --by | null | Reviewed source-bound CLI literal and conditional guard; native help capture pending |
| --time-levels | null | Reviewed source-bound CLI literal and conditional guard; native help capture pending |
| --dataset-name | null | Reviewed source-bound CLI literal and conditional guard; native help capture pending |
| --spec | null | Existing run_emmeans_contrast.R replay declaration |
<!-- registry:end -->

## Inference annotations

`--adjust` applies to pairwise contrasts separately within each `--by` stratum; no cross-stratum adjustment is applied. Marginal means use explicit `adjust="none"` pointwise intervals. `inference_families.csv` records declared and native summary adjustments, complete native messages, and observed table-row family membership/counts. These counts are not presented as the engine's multiplicity denominator (Tukey families count means, not all pairwise rows). The same annotations and row indices are retained in the typed metadata RDS and provenance. CI and P adjustments must be read separately from native messages.
