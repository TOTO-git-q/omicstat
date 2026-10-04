# clusterprofiler-compare -- S4 fixes (1.0.0 -> 1.1.0)

Branch `s4/cp-ora-compare` (from integrate/m1m2 @fb63e52). GT103 run dir
`~/omic-build-logs/s4/cp-ora-compare/` (smoke tmp `_smoke/compare/`). Container `omicstat-r:2026.09.1`.

## F1 -- GO ALL with pool FALSE (contract d)

- Locked source (`cp-ora-compare-src.log`): `compareCluster` calls `fun` once per list
  (`llply(geneClusters, fun, ...)`), so BH and q-values are always within a list; enrichGO with
  `ont = "ALL", pool = FALSE` runs once per ontology, so each list x ontology is its own family
  (own effective input/background, BH, q-value). `pool = TRUE`: one family per list. The separate
  background route (one enrichGO per list) has the same families.
- Change (`scripts/clusterprofiler_compare_report.R`): `cx_families()` builds the families from the
  result, requires unique denominators and p.adjust = BH per family (else `OS_INVALID_RESULT`);
  `tables/test_families.csv` (group, family, effective input/background, tested, BH<0.05, scope);
  `test_family` column in the full table; `list_definitions.csv` gives `n_effective_input/background`
  only for one family per list (NA otherwise) plus `effective_input_by_family` /
  `effective_background_by_family` (e.g. `BP=198;CC=201;MF=205`) and `adjustment_scope`; JSON
  `test_families`; Methods state per-list, per-family denominators and the BH scope; ALL figure labels
  carry the ontology and the caption states the families. The first-row shortcut is removed; no union
  background.
- Evidence (`cp-ora-compare-cmp-final.log`; lists X1, X2 of the preset fixture, 12495-ID universe):
  - ALL pool FALSE: X1 BP/CC/MF input 198/201/205, background 11525/11914/11822; X2 746/768/758,
    same backgrounds (= Astra's measurement); every row's denominators equal its family's;
    list_definitions `BP=198;CC=201;MF=205` / `BP=746;CC=768;MF=758`, single counts NA; direct
    compareCluster replay equal; BH within list x ontology recomputed independently.
  - ALL pool TRUE: X1 206/12112, X2 778/12112; one family per list; replay equal; BH within list.

## F2 -- original gcSample example vs suite preset

- Source of the original example: clusterProfiler book `comparecluster-analysis.qmd` lines 31-42 at
  commit 549613197f7953b97bf1346cc81eb0e1c61b6dbc, fetched read-only; sha256
  e4c2ea01381c9370ed7074013917d523e66dcab4084e1cbf79966632101da6ab equals `L2/manifest.tsv`
  (text not copied, no licence). Code: `data(gcSample)`, `compareCluster(geneCluster = gcSample,
  fun = enrichGO, OrgDb = org.Hs.eg.db, ont="BP")`, `setReadable(...)`, `head(ck)`. No universe (enrichGO
  implicit default = all genes annotated in the GO collection), default cutoffs 0.05/0.2. The page
  source prints no values; the rendered online page follows development versions and is not a locked
  release, so there is no printed anchor.
- Change: `tests/fixtures/make_gcsample.R` adds `cx_make_gcsample_original()` (unmodified lists
  216/805/392/838/929/585/582/237; candidate universe = all org.Hs.eg.db ENTREZID keys + the gcSample IDs
  absent from OrgDb, 193809 IDs, i.e. the implicit default made explicit so the module's mandatory
  explicit-universe gate is satisfied without altering any list; labelled tracing only, not a
  selectable population). `tests/run_smoke_test.R` section (3) runs the book code verbatim in the test
  session (reference replay) and the module on the same unmodified lists.
  Evidence: book output 1020 list-term rows (X1..X8: 6/149/71/69/68/99/274/284); the module's full
  table (30860 rows) filtered with the book's reporting rule (`enrichit::get_enriched`: pvalue <= 0.05,
  p.adjust <= 0.05, qvalue <= 0.2) has exactly these rows; pvalue/p.adjust/qvalue equal (relative 1e-14
  after the CSV round trip; in memory the probe `cp-ora-compare-orig.log` found max difference 0) and
  GeneRatio/BgRatio identical; effective background 18842 for every list, inputs
  198/761/351/793/884/544/558/234.
- Section (1) "suite enforced-background preset test" is unchanged in substance and now labelled as an
  adapted fixture (gcSample intersected with DOSE geneList, 12495-ID explicit universe): 29874 rows,
  247 BH<0.05, 11525 effective background per list, golden PASS. It is not presented as the original
  example.

## Other

- Version 1.1.0 (`CX_MODULE_VERSION`); Methods now fill clusterProfiler/enrichit/GO.db (GO release)/
  org.Hs.eg.db versions from the run (JSON and provenance `software`) instead of a fixed "4.20.0".
- Goldens regenerated (`cp-ora-compare-cmp-gold.log`, adds `tables/test_families.csv`), normal rerun
  `cp-ora-compare-cmp-final.log` SMOKE PASSED, lock written (`cp-ora-compare-lock-cmp.log`) and checked
  (`cp-ora-compare-lock-check.log`).
- Figures looked at (`_smoke/compare/*/figures/compare_dotplot.png`, from `cmp-final`):
  - preset anchor: 8 list labels (4 empty columns kept), 20 terms, legends readable, no clipping
    (figure_spec hash unchanged from 1.0.0);
  - ALL pool FALSE / pool TRUE (X1, X2): `[BP]` prefixes readable, legends present; figure_spec caption
    carries the per-family / pooled sentence;
  - original replay (8 unmodified lists, 36 terms): readable except that two adjacent three-line
    wrapped labels ("positive regulation of post-translational protein modification" / "positive
    regulation of protein modification by small protein conjugation or removal") touch/overlap
    vertically. This is the shared `os_enrich_compare` row spacing (see Shared needs); it is a
    test-only tracing run, not the golden figure.

## Known failing anchors

None.

## Owner items

- The original book example has no eligible background; its replay uses enrichGO's implicit default
  made explicit. This validates the engine against the original code, not a scientific population.
  Owner may confirm that this plus the preset test is the accepted PACK C basis.
- Full-table P/q cutoffs 1/1 vs PACK D-C3 0.05/0.2: unchanged, flag only.
- GO asset hash / licence: unchanged; other collections `OS_REFDATA_MISSING`, no KEGG content.

## Shared needs

- `skills/_shared/scripts/fig_enrich.R` `os_enrich_compare()` (called by `os_cp_compare_dotplot`,
  `fig_mod_enrich.R`): with many terms, wrapped labels of three lines overlap the neighbouring label
  (seen in `_smoke/compare/original_replay/figures/compare_dotplot.png`). Request: scale the panel
  height / row spacing with the number of wrapped label lines (or cap wrapping at two lines). Not
  needed for any F item; the module's golden figure is unaffected.
- Optional (same as ORA): shared captions cannot state testing families; the module appends a sentence
  via `os_with_meta`.

## Notes for the final verifier

- The 193809-ID universe file of the original replay contains OrgDb keys without GO annotation and a
  few retired IDs; `ora_gson` intersects it with the GO-annotated genes (18842 for BP), exactly as the
  implicit default does. `n_candidate_background` therefore reads 193809 for that tracing run.
