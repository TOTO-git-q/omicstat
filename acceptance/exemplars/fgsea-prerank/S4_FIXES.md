# fgsea-prerank — S4 fixes (1.0.0 -> 1.1.0)

Repaired by the S4 coordinator on `integrate/m1m2` against `S3_REVIEW_astra.md`
(pin `build/m2-rank@27fca06`) and contract (a). Runs in `omicstat-r:2026.09.1`,
GT103 `~/omic-build-logs/s4/coord/` (logs `coord-fgsea*.log`).

## F1 — printed anchor from the tutorial's own code (PACK C)
- Change: `tests/run_smoke_test.R` block "P" runs the tutorial Quick run verbatim
  (`fgsea-tutorial.rendered.txt:17-56`: `data(examplePathways); data(exampleRanks);
  set.seed(42); fgsea(pathways, stats, minSize = 15, maxSize = 500)`) with fgsea's own
  functions only (no engine, no shared reader) and asserts the printed
  `head(fgseaRes[order(pval), ])`: the six pathways in order; pval and padj at the printed 7
  significant digits; log2err at the printed 7 decimals; ES/NES at 7 significant digits; size;
  the first six leading-edge IDs and the leading-edge lengths 155/141/44/40/67/51. All PASS
  (`coord-fgseag.log`, `coord-fgsea2.log`). The suite-seed replay (fgseaMultilevel with
  the suite call, direct call vs engine) and the golden stay as before, separately.
## F2 — table order (PACK T)
- Change: `scripts/fgsea_prerank_core.R` sorts significant sets (BH padj < alpha) first,
  then by NES descending within each group (ties by pathway, NA last).
- Evidence: smoke "S4-F2 table order" asserts the grouping and NES monotonicity on the
  586-row table; goldens regenerated.
## F3 — direction wording (PACK W, S1 P-1)
- Change: the NES bar caption names the two ends of the NAMED ranking via the shared
  `os_nes_bar(positive_end, negative_end)` (coordinator shared change); the module passes
  "<metric>: <positive end>" and the negative end. No up/down-regulated wording unless the
  metadata says so.
- Evidence: smoke "S4-F3" (user-declared statistic: caption quotes the declared direction, no
  "up-regulated"); chain test R2 (Wald: "DESeq2 Wald statistic: higher expression in trt
  than in ctrl"). Figures looked at: a1 nes_bar, chain nes_bar and gsea_curve.
## Contract (a) — ranked_list consumer
- `--from-run`: metric, contrast and direction are read from the upstream ranked_list
  metadata (`os_ranked_list_meta`); an explicit `--rank-metric` or `--direction` that
  contradicts it -> `OS_CONFLICTING_PARAMETERS`; missing metadata -> `OS_HANDOFF_MISMATCH`;
  undirectional -> `OS_RANKING_UNDIRECTIONAL`. `--direction` is no longer a required flag:
  it is required only for a plain CSV without omicstat metadata (sidecar `.meta.json` is
  honoured). The validated metadata is handed on in state `ranked_list`.
- Evidence: smoke R0–R6 — a REAL deseq2-wald run (synthetic counts on exampleRanks IDs, Cell
  Cycle members shifted x3) chained into fgsea: exit 0; Methods and caption carry the Wald
  metric/direction; Cell Cycle NES > 0, padj < 0.05; conflicting metric refused;
  undirectional metadata refused; user-declared upstream refused on `--from-run`.
## Version, goldens, lock
- 1.1.0; goldens regenerated in the container; normal rerun PASS incl. golden; lock 14 files.
## Owner items
- Hallmark default still waits for M1-3 (`OS_REFDATA_MISSING`, unchanged).
