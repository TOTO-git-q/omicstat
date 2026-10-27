# Method basis

Package pins: {"anndata": "0.13.3.post0", "scanpy": "1.12.4", "scvi-tools": "1.5.1"}.

- Official API/tutorial: https://docs.scvi-tools.org/en/1.5.1/api/reference/scvi.model.SCVI.html
- Official API/tutorial: https://docs.scvi-tools.org/en/1.5.1/tutorials/notebooks/quick_start/api_overview.html

Documentation lookup attempted on 2026-09-30. The scvi-tools 1.5.1 API and current official Scanpy tutorial were readable; not all version-specific Scanpy URLs were accessible. These are official source pointers, not a claim that the pinned package or every linked page was inspected. Locked-image formals must be exported and checked at sealing. No printed anchor values were invented. See tests/fixtures/make_anchor.py and acceptance/data/ANCHOR_REGISTRY.md.

The igraph Leiden backend follows the official scanpy tutorial; directed=False and n_iterations=-1 are explicit. QC thresholds, HVG/PC counts, resolution and training budget in examples are examples, never silent scientific defaults.

## Locked evidence review (2026-10-01)

Installed inspect.signature was compared with `/home/<user>/omic-s0-c/acceptance/exemplars/scvi-integrate/L1_pypi2026-09-15/defaults.tsv`. The old PACK alpha preset/RNG claims are superseded by the re-pinned scanpy 1.12.4 source and resolved_defaults.tsv; literature counts are context only (S0_VERIFICATION_M3M4 sections 3 and 4.3). This lane retains function defaults unless documented below.
The cached scvi-tutorials harmonization and model_user_guide notebooks distinguish their architecture examples (2 layers/30 latent dimensions/NB) from SCVI defaults (1/10/ZINB). Epochs and batch/label declarations are explicit user choices. CPU training/inference, fixed seed, deterministic algorithms, disabled progress/checkpoint logging and registered count layer are suite execution/state contracts. A supplied batch-size controls training and inference consistently.

## Owner adjudication 2026-10-11 (n_latent, n_layers)

`--n-latent` has no default and is required when training (not with `--latent-from-run`): reviewed literature gives 30 (6 papers), 10 (2), 64 (2), 50, 52 and 6, so no value is a majority. `--n-layers` keeps the locked scvi-tools 1.5.1 value 1; the reviewed values of 2 (11 of 12) mostly restate the official harmonization tutorial (https://docs.scvi-tools.org/en/1.5.1/tutorials/notebooks/scrna/harmonization.html), which names `n_layers=2, n_latent=30, gene_likelihood="nb"` as non-default. That triple is documented as a named configuration; the S4 option replay `tutorial_structure` already runs it.
