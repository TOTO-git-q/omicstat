# Method basis

Package pins: {"anndata": "0.13.3.post0", "scanpy": "1.12.4"}.

- Official API/tutorial: https://scanpy.readthedocs.io/en/1.12.4/generated/scanpy.tl.rank_genes_groups.html

Documentation lookup attempted on 2026-09-30. The scvi-tools 1.5.1 API and current official Scanpy tutorial were readable; not all version-specific Scanpy URLs were accessible. These are official source pointers, not a claim that the pinned package or every linked page was inspected. Locked-image formals must be exported and checked at sealing. No printed anchor values were invented. See tests/fixtures/make_anchor.py and acceptance/data/ANCHOR_REGISTRY.md.

The igraph Leiden backend follows the official scanpy tutorial; directed=False and n_iterations=-1 are explicit. QC thresholds, HVG/PC counts, resolution and training budget in examples are examples, never silent scientific defaults.

## Locked evidence review (2026-10-01)

Installed inspect.signature was compared with `/home/<user>/omic-s0-c/acceptance/exemplars/scanpy-markers/L1_pypi2026-09-15/defaults.tsv`. The old PACK alpha preset/RNG claims are superseded by the re-pinned scanpy 1.12.4 source and resolved_defaults.tsv; literature counts are context only (S0_VERIFICATION_M3M4 sections 3 and 4.3). This lane retains function defaults unless documented below.
The cached `scanpy/docs/tutorials/basics/clustering.ipynb.rendered.txt` sections Normalization (lines 149-157), Clustering (238-243) and marker genes (399-403) support median normalization, Leiden/igraph and descriptive marker use. n_iterations=-1 retains the function default; the tutorial uses 2 as a speed example. t-test retains the resolved package default; the tutorial shows Wilcoxon as another descriptive test. Tutorial counts/dimensions/resolutions and QC thresholds remain explicit user choices. CPU, a fixed seed, counts/logcounts layers, output keys and deterministic PCA conventions are suite execution/state contracts.

## Owner adjudication 2026-10-11 (`--test`)

`--test` keeps the scanpy 1.12.4 documented default `t-test` (owner adjudication 2026-10-11). The official scanpy clustering tutorial runs `method="wilcoxon"`, and of the 21 reviewed papers that report a test, 16 used Wilcoxon (13 of 16 in scverse-only workflows) and 5 the t-test. The benchmark by Pullin and McCarthy (2024, Genome Biology, PMID 38409056) finds simple methods, especially the Wilcoxon rank-sum test, Student's t-test and logistic regression, to be effective, so neither choice is an error here. The module reports `descriptive_cluster_markers`: scores and P values rank genes within the descriptive cluster comparison and are not evidence of differential expression. Note the cross-module difference: seurat-markers defaults to `wilcox` (its locked function default) while scanpy-markers defaults to `t-test` (its locked function default). To reproduce the scanpy tutorial or to place results next to seurat-markers output, pass `--test wilcoxon` explicitly (and consider `--tie-correct on`) and report it. Verified sources: scanpy 1.12.4 `rank_genes_groups` documentation (default method t-test); the official scanpy clustering tutorial (wilcoxon); Pullin JM, McCarthy DJ. A comparison of marker gene selection methods for single-cell RNA sequencing data. Genome Biology 2024 (PMID 38409056), which describes Welch's t-test as the default test of Scanpy.
