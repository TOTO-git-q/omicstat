# Build lane M1 worklog

- Worktree: `/home/<user>/omic-build`, branch `build/m1m2`.
- Container: `omicstat-r:2026.09.1`.
- Source: `build_m1.md`, `build_common.md`, coordinator resume point in `m1m2_build_worklog.md`.

## Progress

- 2026-09-28: Resumed at step 1 (sva-batch). Existing worktree was clean at `46cec19`; no prior lane worklog existed. Next: rerun sva-batch smoke and goldens in the locked container.
- 2026-09-28: Step 1 sva-batch S2 rerun complete: golden write and check PASS, lock regenerated, figures checked, S3 request written. Commit `12127da`; next: deseq2-qc S3 defect fixes and rerun.
- 2026-09-28: Step 2 deseq2-qc S2 follow-up 1.0.1 complete: reviewer defects F2-F5 fixed, golden write and check PASS, figures checked, lock regenerated, S3 request updated. Commit `5a0fd30`; next: merge deseq2-lrt WIP and resume its recorded NEXT STEP.
- 2026-09-28: Step 3 deseq2-lrt S2 complete: merged WIP `342bcc6`, fission and pasilla replay anchors PASS, golden write/check PASS, all figures inspected, lock and S3 request written; deseq2-wald regression PASS after minimal shared feature-ID fix. Commit `1bcd08c`; next: merge edger-qlf WIP and resume its NEXT STEP.
- 2026-09-28: Step 4 edger-qlf S2 complete: merged WIP `a683ded`; locked GSE60450 QLF and glmTreat anchors and independent replay PASS, golden write/check PASS, figures inspected, lock and S3 request written. Commit `c7f1c1e`; next: plan sync v1.2.
- 2026-09-28: Step 8 plan sync complete: ENGINEERING_PLAN bumped to v1.2, SUITE 10 synchronization items addressed without changing frozen decisions or implementation. Commit `ed4ad05`; next: Chinese lane report and final DONE line.
- 2026-09-28: Chinese lane report committed as `d28263a`; next: independent S3 by coordinator; no further build_m1 steps.
DONE
