# Method basis

- limma 3.68.5 User's Guide §17.4 describes Agilent raw-data preprocessing, `gIsWellAboveBG`, four-array filtering, `lmFit`, and `eBayes(trend=TRUE, robust=TRUE)`; this module begins with the normalized log2 matrix.
- limma 3.68.5 `Rd/eBayes.Rd`, `Rd/avereps.Rd`, and PACK S1 appendix P-1/P-2 support the registered calls and probe policy.
- User's Guide 17.4.7 fits `~Treatment` with all four groups and tests one coefficient (`--keep-other-levels`); 17.4.4 attaches symbols/Entrez IDs from an explicit annotation (`--probe-annotation`); 17.4.6 filters controls and probes above background on at least k = 4 arrays. The smoke test replays this example with the guide's own code (`tests/guide_17_4.R`).
