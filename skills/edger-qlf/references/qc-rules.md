# edger-qlf QC rules

Every rule has a source and is written to `qc/qc_results.csv`. EQ-01..03 block before fitting and withhold the draft. Design confounding is a typed error.

| Rule | Criterion | Source |
|---|---|---|
| EQ-01 | non-integer input counts | edgeR User's Guide 2.1; ENGINEERING_PLAN 4.5 |
| EQ-02 | negative counts | edgeR User's Guide 2.1; ENGINEERING_PLAN 4.5 |
| EQ-03 | fewer than two replicates in a compared group | ENGINEERING_PLAN 4.5; edgeR User's Guide 4.4.1 |
| EQ-04 | fewer than three replicates in a compared group | ENGINEERING_PLAN 4.5 |
| EQ-05 | every adjusted P value missing | ENGINEERING_PLAN 4.5 numeric degeneracy |
| EQ-06 | more than half of genes significant | ENGINEERING_PLAN 4.5 numeric degeneracy |
| EQ-07 | engine warnings | CONVENTIONS sec 15 |
| EQ-08 | annotation mapping loss >5% | CONVENTIONS sec 8 |
| EQ-09 | robust QL prior reminder | PACK S1 P-2; edgeR User's Guide 4.4.7 |
| EQ-10 | legacy QL explicitly selected | PACK S1 P-1; glmQLFit.Rd |
| EQ-11 | glmTreat minimum-effect test selected | PACK S1 P-3; glmTreat.Rd |
