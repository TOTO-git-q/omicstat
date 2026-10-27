# Repeated biological-unit input and model scope

UTF-8 CSV; explicitly name response, positive untransformed dose and subject
columns. Names must differ. Subject identities stay text (01 differs from 1),
nonempty and unpadded. Finite complete data only. A duplicate subject/dose is
refused: curate technical measurements upstream with a documented policy.
Candidate scope requires >=5 biological subjects, >=5 distinct doses per subject,
and >=6 doses overall. These are conservative development restrictions, not a
universal power or adequacy rule. Unequal subject dose grids are supported.

`nlme::nlme(response ~ stats::SSlogis(log(dose), Asym, logED50, scal))` uses the
self-starter on log dose, fixes the lower asymptote to zero and fits three fixed
parameters. Prespecify increasing/decreasing direction and a positive upper
asymptote; `scal` controls direction. One scalar normal random effect is supported:
`logED50` (subject sensitivity), or `Asym` (amplitude). No crossed/group comparison,
random covariance matrix, AR1, heteroscedastic weighting or zero doses. Prespecify
ML/REML and conditionally independent residuals. This is not the independent-unit
drc workflow. Random effects account for biological clustering, not for any
unmodelled time/carryover trend in sequential dose administrations.

Native fixed logED50 t interval (`nlme::intervals(...,which='fixed')`) is
exponentiated. For the supported single symmetric normal location random effect
or additive amplitude effect, marginal half-max occurs at exp(fixed logED50).
The plotted level-0 response curve is the typical/zero-random-effect curve; for
location random effects it is not the marginalized population response curve.
Subject curves use native conditional predictions. Variance components and
conditional residuals are exported. Biological n counts subjects, never rows.

Optimizer errors/warnings, non-positive variance Hessian, nonfinite/singular
fixed covariance, invalid asymptote/direction and random SD / corresponding
fixed scale below `singular-tol` are hard refusals. `singular-tol` and `max-iter`
are explicit candidate engineering choices. ED50 outside the observed range is
refused; interval crossing is blocking QC. Convergence never certifies biological
model adequacy; review plateaus, lower-limit assumption and residuals.

The Orange documented-package anchor is an exact reparameterization
`dose=exp(age/1000)` of the shipped chapter-8 SSlogis example. Orange tree age is
not pharmacological dose; this verifies the engine/reparameterization, not dose
biology. Realistic repeated-dose demo inputs are explicitly simulated 16-donor
curves with varying sensitivity and independent measurement errors.
