# limma-array parameters

The input must already be normalized on a log2 scale. No array-platform normalization is performed in this module.

| Flag | Default | Allowed | Why |
|---|---|---|---|
| `--matrix` | none | path | Normalized log2 intensities, one row per probe. |
| `--samples` | none | path | Align every array by identifier. |
| `--from-run` | none | path | Verified expression and sample handoff. |
| `--outdir` | (required) | path | Run outputs. |
| `--spec` | none | path | Replay a resolved run. |
| `--sample-col` | sample | string | Sample ID field. |
| `--condition` | condition | string | Compared treatment factor. |
| `--reference` | (required) | string | Denominator. |
| `--target` | (required) | string | Numerator. |
| `--covariates` | none | string | Fixed effects. |
| `--keep-other-levels` | off | switch | Keep condition levels other than reference/target in the design (User's Guide 17.4.7 `~Treatment`); their arrays enter the residual variance, only target vs reference is tested. Off: exactly two levels required. |
| `--platform` | (required) | agilent|other | Agilent preset; other requires explicit trend and robust. |
| `--trend` | auto | auto|true|false | Agilent auto is TRUE; other is explicit pending owner. |
| `--robust` | auto | auto|true|false | Agilent auto is TRUE; other is explicit pending owner. |
| `--control-ids` | none | path | Remove known control probes. |
| `--controls-removed` | off | switch | Declare prior control removal. |
| `--above-background` | none | path | Platform detection matrix; no implicit filtering. |
| `--background-k` | none | int in [1, 100000] | Explicit minimum detected arrays (S1 P-2). |
| `--technical-ids` | none | path | Validated technical replicate IDs for avereps. |
| `--verified-technical-ids` | off | switch | Declaration required before avereps. |
| `--probe-annotation` | none | path | CSV `feature_id,symbol,entrez[,...]` keyed by the matrix probe IDs; merged per tested feature (after avereps), unmapped marked; hashed in provenance. |
| `--preprocessing` | none | string | Upstream background correction / normalization as declared by the user; reported verbatim in Methods, otherwise "not stated". Never inferred or verified. |
| `--alpha` | 0.05 | num in [0.000001, 0.5] | BH reporting cutoff. |
| `--min-effect-fc` | 1 | num in [1, 100] | Linear FC used by treat if >1. |
| `--display-lfc-filter` | 0 | num in [0, 20] | Post-test display only, off by default. |
| `--label-n` | 5 | int in [0, 30] | Figure labels. |
| `--seed` | 20260925 | int | Recorded seed. |
| `--journal` | nature | nature|cell|science|generic | Figure preset. |

## Fixed calls

`lmFit` uses `method="ls"` and explicit design; Agilent `eBayes` uses `proportion=0.01`, `stdev.coef.lim=c(0.1,4)`, `trend=TRUE`, `span=NULL`, `robust=TRUE`, `winsor.tail.p=c(0.05,0.1)`, `legacy=NULL`. Optional `treat` uses the declared linear FC and its log2 value. `topTable` uses BH, no inferential FC post-filter. Technical averaging calls `avereps` only with a validated technical ID. See PACK S1 P-1/P-2.

## Auxiliary inputs and provenance

`--control-ids`, `--above-background`, `--technical-ids` and `--probe-annotation` change what is tested or reported; each one used is hashed (SHA-256) in `provenance/provenance.json` `inputs` next to the matrix and sample table.

## Probe annotation contract

Columns `feature_id`, `symbol`, `entrez` are required (extra columns such as `probe_name` are carried along); `annotation_status`, `probe_ids`, `n_probes` are reserved. IDs must match the matrix probe IDs; a file that matches none of the retained probes is refused. After technical-ID averaging the member probes of each tested feature are listed in `probe_ids`; one distinct symbol = `mapped`, none = `unmapped` (symbol empty), several = `conflicting` (values joined with `;`, never resolved by the module). Output: `tables/feature_annotation.csv`, symbols in `tables/feature_table.csv`, all annotation columns in `tables/limma_full.csv`.
