# Method basis and review boundary

Primary port source is the complete pinned MedStat diagnostic-accuracy engine,
QC, entry, original verified case and documentation listed in PORT_SOURCE.json.
The numerical estimators are copied and independently wrapped, not reimplemented
as a new Python/R alternative. Native numerical equivalence has not been demonstrated.

The original core supplies Clopper-Pearson via stats::binom.test, optional Wilson,
Se/Sp/PPV/NPV/accuracy, Simel log-normal LR intervals, log-odds DOR intervals, a 0.5
zero-cell companion and Bayes PPV/NPV projections. Native pROC supplies fixed-direction
ROC, DeLong AUC CI, paired DeLong differences, independent uncorrected pAUC bootstrap,
cutoff selection, cutoff-selection bootstrap and empirical curve coordinates.
The original LOO and out-of-bag algorithms retain their independent-unit assumptions.

P0-13 A row 3 expressly requires explicit correction for multi-marker comparisons.
OmicStat therefore requires a selected p.adjust method and preserves the original
primary-versus-rest family. No method is recommended or silently selected. Raw P,
adjusted P, family size and unadjusted pointwise difference CI are separate columns.
The original bootstrap internal-validation min(boot_n,200) cap stays unchanged.

## Original independent numerical example

The pinned tests/verified/REFERENCE.md specifies a deterministic synthetic 40-row
case with TP=18, FN=2, FP=4, TN=16 at 0.5. Its four original checks are retained:
sensitivity, specificity, PPV and pair-count AUC. The source is explicitly synthetic;
it is never promoted to official owner data. Additional placement-covariance,
Holm, Wilson and LR arithmetic checks are independent validation definitions,
not freshly obtained native outputs.

## Official API cross-check (documentation only)

The [official pROC manual](https://cran.r-project.org/web/packages/pROC/refman/pROC.html)
confirms that paired DeLong inference must not compare opposite directions;
ci.coords stops on multiple best thresholds by default; ci.se uses pointwise
bootstrap quantiles and distinguishes their median from the empirical curve.
The [package site](https://xrobin.github.io/pROC/) identifies the authors' reference
and source documentation. These online pages do not establish an installed
OmicStat version, dependency pin, observed default or completed numerical test.

## Important unresolved semantics

- The original LOO binomial intervals ignore dependence between folds; retained
  only with an explicit descriptive limitation. No replacement CV estimator is
  introduced without separate scientific review.
- A best cutoff can tie or be an infinite no-call boundary. Native tie errors and
  nonfinite selected-cutoff refusals remain; no silent choice of another threshold.
- The source negative-J review range does not define J's mathematical range.
  Negative observed values remain visible; the message now explains this.
- Original full/partial point-versus-CI checks remain visible. Partial bootstrap
  intervals are not forced to enclose their point estimate, clipped or replaced.
- Counts and flow are analytical units, never ROC grid rows or bootstrap draws.
  Missingness exclusions are disjoint, and confusion-count identities are explicitly
  not applicable when no cutoff exists.
