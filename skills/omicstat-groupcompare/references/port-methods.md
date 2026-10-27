# P0-13 B1: copied group-comparison distribution tools

Candidate source adaptation only. Real native numerical equivalence and owner acceptance are pending.

## Scope and source
ported_from: TOTO-git-q/medstat@12292d020ef4a8575a3a1db880b81786ee3547fa:skills/descriptive-distribution/, skills/baseline-table/, skills/_shared/scripts/var_typing.R.
The twenty exact source blobs, function hashes, code-mapping patch and copied test identities are recorded under the module references. Source code was read only; no MedStat runtime or environment was used.

## Explicit modes
The default hypothesis-tests numerical body is preserved. Its caller-specified tests, comparisons, exact/asymptotic rank policy, P-value family and t confidence level remain authoritative.
Optional distribution-diagnostics=source-advisory reports the copied classifier and recommendation next to the actual test; it cannot select or rerun a test. The source heuristic uses n < 20 conservatively, then absolute g1 <= 1; Shapiro and Q-Q correlation are reference statistics. Advice on pooled values is not a residual diagnostic. A nonconstant numeric endpoint is explicitly continuous, including two-valued measurements; this differs from source auto-binary classification and is separately tested.

analysis-mode=distribution-effects is an exclusive independent descriptive branch. It requires fixed reference/group order/grid/minimum-cell size/outcome unit/inference/dataset. Select pairwise-test=none,omnibus=none,rank-method=not-applicable,adjust=none,family-size=1,ci-level=.95,display=interval. The legacy required family-size 1 is only a compatibility placeholder; output records zero hypothesis tests. Neither weights, repeated units, covariates nor standardized target populations are exposed here.

## Scientific details and small samples
Mean/SMD/quantile effects follow other group minus fixed reference; the old t-test branch remains group1 minus group2. SMD uses the square root of the average two unbiased within-group variances. Quantiles invert the ECDF with ties retained; the grid is fixed before outcomes are examined.
The copied minimum 10, group/effective-n/tail/increment guards suppress estimates and associated effective n. Declared empty groups remain inestimable. Source zero-scale SMD and degenerate-bootstrap guards remain. In this branch every serialized table/object/metadata is aggregate-only: no individual IDs, raw values, extrema or bootstrap draws. Labels must also be nonidentifying.
Optional bootstrap is iid within fixed groups; explicit 200..100000 attempts, a finite fraction >= .95, only 95% pointwise percentile intervals. No hidden cap, simultaneous band or multiplicity adjustment. A percentile interval can exclude the original estimate; display preserves the values. With inference=none, source bootstrap defaults remain recorded but explicitly inactive.
Existing biological-unit/technical-identity guards still apply. Logical/censored/nonfinite source inputs refuse. OmicStat additionally refuses missing outcomes instead of applying the original complete-case exclusion. Technical repeats only contribute a within-unit mean and never increase biological n.

## Multiplicity record
Source baseline_table.R uses add_q after raw p.value; baseline_qc.R BT09 warns on unadjusted multi-group tests rather than choosing an adjustment. OmicStat retains its stricter explicit family including requested omnibus and pairwise tests, original raw p_value and p_adjusted columns and declared family_size. No inference family is claimed by descriptive distribution effects.

## Figures and evidence
Shared os_distribution_effects consumes the exported effect table; it performs no estimation or bootstrap. Dataset labels, direction, source identity, unit, nonestimable states and pointwise coverage are explicit. At most 14 terms per page. Whole-suppressed pages produce status rows instead of fake plots. Existing os_group_points stays unchanged for prior analyses.
Existing official datasets::sleep receipt and six printed paired-t anchors remain the real owner example for the old path. New source fixtures are invented contracts only. A genuine independent source dataset with version/SHA/registration and its native contact sheet is still needed for owner review of the new branch.

## Validation boundaries
The original 27 distribution checks are copied with OS-code changes; ten source/adapter anchor definitions extend the six original sleep anchors. There are 31 new CLI refusal definitions and native entry/replay/row-permutation/aggregate-privacy/figure tests are supplied. The unmodified prespecified function is retained for same-input comparison. R4.6.1 native tests must produce actual before-after numerical tables; no such values were obtained here.
No Rscript or Docker is present in the cloud workspace. Added stats call arguments have unverified native defaults; historical stats 4.5.0 observations are not relabelled4.6.1. Exact installed-formal capture is still required. No dependencies were installed or locks changed.
P0-12/13/14 remaining scope is preserved in source_requirements.json and GAPS.md. No seal, merge, promotion or deployment is performed.

## Binding revisions and current proof
See VALIDATION.md (module-local references/validation.md), TEST_RESULTS.json and TEST_SUMMARY.json for actual final results and preserved nonpasses. Earlier source manifests/revisions are immutable. Parameter-guidance 7, restyle 4 and resource 2 bind current source only; old scientific evidence is not requalified.
The official sleep registration changes only its anchors-file digest, with prior bytes retained and original six anchor objects unchanged. Synthetic new anchors are not registered owner data. The original 27 checks are retained by exact block hashes; only OS-code mapping and naming seed 19 for lint differ.
