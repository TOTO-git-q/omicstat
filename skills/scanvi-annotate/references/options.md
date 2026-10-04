# Option evidence mapping

Locked defaults are captured in `scripts/calls_registry.json`; tutorial examples are context, not universal scientific choices. Required values are chosen explicitly. See the frozen L1 tutorial and `parameters.md` for meaning and allowed values.

| option | locked default / vignette value | required? | S0 extraction parameter key |
|---|---|---|---|
| `--input` | None | no | `none` |
| `--from-run` | None | no | `none` |
| `--upstream-object` | None | no | `none` |
| `--outdir` | no scientific default; consult L1 tutorial example | yes | `none` |
| `--spec` | None | no | `none` |
| `--study-contract` | None | no | `none` |
| `--species` | no scientific default; consult L1 tutorial example | yes | `none` |
| `--annotation` | no scientific default; consult L1 tutorial example | yes | `none` |
| `--sample-col` | no scientific default; consult L1 tutorial example | yes | `none` |
| `--counts-layer` | no scientific default; consult L1 tutorial example | yes | `none` |
| `--seed` | 20260925 | no | `seed` |
| `--journal` | 'nature' | no | `none` |
| `--labels-col` | no scientific default; consult L1 tutorial example | yes | `labels_key` |
| `--unlabeled-category` | no scientific default; consult L1 tutorial example | yes | `unlabeled_category` |
| `--cluster-col` | no scientific default; consult L1 tutorial example | yes | `none` |
| `--prediction-col` | 'scanvi_label' | no | `none` |
| `--max-epochs` | no scientific default; consult L1 tutorial example | yes | `max_epochs` |
| `--samples-per-label` | None | no | `n_samples_per_label` |
| `--batch-size` | 128 | no | `batch_size` |
| `--min-confidence` | no scientific default; consult L1 tutorial example | yes | `none` |
| `--help` | None | no | `none` |
| `--train-size` | `0.9` (model.train.train_size; value) | no | `train_size` |
| `--validation-size` | `None` (model.train.validation_size; value) | no | `validation_size` |
| `--shuffle-set-split` | `on` (model.train.shuffle_set_split; boolean; on\|off) | no | `shuffle_set_split` |
| `--adversarial-classifier` | `none` (model.train.adversarial_classifier; boolean; on\|off\|none) | no | `adversarial_classifier` |
| `--datasplitter-kwargs` | `None` (model.train.datasplitter_kwargs; object) | no | `datasplitter_kwargs` |
| `--plan-kwargs` | `None` (model.train.plan_kwargs; object) | no | `plan_kwargs` |
| `--use-posterior-mean` | `on` (model.predict.use_posterior_mean; boolean; on\|off) | no | `use_posterior_mean` |

Structured options accept JSON objects/lists, not Python expressions. `--groups` accepts `all` or a JSON list of cluster names; `--mask-var` names a Boolean var column. Optional numeric values omitted mean the locked `None`. Boolean options use `on`/`off` (and `none` where the API allows it). Partition types name supported leidenalg classes and require a compatible native Leiden implementation. Actual converted native arguments are recorded in the result summary and Methods.
