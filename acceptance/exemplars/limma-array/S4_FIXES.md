# limma-array S4 fixes (1.0.1 -> 1.1.0)

Branch `s4/limma-array` from `integrate/m1m2@53006d8`. GT103 run dir `~/omic-build-logs/s4/limma-array`
(logs `~/omic-build-logs/s4/limma-array-<tag>.log`). Container `omicstat-r:2026.09.1` for every run.
Work list: `S3_REVIEW_astra.md` F1-F4.

Commits: `98c17a3` F1 (guide replay file, probes), `20364ef` F3 + engine side of F1 + F4 code + smoke
assertions, `b7d6bcc` F2 (templates, SKILL/references), final commit = goldens, module lock, this file.
F2/F3/F4 were coded together (one core rewrite), so the split by commit is by file, not strictly by item.

## F1 - printed anchor of User's Guide 17.4 (GSE33005) and replay on real data

Changed
- `skills/limma-array/tests/guide_17_4.R` (new): the guide's OWN code, cited per step
  (`L1_bioc3.23/limma/vignettes/usersguide.rendered.txt` :6626-6757): `read.delim` SDRF, `Treatment` factor,
  `read.maimages(source="agilent", green.only=TRUE, other.columns="gIsWellAboveBG")`, `mapIds` on
  `RnAgilentDesign028282.db`, `backgroundCorrect(normexp)`, `normalizeBetweenArrays(quantile)`,
  `NotControl`/`NoSymbol`/`IsExpr`, `model.matrix(~Treatment)`, `lmFit`, `eBayes(trend=TRUE, robust=TRUE)`,
  `decideTests`, `topTable(coef=4, n=20)`. Printed values held in `G174_PRINTED` with line numbers. The only
  difference from the guide text: file names get `.gz` (the sha-locked GEO tar ships the same files gzipped).
- `tests/fixtures/make_gse33005.R` removed (first 5000 probes / 10 arrays / `probe_XXXXX` renaming).
  Engine inputs are now written from the guide's normalized EList at full precision (`%.17g`), all 44254
  probes x 19 arrays, original ProbeName IDs (replicate spots of one ProbeName: `ProbeName|<spot>`, spot =
  the row number the guide prints, e.g. `A_42_P667782|6942`), controls from `ControlType`, the
  `gIsWellAboveBG` 0/1 matrix, samples with all four treatment levels.
- `scripts/run_limma_array.R`: new switch `--keep-other-levels` so the engine can fit the guide's four-level
  `~Treatment` design and test one coefficient (off = previous behaviour, now with a typed message
  `OS_INVALID_DESIGN: condition has K levels; pass --keep-other-levels ...`). Uses the shared
  `os_limma_design(allow_multilevel=)` exactly like limma-dupcor. No estimator call changed.

Anchors (kind; evidence)
| Anchor | Kind | Where it runs | Result |
|---|---|---|---|
| dim(x) 44254 x 19 (:6681) | PRINTED | every smoke | PASS (`limma-array-final.log`) |
| x$genes[201:205] Row/Col/ControlType/ProbeName/SystematicName (:6691-6696) | PRINTED | every smoke | PASS |
| spot -> ProbeName of head(yfilt) and top-20 rows (:6736-6742, :6759-6778) | PRINTED | every smoke | PASS |
| Engine = guide code on the guide route without the NoSymbol term (37571 probes, ~Treatment, eBayes trend/robust): fit logFC/AveExpr/t/P/adj.P/B tol 1e-10 via `objects/fit.rds`; feature_table.csv at its 10 printed digits; direction summary = guide decideTests (Down 888 / NotSig 34889 / Up 1794) | REPLAY | every smoke | PASS |
| Validated technical IDs (replicate spots of one ProbeName): 37571 spots -> 25501 probes; P = direct avereps+lmFit+eBayes | REPLAY | every smoke | PASS |
| mapIds EntrezID/Symbol spots 201-205; dim(yfilt) 27024 x 19; head(yfilt$genes); summary(decideTests(fit[,-1])) incl. 10 ml/kg Down 756 / NotSig 24734 / Up 1534 and 0/27024/0; full topTable(coef=4,n=20) (spot, ProbeName, Symbol, EntrezID, logFC, AveExpr, t, P, adj.P, B at printed precision; RT1-Bb logFC 9.33) | PRINTED | smoke when the acceptance layer has the annotation; else NOT-RUN line | PASS with private library (`_s4/probe_full_anchor.R`, log `limma-array-full2.log`: `FULL ANCHOR PASSED`) |
| Engine on the full route (27024 probes): fit = guide fit (tol 1e-10); engine `direction_summary.csv` Down 756 / NotSig 24734 / Up 1534; top feature A_44_P552452 RT1-Bb logFC 9.33; feature_annotation 27024 mapped, top-20 Symbol/EntrezID as printed | REPLAY + PRINTED | same as above | PASS with private library (same log) |

Annotation package trace (`_s4/probe_annot.R`, log `limma-array-annot.log`)
- `RnAgilentDesign028282.db` 3.2.3, Bioconductor 3.23 annotation repository
  `https://bioconductor.org/packages/3.23/data/annotation/src/contrib/RnAgilentDesign028282.db_3.2.3.tar.gz`,
  1070509 bytes, sha256 `4e9197128f432239b25b653a2552092b094227e8948599e7a9feaeabc9891903`, License Artistic-2.0,
  Depends `AnnotationDbi (>= 1.34.3), org.Rn.eg.db (>= 3.3.0)`.
- `org.Rn.eg.db` 3.23.0, same repository, `org.Rn.eg.db_3.23.0.tar.gz`, 63231272 bytes, sha256
  `2fb0c72f8da59a80cb760590e3b5261c9a79890ee4170da13e44a83017d22fc8`, Artistic-2.0, Depends `AnnotationDbi (>= 1.73.0)`.
- `AnnotationDbi` 1.74.0 is in the image; neither .db package is. Downloadable from inside the container on GT103.
- Installed only into `~/omic-build-logs/s4/limma-array/.s4-annot-lib` (tarballs in `.s4-annot-src`).

Status: fixed in code; the full printed chain is **NOT-RUN in the smoke test** until the coordinator adds the two
packages to the acceptance layer (Shared needs 1). Proven reproducible (all printed values exact) with the private library.

## F2 - Methods report the actual operations and parameters

Changed: `scripts/limma_array_core.R` (`template_values`: platform, preprocessing, control, background,
retained, averaging, design, moderation, annotation sentences; `n_notsig`), `references/reporting-templates.md`
(new slots; `{detail}` dropped), new flag `--preprocessing` (string, reported verbatim; absent -> "were not stated
to this module and are therefore not reported"). `details` in `results/limma_results.json` carry the same facts
(controls removed/declared, n removed, k, n passing, n retained, avereps and multi-probe IDs, trend/robust and
source `agilent_preset`/`user`, preprocessing declared, annotation counts, design levels).

Evidence (smoke, `limma-array-final.log`): a0 Methods contain "1,377 control probes listed in the control-ID
file (controls.csv) were removed", "at least k = 4 of 19 arrays (37,571 of 42,877 passed)", "37,571 of 44,254
input probes were retained", "No technical averaging was applied", "contained all 4 levels of condition",
"trend = TRUE and robust = TRUE (registered Agilent preset)", the declared normexp + quantile text, the
Down/NotSig/Up sentence and the annotation counts (check "F2 Methods report ..."); override run: "trend = FALSE and
robust = FALSE (chosen explicitly by the user)", "not stated", "No probe annotation"; declared-controls run:
"declared free of control probes (--controls-removed); no control probes were removed"; avereps run:
"37,571 retained probes gave 25,501 tested features, N of which combined two or more probes".

## F3 - explicit probe annotation, original IDs, direction summary

Changed: new flag `--probe-annotation` (CSV `feature_id,symbol,entrez[,...]`), `la_probe_annotation()` in the core:
one row per tested feature after technical averaging with `annotation_status` mapped / unmapped (symbol "") /
conflicting (values joined with ";", never resolved), `probe_ids` (original member probe IDs), `n_probes`, extra
columns carried. Passed as `res$annotation` to the shared `os_limma_write()` -> symbol in `feature_table.csv`,
annotation columns in `limma_full.csv`, `tables/feature_annotation.csv`. Typed errors: missing columns
(`OS_MISSING_COLUMN`), reserved columns, duplicate IDs, no ID overlap (`OS_INVALID_INPUT`). Fixture keeps the
original ProbeName IDs (F1). Smoke annotation = the probe->gene pairs PRINTED in the guide (:6691-6696,
:6736-6742, :6759-6778; 22 probes, 67 spots) so the golden does not depend on the layer; the full `.db` mapping is
used in the full-route anchor.

Evidence: checks "F3 feature_annotation.csv ... 67 mapped / 37504 unmapped marked", "F3 symbol/Entrez carried
into feature_table and limma_full (A_44_P552452 -> RT1-Bb, 309622)", "averaging keeps the probe->gene mapping
(A_42_P667782: 10 spots -> Fastkd2, spot IDs listed)", "conflicting symbols ... marked", "annotation without
entrez column or with foreign IDs refused"; direction summary asserted against the guide decideTests (replay,
every run) and against the printed 756/24734/1534 (full route).

## F4 - every auxiliary input hashed

Changed: `scripts/run_limma_array.R` passes `control_ids`, `above_background`, `technical_ids`,
`probe_annotation` (when used) to `os_write_provenance(inputs=)` next to matrix/samples.
Evidence: "F4 provenance inputs hash matrix, samples, control IDs, above-background and probe annotation"
(sha equal to the files), "a changed control-ID file (same IDs, other order) is detected by its provenance hash"
(same feature table, different `control_ids` sha, same matrix sha), avereps run hashes `technical_ids`, declared
run hashes no control file. Goldens regenerated in the container (`limma-array-golden.log`,
`OMICSTAT_WRITE_GOLDEN=1`), normal rerun `limma-array-final.log`: `PASS: container golden`, `SMOKE PASSED`, EXIT 0
(47 PASS, 0 FAIL, one NOT-RUN line). Golden set now also covers `direction_summary.csv`,
`feature_annotation.csv`, `draft/methods_results.md`. `module_lock.json` regenerated (`limma-array-lock.log`, 1.1.0,
14 files) and `--check` OK (`limma-array-lockcheck.log`). check_defaults (28/28), check_flag_docs (28/28), lint_r
clean inside the container (smoke checks).

## Figures looked at (Read, copies of `_smoke/limma-array-smoke/*/figures/*.png`)
- a0/volcano: 37,571 features, Down 888 / Up 1,794 legend, padj 0.05 dashed line, labels RT1-Bb, Bad, Lcn2, Mei1,
  Vegfb, Fastkd2 (three replicate spots, separate features), nothing clipped, labels do not overlap each other.
- a0/md: red/blue/grey classes, zero line, RT1-Bb outlier at logFC 9.3 inside the panel; y ticks only 0 and 5
  (shared builder's breaks, sparse but correct).
- avereps/volcano: Down 434 / Up 992 on 25,501 averaged probes, one Fastkd2 label (averaged), symbols shown.
- treat/volcano and treat/md: Down 31 / Up 85; unannotated run labels original probe IDs (e.g.
  `A_42_P667782|6942`), legible.
- other/volcano, other/md, other/sa_diagnostic: explicit-choice run; SA scatter of sqrt(residual SD) vs mean with
  decreasing trend; volcano label `A_42_P667782|655` sits over a few red points (no label-label overlap).
Captions (figure_spec.json) state n features, BH adjusted P < 0.05 and up/down counts (smoke "caption and PNG").

## Known failing / not-run anchors
- **NOT-RUN ANCHOR** (printed on every smoke run until Shared needs 1 is done): the full printed chain of 17.4
  (Symbol/EntrezID of spots 201-205, dim(yfilt) 27024 x 19, head(yfilt), decideTests 756/24734/1534 and
  0/27024/0, top-20 table with RT1-Bb logFC 9.33) and its engine replay. Not a reproduction problem: it passes
  exactly with the private library (`limma-array-full2.log`). No KNOWN-FAILING anchor.

## Owner items (not decided here)
- Non-Agilent presets: unchanged, `--platform other` still requires explicit `--trend`/`--robust` (typed refusal,
  asserted).
- `--keep-other-levels` is opt-in (default off, previous two-level behaviour); whether multi-level arrays should
  be the default is left to the owner. The guide's example needs it.
- Removal of probes without a gene symbol (the guide's `NoSymbol` filter) is NOT an engine option (S1 P-2 freezes
  only control removal and the background rule); the full-route anchor performs it upstream and declares it via
  `--preprocessing`. An engine filter would need an owner decision.

## Shared needs (coordinator)
1. Acceptance layer: add two lock rows to `acceptance/data/acceptance_lib_lock.csv` (mode `installed`):
   - `"RnAgilentDesign028282.db","3.2.3","RnAgilentDesign028282.db_3.2.3.tar.gz","4e9197128f432239b25b653a2552092b094227e8948599e7a9feaeabc9891903","https://bioconductor.org/packages/3.23/data/annotation/src/contrib",3.23,"installed"`
   - `"org.Rn.eg.db","3.23.0","org.Rn.eg.db_3.23.0.tar.gz","2fb0c72f8da59a80cb760590e3b5261c9a79890ee4170da13e44a83017d22fc8","https://bioconductor.org/packages/3.23/data/annotation/src/contrib",3.23,"installed"`
   Both Artistic-2.0. `acceptance/data/install_acceptance_lib.R` needs two changes for them: (a) the no-lock path
   only queries `BioCexp` (add `BioCann`, or rely on the per-row `repository` of the lock path, which already
   works); (b) `deps_ok()` accepts only image packages, so `RnAgilentDesign028282.db` (Depends `org.Rn.eg.db`)
   would get mode `extracted`; it must also accept packages installed earlier in the layer and install in
   dependency order (`org.Rn.eg.db` before `RnAgilentDesign028282.db`; the lock is radix-sorted, which puts
   `RnAgilentDesign028282.db` first). The smoke test finds them with `os_acceptance_entry()` (mode `installed`)
   + `os_acceptance_lib()` + `requireNamespace()`; nothing else to change in the module.
2. None for `limma_io.R`: the S4 `os_limma_write()` contract (template_values, annotation, direction_summary)
   was sufficient. Note: this module now also returns `res$expr` (fitted matrix) so the writer hands on
   `objects/expression_matrix.csv`, as the shared contract comment describes.

## Notes for the final verifier
- Replay tolerance: the engine vs guide comparison is exact to 1e-10 on the saved `MArrayLM` (`objects/fit.rds`);
  `feature_table.csv` is compared at its 10 significant printed digits (shared `write_feature_table` uses
  `formatC(digits = 10)`; debug `_s4/debug_compare.R`, log `limma-array-dbg.log`, max rel diff 5e-10).
- The engine design has columns (Intercept, corn10, corn2, corn5); the guide has (Intercept, 2, 5, 10 ml/kg);
  same column space, so the tested coefficient is identical up to floating point.
- To rerun the full chain with the private library: `bash docs/build/agent_briefs/s4_run.sh limma-array full
  Rscript acceptance/exemplars/limma-array/_s4/probe_full_anchor.R` (uses the same functions as the smoke test).
- The smoke test now runs ~20 engine calls on the full 44254 x 19 matrix (~6 min in the container).
