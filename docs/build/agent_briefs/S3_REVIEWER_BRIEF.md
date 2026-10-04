# omicstat S3 acceptance brief (M1/M2, 2026-09-27) -- read fully before starting

You are the independent S3 acceptance reviewer of ONE module (ENGINEERING_PLAN 7.2 "S3 验收卡").
You did not build it. You judge; you do not fix. The coordinator (Claude Opus) fixes and installs.

## What you review
The module as merged on branch `build/m1m2` in the coordinator's worktree
`E:\claude workspace\skills-dev\omic-build` (read-only for you, EXCEPT the one file you write:
`acceptance/exemplars/<module>/S3_REVIEW.md`). Do not edit anything else, do not commit, do not push.

## Worklog protocol (mandatory)
Keep your notes in `acceptance/exemplars/<module>/S3_REVIEW.md` from the start: a checklist of the
sections below with status, the evidence you verified (file:line, command, output), and a NEXT STEP
line. If the file exists when you start, you are resuming: continue from its NEXT STEP.

## How to run things
Never run R on the laptop. Use the GT103 helpers in
`$T=/c/Users/<user>/AppData/Local/Temp/claude/E--claude-workspace/1b067756-dd37-48b3-8c07-2bc646819542/scratchpad/omic-tools`:
`$T/gt_sync.sh "E:/claude workspace/skills-dev/omic-build" s3-<module>` (Git Bash path
"/e/claude workspace/skills-dev/omic-build"), then
`$T/gt_run.sh s3-<module> <tag> Rscript skills/<module>/tests/run_smoke_test.R` and
`$T/gt_wait.sh s3-<module> <tag> [max_s]`. Outputs of the smoke test are on GT103 under
`~/omic-build-logs/runs/s3-<module>/_smoke/`; copy what you need with
`scp -o BatchMode=yes <user>@<analysis-host>:omic-build-logs/runs/s3-<module>/<path> <local>`.
You may run the engine yourself with other flags (`$T/gt_run.sh s3-<module> t1 Rscript skills/<module>/scripts/run_<...>.R ... --outdir /omicstat/_s3/t1`)
and small `Rscript -e` probes (e.g. to replay a vignette/guide chunk). GT103 rules: touch only
`~/omic-build-logs/runs/s3-<module>/` and your own logs; only `docker run --rm omicstat-r:*` via the helpers;
no sudo, no installs, kill nothing. The Bash tool times out at 10 minutes; no foreground `sleep`.

## The four judgements (ENGINEERING_PLAN 7.2 S3) -- every finding cites a PACK section
1. **Anchors**: every PACK C anchor is asserted by the smoke test, the asserted values equal the
   PACK/L1 source (open the L1 rendered text / guide and check the printed numbers yourself), the
   printed-vs-replay classification is honest, and the test really passes in the container. For a
   replay anchor, check that the replay code is the vignette's/guide's own code, not the engine's.
2. **Table shape** (PACK T): columns, ordering, what the primary table holds; feature_table schema.
3. **Wording** (PACK W): the Methods/Results draft (read a real `draft/methods_results.md` from the
   anchor run): software + version + function + result-affecting arguments; no claim the PACK or the
   S1 appendix forbids; numbers match the results JSON.
4. **Mechanical**: calls_registry covers every result-affecting argument of every registered call with
   the S1-appendix value (compare call sites with the appendix table line by line); check_calls /
   default drift / check_defaults / check_flag_docs / lint pass; typed errors; determinism; --from-run;
   golden check PASS (not SKIP); no Rplots.pdf. Also check that every frozen S1-appendix decision is
   implemented exactly and that 待澄清 / class-C items are NOT decided silently (safe behaviour + recorded).
Also look at every figure PNG of the anchor run (copy them back, open with the Read tool): overlapping
or clipped labels, caption states thresholds and n (captions are in `*.figure_spec.json`).

## Output
`S3_REVIEW.md` ends with a verdict line: `VERDICT: PASS`, `VERDICT: PASS WITH NOTES` (only
cosmetic/documentation notes), or `VERDICT: FAIL` + a closed repair list (each item: PACK section,
file:line, what is wrong, what would be right). Your final message: the verdict, the repair list (if
any) and the notes, in short plain text.
