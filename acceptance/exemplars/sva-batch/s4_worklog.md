# sva-batch S4 worklog

Branch `s4/sva-batch` from `integrate/m1m2` @fb63e52. GT103 run dir `~/omic-build-logs/s4/sva-batch`.

## Verified state
- 2026-09-29: read brief, S3 review (F1-F4), PACK, engine/report/qc/tests. Baseline smoke PASS (coordinator).
- Probes (`_s4/probe*.R`, logs `_s4/probe{1,2,3}.log`): vignette leek num.sv in memory = 4 (printed 2), chaotic on 1e-16
  eigenvalue noise; vignette chain with printed n.sv = 2 reproduces the printed topTableF exactly; ComBat source captured.
- F1 done: smoke run `f1` (log `_s4/f1.log`) SMOKE PASSED with 2 documented KNOWN-FAILING anchors (A6a); A6b/A6c PASS.
  Committed as "S4 sva-batch F1".

- F2 done: smoke run `f2` (`_s4/f2.log`): E9 (combat + combat_seq), E10, E11, E12, A1 joint check PASS; only
  G golden fails (batch_report/json content changed on purpose -- regenerate at the end). Committed as "S4 sva-batch F2".

- F3 + F4 done together (same report functions): smoke run `f34b` (`_s4/f34b.log`): W a1-a5/f2 checks, A1 F4
  (trace() equality 0.00e+00, ComBat matrix rebuilt, dinvgamma grid), F4 absent-path checks PASS; only G golden fails
  (intended content change). Figures looked at: a1..a5, e11 batch_pca, a1 combat_prior + combat_prior_2.
  Version bumped to 1.1.0.

- Goldens regenerated (run `gold`), normal rerun `final`: 94 PASS / 0 FAIL / 0 SKIP, golden PASS, 2 documented
  KNOWN-FAILING (A6a). module_lock 1.1.0 written and `--check` OK; check_defaults and lint_r clean in the container.
  S4_FIXES.md written.

## Next step
- Done. Hand back to the coordinator (final report). Nothing pending on this branch.
