# edger-qlf S4 worklog

Branch `s4/edger-qlf` from `integrate/m1m2@fb63e52`. GT103 run dir `~/omic-build-logs/s4/edger-qlf/`.
Work list: `S3_REVIEW_astra.md` F1 (guide-path printed anchor, suite-route difference, dispersion
assertions, correct attribution text) and F2 (QL dispersion plot + sample MDS).

## Verified state
- (start) Brief, S3 review, S3 report sec 2-4, PACK, module code, Astra probes read.

- Sources probed (`_s4/probe_source.R`, log edger-qlf-probe-src.log): plotQLDisp reads AveLogCPM,
  deviance.adj/df.residual.adj (or deviance/df.residual.zeros for legacy), s2.post, s2.prior; fit$dispersion is a
  scalar from estimateGLMCommonDisp (new method); plotMDS.DGEList = cpm(log=TRUE, prior.count=2) + limma plotMDS.
- F1 DONE: C-guide printed anchors + C-suite difference checks in smoke; smoke PASS (edger-qlf-f1-smoke.log).
  Docs corrected (method-basis, SKILL, S3_REQUEST). Commit F1.

- F1 committed c48e5e5.
- F2 code written (core eq_ql_disp_data + limma::plotMDS; report figures ql_dispersion/mds + tables; registry limma; smoke F2 checks; version 1.1.0). Not yet run.

- F2 DONE: smoke f2 (only golden JSON changed) -> golden write -> final smoke 73 PASS / SMOKE PASSED;
  module_lock 1.1.0 regenerated, --check OK; all PNGs looked at (see S4_FIXES.md). Commit F2.

## Next step
- None for this helper: final report to the coordinator. Verifier re-runs `s4_run.sh edger-qlf ... run_smoke_test.R`.
