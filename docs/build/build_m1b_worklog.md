# Build lane M1b worklog

Worktree: `/home/<user>/omic-build-m1b`; branch: `build/m1-limma`; logs: `/home/<user>/omic-build-logs/build_m1b/`.

## Steps

1. limma-voom: export locked edgeR `voomLmFit` evidence; scaffold, build, test, golden, lock, S3 request, commit. DONE.
2. limma-array: scaffold, build, test, golden, lock, S3 request, commit. DONE.
3. limma-dupcor: scaffold, build, test, golden, lock, S3 request, commit. DONE.
3a. Refresh limma-voom and limma-array goldens/locks after shared MD rendering change. DONE.
4. Chinese lane report and commit. DONE.

## Verified log

- 2026-09-28: Read lane and common task files, coordinator resume point, builder and module briefs, SUITE S1 section, and the three frozen PACK appendices. Branch is `build/m1-limma` at `46cec19`; no existing lane worklog.

- limma-voom: S2 built, GSE63310 replay anchor 3320 genes/17 BH discoveries, container smoke and golden PASS, figures inspected, S3 requested; commit `e9772bd`; next step limma-array scaffold.

- limma-array: S2 built, GSE33005 normalized subset replay 3867 probes/142 BH discoveries, container smoke and golden PASS, figures inspected, S3 requested; commit `ffa1980`; next step limma-dupcor scaffold.

- limma-dupcor: S2 built. Illumina F7-F9 anchor 24691 probes, consensus 0.1344848639 (guide 0.134); Yoruba F10 locked replay 0.4454514 versus guide printed 0.446, documented as S3 anchor gap. Golden smoke, figure review and lock done; commit `dd07c84`; next step refresh earlier figure goldens and locks.

- limma-voom/limma-array: version 1.0.1 shared MD figure refresh, golden and locked module locks passed; voom sample-weight estimates now reported and flag effect checked; follow-up commit `ffe1ff3`; next step Chinese lane report.

- Chinese lane report: owner items, anchors, tests, figures, shared-code changes, deviations and S3/S5 boundaries recorded; commit `88ea1d0`; next step close lane worklog.

DONE
