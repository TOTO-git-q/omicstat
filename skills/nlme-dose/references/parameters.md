# Parameters

Choices are declared before examining outcomes. No contract hash can substitute for a real contract file.

| Flag | Default | Meaning |
| --- | --- | --- |
| `--response` | `required` | Response column |
| `--dose` | `required` | Positive untransformed dose column |
| `--subject` | `none` | Optional assertion matching mandatory --unit-col |
| `--random-parameter` | `required` | One scalar random effect |
| `--direction` | `required` | Prespecified response direction |
| `--method` | `required` | Estimation method |
| `--residual` | `required` | Conditional residual structure |
| `--singular-tol` | `required` | Relative random SD boundary tolerance |
| `--max-iter` | `required` | Optimizer maximum iterations |
| `--input` | `required` | Input CSV |
| `--dose-unit` | `required` | Actual concentration unit or reciprocal dilution |
| `--ci-level` | `required` | Prespecified confidence level |
| `--study-contract` | `none` | Optional validated study contract JSON |
| `--seed` | `required` | Recorded reproducibility seed |
| `--outdir` | `required` | New or empty output directory |
| `--development-mode` | `off` | Explicit candidate execution |
| `--spec` | `none` | Replay resolved spec |
| `--study-contract-sha256` | `none` | shared StudyContract byte binding; see _shared/docs/STUDY_CONTRACT.md |
| `--help` | `off` | show this help and exit |

Actual source API signatures are preserved in ../installed_api.json. Source runtime versions are historical candidate evidence, not installed versions in every developer workspace.

<!-- registry:begin -->
| Flag | Default | Source |
|---|---|---|
| --response | "required" | prespecified candidate entry contract |
| --dose | "required" | prespecified candidate entry contract |
| --unit-col | "required" | prespecified candidate entry contract |
| --subject | null | prespecified candidate entry contract |
| --technical-policy | "required" | prespecified candidate entry contract |
| --random-parameter | "required" | prespecified candidate entry contract |
| --direction | "required" | prespecified candidate entry contract |
| --method | "required" | prespecified candidate entry contract |
| --residual | "required" | prespecified candidate entry contract |
| --singular-tol | "required" | prespecified candidate entry contract |
| --max-iter | "required" | prespecified candidate entry contract |
| --input | "required" | prespecified candidate entry contract |
| --dose-unit | "required" | prespecified candidate entry contract |
| --ci-level | "required" | prespecified candidate entry contract |
| --study-contract | "none" | prespecified candidate entry contract |
| --seed | "required" | prespecified candidate entry contract |
| --outdir | "required" | prespecified candidate entry contract |
| --development-mode | false | prespecified candidate entry contract |
| --spec | null | prespecified candidate entry contract |
<!-- registry:end -->
