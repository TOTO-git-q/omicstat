# Acceptance tiers

`run_smoke_test.py` always checks syntax-linked calls, flag documentation,
default consistency and typed CLI errors. Numerical acceptance is **not**
substituted by mocks: it requires the exact pinned image. Outside it the
numerical part prints SKIP. `OMICSTAT_REQUIRE_LOCKED=1` makes that a failure.

The PBMC3k archive comes from F1 and is SHA256 checked. scVI/scANVI use the
package-owned `synthetic_iid` simulator; these are replay tests, not printed
vignette benchmarks or biological validation. Fixture settings are explicit
smoke-budget choices, not production scientific defaults.

Same-platform output is split into exact tables/labels and coordinate/probability
arrays with predeclared atol=1e-6 and rtol=1e-6. PCA/cluster replay additionally
requires ARI=1. Markers are compared to direct package replay with tighter
atol=1e-12 and rtol=1e-10. Cross-platform ARI>=0.95 acceptance remains a separate
unexecuted release gate; no cross-platform pass is claimed.

Goldens and `module_lock.json` are generated only by `generate_golden.sh` inside
the locked image. They are intentionally absent in an unsealed source delivery.
The generated acceptance record excludes R figure rendering and visual review:
run the retained anchor output through `render_figure_request.R` in the R image.

## Round-3 owner review (2026-10-17 decision)

`acceptance.json` now supplies an explicit canonical fixture using the **whole
registered PBMC3k input**, SHA256 checked by `sc_anchor.make_pbmc(max_cells=None)`.
The legacy smoke test still uses its original first-600-cell budget. The new
owner recipe explicitly supplies 600 HVGs, 10 PCs, 10 neighbors, resolution 0.5,
and seed 20260925, using the retained smoke recipe values. These are acceptance
settings, not new CLI defaults or claims that one setting is universally best.
The input has one biological sample; cells are not independent sample replicates.

The preparer writes `owner_dataset.json` with raw-archive SHA, prepared-input
SHA/bytes, actual dimensions, and the complete-input rule. No download or package
installation occurs. The executor must expose its existing verified F1 cache at
`acceptance/data/pbmc3k_filtered_gene_bc_matrices.tar.gz` in its read-only source
view. Do not commit the archive or prepared cell-level input to GitHub.

The independent replay uses the existing exact HVG comparison, PCA atol/rtol
1e-6, and ARI=1 checks. All three anchors are explicitly `replay`; no printed
cluster number is inferred. Failures remain failures. The separate resource
refusal fixture still prepares its invented 141000-nucleus input only for the
refusal stage; it can never qualify a figure for owner review.

The canonical Python FigureRequest is rendered through the independently
verified R runner. `figure_policy=required` binds this runner even though old
legacy module metadata has an empty figure-builder list. Owner sheets require
the successful command/log binding, current source hashes, registered receipt,
unchanged numeric tables and complete figure inventory; each tile names PBMC3k.
Missing Python/R packages, cache, cross-lane execution, or real image output
must remain blocked. Synthetic diagnostics are labelled and kept separate.
No golden, seal, merge, deployment or production acceptance is authorized here.
