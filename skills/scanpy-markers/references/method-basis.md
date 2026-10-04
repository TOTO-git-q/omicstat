# Method basis

Package pins: {"anndata": "0.13.3.post0", "scanpy": "1.12.4"}.

- Official API/tutorial: https://scanpy.readthedocs.io/en/1.12.4/generated/scanpy.tl.rank_genes_groups.html

Documentation lookup attempted on 2026-09-30. The scvi-tools 1.5.1 API and current official Scanpy tutorial were readable; not all version-specific Scanpy URLs were accessible. These are official source pointers, not a claim that the pinned package or every linked page was inspected. Locked-image formals must be exported and checked at sealing. No printed anchor values were invented. See tests/fixtures/make_anchor.py and acceptance/data/ANCHOR_REGISTRY.md.

The igraph Leiden backend follows the official scanpy tutorial; directed=False and n_iterations=-1 are explicit. QC thresholds, HVG/PC counts, resolution and training budget in examples are examples, never silent scientific defaults.

## Locked evidence review (2026-10-01)

Installed inspect.signature was compared with `/home/<user>/omic-s0-c/acceptance/exemplars/scanpy-markers/L1_pypi2026-09-15/defaults.tsv`. The old PACK alpha preset/RNG claims are superseded by the re-pinned scanpy 1.12.4 source and resolved_defaults.tsv; literature counts are context only (S0_VERIFICATION_M3M4 sections 3 and 4.3). This lane retains function defaults unless documented below.
The cached `scanpy/docs/tutorials/basics/clustering.ipynb.rendered.txt` sections Normalization (lines 149-157), Clustering (238-243) and marker genes (399-403) support median normalization, Leiden/igraph and descriptive marker use. n_iterations=-1 retains the function default; the tutorial uses 2 as a speed example. t-test retains the resolved package default; the tutorial shows Wilcoxon as another descriptive test. Tutorial counts/dimensions/resolutions and QC thresholds remain explicit user choices. CPU, a fixed seed, counts/logcounts layers, output keys and deterministic PCA conventions are suite execution/state contracts.
