# omicstat S2 builder brief (M1/M2, 2026-09-27) -- read fully before starting

You build ONE analysis module of the omicstat suite (stage S2 of ENGINEERING_PLAN part 7),
under a coordinator (Claude Opus) who does S3 acceptance and S5 installation. The module
name, your local worktree and your GT103 run name are given in your prompt.

## 0. Worklog protocol (mandatory, owner's standing order)
- Keep `acceptance/exemplars/<module>/build_worklog.md` in YOUR worktree from the first minute:
  a header (module, worktree, branch, run name), then a checklist of the steps in section 3
  with status, and a log of VERIFIED facts (what ran, exit code, which checks passed) and the
  exact NEXT STEP. Update it after every step and commit it with your work.
- If the worklog already exists when you start, you are a retry: read it, trust only the
  verified state it records, and continue from its NEXT STEP. Do not start over.
- Section "## 待裁决 (S2)" at the end of the worklog: every point you could not decide from
  the PACK (see section 5), with the safe behaviour you implemented.

## 1. Where you work
- Edit code ONLY in your local worktree (Windows laptop, Git Bash; always use absolute paths,
  the worktree path contains a space: quote it). Your branch is `wip/<module>`; commit there
  (`git -C "<worktree>" ...`). Never push, never touch another worktree or branch, never edit
  `E:\claude workspace\skills-dev\omic-MCP` or `...\omic-build`.
- Never run R on the laptop. Every R run, test, golden and `--help` runs on the small host
  GT103 inside the locked container `omicstat-r:2026.09.1` (R 4.6.1, Bioconductor 3.23),
  through three helper scripts in `$T=/c/Users/<user>/AppData/Local/Temp/claude/E--claude-workspace/1b067756-dd37-48b3-8c07-2bc646819542/scratchpad/omic-tools`:
  - `$T/gt_sync.sh "<worktree>" <run>` copies your code to GT103 `~/omic-build-logs/runs/<run>/`
    (acceptance data are hard-linked in automatically). Sync after every edit, before a run.
  - `$T/gt_run.sh <run> <tag> Rscript <path relative to the suite root> [args]` starts the
    command DETACHED in the container (as user toto, suite mounted at /omicstat, smoke-test
    temp dir `OMICSTAT_TEST_TMP=/omicstat/_smoke` = host `~/omic-build-logs/runs/<run>/_smoke`).
    Extra env vars: `GT_ENV="OMICSTAT_WRITE_GOLDEN=1" $T/gt_run.sh ...`. python3 tools also run
    this way: `$T/gt_run.sh <run> <tag> python3 tools/check_defaults.py skills/<module>`.
  - `$T/gt_wait.sh <run> <tag> [max_s]` waits (<= 9 min per call; call again if needed) and
    prints FAIL/SKIP lines and the log tail. Full log: `ssh -o BatchMode=yes <user>@<analysis-host> 'cat ~/omic-build-logs/<run>-<tag>.log'`.
  - Quick one-off R: `$T/gt_run.sh <run> probe Rscript -e '<expr>'` then gt_wait.
  - Copy outputs back with `scp -o BatchMode=yes <user>@<analysis-host>:omic-build-logs/runs/<run>/<path> <local>`.
- GT103 hard rules: touch nothing except `~/omic-build-logs/runs/<run>/` and your own
  `~/omic-build-logs/<run>-*.log`; only `docker run --rm` of `omicstat-r:*` (the helpers do it);
  never docker rm/kill/stop/prune; kill processes only by exact PID; no sudo; no package
  installs; no downloads of subscription content. Other agents run on that host.
- The Bash tool times out after 10 minutes; never run a foreground `sleep`; use gt_wait.sh.
- At most one smoke-test run of yours at a time (the host is shared).

## 2. Read first (in this order)
1. `docs/build/MODULE_BUILD_BRIEF.md`. OVERRIDES: ignore its dev-tier / conda / micromamba
   instructions (use the container via the helpers); L3/L4 literature EXISTS for your module
   (`acceptance/exemplars/<module>/literature/`); goldens are generated IN THE CONTAINER.
2. `docs/handoff/ENGINEERING_PLAN.md` parts 3 and 4 (locks, module layout, QC rule families).
3. `SUITE.md` section "M1/M2 S1 审定（2026-09-27）" -- the 10 cross-module rules are binding.
4. `acceptance/exemplars/<module>/PACK.md` in full. Its final section
   `## S1 审定附录（2026-09-27，所有者批准）` holds the FROZEN owner decisions: implement them
   EXACTLY (argument values, which arguments are written out, options). The older
   "S1 drafts" sections are history. Also its rows in `docs/build/S1_DECISION_TABLE_M1M2.md`.
5. The reference module `skills/deseq2-wald/` (entry, core, report, qc, calls_registry.json,
   references/*.md, SKILL.md, tests/run_smoke_test.R, tests/fixtures/) and its PACK: copy its
   structure, level of detail and test style. `skills/_shared/docs/CONVENTIONS.md`,
   `skills/_shared/docs/FIGURE_STYLE.md`, `skills/_shared/scripts/{args,module_kit,engine_run,design_check,feature_table,handoff}.R`.
6. L1 evidence of the locked versions: `acceptance/exemplars/<module>/L1_bioc3.23/` (Rd,
   vignettes, NEWS, defaults.tsv). Never cite anything from memory; every vignette section
   title you cite must exist in the L1 text (grep it); every quoted console message must exist
   in the package source/Rd.

## 3. Steps
1. Scaffold: `python tools/new_module.py <pkg> <part>` (python runs locally; it only writes
   files). Commit the scaffold.
2. Engine: one `os_arg_spec` (every flag typed, defaults explicit), `os_spec_argv` for `--spec`,
   `os_engine_capture` around every stage, typed `OS_*` errors, the 10-step structure of the
   reference entry script, closing line "N of M rules triggered; read X first".
   Every result-affecting argument of every registered package call is written out at the
   call site, even when equal to the function default (lock 3).
3. `scripts/calls_registry.json`: every registered call, every result-affecting argument with
   value + source + PACK id + `function_default` READ FROM `formals()` IN THE CONTAINER (export
   them with a probe run; do not copy from memory). `source` for frozen decisions points to
   the PACK S1 appendix (e.g. `"source": "S1-appendix P-1"`). `package_versions` = the versions
   in `env/pkg_lock.csv`. Pure accessors under `"accessors"`.
4. QC rules (`<prefix>-01..`): each with a source (L1/L2 section or PACK id) -- no rule without
   a source. Blockers stop before fitting and withhold the draft, like DW-01/DW-03.
5. references/: method-basis.md, parameters.md (`Flag | Default | Allowed | Why` + fixed
   arguments table), qc-rules.md, reporting-templates.md (```template <id>``` blocks the engine
   fills through `os_read_templates`/`os_fill_template`), troubleshooting.md (English,
   "symptom -> cause -> fix"). SKILL.md: frontmatter description <= 1000 characters (verb +
   product first, triggers early incl. Chinese terms, NOT-for lines naming the module to use
   instead), the eight body sections of ENGINEERING_PLAN 4.3.
6. Figures ONLY through `_shared/scripts/fig_*.R` + `os_finalize_figure`; no colour, size,
   shape or position literals in module code. A NEW builder goes into
   `skills/_shared/scripts/fig_mod_bulk.R` (M1) or `fig_mod_enrich.R` (M2) inside a block
   headed `# ---- <module> ----`, plus a subsection in `FIGURE_STYLE.md` under a new heading
   `## 19.x <module>` at the end. Do not change the behaviour of existing shared functions;
   if a shared bug blocks you, fix it minimally and report it.
7. Smoke test `tests/run_smoke_test.R` with a `# requires:` header line; same sections as the
   reference: static checks (check_calls, check_default_drift, check_defaults.py,
   check_flag_docs.py, lint_r.py), anchors from PACK C (say for each whether it is a PRINTED
   value or a REPLAY anchor = the vignette/guide code run in the same session must equal the
   engine), flag effectiveness, typed errors and blockers, determinism (`--spec` replay
   byte-identical tables/specs/PNGs), `--from-run` chaining where the module has an upstream
   (and a refused tampered upstream), golden check, no Rplots.pdf. Under ~5 minutes.
   Anchor data: Bioconductor data packages via `os_acceptance_file(suite, pkg, ...)` /
   `os_acceptance_data(suite, pkg, name)` (module_kit.R; acceptance data layer, see
   `acceptance/data/acceptance_lib_lock.csv`); downloaded files at
   `file.path(suite, "acceptance", "data", "<file>")` (see `acceptance/data/ANCHOR_REGISTRY.md`,
   `fetch_anchor_data.sh`; they exist on GT103). Put the fixture builder in `tests/fixtures/`,
   sha256-check the input files it reads (as `make_pasilla.R` does), SKIP (never FAIL) when
   a data file is absent.
8. Run the smoke test in the container until it passes. Then goldens:
   `GT_ENV="OMICSTAT_WRITE_GOLDEN=1" $T/gt_run.sh <run> golden Rscript skills/<module>/tests/run_smoke_test.R`,
   copy `skills/<module>/tests/golden_manifest.csv` back into your worktree, re-sync, and run the
   smoke test once more (the golden check must now PASS, not SKIP). Then
   `$T/gt_run.sh <run> lock Rscript tools/make_module_lock.R <module>`, copy
   `skills/<module>/module_lock.json` back. Commit.
9. Figures: copy every PNG of the anchor run back to
   `$T/../omic-figs/<module>/` and LOOK at each one with the Read tool: no overlapping or
   clipped labels, readable text, caption states thresholds and n. Record per figure in the
   worklog what you saw. Fix layout problems in `_shared` (your fig_mod_* block), not with
   literals in the module.
10. Final commit on `wip/<module>` (message: what the module does, anchors reproduced, what
    was deferred; last line `Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>`).

## 4. Do NOT edit
`skills/omicstat/SKILL.md` (router), `skills/_shared/publication/*`, `SUITE.md`,
`tools/qc_prefixes.json`, `docs/LOCAL_BUILD_GUIDE.md`, `docs/handoff/*`, other modules,
the PACK's frozen appendix, `vendor/`, `acceptance/exemplars/*/L1*`, `literature/`.
Instead put in your final report: the router section-1 row
(`| question sounds like ... | \`<module>\` | \`scripts/run_<pkg>_<part>.R\` |`), a section-2/3
note if relevant, and a `module_rules_v1.json` record in the deseq2-wald format.

## 5. Undecided points
- Class C items and "待澄清" items of the S1 appendix: implement NOTHING that depends on them;
  choose the safest behaviour that does not change a statistical result (refuse with a typed
  error, or flag/display only); record it under "## 待裁决 (S2)" in the worklog and in
  SKILL.md "Known limitations" where users need to know.
- Anything else the PACK does not cover: same rule. Never invent a default from memory; never
  change an estimator or default without a reproducible reason.

## 6. Cross-module contracts (coordinator decisions, binding)
- Handoff object types: MODULE_BUILD_BRIEF sec 3. A batch-corrected matrix (sva-batch) has
  type `batch_corrected_matrix`; `read_handoff()` refuses it with `OS_BATCH_CORRECTED_INPUT`
  whenever another type is expected (already implemented in handoff.R) -- DE modules need no
  extra code, but their smoke test must show the refusal once (write a tiny upstream with that
  type, like the reference's D2/D3 upstream).
- FC criterion three fields (SUITE cross-module rule 1): (a) the zero-effect primary test,
  (b) a prespecified minimum-effect test (`--lfc-threshold`, log2 units, goes INTO the test
  call), (c) a display-only filter, default OFF (`--display-lfc-filter`, log2 units, 0 = off):
  never changes padj, the full results table is always kept, the filtered set is written
  separately (`tables/display_filtered.csv`) and the Methods state it separately without the
  FDR guarantee. The results JSON records the three as `null_test`, `min_effect_lfc_threshold`,
  `display_lfc_filter`. deseq2-wald 1.1.0 implements this pattern (coordinator); mirror it.
- Pre-filter rule for complex designs (deseq2-wald P-3 pattern): an automatic "smallest group"
  count is used only for a simple two-group design; with covariates or more than two condition
  levels the user must give the rule explicitly, otherwise `OS_MISSING_PARAMETER`.
- Seeds: `--seed` default 20260925 wherever randomness exists; pass it explicitly at the call.

## 7. Final report (your last message; the coordinator reads it)
Short plain text: status per step; anchors (value, source, printed/replay, pass); container
test result (N checks, all pass?); golden status; figures looked at (and issues); shared-file
changes; the router row; the module_rules_v1.json record; 待裁决 items; the last commit hash
on `wip/<module>`.
