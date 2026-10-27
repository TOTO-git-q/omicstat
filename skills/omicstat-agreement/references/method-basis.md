# Method and source basis

Original repository TOTO-git-q/medstat, immutable commit
12292d020ef4a8575a3a1db880b81786ee3547fa, skills/agreement. All 13 source
files were verified by Git blob, byte count and SHA256. The engine extracts 37
functions and five non-QBA QC helpers; normalized function hashes distinguish
unchanged copies from adaptations. No MedStat code is called at runtime.

## Bland-Altman

One complete independent pair per ID. Difference direction is explicit. Bias is
the mean difference; population LoA are bias +/- 1.96 sample SD. With n pairs,
bias SE = SD/sqrt(n), limit SE = SD*sqrt(1/n + 1.96^2/(2*(n-1))). Each CI uses
the selected two-sided Student-t quantile with n-1 degrees of freedom. Changing
confidence-level does not change the fixed 95% population limits. This reproduces
the pinned source formulas; the older printed 1986 +/- 2 SD limits are deliberately
not compared with 1.96 SD as though they were the same formula.

The bias and limits require approximately normal, independent differences.
Absolute-difference versus pair-mean Spearman rho, signed trend, Shapiro-Wilk and
the copied leave-one-out standardized-difference diagnostic are exploratory flags.
The source names the last one externally studentized; its exact implementation
is (d_i - mean(d_-i))/sd(d_-i), retained without silently changing its formula.
No diagnostic selects a new method, transformation or excluded sample.

References: Bland and Altman, Lancet 1986;i:307-310; Bland and Altman,
Statistical Methods in Medical Research 1999;8:135-160. Source's first-readings
PEFR case remains external/local-only; no patient rows are included.

## Cohen / Fleiss

vcd::Kappa computes the two-rater point and large-sample SE; normal-theory CI is
estimate +/- normal quantile * ASE. Ordinal equal-spacing linear weighting is
primary, quadratic Fleiss-Cohen weighting is a sensitivity companion. Unweighted
kappa is retained. The copied p-value uses the non-null ASE and is not relabelled
as a null-variance test. Bootstrap resamples subject rows, not rating cells.

Two-category sensitivity outputs require epiR::epi.kappa(method="fleiss",
alternative="two.sided"). The original availability fallback is removed; actual
epiR errors are preserved as typed failures. No formula-only result is attributed
to an unavailable package. Fleiss uses irr::kappam.fleiss, exact=false and the
original subject-percentile-bootstrap CI. Printed independent Fleiss/bootstrap
validation remains a gap, not a self-comparison advertised as independence.

The SAS SkinCondition example and Fleiss-Cohen-Everitt large-sample oracle are
preserved as external expected checks. Fleiss, Cohen and Everitt,
Psychological Bulletin 1969;72:323-327; SAS PROC FREQ Agreement Study.

## ICC

irr::icc is the only permitted production engine. Original automatic psych::ICC
fallback was removed because substituting the estimator on dependency failure
must not be implicit. This is a scientific/runtime adaptation that requires
review; native equivalence has not been demonstrated. Model, agreement versus
consistency, single versus average unit, random versus fixed raters and common
raters are explicit. No observed-data rule picks the highest ICC.

One-way forms require random raters and different sets across subjects; two-way
random agreement and two-way fixed consistency map to the original ICC2/ICC3
designs. Fixed absolute agreement has a mandatory fixed-target rationale; its
original numerical form is retained and the full design accompanies the notation.
The native interval is F-based and assumption-dependent. The original source
string says exact F-distribution; that inherited label does not imply a general
distribution-free confidence guarantee. Missing/constant/incomplete data fail.

Shrout and Fleiss, Psychological Bulletin 1979;86:420-428; McGraw and Wong,
Psychological Methods 1996;1:30-46. Independent ANOVA and F-quantile oracles are
test-only and do not replace irr in the production calculation.

## Argument documentation versus installed evidence

Argument names were checked against current primary CRAN manuals:
[vcd](https://cran.r-project.org/web/packages/vcd/vcd.pdf),
[irr](https://cran.r-project.org/web/packages/irr/irr.pdf),
[epiR](https://cran.r-project.org/web/packages/epiR/epiR.pdf).
These documentation reads do not bind an installed version, artifact SHA or native
default. calls_registry.json leaves those values unresolved until actual capture
in an independently authorized OmicStat R4.6.1 environment.
