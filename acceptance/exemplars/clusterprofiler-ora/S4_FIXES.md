# clusterprofiler-ora -- S4 fixes (1.0.0 -> 1.1.0)

Branch `s4/cp-ora-compare` (from integrate/m1m2 @fb63e52). GT103 run dir
`~/omic-build-logs/s4/cp-ora-compare/` (smoke tmp `_smoke/ora/`). Container `omicstat-r:2026.09.1`.
Source facts below were read from the locked container (`cp-ora-compare-src.log`, `-simp.log`).

## F1 -- GO ALL with pool FALSE (contract d)

- Locked source (clusterProfiler 4.20.0 `enrichGO`): with `ont = "ALL"` and `pool = FALSE` it calls
  `enrichGO` once per ontology (BP, CC, MF, positional args, `readable`/`pool` default) and binds the
  rows; each call runs `enrichit::ora_gson` (0.2.1), which computes `p.adjust(pvalue, "BH")` and
  `calculate_qvalue` over that ontology's tested sets only (zero-overlap sets removed first). With
  `pool = TRUE` one GO collection of all three ontologies goes to one `ora_gson` call: one
  denominator pair and one BH family. Probe (`cp-ora-compare-all.log`, `-simp.log`): pool FALSE
  p.adjust equals BH within each ontology (max diff 0), BH across all rows differs by up to 0.24;
  pool TRUE equals BH across all rows (max diff 0).
- Change: `scripts/clusterprofiler_ora_core.R` `co_families()` (and `co_compute`): testing family per
  row (`GO BP`/`GO CC`/`GO MF` for ALL pool FALSE; `GO ALL pooled` for pool TRUE; `GO <ont>`
  otherwise); per family the GeneRatio/BgRatio denominators must be unique and p.adjust must equal BH
  over that family, else `OS_INVALID_RESULT`. The old global "all terms share one denominator"
  refusal is gone. No union background is ever built; every term keeps its real GeneRatio/BgRatio.
- Outputs (`scripts/clusterprofiler_ora_report.R`): `test_family` column in
  `tables/enrichment_full.csv`; `tables/test_families.csv` (effective input, background, tested terms,
  BH scope text, n below alpha); JSON `test_families`; top-level `n_effective_input/background` are
  null when there is more than one family; Methods state per-family denominators and the BH scope
  (`references/reporting-templates.md`); ALL dot plot labels carry `[BP]/[CC]/[MF]` and the caption
  states the families.
- Evidence (`cp-ora-compare-ora-final.log`, DOSE selection 207 / explicit background 12495):
  - ALL pool FALSE: families BP/CC/MF input 194/201/193, background 11525/11914/11822, tested
    2588/292/478, BH<0.05 154/27/15; every row's denominators equal its family's; IDs, ratios and
    p.adjust equal a direct `enrichGO(ont="ALL", pool=FALSE)` in the test (replay anchor, 1e-14);
    BH within ontology recomputed independently; pooled BH would differ (> 1e-3).
  - ALL pool TRUE: one family, input 204, background 12112, 3358 terms; direct-call replay; BH over all.
  - BP preset unchanged: 2588 terms, first GO:0140014 padj 1.69548321341e-16, 194/11525, golden PASS.

## F2 -- symbols and simplify relation

- Symbols: `co_symbols()` uses `enrichit::EXTID2NAME` (the mapper inside `setReadable`; registered in
  `calls_registry.json`, `enrichit` added to `package_versions`). Outputs `tables/gene_symbol_map.csv`
  (every selected ID, symbol, mapping status) and `tables/enrichment_full_symbols.csv` (term, family,
  Count, original geneID, geneID_symbol). `enrichment_full.csv` keeps original IDs.
  Evidence: 207 rows in input order, 206 mapped; per-term symbol sets equal
  `enrichit::setReadable()` applied to the independent direct enrichGO result (all 2588 terms).
- Simplify relation (S1 P-3): `co_capture_similarity()` traces `mgoSim` inside clusterProfiler's
  namespace during the single `clusterProfiler::simplify()` call, capturing the package's own Wang
  similarity matrices (a 2588-term BP simplify takes ~15 min, so no second pass);
  `co_simplify_relation()` replays the selection loop of `simplify_internal` (groups with similarity
  > 0.7 around each term in result order, smallest p.adjust kept, ties by most GO ancestors, per
  ontology for ALL as `simplify_ALL`) and refuses unless its kept set is identical to the package
  output. `tables/simplify_relation.csv`: one row per merged term with representative,
  representative_retained (the package's greedy loop can later remove a representative), group anchor,
  similarity, number of removal events. JSON `simplify` records rule, counts and similarity source;
  Methods state the rule and counts.
  Evidence: CC 292 -> 82 (210 merged); ALL pool FALSE with `--min-size 200` 498 -> 275 (223 merged,
  all three ontologies); display IDs identical to a direct `clusterProfiler::simplify` in the test;
  merged + retained = all tested terms; representatives have padj <= merged padj; similarity source
  "captured from clusterProfiler::simplify".

## F3 -- software and annotation releases

- `co_software()` fills from the run: clusterProfiler 4.20.0 (`clusterProfiler::enrichGO`), enrichit
  0.2.1 (`enrichit::ora_gson`), GO.db 3.23.1 with GO release 2026-01-23 (GO.db metadata GOSOURCEDATE),
  org.Hs.eg.db 3.23.1 (Entrez Gene 2026-Mar18, GO annotation 2026-01-23), AnnotationDbi; GOSemSim
  2.38.3 when simplify is used. Written to JSON `software`, provenance `software` (extra) and Methods.
  Evidence: test asserts JSON versions = `packageVersion()` in the container, = provenance `packages`,
  provenance `software` = JSON `software`, and the Methods sentences contain each version/date,
  the background/cutoff statements are unchanged.

## Other

- Version 1.1.0 (`CO_VERSION`, `CO_MODULE_VERSION`); SKILL.md, method-basis, parameters, templates updated.
- Goldens regenerated in the container (`cp-ora-compare-ora-gold.log`), then normal rerun
  `cp-ora-compare-ora-final.log` SMOKE PASSED with golden PASS; lock written
  (`cp-ora-compare-lock-ora.log`) and checked (`cp-ora-compare-lock-check.log`).
  Static checks (registry, formals, check_defaults, check_flag_docs, lint_r) run inside the smoke.
- Figures looked at (copied from `_smoke/ora/*/figures/ora_dotplot.png`): anchor (BP, 15 of 154,
  labels/legends readable, nothing clipped); ALL pool FALSE and pool TRUE (ontology prefixes readable,
  captions in figure_spec state per-family denominators / pooled family); simplify CC and simplify ALL
  (full table plotted, prefixes readable). Captions state BH threshold and counts.

## Known failing anchors

None. PACK C has no printed values (book not a release document); the anchors are replay anchors
(direct enrichGO / simplify / setReadable in the same session).

## Owner items

- Full-table P/q calculation cutoffs 1/1 vs PACK D-O5 function defaults 0.05/0.2: unchanged
  (transparent full table, separate BH flag); flag only, not decided here.
- GO asset hash / licence in `env/refdata_registry.json` (M1-3): unchanged; other collections keep
  `OS_REFDATA_MISSING`, no KEGG content.
- The package's simplify loop can drop a representative in a later group (representative_retained =
  FALSE in 63 of 210 CC rows). The table reports this as is; no alternative rule was chosen.

## Shared needs

None required. Notes for the coordinator: (1) `enrich_io.R` `os_enrich_registry_go()` records only
package versions; if the suite wants GO release dates in `refdata`, the helper could add the GO.db /
org.Hs.eg.db metadata dates (the module records them in `software`). (2) The shared ORA/compare dot
plot captions cannot state testing families; the modules append a sentence via `os_with_meta`.

## Notes for the final verifier

- `representative_retained` and `n_removal_events` explain the greedy semantics of simplify; the
  relation is verified against the package output, not an independent clustering.
- `co_capture_similarity()` uses base `trace()` on the imported `mgoSim` and always `untrace`s; if the
  capture fails the engine recomputes with the same `GOSemSim::mgoSim` call and records that in JSON.
- simplify on a full BP table (~2600 terms) takes ~15 min in the container; the smoke uses CC and an
  ALL run with `--min-size 200` to exercise both code paths.
