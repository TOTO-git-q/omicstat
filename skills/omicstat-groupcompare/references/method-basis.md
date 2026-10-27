# Method basis and source scope

Suite-owned design validation and technical averaging; statistical tests use R stats.
All method choices, design, multiplicity family, CI and display choices are explicit required inputs.
No agent-selected scientific default is treated as owner-approved. Technical means do not create more n.

- R stats t.test: https://stat.ethz.ch/R-manual/R-devel/library/stats/html/t.test.html
- R stats one-way tests: https://stat.ethz.ch/R-manual/R-devel/library/stats/html/oneway.test.html
- R p.adjust family-size semantics: https://stat.ethz.ch/R-manual/R-devel/library/stats/html/p.adjust.html
- Wilcoxon: https://stat.ethz.ch/R-manual/R-devel/library/stats/html/wilcox.test.html
- Friedman: https://stat.ethz.ch/R-manual/R-devel/library/stats/html/friedman.test.html
- Six independent printed anchors: https://stat.ethz.ch/CRAN/web/packages/TOSTER/vignettes/IntroTOSTt.html#paired-samples-analysis
  Paired-sleep t-test row and raw-effect row; 90% CI. These validate NHST only, not equivalence/TOST.
  Three-decimal printed values use half-last-place absolute tolerance; integer df exact.
  Values are transcribed from the published package vignette, never this implementation's output.
  Accessed 2026-10-15. The base datasets::sleep observations are paired by ID, not input row order.

API inventory in calls_registry.json is actually captured in cloud R 4.5.0. Production R 4.6.1
signature drift remains an exec gate, not silently accepted. No package lock is changed.

## P0-13 copied distribution and advisory scope
Read port-methods.md and PORT_ADAPTATIONS.json for the exact pinned source and every adaptation.
The new independent distribution branch preserves source inverse-ECDF quantiles, average-variance SMD,
minimum-10 disclosure and finite/degenerate bootstrap guards. Optional intervals are pointwise 95% only.
Baseline classification is advice only; it cannot replace the prespecified test or choose adjustment.
Missing outcomes refuse in OmicStat; source complete-case deletion is not adopted. Native equivalence,
installed R4.6.1 formals and new real owner examples remain pending. Original sleep evidence is unchanged.
