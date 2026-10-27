# LONG-balanced-cells

- Data: seeded balanced cohort, 80 subjects, two groups, three observations per subject, complete outcomes and a subject intercept shared across groups.
- Engine: `run_longitudinal.R --design cohort --engine lmer --random-effects intercept`, output `tables/lc_differences_by_timepoint.csv`.
- Expected: at visit 3, the group B minus group A mean difference from direct sums and counts in base R; balanced saturated group-by-visit fixed effects preserve cell means. Tolerance 1e-5.
- Source: Laird NM, Ware JH. Random-effects models for longitudinal data. *Biometrics* 1982;38:963-974, balanced repeated-measures mean structure; standard cell-means normal equations.
- Why independent: direct group means, no `lmer`, `emmeans`, or engine helper.
