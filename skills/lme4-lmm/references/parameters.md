# Parameters

Choices are declared before examining outcomes. No contract hash can substitute for a real contract file.

| Flag | Default | Meaning |
| --- | --- | --- |
| `--input` | `required` | Curated complete-case CSV |
| `--response` | `required` | Numeric endpoint column |
| `--subject` | `required` | Biological-unit grouping column |
| `--formula` | `required` | Explicit fixed and random-effects formula |
| `--estimation` | `required` | Prespecified estimation method |
| `--singular-tolerance` | `required` | Explicit isSingular tolerance |
| `--study-contract` | `none` | Optional validated study contract JSON |
| `--ci-level` | `required` | Prespecified confidence level |
| `--effect-plot` | `off` | Supplementary fixed-effect forest plot; off by default (profiles 22/27 vs forests 2/27 surveyed figures) |
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
| --subject | "required" | explicit required CLI declaration |
| --formula | "required" | explicit required CLI declaration |
| --estimation | "required" | explicit required CLI declaration |
| --singular-tolerance | "required" | explicit required CLI declaration |
| --ci-level | "required" | explicit required CLI declaration |
| --seed | "required" | explicit required CLI declaration |
| --outdir | "required" | explicit required CLI declaration |
| --development-mode | "off" | actual CLI declaration; conditional guard reviewed |
<!-- registry:end -->
