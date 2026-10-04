# clusterprofiler-gsea — S4 fixes (1.0.0 -> 1.1.0)

Repaired by the S4 coordinator on `integrate/m1m2` against `S3_REVIEW_astra.md`
(pin `build/m2@bbbf937`) and contract (a). Runs in `omicstat-r:2026.09.1`, GT103
`~/omic-build-logs/s4/coord/` (logs `coord-cpg*.log`; goldens `coord-cpg3-golden.log`, final rerun + lock `coord-cpg3.log`).

## F1 — ranking metric consumed, never named after the producer (PACK T/W, S1 P-1)
- Change: `scripts/clusterprofiler_gsea_core.R` `cg_input()` rewritten. With `--from-run` the
  metric, statistic kind, LFC type, contrast and direction come from the upstream ranked_list
  metadata (`os_ranked_list_meta`, `_shared/scripts/ranked_list.R`); an upstream without that
  metadata is refused (`OS_HANDOFF_MISMATCH`). The old feature_table `stat` fallback and the
  producer-name metric mapping are gone. A plain `--ranked` CSV needs `--ranking-metric`,
  `--direction` and the new `--statistic-kind` (test_statistic / effect_size); an effect-size
  ranking needs `--lfc-type` (S1 cross-module rule 2). A sidecar `.meta.json` must agree with the
  flags. `run_clusterprofiler_gsea.R` passes `expect = list(ranked_list = "ranked_list")`; the
  hand-off state, results JSON and provenance record metric, kind, LFC type, contrast and source;
  the written ranked_list now has the frozen `feature_id,symbol,score` columns.
- Methods (`references/reporting-templates.md`): clusterProfiler/enrichit versions from the run
  (were hard-coded), `{ranking_detail}` (kind, LFC type, contrast, source).
- Evidence (smoke): DOSE anchor declared as an effect size with its LFC type (Methods checked);
  no-metadata upstream refused; missing `--lfc-type` refused; REAL chains deseq2-wald -> gsea and
  limma-voom -> gsea (synthetic counts on DOSE geneList IDs): metric "DESeq2 Wald statistic" /
  "limma moderated t-statistic", direction "higher expression in trt than in ctrl", contrast
  `condition: trt vs ctrl` asserted in JSON and Methods.

## F2 — directionality from the statistic, not from observed signs (S1 P-1)
- Change: the "needs positive and negative scores" refusal is removed; undirectional input is
  refused from metadata (`OS_RANKING_UNDIRECTIONAL`) or from the declared metric name (LRT/F).
  An all-same-sign ranking is analysed and the Methods say only one end is populated.
- Evidence: all-positive single-contrast ranking accepted + Methods sentence; LRT metadata refused;
  "LRT F-stat" metric name refused (existing check).

## F3 — PACK F ridge and sign-split dot plot
- Change: shared builders (coordinator) `os_cp_gsea_dotplot_signed()` and `os_cp_gsea_ridge()`
  in `_shared/scripts/fig_mod_enrich.R`; the module writes `figures/gsea_dotplot_signed` (up to
  10 sets per sign, positive block on top, negative block below, zero line) and
  `figures/gsea_ridge` (ranking-metric distribution of the core-enrichment genes of the
  significant sets with the largest |NES| per sign; os_ridge density, pooled bandwidth). Captions
  state threshold, per-sign counts, the ranking ends and the metric. Figure legends are appended
  to the draft.
- Evidence: the DOSE fixture has both signs (442 positive / 273 negative significant sets);
  smoke asserts per-sign counts, captions, figure types, byte-identical replay of both PNGs;
  goldens include both figure specs. Figures looked at (dot plot, ridge, curve).

## Version, goldens, lock
- 1.1.0; goldens regenerated in the container; normal rerun PASS incl. golden; lock regenerated.

## Owner items
- enrichit / pkg_lock infrastructure (M2-2) unchanged; Hallmark/KEGG remain refused.

## Notes for the verifier
- The golden's DOSE run is an effect-size ranking by declaration; the Wald/limma chains are
  the real-producer tests of the contract.
