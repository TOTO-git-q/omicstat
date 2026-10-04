# limma-dupcor S4 worklog

## Verified state
- First helper (2026-09-29, cut off ~04:30 by a rate limit) edited core/smoke/fixtures/references/registry for F1-F3 and ran
  GT103 limma-dupcor-smoke1 (4 FAIL), -golden (goldens written, SMOKE PASSED), -final (SMOKE PASSED, golden PASS). Edits saved
  unverified as WIP c34d593; module tree byte-identical (md5) to the GT103 limma-dupcor run dir at -final.
- Anchor trace (docs/build/S4_ANCHOR_TRACE.md): Yoruba printed 0.446 etc. reproduce with the guide code and
  voom(adaptive.span = FALSE); suite route keeps adaptive.span = TRUE (0.4449716 / 0.4454514).
- Resume: probe _s4/probe_illumina_guide.R (GT103 limma-dupcor-ilmnprobe.log, -ilmnprobe2.log): guide sec 17.3 code on the
  locked F7-F9: dim 24691 x 12, consensus 0.1344848639 (prints 0.134), sec 17.3.7 decideTests(global) 3074/18088/3529,
  2836/18707/3148, 1631/21307/1753 as printed; topTable(fit2, coef = 1) matches the print except row 9 (ILMN_1777199) P value
  4.236877e-11 vs printed 4.23e-11. Only the consensus is a PACK C anchor (row 7).
- Smoke edits: Illumina printed consensus now asserted with the guide's own code (guide:6521-6525) plus engine == guide code
  replay; Yoruba locked round-1 value 0.4449716 asserted too.
- Verified: limma-dupcor-d1.log SMOKE PASSED on the merged tree (all anchors incl. the new Illumina guide-code check), golden
  PASS (goldens from limma-dupcor-golden.log); lock limma-dupcor-lock.log, --check OK limma-dupcor-lockcheck.log; local
  module_lock.json hashes match. Every PNG of _smoke/limma-dupcor-smoke looked at. S4_FIXES.md written.

## Next step
- Done for limma-dupcor (F1-F3 fixed). Open: owner items (adaptive.span, non-Agilent presets, optional sec 17.3.7 extension)
  and shared needs listed in S4_FIXES.md. Any edit to a locked file needs a new lock and --check.
