# limma-array S2 build worklog

Worktree `/home/<user>/omic-build-m1b`; branch `build/m1-limma`; container `omicstat-r:2026.09.1`; logs `/home/<user>/omic-build-logs/build_m1b/`.

## Steps

- Scaffold: DONE.
- Engine, calls registry, QC, figures, references: DONE.
- Container smoke and anchors: DONE.
- Golden, lock, figure review, S3 request, commit: DONE.

## Verified log

- Read PACK S1 appendix. Agilent preset is `eBayes(trend=TRUE, robust=TRUE)`; other platforms require an explicit choice while the owner decision is pending. Probe filtering requires known control identities; above-background filtering requires platform detection data and explicit k; distinct probes remain separate unless validated technical IDs are supplied.
- The locked container lacks `RnAgilentDesign028282.db`, which the guide §17.4 uses to produce its 27024-probe printed anchor. A normalized-input replay using the hash-locked F5/F6 files can still be run; the printed guide count cannot be asserted without that annotation.

NEXT STEP: implement normalized log2 input, explicit platform preset/override, probe rules and estimator.

## 待裁决 (S2)

- Agilent-adjacent and other platform presets are unspecified; require explicit `--trend` and `--robust` for non-Agilent platforms and generate a mean-variance diagnostic.
- Define the accepted background evidence narrowly as a per-probe, per-array detection matrix aligned to the normalized matrix; no unspecified metadata field causes filtering.

- Engine and call registry implemented. Locked `tools/check_calls.R`: 0 call/default-drift problems. `check_defaults.py`: 25/25 flags. Flag docs and R lint pass in the container.
- Hash-checked F5/F6, preprocessed as guide §17.4, then tested 5000 probes on 10 selected arrays. After control/detection filter, 3867 probes tested; 142 BH discoveries. Direct locked limma replay of P values passed. Printed full-guide anchors remain unasserted because `RnAgilentDesign028282.db` is absent and this is a two-group subset.
- Container smoke with golden writing: SMOKE PASSED. Treat, display filter, trend/robust override, background-k, validated technical-ID averaging, non-Agilent explicit choices, typed refusals, handoff and byte-identical replay passed.
- Opened `a0/figures/volcano.png` and `md.png`, and non-Agilent `other/figures/sa_diagnostic.png`: no clipped text; volcano labels separate, MD/SA axes readable; captions state n and BH threshold where applicable.

NEXT STEP: run final golden check, generate module lock, commit, then start limma-dupcor.

- Initial S2 commit `ffa1980`. Version 1.0.1 refreshes the shared MD renderer and golden; inferential estimator is unchanged. Locked container smoke passed and refreshed module lock checked OK. Updated MD PNG opened and readable.
2026-10-01 env_rebuild: baseline new-image smoke PASS; existing golden retained; lock refreshed/check; addon-specific checks pending
limma-array: final 2026.10.1 smoke PASS (non-root/offline; golden unchanged; lock checked; awaiting independent S3); next remaining full R suite
