# Parameters

Choices are declared before examining outcomes. No contract hash can substitute for a real contract file.

| Flag | Default | Meaning |
| --- | --- | --- |
| `--input` | `required` | Independent-unit response CSV |
| `--response` | `required` | Continuous response column |
| `--dose` | `required` | Untransformed nonnegative dose column |
| `--unit` | `required` | Unique biological-unit column |
| `--dose-unit` | `required` | Dose measurement unit |
| `--model` | `required` | Prespecified log-logistic model |
| `--response-levels` | `required` | Comma-separated ED levels |
| `--response-type` | `required` | Response level interpretation |
| `--reference` | `required` | ED reference |
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
| --input | "required" | candidate entry script |
| --response | "required" | explicit required CLI declaration |
| --dose | "required" | explicit required CLI declaration |
| --unit | "required" | explicit required CLI declaration |
| --dose-unit | "required" | explicit required CLI declaration |
| --model | "required" | explicit required CLI declaration |
| --response-levels | "required" | explicit required CLI declaration |
| --response-type | "required" | explicit required CLI declaration |
| --reference | "required" | explicit required CLI declaration |
| --ci-level | "required" | explicit required CLI declaration |
| --seed | "required" | explicit required CLI declaration |
| --outdir | "required" | explicit required CLI declaration |
| --development-mode | "off" | actual CLI declaration; conditional guard reviewed |
<!-- registry:end -->
