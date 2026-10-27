# Parameters

Every scientific choice is explicit; no implicit data-derived method selection.

<!-- registry:begin -->
| Flag | Default | Source |
|---|---|---|
| --input | "required" | required scientific declaration |
| --response-col | "required" | required scientific declaration |
| --group-col | "required" | required scientific declaration |
| --unit-col | "required" | required scientific declaration |
| --group-order | "required" | required scientific declaration |
| --design | "required" | required scientific declaration |
| --technical-policy | "required" | required scientific declaration |
| --technical-col | null | execution control; no scientific inference |
| --comparisons | null | execution control; no scientific inference |
| --pairwise-test | "required" | required scientific declaration |
| --omnibus | "required" | required scientific declaration |
| --rank-method | "required" | required scientific declaration |
| --adjust | "required" | required scientific declaration |
| --family-size | "required" | required scientific declaration |
| --ci-level | "required" | required scientific declaration |
| --display | "required" | required scientific declaration |
| --journal | "required" | required scientific declaration |
| --study-contract | "none" | required scientific declaration |
| --development-mode | false | execution control; no scientific inference |
| --seed | "required" | required scientific declaration |
| --outdir | "required" | required scientific declaration |
| --spec | null | execution control; no scientific inference |
| --analysis-mode | "hypothesis-tests" | Reviewed P0-13 independent source adapter; no native formals or numerical equivalence claim |
| --distribution-diagnostics | "off" | Reviewed P0-13 independent source adapter; no native formals or numerical equivalence claim |
| --reference-group | null | Reviewed P0-13 independent source adapter; no native formals or numerical equivalence claim |
| --quantile-grid | null | Reviewed P0-13 independent source adapter; no native formals or numerical equivalence claim |
| --min-cell-n | null | Reviewed P0-13 independent source adapter; no native formals or numerical equivalence claim |
| --outcome-unit | null | Reviewed P0-13 independent source adapter; no native formals or numerical equivalence claim |
| --inference | null | Reviewed P0-13 independent source adapter; no native formals or numerical equivalence claim |
| --bootstrap-replicates | null | Reviewed P0-13 independent source adapter; no native formals or numerical equivalence claim |
| --min-success-fraction | null | Reviewed P0-13 independent source adapter; no native formals or numerical equivalence claim |
| --dataset-name | null | Reviewed P0-13 independent source adapter; no native formals or numerical equivalence claim |
<!-- registry:end -->

- --unit-col: Biological identity required; technical wells are never independent units.
- --technical-policy: reject or equal within-unit mean; never average across units.
- --design: Independent or complete paired design.
- --comparisons: CSV contrast,group1,group2; all rows planned before inference.
- --family-size: Includes every requested omnibus and pairwise test; larger planned family allowed.
- --ci-level: Two-sided marginal t intervals, never adjusted merely because p-values are.
- --rank-method: exact rejects tied ranks/zero paired differences; asymptotic uses continuity correction.
- --display: Box or arithmetic mean; no inferred error bars.
- --study-contract: JSON content schema/semantics/SHA validated by the engine.
- --spec: Replay immutable resolved arguments into another output directory.
