# limma-voom S2 build worklog

Worktree `/home/<user>/omic-build-m1b`; branch `build/m1-limma`; container `omicstat-r:2026.09.1`; logs `/home/<user>/omic-build-logs/build_m1b/`.

## Steps

- Locked `voomLmFit` Rd/formals and sha256 manifest: DONE.
- Scaffold: DONE.
- Engine, registered calls, QC, figures, references: DONE.
- Container smoke, anchor, flags, typed errors, determinism, handoff: DONE.
- Golden and module lock: DONE.
- Visual figure review, S3 request, module commit: DONE.

## Verified log

- Exported `edgeR::voomLmFit` help Rd, rendered text and `formals()` from edgeR 4.10.5 in `omicstat-r:2026.09.1`; hashes are in `L1_bioc3.23/manifest.tsv`. Its defaults include `sample.weights=FALSE`, `adaptive.span=TRUE`, and `keep.EList=TRUE`; the returned object is MArrayLM with `EList` when requested.
- Ran `python3 tools/new_module.py limma voom`; scaffold prefix is LV.

NEXT STEP: implement engine and registered explicit calls.

## 待裁决 (S2)

- P-1 complete call set needs owner confirmation after this build; record the proposed set in S3_REQUEST and lane report.
- P-2 `treat(fc=)` policy: use the user's linear `fc` alongside `lfc=log2(fc)` as the PACK interim recommendation; both name the same threshold.

- Engine, call registry, QC, figures and documentation implemented. `tools/check_calls.R` found 0 registry/default-drift problems; `check_defaults.py` 19/19 flags, `check_flag_docs.py` 19/19, and `lint_r.py` 0 problems in the container.
- GSE63310 F4 fixture sha256 verified; 5000 genes, 5 samples, 3320 tested, 17 BH discoveries. Direct locked-package replay of P values passed. Treat, legacy fit, display filter, typed error, handoff, tamper refusal and byte-identical table/spec/PNG replay passed. Golden smoke and final golden check: SMOKE PASSED.
- Opened `a0/figures/volcano.png`: labels and Up/Down key distinct, no clipped labels. Opened `md.png`: no labels, axes readable, no clipping. Both figure specs include n and threshold in captions.

NEXT STEP: generate module lock, commit module, then start limma-array.

- Initial S2 commit `e9772bd`. After the shared MD renderer update, version 1.0.1 regenerated its golden; locked container smoke passed, including a new sample-quality-weight flag run. The returned five named positive sample weights are now recorded in results JSON, and this option changed the fit. Updated MD PNG opened and readable. Refreshed module lock checked OK.
2026-10-01 env_rebuild: baseline new-image smoke PASS; existing golden retained; lock refreshed/check; addon-specific checks pending
limma-voom: final 2026.10.1 smoke PASS (non-root/offline; golden unchanged; lock checked; awaiting independent S3); next remaining full R suite
