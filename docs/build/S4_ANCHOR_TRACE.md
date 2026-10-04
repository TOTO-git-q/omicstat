# S4 anchor trace: limma User's Guide §18.1 (Yoruba) — limma-dupcor / limma-voom / limma-camera

Question (S3_REPORT_astra §3): why does the locked container give duplicateCorrelation
consensus 0.4454514 (printed 0.446) and camera Y P = 1.79e-262 (printed 2.40e-262)?

## Root cause (reproduced in `omicstat-r:2026.09.1`, limma 3.68.5, edgeR 4.10.5)
1. The User's Guide is a **static PDF**: `L1_bioc3.23/limma/vignettes/usersguide.Rnw` only
   does `\includepdf{pdf/usersguide.pdf}`; the printed output is not re-executed at package
   build. The Yoruba case study was last re-run in limma 3.42.0 (NEWS 3.42.0 "Update Yoruba
   case study ... call voom() and duplicateCorrelation() twice", "rerun the Yoruba and Pasilla
   case studies").
2. limma **3.66.0 (2025-10-28)** changed the default of `voom(adaptive.span)` to `TRUE`
   ("All the voom functions now use chooseLowessSpan() by default"). The guide's `voom(y,
   design)` therefore ran with the old default `span = 0.5` when it was printed; in 3.68.5 the
   same call chooses span 0.400455 for these 86 libraries.
3. With the guide's own code and the guide-era span made explicit
   (`voom(..., adaptive.span = FALSE)`, i.e. span = 0.5), every printed value is reproduced:

| quantity (guide line in usersguide.rendered.txt) | printed | adaptive.span = FALSE | adaptive.span = TRUE (3.68.5 default) |
|---|---|---|---|
| consensus correlation round 1 (:7395) | 0.446 | 0.4455442 | 0.4449716 |
| consensus correlation round 2 (:7401) | 0.446 | 0.4459984 | 0.4454514 |
| decideTests genderMale Down/NotSig/Up (:7408–7411) | 27 / 16869 / 22 | 27 / 16869 / 22 | 27 / 16869 / 22 |
| TTTY15 logFC / t / P (:7414) | 6.529 / 52.97 / 3.63e-68 | 6.528862 / 52.97238 / 3.627088e-68 | 6.527254 / 53.84239 / 8.614802e-69 |
| RPS4Y1 logFC / t / P | 9.691 / 44.08 / 1.91e-61 | 9.690881 / 44.07693 / 1.911639e-61 | 9.679521 / 44.29837 / 1.197324e-61 |
| EIF1AY logFC / t / P | 7.962 / 42.44 / 4.52e-60 | 7.961722 / 42.43732 / 4.524801e-60 | 7.955656 / 43.14332 / 1.089759e-60 |
| camera(v, index, design, 2) Y P / FDR (:7499) | 2.40e-262 / 4.80e-262 | 2.402131e-262 / 4.804263e-262 | 1.791224e-262 / 3.582449e-262 |
| camera X P / FDR (:7500) | 5.58e-26 / 5.58e-26 | 5.576931e-26 / 5.576931e-26 | 6.020183e-26 / 6.020183e-26 |

Probe: `acceptance/exemplars/limma-dupcor/_s4/yoruba_span_probe.R` (run from the suite root);
log `acceptance/exemplars/limma-dupcor/_s4/yoruba_span_probe.log` (GT103
`~/omic-build-logs/s4/coord-yoruba.log`). Input: sha256-locked `acceptance/data/limma_Yoruba.RData`
(filter `rowSums(counts) > 50` and annotation present -> 16918 x 86 as printed, TMM).

## Consequence for the anchors (strict rules kept)
- The printed values are asserted **strictly** by the guide's own code with the guide-era
  default written out (`adaptive.span = FALSE`), cited to limma NEWS 3.66.0. This is a
  version-matched printed anchor, not a loosened tolerance.
- The frozen suite route keeps `adaptive.span = TRUE` (S1; locked 3.68.5 default) and is
  checked separately by a locked replay (0.4454514 etc.), exactly like the edger-qlf
  guide-path vs suite-path split.
- Owner item: acknowledge that the §18.1 printed anchors are asserted under the guide-era
  voom span (documented version difference), not under the suite's adaptive span.
