# build_worklog -- edger-qlf (S2 builder)

- module: edger-qlf ; worktree: `E:\claude workspace\skills-dev\omic-wt-edger-qlf` ; branch: `wip/edger-qlf`
- GT103 run name: `edger-qlf` (NOT YET synced/created -- no GT103 docker run has been started for this module)
- Coordinator: Claude Opus, S3 acceptance + S5 installation.

## STATUS (2026-09-27): PAUSED by owner (quota). No GT103 run in flight. Safe to resume any time.

## Checklist (ENGINEERING_PLAN 7.2 / BUILDER_BRIEF sec 3)
1. [x] Scaffold (`python tools/new_module.py edger qlf`) -- committed.
2. [ ] Engine (core.R) -- NOT WRITTEN YET. Full design decided below; write it next.
3. [ ] calls_registry.json -- NOT WRITTEN YET (values known from L1 Rd + PACK; two
       `function_default`s still need a container probe: see "Container probes needed").
4. [ ] QC rules (EQ-01..) -- NOT WRITTEN YET; rule list drafted below.
5. [ ] references/*.md -- NOT WRITTEN YET.
6. [ ] Figures: new builders needed in `_shared/scripts/fig_mod_bulk.R` (MD plot) and a
       BCV plot via existing `os_diag_xy`. NOT WRITTEN YET. One shared-file change already
       planned: add `log2cpm = quote(log[2]*" counts per million")` to `OS_AXIS` in
       `skills/_shared/scripts/fig_style.R` (additive only, no existing token's behaviour
       changes) -- needed for the MD plot's x-axis label. NOT YET APPLIED.
7. [ ] Smoke test (`tests/run_smoke_test.R`) + fixture (`tests/fixtures/make_gse60450.R`) --
       NOT WRITTEN YET.
8. [ ] First container run (smoke test) -- NOT STARTED. No GT103 sync has happened.
9. [ ] Goldens, module_lock.json -- NOT STARTED.
10. [ ] Figures looked at -- NOT STARTED.
11. [ ] Final commit / report -- NOT STARTED.

## VERIFIED facts (research complete; safe to trust)

### Reading done (S2 sec 2 of BUILDER_BRIEF)
- Read in full: BUILDER_BRIEF.md, MODULE_BUILD_BRIEF.md, ENGINEERING_PLAN.md parts 1, 3, 4
  (skimmed part 2/5-9), SUITE.md "M1/M2 S1 审定（2026-09-27）" section (all 10 cross-module
  rules), `acceptance/exemplars/edger-qlf/PACK.md` in full (including the frozen S1 附录:
  P-1 legacy/new QL, P-2 robust, P-3 FC criterion, Note on MINTIE PMC8532352).
- Read in full: `skills/deseq2-wald/` (all files: run/core/report/qc R scripts,
  calls_registry.json, all 5 references/*.md, SKILL.md, tests/run_smoke_test.R,
  tests/fixtures/make_pasilla.R, tests/golden_manifest.csv, module_lock.json) as the
  structural template.
- Read in full: `skills/_shared/scripts/{args,engine_run,design_check,module_kit,
  feature_table,handoff,fig_all,fig_mod_bulk,fig_bulk}.R` (fig_bulk.R fully, incl. os_ma,
  os_volcano, os_pca_scores/os_pca_plot, os_top_heatmap, os_diag_xy which already exists
  and fits the BCV plot). fig_mod_bulk.R currently only has the sva-batch `os_batch_pca_pair`
  block; ours will be a second `# ---- edger-qlf ----` block.
- Read L1 Rd (in `acceptance/exemplars/edger-qlf/L1_bioc3.23/edgeR/Rd/`): DGEList.Rd,
  filterByExpr.Rd, normLibSizes.Rd, estimateDisp.Rd, glmQLFit.Rd, glmQLFTest.Rd,
  glmTreat.Rd, topTags.Rd, defaults.tsv. Read the vignette case study verbatim
  (`edgeRUsersGuide.rendered.txt` lines 2473-2734, section 4.4.1-4.4.9) -- this is the
  anchor's exact source code and printed values (transcribed below).
- `decideTests.Rd` is NOT in our L1 collection (only 9 Rd files were exported for this
  module) and is NOT named in the PACK's S1 appendix registered-call list. DECISION: do
  NOT call `edgeR::decideTests()` in the engine; compute the Down/NotSig/Up counts directly
  from the feature table (FDR <= alpha, direction = sign of logFC), exactly the same pattern
  `deseq2_wald_core.R::dw_counts()` uses instead of calling `DESeq2::results()`'s own
  summary. This is verified against the anchor's own printed `summary(decideTests(...))`
  numbers (Down/NotSig/Up), so the check is numeric, not a call to an unregistered function.

### Anchor verified against GT103 (read-only `ssh`/`zcat`/`sha256sum`, no docker run)
- `acceptance/data/GSE60450_Lactation-GenewiseCounts.txt.gz` exists on GT103 at
  `~/omic-build/acceptance/data/` (will be hard-linked into the run dir by `gt_sync.sh`).
  sha256 `906b6ec4c33e95ca0ba454a3e0d07ad74e9cb7528ee38b89a9b122f5674a5f0d` -- MATCHES
  `acceptance/data/fetch_anchor_data.sh`.
  27180 lines (header + 27179 genes) -- matches "27179" in the PACK anchor (C section).
  Header: `EntrezGeneID  Length  MCL1-DG_... MCL1-DH_... MCL1-DI_... MCL1-DJ_... MCL1-DK_...
  MCL1-DL_... MCL1-LA_... MCL1-LB_... MCL1-LC_... MCL1-LD_... MCL1-LE_... MCL1-LF_...`
  First data row (497097: 438 300 65 237 354 287 0 0 0 0 0 0) EXACTLY matches the
  `head(fc$counts)` row printed in vignette 4.4.2 for GSM columns 1-12 in targets order
  (B.virgin,B.virgin,B.pregnant,B.pregnant,B.lactate,B.lactate,L.virgin,L.virgin,
  L.pregnant,L.pregnant,L.lactate,L.lactate) -- CONFIRMS column order/group mapping:
  MCL1-DG=B.virgin, DH=B.virgin, DI=B.pregnant, DJ=B.pregnant, DK=B.lactate, DL=B.lactate,
  LA=L.virgin, LB=L.virgin, LC=L.pregnant, LD=L.pregnant, LE=L.lactate, LF=L.lactate.
  This mapping is what `tests/fixtures/make_gse60450.R` must hard-code (with the sha256
  check like `make_pasilla.R` does).

### Anchor code + printed values transcribed verbatim from the guide (section 4.4)
```
group <- factor(paste0(targets$CellType, ".", targets$Status))   # -> our .eqgrp
y <- DGEList(fc$counts, group=group)
keep <- filterByExpr(y)                    # summary: FALSE 11210, TRUE 15969 (of 27179)
y <- y[keep, , keep.lib.sizes=FALSE]
y <- normLibSizes(y)                       # TMM (default method)
design <- model.matrix(~0 + group); colnames(design) <- levels(group)
y <- estimateDisp(y, design, robust=TRUE)  # y$common.dispersion == 0.0134 (BCV plot only)
fit <- glmQLFit(y, design, robust=TRUE)    # fit$dispersion printed "[1] 0.013"
con <- makeContrasts(B.pregnant - B.lactate, levels=design)
qlf <- glmQLFTest(fit, contrast=con)
topTags(qlf) top row: Mrgprf logFC -5.15 logCPM 2.74 F 473 PValue 7.62e-13 FDR 1.22e-08
summary(decideTests(qlf)): Down 2607, NotSig 10546, Up 2816
tr <- glmTreat(fit, contrast=con, lfc=log2(1.2))
topTags(tr) top row: Mrgprf logFC -5.15 unshrunk.logFC -5.16 logCPM 2.74 PValue 8.57e-13 FDR 1.37e-08
summary(decideTests(tr)): Down 1533, NotSig 12573, Up 1863
```
Other topTags(qlf) rows (for extra anchor checks / gene-annotation fixture symbols):
Muc4 (140474) 7.17/6.05/337/4.64e-11/2.80e-07; Csn1s2b (12992) -6.09/10.18/434/5.27e-11/2.80e-07;
Wif1 (24117) 1.82/6.76/285/1.43e-10/5.22e-07; Tnni2 (21953) -5.76/3.86/360/1.63e-10/5.22e-07;
Myof (226101) -2.32/6.44/313/3.73e-10/8.66e-07; Atp2b4 (381290) -2.14/6.14/311/3.86e-10/8.66e-07;
Cldn4 (12740) 5.32/9.87/302/4.65e-10/8.66e-07; Gjb4 (14621) 4.54/5.54/235/4.88e-10/8.66e-07;
Ecrg4 (78896) 2.81/6.68/228/6.06e-10/9.67e-07.
NOTE: `fit$dispersion` is a per-gene vector; the guide's PDF shows only "[1] 0.013" (likely
truncated in PDF-to-text conversion, not the full vector). Treat as an UNCERTAIN anchor:
check `round(fit$dispersion[1], 3) == 0.013` (first row = gene 497097) and record this
assumption under "待裁决" once the smoke test is written; if it fails in the container,
downgrade this one line to informational-only and keep the topTags/decideTests numbers
(which are unambiguous) as the binding anchor.

## DESIGN DECIDED (write into code next; not yet implemented)

### CLI surface (mirrors deseq2-wald where sensible; new flags where edgeR differs)
`--counts/--samples` or `--from-run`, `--outdir`, `--spec`, `--sample-col` (default
"sample"), `--condition` (default "condition"), `--reference`/`--target` (required,
two levels of `--condition`), `--covariates` (comma list, factors, like deseq2-wald).
KEY DIFFERENCE from deseq2-wald: do **NOT** subset the sample table to just the
reference/target rows. All samples/levels of `--condition` stay in one means-model
design (`~ 0 + .eqgrp + covariates`), exactly reproducing the anchor's 6-group `~0+group`
fit; the contrast (+1 target / -1 reference, 0 elsewhere) selects the two levels tested.
This generalises the anchor's `makeContrasts(B.pregnant - B.lactate, levels=design)` to
a numeric contrast vector built directly (no string parsing of formulas needed).
Column-name matching for the contrast uses exact string match on `paste0(".eqgrp", level)`
model.matrix column names -- since we never need DESeq2-style `resultsNames()` parsing,
level strings do **not** need to be syntactic R names (simplification vs. deseq2-wald;
note this in parameters.md as an explicit, reasoned deviation, not an oversight).

Filter flags (filterByExpr locked defaults, PACK D-E1, all explicit per lock 3):
`--min-count` (10), `--min-total-count` (15), `--large-n` (10), `--min-prop` (0.7).
Always call `filterByExpr(y, design=design, group=NULL, lib.size=NULL, min.count=...,
min.total.count=..., large.n=..., min.prop=...)` -- passing `design` (not `group`) so
covariates/multi-level designs are handled by filterByExpr's own MinSampleSize logic
(the "minimum inverse leverage computed from the design matrix", per filterByExpr.Rd
Details). For the anchor's no-covariate case, a saturated `~0+group` design's leverage
reduces exactly to the smallest-group-size rule, so `filterByExpr(y, design=design)` must
reproduce `filterByExpr(y)` (group-implicit) numerically -- VERIFY THIS IN THE CONTAINER
as the first smoke-test check; if it does not reproduce 15969/27179, that is a real
finding to record, not silently patched.
DECISION (documented, not a 待裁决): SUITE cross-module rule 3 ("smallest group" prefilter
needs an explicit override for complex designs) is a DESeq2-shaped rule about a manual
min-count/min-samples heuristic; edgeR's `filterByExpr` already computes its own
design-based MinSampleSize with no such heuristic, so no analogous `--min-samples`
override flag is needed here. State this reasoning in references/parameters.md.

`--alpha` (0.05, FDR level for the Down/NotSig/Up counts and figure highlighting, BH only).
`--treat-fc` (num, default 0 = off; a LINEAR fold-change > 1; when > 0, switch from the
default `glmQLFTest` to `glmTreat(fit, contrast=eq_contrast, lfc=log2(--treat-fc),
null="interval")`; reject 0 < value <= 1 as OS_INVALID_PARAMETER). No default of 1.2
(PACK P-3: never invent a biological threshold).
`--display-lfc-filter` (num, default 0 = off, log2 units, same semantics as deseq2-wald
1.1.0: significant (FDR<alpha) AND |log2fc|>=filter, written to tables/display_filtered.csv,
never changes padj/FDR, reported separately in the draft). fc_criterion JSON block:
`null_test` / `min_effect_lfc_threshold` (log2 units always, even though `--treat-fc` is
linear -- convert for the field, but ALSO keep a `treat_fc_linear` field in the results
JSON documenting the linear input, per the coordinator's "document the unit" instruction)
/ `display_lfc_filter`.
`--legacy` (bool switch, off by default) -> `glmQLFit(legacy=TRUE)`, reported separately
in the Methods (PACK P-1, class B). `robust=TRUE, winsor.tail.p=c(0.05,0.1)` are FIXED,
no flag (PACK P-2, class A, no user override mentioned in the S1 appendix).
`--gene-annotation`, `--top-n`, `--label-n`, `--seed` (20260925), `--journal`: same as
deseq2-wald.

### Pipeline (all args explicit per lock 3; two need a container `formals()` probe, see below)
`DGEList(counts=filtered? no: full mat, lib.size=NULL, norm.factors=NULL, samples=NULL,
group=.eqgrp, genes=NULL, remove.zeros=FALSE)` ->
`filterByExpr(y, design=design, group=NULL, lib.size=NULL, min.count=, min.total.count=,
large.n=, min.prop=)` -> subset `y[keep, , keep.lib.sizes=FALSE]` -> `normLibSizes(y,
method="TMM", refColumn=NULL, logratioTrim=.3, sumTrim=0.05, doWeighting=TRUE,
Acutoff=-1e10, p=0.75)` -> (BCV-plot only) `estimateDisp(y, design, prior.df=NULL,
trend.method="locfit", tagwise=TRUE, span=NULL, legacy.span=FALSE, min.row.sum=5,
grid.length=21, grid.range=c(-10,10), robust=TRUE, winsor.tail.p=c(0.05,0.1), tol=1e-06)`
(trended dispersion from this call is NEVER passed into glmQLFit, per PACK P-1) ->
`glmQLFit(y, design, dispersion=NULL, abundance.trend=TRUE, robust=TRUE,
winsor.tail.p=c(0.05,0.1), legacy=<flag>, top.proportion=NULL, keep.unit.mat=FALSE)` ->
`glmQLFTest(fit, coef=NULL, contrast=eq_contrast, poisson.bound=TRUE)` (default) or
`glmTreat(fit, coef=NULL, contrast=eq_contrast, lfc=log2(fc), null="interval")` (optional)
-> `topTags(obj, n=Inf, adjust.method="BH", sort.by="none", p.value=1)` (as_feature_table()
does the final canonical sort, so sort.by="none" avoids double sorting ambiguity).

Down/NotSig/Up counts: computed directly (FDR<=alpha & sign(logFC)), NOT via
`edgeR::decideTests()` (see "decideTests.Rd is NOT in our L1" above).

### Container probes needed (do in the FIRST container session, before writing final
calls_registry.json -- do NOT copy these from memory):
1. `formals(edgeR:::cpm.DGEList)` or `edgeR::cpm.DGEList` -- for the logCPM
   expression_matrix handoff object and the top-heatmap input matrix. `cpm()` is NOT in
   our L1 Rd set (only 9 Rd files were exported for this module) and is NOT in the PACK's
   registered-call list -- this is a genuine PACK gap for a call we still need. Resolve it
   the way the PACK's own footnote sanctions (glmQLFit.Rd inconsistency note): read
   `formals()` directly in the locked container, register the call with
   `"source": "container formals() probe (cpm not in module L1)"`, and note the gap in
   worklog "待裁决". Expected default `prior.count` is commonly 2 in edgeR but MUST be
   confirmed in-container, never assumed.
2. Confirm `filterByExpr(y, design=design)` (no covariates) reproduces
   `filterByExpr(y)` (group-implicit) exactly on the anchor (15969/27179) -- see above.
3. Re-run `check_default_drift` after calls_registry.json is written (standard step).

### Figures planned (per coordinator's instructions: MD + BCV only; QL-dispersion plot and
MDS plot from PACK section F are DEFERRED, not a PACK gap -- the coordinator's own
instructions named only MD and BCV as the figures to build via `os_ma`-if-honest /
`os_diag_xy`). Record this scope choice (not a 待裁决 item; it's answering the
coordinator's own text) in the final report.
- **Volcano**: reuse `os_volcano` unchanged (already generic over any feature table).
- **MD plot**: NEW builder `os_md_edger()` in `fig_mod_bulk.R` under a
  `# ---- edger-qlf ----` heading -- a close copy of `os_ma()` but `x = ft$base_mean`
  used AS-IS (already average log2 CPM from the QL table's `logCPM` column, so it is
  NEVER log10-transformed again, unlike `os_ma`'s DESeq2 mean-of-normalized-counts axis),
  with axis label `OS_AXIS$log2cpm` (NEW token to add to `fig_style.R`'s `OS_AXIS` list --
  additive only, see checklist item 6).
- **BCV plot**: via the EXISTING `os_diag_xy()` (no new builder needed): points of
  tagwise BCV (`sqrt(y$tagwise.dispersion)`) vs `y$AveLogCPM` from the `estimateDisp()`
  object, `hlines = sqrt(y$common.dispersion)`. Simplification vs `edgeR::plotBCV`: no
  overlaid trend curve (os_diag_xy plots one series + optional href/vlines, not a mixed
  points+line-for-a-different-series plot) -- document this explicitly as a named
  simplification in SKILL.md "Known limitations", not silently.
- **top_heatmap**: reuse `os_top_heatmap` unchanged, fed by the logCPM matrix from probe 1.

### Handoff / ranked_list decision
Per BUILDER_BRIEF instructions in the prompt: try `sign(logFC) * sqrt(F)` of the QL
F-test as the `ranked_list` signed statistic; if not confident it is PACK/L1-sanctioned,
do NOT write `ranked_list` and record it under "待裁决". CURRENT LEAN: do not write it in
v1 (the PACK's S1 appendix never mentions a ranked_list contract for edger-qlf, and
SUITE cross-module rule 2 ties the sanctioned ranking statistic to "the same explicit LFC
type" convention shared with fgsea/CP-GSEA, which is a DESeq2 Wald stat / limma moderated
t precedent -- a QL F-statistic has no sign of its own, sign(logFC)*sqrt(F) is a plausible
but NOT explicitly sanctioned construction). Finalize this decision when writing qc.R;
write the reasoning into the worklog's "## 待裁决 (S2)" section either way.

`--from-run` upstream: `deseq2-qc` (hands on `count_matrix`, `sample_table`), same as
deseq2-wald. `sva-batch`'s `batch_corrected_matrix` type must be refused --
`read_handoff()` already does this generically; smoke test just needs one D4-style check
copied from deseq2-wald's pattern.

## 待裁决 (S2) -- running list, finalize/expand when qc.R and results JSON are written
1. `fit$dispersion` printed anchor ("[1] 0.013") may be a PDF-truncated vector, not a
   scalar -- treated as informational-only if the container disagrees (see above).
2. `ranked_list` handoff object -- leaning "do not write in v1", not yet finalized.
3. `cpm()` is not in the module's L1 Rd collection or the PACK's registered-call list;
   resolved via a container `formals()` probe per lock 3's own escape hatch, not memory.

## NEXT STEP (exact, for whoever resumes)
1. Read the remaining background needed to start writing code (not yet done): this
   worklog already contains everything gathered from L1/PACK/deseq2-wald/_shared -- no
   more reading is required before writing.
2. Write `skills/edger-qlf/scripts/edger_qlf_core.R` per "DESIGN DECIDED" above (mirror
   `deseq2_wald_core.R` structure: design-args check, `eq_design()`, `edger_qlf_compute()`,
   `eq_feature_table()`, `eq_counts()`, `eq_display_filter()`).
3. Write `edger_qlf_report.R`, `edger_qlf_qc.R` (rules EQ-01.. mirroring DW-01..12 where
   applicable: integer counts, replicates on reference/target levels only, padj-all-NA,
   most-features-significant, engine warnings, symbol mapping, legacy-vs-new QL reported,
   glmTreat active reported).
4. Add `os_md_edger()` to `skills/_shared/scripts/fig_mod_bulk.R` under
   `# ---- edger-qlf ----`; add the `log2cpm` token to `OS_AXIS` in `fig_style.R`; add a
   `## 19.x edger-qlf` section to `FIGURE_STYLE.md`.
5. Write `calls_registry.json` with placeholder `function_default`s marked
   `"UNVERIFIED: needs container formals() probe"` for the two items above, then correct
   them from the first container probe (do not skip the probe).
6. Write `references/*.md`, `SKILL.md`.
7. Write `tests/fixtures/make_gse60450.R` (sha256-gated like `make_pasilla.R`, using the
   verified column order above) and `tests/run_smoke_test.R` (anchors: filterByExpr
   15969/27179, decideTests-equivalent counts for both qlf and glmTreat(1.2), topTags top
   row Mrgprf, --from-run chaining + batch-corrected refusal, flag effectiveness for
   `--treat-fc`/`--display-lfc-filter`/`--legacy`, determinism/--spec replay, golden check).
8. THEN start the GT103 container: `gt_sync.sh`, `gt_run.sh edger-qlf <tag> ...`,
   `gt_wait.sh edger-qlf <tag>`. Iterate to a passing smoke test, write goldens, run
   `make_module_lock.R edger-qlf`, look at every figure PNG, commit, write final report.

No GT103 sync/run has happened yet for this module -- step 8 is the first one that
touches the shared host, and per the pause instruction nothing there should start until
the owner resumes the work.

## S2 implementation continuation (2026-09-28)

- Resumed the above NEXT STEP in the `build/m1m2` worktree. Built the engine, QC, report, references, flag/call registry, locked GSE60450 fixture and smoke checks. `filterByExpr(y, design=mm)` and guide `filterByExpr(y)` give the same 15,969/27,179 genes. No ranked-list handoff is written: `sign(logFC)*sqrt(F)` is not an S1-sanctioned ranking statistic.
- Locked edgeR 4.10.5 gives QLF Down/NotSig/Up = 2608/10546/2815, whereas the guide output from 4.9.9 prints 2607/10546/2816. The 4.10.5 `glmTreat(log2(1.2))` result is 1535/12570/1864, versus guide 1533/12573/1863. The new-method result was independently replayed across all 15,969 P values and FDRs, with exact agreement. These are version differences, not tolerances used to hide a failed anchor.
- The old QL method (`--legacy`) requires estimated dispersions in its DGEList. It receives the existing `estimateDisp()` object. Default `legacy=FALSE` receives the TMM DGEList directly with `dispersion=NULL`, per S1 P-1. Its BCV caption distinguishes these branches.
- `cpm.DGEList` and other registered defaults were probed with `formals()` in the locked container. The module's L1/Rd collection did not have `cpm`; the registry explicitly records this provenance. `check_calls`, default-drift, default/help/docs and hygiene checks passed.
- GSE60450 figure labels use the guide's 12 GEO accessions rather than long raw sequencing-column strings, preserving order and the gz SHA gate. All four unique QLF PNGs were opened and checked for clipping and label overlap. The BCV trend curve is deliberately omitted, as documented in SKILL.md. QL dispersion and MDS figures are outside the coordinator's MD+BCV build scope.
- `S3_REQUEST.md` contains the independent review focus, router row and proposed rules record. S3 and S5 remain for independent coordination.
- Final locked-container `OMICSTAT_WRITE_GOLDEN=1` smoke: PASS; ordinary smoke: PASS with G golden PASS, deterministic PNG/spec/table checks, typed refusals, all option checks and no Rplots.pdf. `module_lock.json` generated and `--check` PASS (14 files, tier container).
- Figure inspection after the short-label fix: QLF volcano (threshold/count legend and labels readable), MD (log2 CPM axis and labels readable), BCV (common line and cloud readable), top heatmap (12 accession labels, 50 feature labels and legend unclipped). Optional glmTreat volcano/MD/top heatmap and legacy volcano/MD/top heatmap were also opened; threshold lines, labels and legends were legible. The BCV picture uses the same data in these branches, with branch-specific caption; `figure_spec.json` states the count, contrast and criterion. No overlapping or clipped text observed.
- NEXT STEP: independent S3 review of `S3_REQUEST.md`. Do not install the router or rules in this lane.
- Shared figure-layer regression `skills/_shared/tests/test_figures.R`: ALL FIGURE CHECKS PASSED in the locked container after the additive MD axis token/builder change.
2026-10-01 env_rebuild: baseline new-image smoke PASS; existing golden retained; lock refreshed/check; addon-specific checks pending
edger-qlf: final 2026.10.1 smoke PASS (non-root/offline; golden unchanged; lock checked; awaiting independent S3); next remaining full R suite
