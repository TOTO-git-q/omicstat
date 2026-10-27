# Parameters

Choices are declared before examining outcomes. No contract hash can substitute for a real contract file.

| Flag | Default | Meaning |
| --- | --- | --- |
| `--study-contract` | `none` | Optional validated study contract JSON |
| `--development-mode` | `off` | Explicit candidate-only execution |
| `--matrix` | `required` | protein-by-sample CSV/TSV, NA preserved |
| `--samples` | `required` | one row per biological sample |
| `--sample-col` | `sample` | sample identifier column |
| `--bio-col` | `required` | unique independent biological replicate ID column |
| `--condition` | `condition` | two-group column |
| `--input-scale` | `required` | declared abundance scale, never inferred |
| `--zero-policy` | `required` | linear missing zero or observed log2 zero |
| `--normalization` | `required` | explicit median normalization choice |
| `--outdir` | `required` | new or empty output directory |
| `--spec` | `none` | resolved specification replay |
| `--reference` | `required` | denominator condition |
| `--target` | `required` | numerator condition |
| `--feature-id-type` | `required` | declared protein identifier namespace |
| `--alpha` | `0.05` | BH display threshold; does not refit |
| `--label-n` | `5` | maximum feature labels per direction |
| `--seed` | `20261015` | recorded random seed |
| `--journal` | `nature` | shared figure style |
| `--study-contract-sha256` | `none` | shared StudyContract byte binding; see _shared/docs/STUDY_CONTRACT.md |
| `--help` | `off` | show this help and exit |

Actual source API signatures are preserved in ../installed_api.json. Source runtime versions are historical candidate evidence, not installed versions in every developer workspace.

<!-- registry:begin -->
| Flag | Default | Source |
|---|---|---|
| --study-contract | "none" | candidate entry script |
| --matrix | "required" | candidate entry script |
| --samples | "required" | candidate entry script |
| --bio-col | "required" | explicit required CLI declaration |
| --input-scale | "required" | explicit required CLI declaration |
| --zero-policy | "required" | explicit required CLI declaration |
| --normalization | "required" | explicit required CLI declaration |
| --outdir | "required" | explicit required CLI declaration |
| --reference | "required" | explicit required CLI declaration |
| --target | "required" | explicit required CLI declaration |
| --feature-id-type | "required" | explicit required CLI declaration |
| --development-mode | "off" | actual CLI declaration; conditional guard reviewed |
<!-- registry:end -->
