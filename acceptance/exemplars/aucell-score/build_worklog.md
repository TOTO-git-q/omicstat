# aucell-score S2 worklog
Worktree /home/<user>/omic-b-bioc; branch build/m3a-bioc; lane build_m3a_bioc.
- [x] Scaffold and read PACK/locked evidence
NEXT STEP: official workflow engine, native options and smoke.
## 待裁决 (S2)
Study choices are explicit; consult reference service; no literature majority defaults.
- [x] Official AUCell engine, CLI/native options, licence-clean container GMT hash gate and reference-service docs.
- VERIFIED: lane A lacks GEO anchor file despite registry claim; first fetched into this lane with docker run --rm and verified SHA256 dd09532c...; no existing anchor redownloaded.
- VERIFIED: container smoke exit 0; printed official seed333 gene sampling 5000x3005 PASS; 120-cell normalized SCE handoff, exact native buildRankings/calcAUC replay, finite four-set AUC, reference refusal and golden PASS. Native package excludes Neuron_Cahoy/Astrocyte_Lein for insufficient overlap; warning retained.
- [x] Both auc_distributions.png and auc_heatmap.png opened: nonblank/readable/unclipped; captions n/aucMaxRank/no threshold; automatic lint no blockers.
- [x] Container R parse/default/package checks, docs 18/18; module lock generated and --check OK (8 files).
- VERIFIED: original official GEO genes contain 91 '_'/'|' identifiers; convert.R correctly refuses Seurat renaming with OS_CONVERT_UNSUPPORTED. Additional conversion replay uses an explicitly named compatible-feature fixture, without altering engine anchor.
NEXT STEP: finish conversion replay/log, report checkpoint.
- VERIFIED: additional container replay on 4909 explicitly compatible features: Seurat -> SCE scoring equals the same SCE scoring exactly. AnnData conversion returns OS_ENV_MISSING because prebuilt anndata 0.12.3 basilisk cache is inaccessible at /home/rstudio/.cache/R/basilisk/... under the locked run user; no install/download workaround attempted. Shared convert.R unchanged.
S2 finished with documented AnnData environment limitation; NEXT STEP: independent S3.
2026-10-01 env_rebuild: baseline new-image smoke PASS; existing golden retained; lock refreshed/check; addon-specific checks pending
2026-10-01 env_rebuild: non-root offline h5ad native table/golden parity PASS in disposable fixed environment; final image exception and validation pending; awaiting independent S3
aucell-score: final 2026.10.1 smoke PASS (non-root/offline; golden unchanged; lock checked; awaiting independent S3); next remaining full R suite
