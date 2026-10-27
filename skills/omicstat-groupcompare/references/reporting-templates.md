# Reporting
Report biological n per group (paired: number of subjects), technical-repeat policy, exact test,
two-sided alternative, prespecified contrast direction, family size, p adjustment and marginal CI level.
Report rank statistics as rank statistics, not effect estimates. A p-value does not establish equivalence.
Automatic methods.txt is a candidate draft. Numerical tables are the source for effect and interval values.

## Distribution-effects report
Name the dataset, measurement unit, fixed reference and direction (other group minus reference), fixed
quantile grid, independent biological-unit rule and technical-repeat policy. State the disclosure minimum
and every withheld estimate/interval. Describe the average-within-group-unbiased-variance SMD denominator.
Record inference=none or the explicit attempted bootstrap count, finite fraction threshold and seed;
95% percentile intervals are pointwise, may exclude the original estimate and have no multiplicity adjustment.
There are no hypothesis tests in this branch; do not interpret family-size=1 as a tested family.
Do not release row IDs, raw observations, extrema, raw resamples or suppressed effective n in this output.
Advisory diagnostics must say heuristic/reference only and show the actual chosen test without rerouting it.
