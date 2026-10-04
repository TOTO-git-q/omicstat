# limma-camera S4 fixes (1.0.0 -> 1.1.0)

Branch `s4/gsva-camera`. Work list: `S3_REVIEW_astra.md` F1-F5, `docs/build/S3_REPORT_astra.md` sec 2-5 (sec 5 items
1, 2, 3, 5 on the consumer side). GT103 run dir `~/omic-build-logs/s4/limma-camera` (container
`omicstat-r:2026.09.1`). Logs: `limma-camera-golden2.log` (goldens written, SMOKE PASSED, EXIT 0),
`limma-camera-smoke5.log` (plain rerun, golden PASS, SMOKE PASSED), `limma-camera-lock2.log` /
`limma-camera-lockcheck.log` (module_lock written / `--check` OK, 14 files).
History: the first S4 helper implemented F1-F5 and contracts b/c but was cut off before committing; the coordinator
saved that tree as WIP 644c72e (unverified). The resumed helper re-ran it (all PASS except goldens), reviewed code,
drafts and every figure, fixed what was wrong (below, "resumed fixes"), regenerated goldens and the lock.

## F1 - printed camera anchor - fixed (version-matched printed anchor; suite replay kept separately)
- Root cause (docs/build/S4_ANCHOR_TRACE.md): limma 3.66.0 made `voom(adaptive.span = TRUE)` the default (L1
  `limma/NEWS.txt`, version 3.66.0); the static User's Guide was printed with the fixed span 0.5.
- `tests/run_smoke_test.R:67-95`: the guide's own code (usersguide.rendered.txt:7395 design, :7398/:7406 voom, :7400/
  :7408 duplicateCorrelation, :7486-7491 GenderGenes index from the locked F11 copy of the URL, :7497 `camera(v, index,
  design, 2)`) with `adaptive.span = FALSE` written out (owner rule; the only change; `plot = TRUE` at :7406 is written
  `plot = FALSE`, no numeric effect). PRINTED assertions at 3 significant digits:
  consensus correlation 0.4455442 / 0.4459984 = printed 0.446 (:7402, :7410); camera Y 13 Up P 2.402131e-262,
  FDR 4.804263e-262, X 54 Down P 5.576931e-26, FDR 5.576931e-26 = printed 2.40e-262 / 4.80e-262 / 5.58e-26 /
  5.58e-26 (:7498-7500).
- The module run on that guide-era voom E + weights reproduces the printed row and equals the guide-code values
  (relative 1e-8).
- Suite route (frozen, unchanged: upstream voom with the locked 3.68.5 default `adaptive.span = TRUE`), REPLAY anchor,
  separate (`:97-112`): Y P 1.79122449658387e-262, X P 6.02018304198957e-26, consensus 0.4454514; engine = an
  independent direct `limma::camera` call.
- mroast 9999 guide anchor unchanged: Y/X P = 1e-04 (`:161`).

## F2 - per-route Methods - fixed
- `scripts/limma_camera_report.R:46-81` builds the Methods from the actual run: input object, scale and weights
  (`input$source_sentence`), design formula and source, design columns, tested coefficient, target vs reference with n
  per group and what positive means, replicate unit (block, n blocks, correlation and its source, or "independent
  unit", or the unmodelled upstream block for acknowledged camera), the ranking sentence for cameraPR (metric,
  contrast, producer, positive/negative end, ties), and the method settings (camera/cameraPR inter.gene.cor 0.01
  preset, use.ranks, directional, weights; fry standardize/sort; roast set, nrot, approx.zscore, legacy; mroast
  adjust.method, midp, sort). `tables/design.csv` saves the design actually used (`:15-22`).
- Expression input without `--input-scale` is refused (`OS_MISSING_PARAMETER`).
- Evidence: each route's final draft asserted separately - camera (`:113-123`), mroast (`:162-166`), fry (`:167-170`),
  roast (`:171-176`), cameraPR from a user file (`:177-195`), camera and cameraPR from a real limma-voom run
  (`:231-238`), acknowledged camera and fry from a real limma-dupcor run (`:256-280`); design.csv equals the fixture
  design exactly.
- Resumed fixes: for a ranked file without metadata the draft said "the declared by the user contrast" and "a negative
  score means the opposite of: ..."; now "the user-declared contrast", "the opposite direction", "null test not stated
  in the file" (`scripts/run_limma_camera.R:119-121`), asserted. cameraPR returns P = 0 for Y (double underflow): the
  barcode legend said "BH adjusted P = 0"; now "< 2.23e-308 (below double precision, returned as 0)" and the draft
  says which sets underflowed and how gene_set_bar draws them (`scripts/limma_camera_report.R:10-12,120-125`),
  asserted.

## F3 - barcode (with worm), set-highlight MD, legends/axis titles on all routes - fixed
- `scripts/limma_camera_core.R:23-66,130-139`: the worm is computed as limma::barcodeplot does
  (`tricubeMovingAverage(membership in rank order, span = 0.45)` / mean membership); the display statistic is the
  upstream fit's moderated t, a display-only lmFit + eBayes on the same design/weights/block for plain expression, or
  the supplied ranking. `scripts/limma_camera_report.R:24-43`: `barcode_1|2` for the top two sets (one for roast),
  `md_set_highlight` for expression routes (none for rank-only). The shared bar builder now has axis titles and a
  legend of the directions present on every route.
- Resumed fix: on cameraPR from a limma-voom ranked_list the long metric name "limma moderated t-statistic" as y title
  overflowed panel b and overlapped the panel tag; the axis now uses a short statistic name ("moderated t", "Wald
  statistic", ... ; user metrics cut at 22 characters), the Methods keep the full metric
  (`scripts/limma_camera_core.R:34-40`), asserted (`tests/run_smoke_test.R:246-247`) and looked at.
- Evidence: captions with n (13/54 members, 16918 features) and the BH threshold, legends in the draft (`:124-132`),
  one barcode for roast, no MD for rank-only (`:171-188`).

## F4 - calls_registry with actual values or explicit bindings - fixed
- `scripts/calls_registry.json`: every argument has `kind` fixed (literal code + value), flag (`a$nrot`, flag name,
  value = flag default) or input (variable + binding description); `function_default` is a separate field; no
  "explicit" placeholder; `value_semantics` documents the scheme.
- `tests/registry_values_check.R`: parses every call site and checks each registered argument's code against it, that
  fixed code evaluates to the value, that flag bindings read the named flag and (resumed addition) that their value
  equals `flag_defaults` (which check_defaults.py ties to `--help`); function defaults are checked by
  check_default_drift().
- Evidence: "F4 registry values/bindings match all 83 call-site arguments; no "explicit" placeholder" PASS; call
  registry, default drift, check_defaults.py (29 flags), check_flag_docs.py, lint_r.py all PASS in the container.

## F5 - routing evaluation asset - fixed
- `acceptance/exemplars/limma-camera/routing_eval_limma_camera.jsonl`, separate from the frequency corpus:
  LC-EVAL-01 negative (microscope camera, PMID 36542715, not in the corpus, must not route to limma-camera),
  LC-EVAL-02 negative (FRY gene symbol, PMID 35993362, the one not-applicable corpus article; expected limma-array),
  LC-EVAL-03 positive (cameraPR on a pre-ranked statistic, PMID 38032734; expected limma-camera, competitive,
  ranked_list, cameraPR). Source sentences are 25 words or fewer.
- Resumed check: sentences 01 and 02 re-found in Europe PMC fullTextXML; sentence 03 re-found in the PMC OA BioC text
  (Europe PMC does not serve this PMCID; the corpus efetch copy is the PubMed record only) - wording of its
  context_check corrected accordingly.
- Evidence (`tests/run_smoke_test.R:37-57`): corpus unchanged (30 articles, 29 apply), asset structure, polarities,
  expected routes and the corpus membership/applicability of each case asserted.

## Contract (b) - done
- `scripts/run_limma_camera.R:73-84,130-171`: a limma-voom / limma-array / limma-dupcor run is read with
  `os_limma_handoff_read()`: EList E + weights, fitted design, tested coefficient, sample table; flags that would
  rebuild the design/samples/weights/block are refused and `--reference/--target/--group-col` must agree
  (`OS_CONFLICTING_PARAMETERS`); a dupcor block makes camera refuse (`OS_UNSUPPORTED_DESIGN`) unless
  `--acknowledge-block-ignored` (then QC LC-06 and a Methods sentence); fry/roast/mroast use the upstream block and
  consensus correlation. cameraPR from a limma run consumes the ranked_list metadata (`os_ranked_list_meta()`) and
  refuses `--direction/--rank-metric/--metric-name` overrides.
- Evidence (`:211-280`): camera on the real voom hand-off equals `camera(EList, index, design, coef)` and the explicit
  E + weights call (relative 1e-12); fry on the real dupcor hand-off equals a direct fry with the upstream block and
  correlation; refusals asserted.

## Contract (c) - done
- `os_handoff_assert_uncorrected()` on every upstream object; a corrected-lineage object is refused
  (`OS_BATCH_CORRECTED_INPUT`, `:202-209`); gsva-score's smoke also shows camera refusing corrected-lineage GSVA scores.

## Figures looked at (Read; every distinct PNG hash of the final runs)
- gene_set_bar, camera suite / guide-era / fromrun / voom / dupcor-ack: Y, X bars, x title "-log10 adjusted P", y
  title "Gene set", Direction legend Up/Down, dashed BH line. cameraPR (file and voom): same; Y drawn at the
  double-precision floor (stated in the draft). fry, mroast: titles and legend present (the S3 defect). roast: one set,
  legend shows Up only (the direction present).
- barcode_1/2 (Y, X) on every route: worm panel a with the 1 = no enrichment line, panel b grey statistic with member
  bars, x title "Rank of <statistic> (most negative left)", y titles fit (cameraPR-voom fixed as above).
- md_set_highlight (camera, guide-era, voom, fry, mroast, roast, dupcor): title "Male vs Female", Gene set legend
  (Other plus the highlighted sets), axis titles.
- Observation (shared, cosmetic): MD highlight colours follow set order, so in mroast X is red and Y blue while in
  camera Y is red - see Shared needs 1.

## Known failing anchors
None.

## Owner items
- Suite voom span: the frozen suite route keeps limma 3.68.5's `adaptive.span = TRUE`; the guide-path anchor uses
  `adaptive.span = FALSE` (NEWS 3.66.0). Whether the suite should state/fix the span is for the owner (recorded only;
  nothing changed).
- limma-voom voomLmFit call set (P-1/P-2) is upstream and unchanged here.
- Hallmark stays `OS_REFDATA_MISSING` (asserted). No KEGG.
- The routing evaluation asset (F5) is delivered for router acceptance; wiring it into a router test is outside this
  module.

## Shared needs
1. `skills/_shared/scripts/fig_mod_enrich_rank.R::os_md_set_highlight()` - assign highlight colours from a
   categorical palette that is not the Up/Down red/blue pair, and in a stable order (e.g. sorted set ID), so a
   down-regulated set is not drawn in the "Up" red and the same set keeps its colour across routes. Item: F3
   (legibility). Goldens of limma-camera must be regenerated after the change.
2. Optional: `os_barcode()` could guard long `stat_label` values itself (wrap or truncate); the module now passes a
   short label, so this is not blocking.
3. `os_ranked_list_sentence()` prints "1 tied scores"; plural handling would read better (cosmetic).

## Notes for the final verifier
- Goldens lock the camera suite route (a1): gene_set_table, method_raw, design.csv, result JSON, gene_set_bar
  PNG/spec, barcode_1 PNG/spec, md_set_highlight PNG.
- The printed anchor is version-matched (guide-era voom span written out, owner rule); the suite route keeps its own
  replay values. Both kinds are labelled in the smoke output ("A-printed", "suite-route locked replay").
- Run `bash docs/build/agent_briefs/s4_run.sh limma-camera <tag> Rscript skills/limma-camera/tests/run_smoke_test.R`.
