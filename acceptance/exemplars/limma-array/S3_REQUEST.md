# S3 independent review request: limma-array 1.0.1

Check the S2 module against PACK S1 appendix P-1..P-3, especially the registered Agilent preset, the explicit override, control and background rules, and technical-ID averaging. This lane has made no independent S3 acceptance judgment.

## Anchor and run

- F5/F6 `GSE33005_RAW.tar`/`E-GEOD-33005.sdrf.txt`, source hashes `3d094f4dc7a771d54d9efff7c67c12dcbdf06e036220132719515ab246e70d92` and `a2e13071c73023ed6b4762d003f2748df97016c184235d22c7b2316838e1fb25` (ANCHOR_REGISTRY row 6). The fixture follows User's Guide §17.4 `read.maimages` → normexp background correction → quantile normalization, then supplies normalized log2 data. It selects the first 5000 probes and the 5 saline/5 10 ml/kg corn oil arrays. Known controls are removed and `gIsWellAboveBG` is checked on at least four arrays.
- Container output: `/home/<user>/omic-build-logs/build_m1b/limma-array-smoke/a0/`. 5000 input probes, 3867 tested, 142 BH discoveries at 0.05. This is a direct replay anchor for the selected subset; raw and BH P values agree with direct locked limma calls within CSV precision. `--spec` replay tables, PNGs and figure specs are byte identical. Trend/robust override, `treat`, display filtering, background-k, technical-ID `avereps`, typed errors, and handoff/tamper tests pass.
- The guide prints 27024 filtered probes and RT1-Bb logFC 9.33 on its full 19-array analysis, which also filters on symbols from `RnAgilentDesign028282.db`. That annotation package is absent from `omicstat-r:2026.09.1`, and this fixture uses a 10-array two-group subset; those printed figures are **not** asserted. S3 should retain this as an explicit limitation, not treat the subset's 3867/142 as published values.
- Golden manifest and module lock were generated in `omicstat-r:2026.09.1` (R 4.6.1, limma 3.68.5). Opened all anchor PNGs: volcano labels are separate with no clipping; MD points have no text labels; the non-Agilent mean-variance diagnostic is readable. Figure captions state n and thresholds.

## Needs owner decision

- Other normalized platforms have no frozen trend/robust preset. The engine requires both choices explicitly, reports them, and draws a mean-variance diagnostic. Confirm whether to register additional platform presets.
- `--above-background` is narrowly defined as a 0/1 probe-by-array matrix matched exactly to normalized input, with `--background-k` required. Confirm this platform-background input contract.
- The diagnostic is a figure-layer rendering of average log2 expression versus square root residual SD, called `sa_diagnostic`; confirm whether S3 requires an exact `limma::plotSA` rendering for non-Agilent platforms.

## Proposed installation records

Router row: `| normalized microarray differential expression, Agilent probes, 芯片差异表达 | limma-array | scripts/run_limma_array.R |`

Rules record: `{ "id": "PUB-M-LIMA-001", "module": "limma-array", "category": "design_conditional", "rule": "Use normalized log2 intensities, exclude known control probes, require background evidence and k for expression filtering, and state trend/robust; keep full BH results separate from treat and display-only FC filtering." }`

Version 1.0.1 refreshes the shared MD rendering and its golden. The inferential default remains the same.
