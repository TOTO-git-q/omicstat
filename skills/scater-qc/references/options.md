# Native options and evidence mapping

| option | locked default / vignette value | required? | S0 extraction parameter key |
|---|---|---|---|
| --input | none | no / conditional | none |
| --from-run | none | no / conditional | none |
| --outdir | none | yes | none |
| --spec | none | no / conditional | none |
| --mt-genes | none | yes | none |
| --species | none | yes | none |
| --id-type | none | yes | none |
| --qc-mode | none | yes | none |
| --nmads | none | no / conditional | none |
| --min-counts | none | no / conditional | none |
| --min-features | none | no / conditional | none |
| --max-mito | none | no / conditional | mito_cutoff |
| --batch-col | none | no / conditional | none |
| --metrics-args | none | no / conditional | none |
| --filter-args | none | no / conditional | none |
| --seed | 20260925 | no | none |
| --journal | nature | no | none |

Required study choices have no implicit default. JSON argument files expose all supplementary arguments of their named locked functions, including delegated `...` arguments; missing entries use native defaults. Primary flags take precedence. `calls_registry.json` contains container-read function/method defaults. Examples are demonstrations, never literature-derived defaults.
