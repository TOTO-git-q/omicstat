# Scientific basis

Livak and Schmittgen2001, Methods25:402-408, DOI10.1006/meth.2001.1262.
Original Table1 raw Ct and rounded descriptive results are independently transcribed in tests.
University-hosted paper: https://mc.uchc.edu/mc/introduction/livak-2001.pdf
Verified original-paper text: https://studylib.net/doc/18183813/analysis-of-relative-gene-expression-data-using-real
Eleven printed anchors use one last printed decimal place as absolute tolerance (exact identity fold=1).
Tolerances and assay declarations remain candidate scientific-review items.

Table1 final kidney GAPDH Ct is22.76. The pcr vignette copy's24.18 is inconsistent and is not our source.
Original Table2 brain printed mean6.93 disagrees with its raw Ct values; no forced reproduction of that number.
PDF pixels were unavailable; the original-paper text was inspected. These limitations are explicit provenance.

Technical uncertainty is SD, not SEM or biological CI. Same-well and separate-well technical variance differ.
Biological inference tests unit-level delta-Ct, not individual wells or transformed fold values. Welch/paired
R stats t.test definitions: https://stat.ethz.ch/R-manual/R-devel/library/stats/html/t.test.html
P-adjust family: https://stat.ethz.ch/R-manual/R-devel/library/stats/html/p.adjust.html
No default test or alpha is scientifically selected by this agent; required CLI choices record prespecification.
