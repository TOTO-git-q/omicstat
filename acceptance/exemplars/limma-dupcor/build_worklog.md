# limma-dupcor S2 build worklog

Worktree `/home/<user>/omic-build-m1b`; branch `build/m1-limma`; container `omicstat-r:2026.09.1`; logs `/home/<user>/omic-build-logs/build_m1b/`.

## Steps

- Scaffold, engine, explicit call registry, QC, figures, references: DONE.
- Container smoke, source anchors, flag effects, errors, replay and handoff: DONE.
- Golden, lock, visual figure review and S3 request: DONE.

## Verified log

- The frozen P-1/P-2/P-3 choices are implemented: described and estimable repeated units, explicit consensus into `lmFit`, two RNA voom/correlation rounds, and platform-aligned array moderation. Technical batch as random block requires a stated rationale. Other array platforms require explicit trend/robust pending owner decision.
- Locked call/default audit, `check_defaults.py` 26/26, flag documentation and lint passed. Illumina F7-F9 fixture reproduces 24,691 filtered probes and guide consensus 0.134 (locked estimate 0.1344848639); 3 donor blocks each have 4 arrays. Synthetic RNA run verifies two rounds, `treat` and display-only semantics. Typed block refusals, verified handoff, tamper refusal, and byte-identical table/PNG/spec replay passed.
- Yoruba F10 direct locked replay retained 16,918 genes/86 lanes and gave 0.4449716 then 0.4454514; the guide prints 0.446. This is documented as an anchor gap in S3_REQUEST. No default or estimator was altered to hide it.
- Golden smoke passed. Opened Illumina volcano, MD, SA diagnostic and RNA volcano/MD PNGs; no clipped labels; dense MD plot was adjusted to readable shared point sizing. Figure captions include n and applicable thresholds. Module lock written in the locked container.

NEXT STEP: commit limma-dupcor S2 and refresh earlier module figure goldens affected by the shared MD renderer.

Worktree `/home/<user>/omic-build-m1b`; branch `build/m1-limma`; container `omicstat-r:2026.09.1`; logs `/home/<user>/omic-build-logs/build_m1b/`.

## Steps

- Scaffold: DONE.
- Engine, registered calls, QC, figures, references: IN PROGRESS.
- Container smoke and printed anchors: TODO.
- Golden, lock, figure review, S3 request, commit: TODO.

## Verified log

- Read the frozen PACK appendix: block is a described correlated unit; require repeated units, a full-rank design, and at least 2 residual df. `duplicateCorrelation` consensus is estimated, reported, and passed explicitly to `lmFit`. RNA-seq follows two voom/correlation rounds. Array trend/robust follows limma-array's platform rule.
- User's Guide §17.3 prints `0.134` on the 12-array Illumina within-donor example; files F7–F9 are present and hash locked. §18.1 prints `0.446` after two RNA-seq rounds; F10 contains a DGEList but its metadata require reconstruction from the guide.

NEXT STEP: implement array and RNA modes and the Illumina printed-value anchor.

## 待裁决 (S2)

- Illumina has no frozen suite preset; require explicit trend/robust. The guide anchor's correlation is estimated before eBayes, so its printed 0.134 can be asserted without resolving the robust setting. Guide-style eBayes replay will explicitly use trend=TRUE, robust=FALSE and will be identified as such.
2026-10-01 env_rebuild: baseline new-image smoke PASS; existing golden retained; lock refreshed/check; addon-specific checks pending
limma-dupcor: final 2026.10.1 smoke PASS (non-root/offline; golden unchanged; lock checked; awaiting independent S3); next remaining full R suite
