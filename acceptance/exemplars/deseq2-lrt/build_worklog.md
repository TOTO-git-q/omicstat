# build_worklog -- deseq2-lrt (S2 builder)

- module: deseq2-lrt
- worktree: E:\claude workspace\skills-dev\omic-wt-deseq2-lrt
- branch: wip/deseq2-lrt
- GT103 run name: deseq2-lrt
- builder: Claude (Sonnet 5), coordinator Claude Opus, 2026-09-27

## Checklist (ENGINEERING_PLAN part 7 / BUILDER_BRIEF sec 3)

- [x] 1. Read brief, ENGINEERING_PLAN parts 3/4, SUITE.md cross-module rules, PACK.md (full,
      incl. S1 appendix), reference module deseq2-wald (all files), _shared scripts
      (args.R, engine_run.R, design_check.R, module_kit.R, feature_table.R, handoff.R,
      fig_all.R, fig_bulk.R, fig_style.R sec 7.3), tools/new_module.py, calls_check.R,
      acceptance_lib_lock.csv, ANCHOR_REGISTRY.md, L1 evidence (DESeq2 DESeq.Rd,
      nbinomLRT.Rd, results.Rd, DEGreport degPatterns.Rd, both rendered vignettes).
- [x] 2. Scaffold: `python tools/new_module.py deseq2 lrt` (QC prefix DL, matches
      tools/qc_prefixes.json planned table).
- [ ] 3. Design decision (recorded here since PACK does not spell out the CLI surface):
      unlike deseq2-wald (condition/target/reference + covariates, auto-assembled formula),
      deseq2-lrt takes raw design formulas `--full` and `--reduced` (both required, no
      default -- P-1), because LRT designs are multi-group / interaction / time-course and a
      two-level condition/target/reference frame does not fit (fission example:
      `~ strain + minute + strain:minute` vs `~ strain + minute`). Full CLI:
      --counts/--samples or --from-run, --outdir, --spec, --sample-col, --full (required),
      --reduced (required), --adjust (optional comma list: term labels that must be kept in
      BOTH full and reduced -- mechanical check beyond nesting), --group-col (optional;
      default = the single variable in full's all.vars not in reduced's all.vars, else
      required -- used only for figure colour annotation, never for the test),
      --group-reference (optional), --time-col (optional; x-axis of the optional top-gene
      trajectory figure; figure skipped when absent), --min-count (default 10),
      --min-samples (default 0 = unset; ALWAYS required explicit > 0 for this module -- an
      LRT design has no "smallest of two compared groups" concept, so there is no
      auto-derivation at all, stricter than deseq2-wald), --alpha (default 0.05),
      --report-coef (optional; results(name=); default NULL = DESeq2's own default
      coefficient), --fit-type / --sf-type (same enum as deseq2-wald, D-L3 consistency),
      --gene-annotation, --top-n (heatmap size), --seed, --journal. NO --lfc-threshold, NO
      --display-lfc-filter (P-3, cross-module rule 1: LRT gets no single-coefficient FC
      screen). NO --shrinkage (LRT results are not a Wald contrast; lfcShrink needs a
      resultsNames coefficient and a Wald-shaped res object with the printed LFC only -- out
      of scope for v1, recorded as a limitation, users needing shrinkage should read the
      single coefficient with deseq2-wald as a documented follow-up, not silently reuse it
      here).
      Nesting/full-rank/df check (P-1): model.matrix() built for both full and reduced from
      the SAME coldata; both qr()-full-rank checked; df = ncol(full) - ncol(reduced) must be
      > 0; nesting checked by projecting reduced's columns onto full's column space
      (residual ~ 0 after `qr.solve(mm_full, mm_reduced)`) -- catches a reduced formula that
      is not actually a sub-model of full. --adjust term labels checked present in both
      formulas' `terms()` term.labels (exact match) when given.
      Feature table (FEATURE_TABLE_SCHEMA): log2fc = the ONE coefficient results() prints
      (controlled by --report-coef / DESeq2's own default), labelled via `method` and a
      dedicated `tested_terms`/`lrt_full`/`lrt_reduced` block in results.json (not in the
      per-row schema, which has no such column) plus the header text; `stat` = LRT deviance
      difference (chi-squared), explicitly documented as NOT a directional statistic (always
      >= 0) -- so NO n_up/n_down split is computed or reported for deseq2-lrt (unlike
      deseq2-wald), only n_significant. `shrinkage` column is always "none". NO ranked_list
      handed on (SUITE cross-module rule 2).
      Figures: reuse `os_top_heatmap` as-is (brief explicitly allows this, no new code) for
      the heatmap of LRT-significant genes; NEW builder `os_lrt_trajectory()` in
      `_shared/scripts/fig_mod_bulk.R` for the "top-gene trajectories" figure (PACK F row 2:
      normalized counts of top LRT genes over `--time-col`, coloured by `--group-col`),
      skipped when `--time-col` is not given. NO volcano/NO MA plot (PACK F lists none for
      this module; consistent with cross-module rule 1 "no single-coefficient FC screen" --
      a volcano/MA plot is inherently framed around one FC threshold). P-2 pattern
      clustering (DEGreport::degPatterns) is NOT implemented (DEGreport not in
      env/pkg_lock.csv per the brief) -- no flag for it, recorded under 待裁决.
      Anchor: fission IS installed in the acceptance data layer
      (acceptance/data/acceptance_lib_lock.csv row 4, mode "installed") -- use it as the
      PRIMARY anchor (rnaseqGene "Time course experiments": `~ strain + minute +
      strain:minute` vs reduced `~ strain + minute`) via os_acceptance_data(); values are a
      REPLAY anchor (DESeq2 vignette's own LRT chunks are eval=FALSE, so nothing is printed
      to check against -- confirmed by grep of the rendered vignette text). pasilla
      (`~ type + condition` vs reduced `~ type`) is the supplementary replay anchor +
      Wald-closeness consistency check (chains to deseq2-wald's own A1/A3 pasilla numbers
      where useful).
- [~] 4. Write core/report/qc + calls_registry.json.
      - DONE: skills/deseq2-lrt/scripts/deseq2_lrt_core.R (design parsing of raw --full/
        --reduced formula text, nesting/full-rank/df checks via qr.solve projection,
        DL_LEVEL_RE level check, dl_resolve_group_col, DESeq()/results() calls with
        S4Vectors::mcols(res)$description captured verbatim as header_log2fc/header_pvalue,
        dl_feature_table (log2fc = one coefficient, NO up/down split, n_group1/n_group2 left
        NA), dl_full_table, dl_counts).
      - DONE: skills/deseq2-lrt/scripts/deseq2_lrt_qc.R (rules DL-01..DL-13, mirrors DW-01..12
        plus new DL-13 "single_coefficient_lfc" info rule, always triggered, naming the
        tested terms/df/used coefficient).
      - NOT DONE YET: skills/deseq2-lrt/scripts/deseq2_lrt_report.R (still the scaffold
        TODO stub from new_module.py -- tables, figures, results json, draft NOT written).
      - NOT DONE YET: skills/deseq2-lrt/scripts/run_deseq2_lrt.R (still the scaffold TODO
        stub -- SPEC flags NOT filled in yet; the intended SPEC is fully designed in step 3
        above but not yet transcribed into os_arg_spec()).
      - NOT DONE YET: skills/deseq2-lrt/scripts/calls_registry.json (still the scaffold
        placeholder; function_default values must be re-read from formals() IN THE CONTAINER
        via a probe run per the brief, not copied from L1_bioc3.23/*/defaults.tsv from
        memory -- draft the entries from defaults.tsv as a starting point, then confirm/
        correct with a container probe before finalizing).
- [~] 5. references/*.md, SKILL.md -- NOT STARTED (still new_module.py scaffold placeholders).
- [x] 6. fig_mod_bulk.R block: `os_lrt_trajectory()` written (facet_wrap by gene, points +
      per-group mean line, log10 y-axis with +0.5 pseudocount like DESeq2::plotCounts,
      skipped by the caller when --time-col is absent). NOT YET DONE: FIGURE_STYLE.md
      sec 19.x subsection documenting it (must add before this counts as complete -- see
      MODULE_BUILD_BRIEF sec 4 "document each builder in FIGURE_STYLE.md sec 19.x").
      NOT YET RUN in the container, so os_lrt_trajectory is UNTESTED (facet_wrap is new to
      the whole fig_style layer -- first faceted figure in the suite; check strip styling,
      lint-clean under nature/cell presets, and the free_y per-gene scaling actually reads
      well once real figures are looked at).
- [ ] 7. tests/run_smoke_test.R + tests/fixtures/ -- NOT STARTED. Plan (see step 3 above):
      reuse deseq2-wald's tests/fixtures/make_pasilla.R (or write a thin deseq2-lrt copy
      pointed at the same acceptance-layer pasilla) for the supplementary pasilla replay
      anchor (full = ~ type + condition, reduced = ~ type) PLUS a Wald-closeness consistency
      check by invoking deseq2-wald's own run_deseq2_wald.R as a subprocess on the same
      pasilla input (--covariates type --reference untreated --target treated
      --min-samples 3) and correlating LRT pvalue vs Wald pvalue across genes (not exact
      equality -- PACK is explicit this is a consistency check, not an equality anchor).
      New tests/fixtures/make_fission.R: pull fission via
      os_acceptance_data(suite, "fission", "fission") (a RangedSummarizedExperiment;
      acceptance_lib_lock.csv row 4 confirms it is installed, mode "installed" -- NOT
      "package not installed" as the older PACK C section says; PACK's S1 appendix P-4 says
      to "补齐 fission" which is now done at the acceptance-data-layer level per SUITE.md
      "M1-2" infra decision). Extract assay(fission) as the count matrix and
      as.data.frame(colData(fission)) as the sample table; the fixture code must NOT assume
      exact column names blindly -- check for "strain" and "minute" at runtime and fail with
      a clear, actionable message if absent, since this has never actually been run (no local
      R). This IS the PRIMARY anchor (full = ~ strain + minute + strain:minute, reduced =
      ~ strain + minute) and is a REPLAY anchor (rnaseqGene workflow text is not in this
      module's L1 evidence -- confirmed absent by grep in step 1 -- so nothing is "printed"
      to check against; the smoke test must run an independent DESeq2 call on the same
      fission input in the SAME session and compare against the module's own output).
      A container run of this fixture has NEVER happened yet -- the column-name assumption
      about fission's colData, and the exact behavior of the acceptance-data accessor for an
      "installed" package (os_acceptance_lib / os_acceptance_data path in module_kit.R), are
      UNVERIFIED and are the most likely first failure point.
- [ ] 8. Sync to GT103, run smoke test in container until green; goldens; module_lock.json.
      NOT STARTED -- NO gt_sync.sh / gt_run.sh / gt_wait.sh call has been made yet this
      session. Nothing has been run in the container. Nothing on GT103 has been touched.
- [ ] 9. Look at every figure (heatmap, trajectory) with Read tool; record findings here.
      NOT STARTED (depends on 8).
- [ ] 10. Final commit on wip/deseq2-lrt -- see "PAUSED" note below; a WIP commit was made
      instead, this step is not done.

## PAUSED 2026-09-27 (owner quota pause via coordinator)

Coordinator relayed an owner pause request (Claude weekly quota low) mid-step-4/6: "do not
start new steps or container runs; commit work in progress now (even WIP); update
build_worklog.md with the exact next step; then stop." No container run had been started yet
(good -- nothing was left half-run on GT103). A WIP commit was made on wip/deseq2-lrt with
everything written so far (core.R, qc.R, fig_mod_bulk.R addition); run.R, report.R,
calls_registry.json, references/*, SKILL.md, tests/ are all still scaffold placeholders from
`new_module.py` and must be written next.

## VERIFIED facts log

(appended as work proceeds; only mechanically checked facts go here)

## 待裁决 (S2)

- P-2 pattern clustering needs DEGreport in the image (owner decision: image rebuild); its
  default input gene rule is also 待澄清 (PACK P-2 待澄清 note). Not implemented in v1; no
  flag added. Safe behaviour: absent entirely, documented in SKILL.md Known limitations.
- "Adjustment terms kept in both" (P-1) is only mechanically checked when the user supplies
  `--adjust`; PACK does not define a default rule for inferring adjustment terms from a raw
  formula pair, and inventing one risks silently accepting a user mistake (e.g. reduced
  formula that drops a covariate the user meant to keep). Safest behaviour: no default,
  `--adjust` optional, checked exactly when given; documented in parameters.md and
  troubleshooting.md.
- No `--shrinkage` / `lfcShrink` in this module: PACK's D-09-equivalent decision is silent
  for LRT; lfcShrink's `res` argument is documented (results.Rd) around Wald-shaped results
  and PACK explicitly limits LRT's LFC to "one coefficient, labelled as such" with no
  shrinkage discussion. Safe behaviour: no shrinkage flag; printed log2fc is always the MLE
  of the single named coefficient. Recorded as a Known limitation with a pointer to
  deseq2-wald for a shrunken single-coefficient estimate.

## Previous NEXT STEP (2026-09-27 pause)

PAUSED (owner quota, 2026-09-27) -- resume here next week:
1. Write skills/deseq2-lrt/scripts/run_deseq2_lrt.R (fill the SPEC per step 3's CLI design:
   --counts/--samples/--from-run/--outdir/--spec/--sample-col/--full/--reduced/--adjust/
   --group-col/--group-reference/--time-col/--min-count/--min-samples/--alpha/--report-coef/
   --fit-type/--sf-type/--gene-annotation/--top-n/--seed/--journal; mirror
   run_deseq2_wald.R's 10-step body, calling dl_check_prefilter_rule/dl_design/
   deseq2_lrt_compute/dl_feature_table/dl_counts/deseq2_lrt_qc/write_handoff/
   os_write_provenance).
2. Write skills/deseq2-lrt/scripts/deseq2_lrt_report.R (tables: feature_table.csv,
   deseq2_lrt_results_full.csv, normalized_counts.csv, vst_matrix.csv, size_factors.csv;
   figures: os_top_heatmap always (>=2 sig genes), os_lrt_trajectory only when --time-col
   given; results/deseq2_lrt_results.json incl. full/reduced formulas verbatim,
   tested_terms, df, used_coef, header_log2fc/header_pvalue (the captured
   S4Vectors::mcols(res)$description text) and qc block; draft/methods_results.md via
   os_read_templates/os_fill_template).
3. Write skills/deseq2-lrt/scripts/calls_registry.json (start from L1_bioc3.23/*/defaults.tsv
   already read in step 1, but function_default MUST be re-confirmed via a container probe
   run before trusting it -- do not skip that confirmation even though a draft exists).
4. Write references/{method-basis,parameters,qc-rules,reporting-templates,troubleshooting}.md
   and SKILL.md, mirroring deseq2-wald's files section by section (already read in full in
   step 1) but reflecting deseq2-lrt's actual flags/behaviour above.
5. Add FIGURE_STYLE.md sec 19.x for os_lrt_trajectory (facet_wrap; note it is the first
   faceted figure in the shared figure layer).
6. Write tests/fixtures/make_fission.R (new) and reuse/copy make_pasilla.R; write
   tests/run_smoke_test.R per the plan in checklist item 7 above (fission REPLAY primary
   anchor, pasilla REPLAY + Wald-closeness consistency secondary anchor, static checks,
   typed-error/blocker cases including the always-required --min-samples and the
   OS_BATCH_CORRECTED_INPUT chain-refusal test, determinism/--spec replay, --from-run
   chaining, golden check, no Rplots.pdf).
7. ONLY THEN start using $T/gt_sync.sh + gt_run.sh + gt_wait.sh (per BUILDER_BRIEF sec 1) --
   nothing has touched GT103 yet this build. Expect the fission column-name assumption
   (strain/minute) and the acceptance-data "installed" package path to be the first things
   that need correcting from real container output.
8. Then goldens, module_lock.json, look at every figure, final commit, final report per
   BUILDER_BRIEF sec 7.

## Lane M1 continuation (2026-09-28, GT103)

- [x] Merged `origin/wip/deseq2-lrt` into `build/m1m2`; resolved `fig_mod_bulk.R` by retaining sva-batch and LRT builders.
- [x] Filled entry, report, registry, references, SKILL, fission fixture and smoke test from the recorded next-step list. A `--pattern-clustering` request returns typed `OS_UNAVAILABLE_DEPENDENCY` (DEGreport is absent in the locked image, verified with `requireNamespace`).
- [x] Container formals probe for DESeqDataSetFromMatrix, DESeq, results, vst and varianceStabilizingTransformation; call registry and default drift PASS. `check_defaults.py` 23/23, `check_flag_docs.py` 23/23, lint PASS.
- [x] Fission primary REPLAY: assay SHA256 `4bec9e6d01665301ced3de128eff4cfb1269aed9701146e794087e24f526fe30`; 7,039 input, 6,205 tested, 8 significant at BH 0.05, interaction df 5. Independent DESeq2 LRT p-values match across >1,000 genes; adjusted-P missingness matches. Pasilla secondary: 14,599 input, 8,148 tested, 1,112 significant, condition df 1.
- [x] Typed pattern/degenerated-design/missing-prefilter errors; `--spec` replay byte-identical tables, JSON and PNGs; deseq2-qc `--from-run` works and tampered upstream is refused. Golden-write and normal smoke PASS, G PASS, no Rplots.pdf. Lock generated in `omicstat-r:2026.09.1` (14 files).
- [x] Viewed all unique PNGs: fission top heatmap and trajectory, pasilla top heatmap. First trajectory had clipped facet labels; switched the shared builder to two columns, regenerated goldens and re-viewed it. Final labels are unclipped, legends/axes readable, captions record n and method.
- Shared bug fixed: `feature_table.R` stripped numeric suffixes from all feature IDs, collapsing distinct fission IDs such as `SPAC212.11`; now it strips only Ensembl version suffixes. This is the sole non-group shared-code change and is needed for the frozen fission anchor.
- Existing deseq2-wald smoke regression against the shared feature-ID change: SMOKE PASSED, G golden PASS, no Rplots.pdf; a targeted Ensembl/fission ID-normalization probe also passed.

## 待裁决 (lane continuation)

- P-2 pattern clustering needs DEGreport in a future locked image and an owner-approved explicit input-gene rule. The flag is a typed refusal, so no exploratory clustering claim is made.
- Adjustment terms can only be checked when named via `--adjust`; no intent is inferred from a formula pair.
- No LRT ranked-list handoff is produced: a nonnegative joint deviance statistic has no directional sign.

## NEXT STEP

Independent S3 review is requested in `S3_REQUEST.md`. No S5 router/rules installation in this lane.
2026-10-01 env_rebuild: DEGreport route implemented as optional official degPatterns wrapper; explicit gene selection + time, all native options captured; fission targeted smoke PASS, native assignments present and default LRT full table byte-identical. Full smoke/new image final seal pending.
2026-10-01 env_rebuild: baseline new-image smoke PASS; existing golden retained; lock refreshed/check; addon-specific checks pending
deseq2-lrt: final 2026.10.1 smoke PASS (non-root/offline; golden unchanged; lock checked; awaiting independent S3); next remaining full R suite
