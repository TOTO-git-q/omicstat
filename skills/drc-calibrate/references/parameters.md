# Parameters

Choices are declared before examining outcomes. No contract hash can substitute for a real contract file.

| Flag | Default | Meaning |
| --- | --- | --- |
| `--mode` | `required` | Assay analysis mode |
| `--model` | `required` | Prespecified standard or titer curve |
| `--blank-policy` | `required` | Explicit blank correction |
| `--max-cv` | `required` | Maximum technical CV percent |
| `--lloq` | `none` | Validated lower quantification limit in well units |
| `--uloq` | `none` | Validated upper quantification limit in well units |
| `--titer-definition` | `none` | Titer threshold definition |
| `--endpoint-response` | `none` | Corrected response endpoint |
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

Actual source API signatures are preserved in scripts/calls_registry.json captured_signatures. Source runtime versions are historical candidate evidence, not installed versions in every developer workspace.

<!-- registry:begin -->
| Flag | Default | Source |
|---|---|---|
| --unit-col | "required" | prespecified candidate entry contract |
| --mode | "required" | prespecified candidate entry contract |
| --model | "required" | prespecified candidate entry contract |
| --blank-policy | "required" | prespecified candidate entry contract |
| --max-cv | "required" | prespecified candidate entry contract |
| --lloq | null | prespecified candidate entry contract |
| --uloq | null | prespecified candidate entry contract |
| --titer-definition | null | prespecified candidate entry contract |
| --endpoint-response | null | prespecified candidate entry contract |
| --input | "required" | prespecified candidate entry contract |
| --dose-unit | "required" | prespecified candidate entry contract |
| --ci-level | "required" | prespecified candidate entry contract |
| --study-contract | "none" | prespecified candidate entry contract |
| --seed | "required" | prespecified candidate entry contract |
| --outdir | "required" | prespecified candidate entry contract |
| --development-mode | false | prespecified candidate entry contract |
| --spec | null | prespecified candidate entry contract |
<!-- registry:end -->

Biological identity is mandatory through --unit-col. Unknown sample IDs are assay aliquots;
biological_units.csv exposes the mapping. Repeated aliquots do not increase biological n.
