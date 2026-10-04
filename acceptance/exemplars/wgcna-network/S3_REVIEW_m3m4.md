# wgcna-network — independent S3 review

Reviewed source commit: `d7355bec9aa73496eba8e2c548a55415455e0508` (branch `s3/m3m4`). Review-only files are excluded from the implementation under review. No module source, golden or lock was changed.

Environment: `omicstat-r:2026.10.1`; image ID `sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7`. Non-root, network disabled; suite and acceptance-library mounts read-only; lane scratch writable. `OMICSTAT_WRITE_GOLDEN` was not set.

## Commands and runtime evidence

```bash
docker run --rm --network none --user 1000:1000 -v /home/<user>/omic-s3m:/omicstat:ro -v /home/<user>/omic-sol61/s3_m3m4/wgcna-network:/scratch -v /home/<user>/omic-integrate/.omicstat-acceptance:/omicstat/.omicstat-acceptance:ro -w /omicstat -e HOME=/tmp/omicstat-home -e OMICSTAT_TEST_TMP=/scratch -e OMICSTAT_CONTAINER=1 -e OMICSTAT_IMAGE_ID=sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7 -e OMICSTAT_REQUIRE_LOCKED=1 -e PYTHONDONTWRITEBYTECODE=1 -e OMP_NUM_THREADS=1 -e OPENBLAS_NUM_THREADS=1 -e MKL_NUM_THREADS=1 -e NUMBA_NUM_THREADS=1 -e PATH=/opt/omicstat/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin omicstat-r:2026.10.1 Rscript skills/wgcna-network/tests/run_smoke_test.R
```
Exit 0; raw log: `/home/<user>/omic-sol61/s3_m3m4/wgcna-network/smoke.log`.
```bash
docker run --rm --network none --user 1000:1000 -v /home/<user>/omic-s3m:/omicstat:ro -v /home/<user>/omic-sol61/s3_m3m4/wgcna-network:/scratch -v /home/<user>/omic-integrate/.omicstat-acceptance:/omicstat/.omicstat-acceptance:ro -w /omicstat -e HOME=/tmp/omicstat-home -e OMICSTAT_TEST_TMP=/scratch -e OMICSTAT_CONTAINER=1 -e OMICSTAT_IMAGE_ID=sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7 -e OMICSTAT_REQUIRE_LOCKED=1 -e PYTHONDONTWRITEBYTECODE=1 -e OMP_NUM_THREADS=1 -e OPENBLAS_NUM_THREADS=1 -e MKL_NUM_THREADS=1 -e NUMBA_NUM_THREADS=1 -e PATH=/opt/omicstat/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin omicstat-r:2026.10.1 Rscript tools/make_module_lock.R wgcna-network --check
```
Exit 0; raw log: `/home/<user>/omic-sol61/s3_m3m4/wgcna-network/lock.log`.

Golden must PASS rather than SKIP: verified in smoke assertions/log; smoke exit 0.
Lock evidence (exit 0):
```text
module_lock wgcna-network 1.0.0: OK (16 files)
```.

## Official workflow and anchor

FemaleLiver official tutorial: goodSamplesGenes -> pickSoftThreshold -> blockwiseModules(power6,unsigned TOM,minSize30,merge.25) -> moduleEigengenes/cor/corPvalueStudent; all3600 native module assignments and19 printed module counts asserted;134 retained biological samples.

Locked documentary evidence: `/home/<user>/omic-s0-b/acceptance/exemplars/wgcna-network/L1_cran2026-09-15`. PACK C/D/F and S0_VERIFICATION_M3M4 §3/§4.3 were used with the owner’s slim-policy override. No literature counts were used to choose defaults. Statistics are delegated to the named native package functions; descriptive reshaping/ranking is distinguished from inference.

Smoke evidence:
```text
PASS: check_calls.R 
PASS: check_defaults.py 
PASS: check_flag_docs.py 
PASS: lint_r.py 
PASS: FemaleLiver hash, 3600x143/361x38 structures and tutorial 134 retained samples 
PASS: full tutorial engine Done cluster 1492  | 2 of 3 rules triggered; read qc/qc_results.csv first 
PASS: REPLAY all 3600 gene module assignments equal tutorial part 2 code 
PASS: PRINTED tutorial part 2 PDF lines 149-153: all 19 label counts; 18 assigned modules, grey99, assigned range34-609 
PASS: REPLAY trait correlations equal tutorial part 3 
PASS: small run 
PASS: spec replay 
PASS: determinism tables/gene_modules.csv 
PASS: determinism tables/module_traits.csv 
PASS: determinism tables/soft_threshold.csv 
PASS: determinism figures/soft_threshold.png 
PASS: determinism figures/module_traits.png 
PASS: determinism figures/samples.png 
PASS: determinism figures/genes_block1.png 
PASS: power flag 
PASS: power changes full-anchor module assignments/membership 
PASS: typed unknown flag 
PASS: from-run equal 
PASS: tampered handoff refused 
PASS: corrected lineage refused 
PASS: container golden 
PASS: no Rplots.pdf 
SMOKE PASSED: 26 checks
```

## Options

Compared engine/entry/registry/options.md and SKILL.md. `23` documented option rows; all non-`none` S0 extraction keys exist in `/home/<user>/omic-s0-b/acceptance/exemplars/wgcna-network/literature/extraction.jsonl`. Both reference services and ask-user guidance are present. Mandatory scientific inputs and native JSON overrides were inspected; input/object names, output keys, serial execution and recorded seeds are transport/execution contracts, not inferred scientific defaults.
The exact options defects, if any, are listed in the closed repair list below.

## Outputs, Methods and handoffs

Native objects observed: 15 RDS/H5AD files; Methods drafts observed: 8. Native result columns/objects are retained except any explicitly listed repair. Methods names, package versions and run options were inspected against the engine and generated outputs. `--from-run` and chain-state evidence are in the smoke logs; real producer-chain supplement is recorded separately where needed.

Independent real producer chain: `{
  "exits": [
    0,
    0,
    0
  ],
  "upstream": "real limma-array with unchanged complete-feature subset of normalized-array input; artificial groups for transport only",
  "n_features": 145,
  "native_anchor_bytes_equal": true,
  "scale": "normalized_array",
  "ecosystem": "neutral",
  "initial_refusal": "limma correctly refused 163 missing values; original attempt log retained"
}`. Commands/logs: `/home/<user>/omic-sol61/s3_m3m4/wgcna-network/real_chain_*.command.json` / `real_chain_*.log`.

## Figures

Opened every generated PNG through SHA256-indexed contact sheets (byte-identical repeats share the opened image). 18 unique PNG contents for this module, 31 figure specs. Inventory: `/home/<user>/omic-sol61/s3_m3m4/visual/inventory.json`; sheets: `sheet_023.jpg`, `sheet_024.jpg`, `sheet_025.jpg`, `sheet_038.jpg`, `sheet_039.jpg`. Captions reside in `*.figure_spec.json`, not necessarily inside PNG pixels. Suite builders/theme/palette and finalizer are used. Visual findings: Plots are nonblank, labels readable and not clipped; plotted quantities follow the package workflow. Captions record n and thresholds or explicitly state no cutoff.

## Known issues / scope

Grey99 plus18 assigned modules; assigned size34–609. Native modules and biological-sample trait correlations are kept; hub rank is explicitly kME-based.

## Closed repair list

1. `skills/wgcna-network/scripts/wgcna_network_core.R:42` — Expose native result-affecting controls currently fixed across goodSamplesGenes, pickSoftThreshold, blockwiseModules, moduleEigengenes and cor, using documented native argument options. Specifically include goodSamplesGenes minFraction/minNSamples/minNGenes/tol/minRelativeWeight/weights; pickSoftThreshold RsquaredCut/removeFirst/nBreaks/corFnc/corOptions/weights; blockwiseModules corType/maxPOutliers/quickCor/pearsonFallback/cosineCorrelation/TOMDenom/replaceMissingAdjacencies/suppressTOMForZeroAdjacencies/suppressNegativeTOM/detectCutHeight/pamStage/minCoreKME/minCoreKMESize/minKMEtoStay/impute; moduleEigengenes impute/nPC/align/excludeGrey/subHubs/scale; correlation method/use/weights/cosine. Keep locked defaults or explicitly supported tutorial values, map keys to extraction or none, reference guidance and actual Methods values. Verify bicor versus Pearson and a native TOMDenom alternative, then official anchor smoke and lock. Evidence: PACK C/D/F; owner slim options/output/figure requirements. Re-verify in the same locked image; no tolerance relaxation or silent golden replacement.
2. `skills/wgcna-network/scripts/wgcna_network_core.R:131` — Expose the additional trait-correlation p.adjust method currently fixed to BH; retain the native unadjusted p_value, document this as an added exploratory summary and report the actual adjustment family/method. Re-verify BH and none against stats::p.adjust on the saved native P values, including Methods/caption, then smoke and lock. Evidence: PACK C/D/F; owner slim options/output/figure requirements. Re-verify in the same locked image; no tolerance relaxation or silent golden replacement.

VERDICT: FAIL
