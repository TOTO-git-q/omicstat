---
name: omicstat-groupcompare
description: >
  Compare prespecified biological-unit continuous endpoints using declared independent or paired tests,
  with technical-repeat aggregation, multiplicity, mean-difference intervals and biological-unit figures.
  Candidate development only. Triggers: group comparison, paired t, Welch, ANOVA, Wilcoxon, Friedman.
---
# omicstat-groupcompare

## When to use / when not
Use for one continuous endpoint and a prespecified group design. Use lme4-lmm for covariate-adjusted,
clustered, partially repeated or incomplete longitudinal designs; use omicstat-ddct for Ct normalization.
No automatic normality-test-driven method selection, no categorical outcomes or survival analysis.
P0-13 B1 adds an explicit independent distribution-effects mode and optional source-advisory diagnostics
within this existing module. The existing prespecified estimator/test body is unchanged.

## Input requirements
Long CSV with --response-col, --group-col and mandatory --unit-col. Values must be finite.
--design is independent (disjoint unit IDs) or paired (identical complete subject sets).
--technical-policy reject enforces one row per unit/group; mean requires --technical-col with unique
within-unit/group technical identities and averages before inference. Units are equally weighted.
A valid --study-contract JSON declares the scientific choices; its bytes are independently validated.

## Run
The complete runnable fixture command is in tests/acceptance.json; prepare fixtures with
python3 skills/omicstat-groupcompare/tests/prepare_acceptance.py /tmp/groupcompare-fixtures.
Run the module entry with the explicit flags in that file, including --development-mode.
All unconditional scientific choices and applicable branch choices must be explicit; see references/parameters.md.
Default --analysis-mode hypothesis-tests preserves the existing path. Optional --distribution-diagnostics
source-advisory records the copied classifier and proposed test beside the actual prespecified test;
it never runs or selects the proposed call.
For --analysis-mode distribution-effects, declare --reference-group, --quantile-grid, --min-cell-n,
--outcome-unit, --inference and --dataset-name. Use independent design, pairwise-test/omnibus none,
rank-method not-applicable, adjust none, family-size 1, ci-level .95, display interval and diagnostics off.
The required legacy family-size 1 is an interface placeholder; the result has zero hypothesis tests.
Bootstrap requires explicit --bootstrap-replicates 200..100000 and --min-success-fraction .95..1.
No weights, repeated-unit bootstrap, covariates or data-driven grid selection are supported. Candidate is excluded from
accepted MCP routing. --spec replays the resolved arguments into a fresh --outdir.

## What gets produced
- tables/tests.csv: explicitly requested pairwise and omnibus tests, raw and adjusted p-values.
- tables/effect_table.csv for t tests: group1 minus group2 mean differences and marginal CIs.
- tables/summary.csv and biological_units.csv: biological counts, descriptive values and technical counts.
- figures/group_comparison PNG/PDF/spec: all biological points, box or mean, named adjusted-p brackets.
- Candidate typed handoff, QC, draft/methods.txt, engine warnings and full input/spec provenance.
- Distribution-effects instead emits aggregate distribution_metrics, effect_table and distribution_guardrails,
  with mean/SMD/fixed-grid quantile contrasts. No biological-unit table, individual IDs, raw values or draws
  are exported in this branch. Suppressed values remain unavailable; associated effective n is withheld.
- Shared effect-interval figures state dataset, reference direction, unit, minimum-cell rule and CI coverage.
  At most 14 terms per page; wholly withheld pages have a status table and no invented plot.

## Reading the results
Pair direction follows the comparisons CSV, never factor coding. Friedman is repeated complete-block;
ANOVA/Welch ANOVA and Kruskal are independent-group tests. Rank statistics are not mean differences
and receive no fabricated effect CI. The p-adjust family includes the omnibus test if requested.
Confidence intervals are explicitly marginal, not simultaneous, even when p-values are adjusted.
A larger --family-size reserves additional planned tests using stats::p.adjust's documented n semantics.
New distribution effects use the source's other-group-minus-fixed-reference direction, unlike the prior
pairwise group1-minus-group2 sign. SMD divides by the square root of the average two unbiased within-group
variances. Quantiles invert the ECDF with ties, at a fixed grid; this is not type-7 sample quantile estimation.
Source minimum cell size 10 and quantile-tail/increment guards are retained. Optional iid within-group
bootstrap returns only pointwise 95% type-7 percentile endpoints; no simultaneous coverage or adjusted CI.
An interval may exclude the original estimate and is never widened to cover it. Descriptive-only mode
has no sampling CI. Missing input values refuse rather than applying the source's complete-case exclusion.

## When a QC rule fires
GPC-01 always blocks candidate publication. GPC-02 records technical means. GPC-03 marks multiple
unadjusted tests exploratory. Input violations stop before statistics, never drop rows or complete pairs.
GPC-04 labels source heuristic advice; GPC-05 labels pointwise distribution effects without a P-value family.
Mapped source OS_GPC findings preserve small-cell and bootstrap guard failures, including fully withheld
results. Do not infer suppressed values from other diagnostics or relabel synthetic tests as real evidence.

## Known limitations
No incomplete repeated measures, covariates, multiple endpoints or data-driven contrasts. Paired figures
show group distributions; pairing is enforced by IDs in computation, not inferred from jitter placement.
Exact Wilcoxon refuses ties and zero differences; asymptotic continuity correction is explicit.
StudyContract validation confirms declared content, not the truth of biological labels. Scientific owner
review, locked-image exec and visual review remain pending; no accepted status or seal is created.
The copied n<20/absolute-skewness heuristic is advice, not validation of test assumptions; Shapiro and Q-Q
correlation are reference only. Pooled-value advice is explicitly not a residual diagnostic. A declared
nonconstant numeric endpoint stays continuous even if it has only two observed values, an explicit source adaptation.
Rscript and Docker are absent in this cloud workspace. Native R4.6.1 before/after values, new CLI/figure checks
and installed formals have not been obtained. Existing six printed sleep anchors and its real receipt cover
the prior paired example only; a registered genuine independent source and native owner sheet for the new
branch are still pending. Synthetic source fixtures are contract tests only, never owner-review evidence.

## Reference files
references/method-basis.md, parameters.md, qc-rules.md, reporting-templates.md and troubleshooting.md.
Source commit, 20 blob identities, 24 copied functions, 27 copied source checks, adaptation patches and
error mapping are in PORT_SOURCE.json, COPIED_FUNCTIONS.json, COPIED_TESTS.json, PORT_ADAPTATIONS.json,
ERROR_MAPPING.json and port-methods.md. Source repository/environment remain independent and read-only.
