# sva-batch build worklog (S2)

- module: sva-batch
- worktree: E:\claude workspace\skills-dev\omic-wt-sva-batch
- branch: wip/sva-batch
- GT103 run name: sva-batch

## Checklist

- [x] Step 0: read BUILDER_BRIEF.md, PACK.md (in full, incl S1 appendix), MODULE_BUILD_BRIEF.md,
      reference module deseq2-wald (entry/core/qc/report/calls_registry/references/tests),
      _shared scripts (args.R, engine_run.R, design_check.R, module_kit.R, handoff.R,
      feature_table.R, fig_bulk.R, fig_compose.R, fig_all.R, fig_mod_bulk.R stub),
      CONVENTIONS.md in full, tools/new_module.py, tools/calls_check.R (calls_check.R),
      L1 evidence (sva Rd x5, sva.rendered.txt in full, limma removeBatchEffect.Rd,
      limma defaults.tsv), acceptance_lib_lock.csv (bladderbatch + zebrafishRNASeq now
      INSTALLED, contradicts PACK C's "package not installed" -- re-verify in container),
      ANCHOR_REGISTRY.md row 8, SUITE.md batch rule 7 and sec on sva-batch cross-refs.
- [x] Step 1: scaffold via `python tools/new_module.py sva batch` (QC prefix SB, matches brief).
- [x] Step 2: engine core (sva_batch_core.R) -- ComBat / ComBat_seq / sva / svaseq / removeBatchEffect
      display step, confounding checks, num.sv, typed errors.
- [x] Step 3: calls_registry.json (sva::ComBat, sva::ComBat_seq, sva::num.sv, sva::sva,
      sva::svaseq, limma::removeBatchEffect) -- function_default read from container formals()
      (verified via a container probe: every formals() value matched the registry byte-for-byte
      on the first try; check_default_drift also PASSes in the smoke test).
- [x] Step 4: QC rules SB-01..SB-08 (8, not 9 -- one planned rule, "ComBat_seq ran with group =
      NULL", turned out unreachable given --study-var is always required, so it was dropped rather
      than kept as dead code; see qc-rules.md).
- [x] Step 5: references/*.md + SKILL.md (description trimmed to 891 chars, under the 1000 limit).
- [x] Step 6: figure builder `os_batch_pca_pair()` in fig_mod_bulk.R (before/after PCA, "display
      only" caption) + FIGURE_STYLE.md sec 19.1. ComBat prior-density plot (PACK F row 2) is
      DEFERRED (base-R graphics inside ComBat(prior.plots=TRUE), incompatible with the ggplot-only
      figure discipline without reimplementing its density estimate; recorded under known
      limitations, not silently dropped). Also fixed a `_shared` bug found while building this
      figure: `os_compose()` did not set a `default_height_mm` on the composite it returns, so
      `os_save_figure()` fell back to a width-derived generic height, leaving a large blank canvas
      above a short row of small panels (visible in the first figure review, step 9). Fixed by
      propagating (rows) x (max child default_height_mm per row) when at least one child panel
      carries its own default_height_mm; NULL (old behaviour, unchanged) when none do. Only this
      module's own new builder calls `os_compose()` anywhere in the suite yet (grepped), so no
      other module's goldens were touched by this fix.
- [x] Step 7: tests/fixtures (bladderbatch loader via os_acceptance_data, zebrafishRNASeq zfGenes
      loader, ComBat_seq simulated rnbinom fixture per vignette code with a fixed seed) +
      tests/run_smoke_test.R.
- [x] Step 8: sync to GT103, run smoke test until pass; write + check goldens; module_lock.json.
      Final state: every check in tests/run_smoke_test.R PASSes (static checks, 5 anchors A1-A5,
      D1-D4 determinism/spec-replay/from-run/cross-module refusal, E1-E8 typed errors and
      blockers, F1-F3 flag effectiveness, G golden baseline PASS not SKIP), ~2 minutes wall clock.
- [x] Step 9: looked at every figure PNG (A1/A2/A4/A5 batch_pca.png, before and after the
      fig_compose.R height fix): panel tags a/b, titles, legends and axis labels all present and
      unclipped; the only issue found (excess blank canvas above the panels) was the `_shared` bug
      above, fixed and re-verified visually and via a re-written, re-checked golden.
- [x] Step 10: final commit (98ef896 scaffold+engine, then the passing-smoke-test/goldens/lock
      commit) + report to the coordinator.

## Design decisions locked in before coding (traced to PACK S1 appendix)

- Four `--method` values: combat, combat_seq, sva, svaseq (D-S1: counts -> combat_seq / svaseq,
  log-scale -> combat / sva; "unknown batch" = sva/svaseq, no --batch given at all for those two).
- `--study-var` is ALWAYS required (P-2: research variable design is mandatory for every method);
  `--study-var-type` enum {categorical, continuous} default categorical (safest default; nothing
  silently inferred from column contents).
- ComBat_seq + continuous study variable -> typed error `OS_UNSUPPORTED_DESIGN` (the 待澄清 point:
  the appendix does not say whether a continuous research variable goes into `group` or
  `covar_mod` for ComBat_seq; refusing is the safe behaviour, recorded under 待裁决 below).
- Confounding check (batch x study variable, combat/combat_seq only): full confounding -> immediate
  `OS_INVALID_DESIGN` stop (mirrors dw_design's not-full-rank stop in deseq2-wald: no QC row,
  the run never reaches the QC table); partial confounding -> QC warning row SB-05 (the run
  continues, contrast is estimable but with reduced residual df).
- sva/svaseq mod/mod0 rank checks (mod0 nested in mod, both full rank) -> immediate
  `OS_INVALID_DESIGN` on failure, same reasoning.
- `num.sv(dat, mod, method = <"be"|"leek">, vfilter = NULL, B = 20, seed = <--seed>)`: method is
  the only exposed CLI choice (`--num-sv-method`, default "be"; PACK P-3 names "leek" as an
  explicit sensitivity option); B, vfilter are function defaults, not flags (decision table did
  not revisit them).
- `sva`/`svaseq(dat, mod, mod0, n.sv = <num.sv output>, controls = NULL, method = "irw",
  vfilter = NULL, B = 5, numSVmethod = "be"[, constant = 1])`: all function defaults, written out,
  not flags (PACK: "决策表未另作取舍"). `controls` is never populated: supervised sva is out of
  scope for v1 (recorded under known limitations).
- ComBat: `mod = <full model: covariates + study var>`, `par.prior = TRUE`, `mean.only = FALSE`,
  `ref.batch = NULL`, `BPPARAM = BiocParallel::SerialParam()` (lock: single thread, matches
  deseq2-wald's `parallel = FALSE` precedent) -- all function defaults, not flags.
  `prior.plots` is NOT registered/passed (FALSE by omission): it only drives a base-R diagnostic
  plot, not the returned matrix, so it is not "result-affecting" under lock 3.
- ComBat_seq: `group = <categorical study var factor>` (NULL only if study var is continuous, which
  is refused before this point so in practice never NULL here), `covar_mod = <model.matrix of
  --covariates, intercept dropped, p-1 indicator columns per factor level>` (NULL when no
  --covariates given), `full_mod = TRUE`, `shrink = FALSE`, `shrink.disp = FALSE`,
  `gene.subset.n = NULL` -- all function defaults.
- Display "after" matrix:
  - method combat / combat_seq: the function's own direct output IS the display matrix.
  - method sva / svaseq: sva/svaseq estimate surrogate variables only (no corrected-matrix
    function of their own); the display matrix is built with
    `limma::removeBatchEffect(x = mat, batch = NULL, batch2 = NULL, covariates = <sv matrix>,
    design = <mod, full protected biological design incl. intercept>, group = NULL)`.
    This is the "protected-design display correction" the deseq2-qc P-3 cross-reference names;
    note the cross-reference's own wording shows `batch = <batch>` (implying a KNOWN-batch use),
    while this module's use of it is for the UNKNOWN-batch/SV path with `batch = NULL` and the
    SVs passed as `covariates` instead -- a defensible but not textually-identical reading,
    recorded under 待裁决.
- Handoff (P-1, binding): the canonical DE-facing object (`count_matrix` when the data stayed
  count-like i.e. combat_seq, `expression_matrix` otherwise) is ALWAYS the CORRECTED/display
  matrix, typed `batch_corrected_matrix` -- this is deliberate: it guarantees `read_handoff()`'s
  existing `OS_BATCH_CORRECTED_INPUT` refusal actually fires when a DE module (deseq2-wald) is
  pointed at a sva-batch run with `--from-run`, because the object name a DE module looks up
  (`count_matrix`) exists but carries the special type. The ORIGINAL uncorrected matrix is not
  re-exported under that name (it was already available to the user upstream, e.g. from
  deseq2-qc, before sva-batch ran); legitimate downstream use is: keep using the original
  --counts/--samples plus sva-batch's `sv_table` (new handoff type, csv: sample + SV1..SVn) or
  the `--batch` column, added as `--covariates` to the DE module's OWN design.
- New handoff type `sv_table` (csv, one row per sample: sample_col + SV1..SVn), written only for
  method sva/svaseq. Named and documented in the final report per MODULE_BUILD_BRIEF sec 3.

## 待裁决 (S2)

- ComBat_seq + continuous --study-var: refused with OS_UNSUPPORTED_DESIGN (see above); the S1
  appendix's own "clarify" note (group vs covar_mod placement) is left open, not guessed.
- removeBatchEffect(batch = NULL, covariates = <SV>, design = mod) for the sva/svaseq display
  path: the deseq2-qc P-3 cross-reference text shows `batch = <batch>` (a known-batch use); this
  module instead uses it for the UNKNOWN-batch/SV path with batch = NULL. Defensible (Rd: design
  "should never be left at NULL"; covariates "allows correction for ... a design matrix
  constructed from batch effects"), but not textually identical to the cross-reference's own
  example -- flagged for the coordinator to confirm at S3.
- Bug found and fixed in `_shared/scripts/module_kit.R` `os_acceptance_data()`: some Bioconductor
  experiment-data packages register a data() name that differs from the R object it loads
  (`data(package = "bladderbatch")$results` lists "bladderEset (bladderdata)": the data() argument
  is "bladderdata", the loaded object is "bladderEset"). The old code checked
  `exists(name, envir = env)` using the SAME `name` for both the data() call and the object
  lookup, so `os_acceptance_data(suite, "bladderbatch", "bladderdata")` and
  `os_acceptance_data(suite, "bladderbatch", "bladderEset")` BOTH silently returned NULL. Fixed:
  when `name` itself is not bound afterwards but exactly one object was loaded into the (fresh)
  environment, that object is returned instead. Backward compatible (zebrafishRNASeq's `zfGenes`,
  where the names already agree, is unaffected -- verified in the container). No other module
  calls `os_acceptance_data()` yet (grepped the whole worktree).
- num.sv(method = "leek") on bladderbatch, run through the ENGINE's own sorted-factor-level
  convention (`sort(unique(...), method = "radix")`), reproduces the vignette's printed n.sv = 2
  exactly (A3). An earlier STANDALONE probe (calling `num.sv` with `mod = model.matrix(~as.factor(
  cancer), data = pheno)` on the ORIGINAL `pData()` factor column, whose native level order need
  not be alphabetical) gave n.sv = 4 instead -- i.e. the discrepancy traced to level ORDER
  (reference-level choice), not a version mismatch as first suspected; once the fixture round-trips
  `cancer` through a plain character column exactly as the engine's own `--samples` csv does, the
  engine's sorted-level convention lines up with the vignette's own (apparently already
  alphabetical) factor and reproduces 2 exactly. Recorded in method-basis.md; no discrepancy left
  in the smoke test.

## NEXT STEP

2026-09-28 GT103 lane M1 rerun after the coordinator's legend/title/caption change:
`OMICSTAT_WRITE_GOLDEN=1` smoke PASS, normal smoke PASS, G golden PASS (not SKIP), no Rplots.pdf;
`module_lock.json` regenerated in `omicstat-r:2026.09.1`. Inspected all unique batch_pca PNGs
(A1-A5, F0, F3; D1/D2 and F1/F2 are byte-identical duplicates): labels and legends use the
input column names, titles are unclipped, and captions name method, n, and display-only use.
S3 request is in `S3_REQUEST.md`. Next: independent S3 review; no S5 installation in this lane.
2026-10-01 env_rebuild: baseline new-image smoke PASS; existing golden retained; lock refreshed/check; addon-specific checks pending
sva-batch: final 2026.10.1 smoke PASS (non-root/offline; golden unchanged; lock checked; awaiting independent S3); next remaining full R suite
