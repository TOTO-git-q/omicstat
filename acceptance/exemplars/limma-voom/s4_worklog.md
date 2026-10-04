# limma-voom S4 worklog

## Verified state
- 2026-09-29 start: branch s4/limma-voom-dupcor @53006d8 (integrate/m1m2). Read brief, S3 reviews (F1-F3), S3 report sec 2-5, S4_ANCHOR_TRACE, PACK.
- RNAseq123 source: git.bioconductor.org/packages/RNAseq123 RELEASE_3_23 @09a5145cc779e0e9772311c8420378df63241031 (v1.36.0);
  evidence in _s4/rnaseq123/ (Rmd byte copy + rendered release text, MANIFEST.tsv with URLs/sha256).
  Release rendering: limma 3.68.4, edgeR 4.10.1, voom span 0.401 (adaptive).
- Probe GT103 ~/omic-build-logs/s4/limma-voom-probe1.log: the workflow's own code reproduces EVERY printed value in the
  locked container (dim 27179x9, 5153 all-zero, 16624 after filterByExpr(group), TMM factors, span 0.401, voom E/weights,
  decideTests efit and treat, de.common 2782, both topTreat heads).
- Interface differences engine vs workflow: D1 filterByExpr(design) keeps 17062 (workflow group-filter 16624, subset);
  D2 engine tests coefficient groupBasal of ~lane+group exactly; workflow contrasts.fit SEs are approximate with voom weights
  (max |dP| 0.106 on the same genes). Engine legacy == workflow chain with D1+D2 (smoke check).
- Yoruba guide code with adaptive.span=FALSE reproduces all printed 18.1.9 values (consensus, decideTests 4 coefs, 49 rows).
- First helper stopped by a rate limit (~04:30); its uncommitted edits were saved as WIP c34d593; integrate/m1m2 merged (6c22204,
  shared fix limma_io res[["expr"]]).
- Resume (second helper, 2026-09-29): the module trees in c34d593 are byte-identical (md5) to what ran on GT103 in
  limma-voom-final2.log (SMOKE PASSED, golden PASS) and limma-dupcor-final.log (SMOKE PASSED); only _shared differs (merge).
  Checked in the container: edgeR 4.10.5 voomLmFit body line 85-87 `if (adaptive.span) span <- chooseLowessSpan(nrow(counts),
  small.n = 50, min.span = 0.3, power = 1/3)` (limma-voom-vlf.log) -> the reported voomLmFit span is the span it used.
- Resume edits: stale comment on res$expr in the core updated (no behaviour change).
- Verified (resume): limma-voom-v1.log SMOKE PASSED on the merged tree, golden PASS (goldens from limma-voom-golden2.log);
  lock regenerated (limma-voom-lock3.log) and --check OK (limma-voom-lockcheck3.log); local module_lock.json hashes match the
  committed files. Every PNG of _smoke/limma-voom-smoke looked at (list in S4_FIXES.md). S4_FIXES.md finalised.

## Next step
- Done for limma-voom (F1-F3 fixed). Only further work: owner decisions (P-1 call set, P-2 fc, adaptive.span) and the shared
  direction_summary lfc column. Any edit to a locked file needs a new lock (s4_run.sh limma-voom lock...) and --check.
