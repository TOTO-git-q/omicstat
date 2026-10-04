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
