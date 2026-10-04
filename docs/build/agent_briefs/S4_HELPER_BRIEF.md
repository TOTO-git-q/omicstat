# S4 helper brief (per-module concentrated fix)

You are an S4 helper. The coordinator integrated the four build lanes into
`integrate/m1m2` and owns every shared / cross-module change. You repair ONE
module (sometimes two) exactly along the closed repair list of its independent
S3 review. You fix; somebody else verifies later. You do not accept your own
work: report evidence, not verdicts.

## Read first (in your worktree)
1. `acceptance/exemplars/<module>/S3_REVIEW_astra.md` -- your work list (F1..Fn).
   Line numbers refer to the reviewed commits; locate the code again.
2. `docs/build/S3_REPORT_astra.md` sec 2 (your module), sec 3 (anchor rulings),
   sec 4 (owner items and the accepted safe handling), sec 5 (cross-module).
3. `acceptance/exemplars/<module>/PACK.md`, especially the `## S1 审定附录`
   at the end (frozen owner decisions) and sections C (anchors), F (figures),
   T (tables), W (write-up).
4. `docs/handoff/ENGINEERING_PLAN.md` parts 3 (locks) and 7; `docs/build/MODULE_BUILD_BRIEF.md`;
   `skills/_shared/docs/CONVENTIONS.md`; `skills/_shared/docs/FIGURE_STYLE.md`.
5. The builder report on the module's lane: `docs/build/BUILD_REPORT_build_*.md`,
   `acceptance/exemplars/<module>/S3_REQUEST.md`, `build_worklog.md`.
6. Astra's probes/logs for your module (read only): GT103 `~/omic-s3-runs/<module>/_s3/`.

## Where you work
- Local git worktree `E:/claude workspace/skills-dev/omic-s4-<module>` on local
  branch `s4/<module>` (created from `integrate/m1m2` by the coordinator).
  Commit there after each F item. **Never push. Never touch other branches.**
  Commit trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Git Bash on Windows; use absolute paths; `core.autocrlf=false` is set. Write
  files with LF endings; R/shell files ASCII only.
- If the coordinator tells you a shared change landed on `integrate/m1m2`,
  `git merge integrate/m1m2` into your branch (it is a local branch of the
  same repository).

## Where R runs: GT103 only, locked container
- Sync your tree: `bash docs/build/agent_briefs/s4_sync.sh "<your worktree>" <run>`
  (copies to `~/omic-build-logs/s4/<run>/`; run name = your module name, or
  `<module>-<suffix>` for a second directory).
- Start a run: `bash docs/build/agent_briefs/s4_run.sh <run> <tag> Rscript skills/<module>/tests/run_smoke_test.R`
  (detached; `GT_ENV="OMICSTAT_WRITE_GOLDEN=1"` prefix to write goldens).
  Any R probe script: put it under your module's exemplar dir (e.g.
  `acceptance/exemplars/<module>/_s4/probe_x.R`), sync, and run it the same way.
- Wait: `bash docs/build/agent_briefs/s4_wait.sh <run> <tag> [max_seconds]`
  (the Bash tool times out at 10 min; re-run the wait if needed).
- Lock: `s4_run.sh <run> lock Rscript tools/make_module_lock.R <module>`, then
  copy `skills/<module>/module_lock.json` and `tests/golden_manifest.csv`
  back with `scp <user>@<analysis-host>:~/omic-build-logs/s4/<run>/skills/<module>/... <local path>`.
- Figures: copy every PNG back (`scp`) into a scratch directory and LOOK at
  each one with the Read tool. Captions must state thresholds and n; nothing
  clipped or overlapping; legends present.
- **On GT103 touch only `~/omic-build-logs/s4/<your run>*`** and
  `docker run --rm omicstat-r:*` (via the scripts). Reading elsewhere is fine;
  writing, deleting, or killing anything else is not: `~/omic-build*`,
  `~/omic-s3*`, `~/omic-verify`, `~/omic-s0-*`, `~/omic-integrate`, PaperFlow,
  medstat, the MC server and other services are off limits. No sudo; kill only
  by exact PID of a process you started. `ssh -o BatchMode=yes <user>@<analysis-host>`.

## What you may edit
- `skills/<module>/**`, `acceptance/exemplars/<module>/**` (never the L1*/L2
  evidence files and never the frozen PACK text above `## S1 审定附录`; an
  S4 note appended at the end of the PACK is allowed only to record facts).
- **Never** `skills/_shared/**`, `tools/**`, `mcp/**`, `env/**`, `SUITE.md`,
  `skills/omicstat/**`, `vendor/**` (read only), other modules, `docs/**`.
  If a fix needs a shared change (builder, io helper, contract),
  write the exact request (function, signature, behaviour, why, which F item) in
  your `S4_FIXES.md` section "Shared needs" and in your final report; do the
  rest of the module meanwhile. The coordinator implements shared changes.

## Strict anchor rules (owner)
- Never loosen a tolerance, swap an anchor, subset data, or drop a required
  figure just to pass.
- Where the guide/vignette prints values, the anchor must assert them, using the
  guide's OWN code path inside the test (copy the guide code from the L1
  rendered/purled text; cite file:line), never the engine's own functions or
  shared helpers. A replay anchor = the guide code run in the same session must
  give identical numbers to the engine; say which kind each anchor is.
- If a printed value truly cannot be reproduced after tracing (source data,
  version, preprocessing, RNG), keep the strict assertion as a documented
  KNOWN FAILING anchor with the evidence (it must be visible in the smoke output
  and in S4_FIXES.md) and list it as an owner decision. Do not quietly downgrade
  it, do not print "ANCHOR GAP" and then pass silently. The smoke test may
  finish with a clear `KNOWN-FAILING ANCHOR: ...` line listed in S4_FIXES.md;
  everything else must pass.
- Never change an estimator or a frozen S1 decision without a reproducible
  error. Never pick an owner-pending setting yourself.

## Owner decisions pending (do NOT decide them)
GSVA downstream limma entry and eBayes trend/robust; limma-voom voomLmFit call
set; deseq2-qc outlier statistic/threshold; DEGreport in the image (deseq2-lrt
pattern clustering); non-Agilent array presets; ORA/compare full-table 1/1
cutoffs; any anchor revision. Use the safe handling accepted in
S3_REPORT_astra sec 4: typed refusal (`OS_*`) or flag only; no inference from
undecided settings. Reference data: keep `OS_REFDATA_MISSING` where it applies;
no KEGG content.

## Per-module deliverables
1. Each F item fixed, with a regression assertion in `tests/run_smoke_test.R`
   (typed errors, numeric anchors, report text checks as the review asks).
2. Module version bumped (lock 7): the `<PREFIX>_MODULE_VERSION` constant in the
   core script, minor bump (x.y.0 -> x.(y+1).0); SKILL.md/references updated
   where they describe changed behaviour.
3. Full smoke test green in the container (apart from documented known-failing
   anchors); goldens regenerated in the container (`OMICSTAT_WRITE_GOLDEN=1`),
   then a normal rerun that PASSes the golden check; `module_lock.json`
   regenerated and `--check` OK; `python3 tools/check_defaults.py skills/<m>`
   and `python3 tools/lint_r.py` clean (run them in the container too).
4. Every figure looked at (list them with one line of what you checked).
5. `acceptance/exemplars/<module>/S4_FIXES.md` (English or Chinese): for each
   F item -> what changed (file:line) -> the evidence it is fixed (command,
   log path on GT103, asserted values) or why not; plus "Known failing
   anchors", "Owner items", "Shared needs", "Notes for the final verifier".
6. Commit on `s4/<module>`.

## Worklog protocol (owner's standing rule)
Keep `acceptance/exemplars/<module>/s4_worklog.md`: verified state and the exact
next step, updated as you go (after each F item and before each long run). If
it exists when you start, read it and continue from the next step. Commit it
with your work.

## Final message to the coordinator (short)
Per F item: fixed / partly / blocked (why); known failing anchors; owner items;
shared needs; last commit hash on `s4/<module>`; GT103 run dir.
