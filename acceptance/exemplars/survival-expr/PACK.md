# P0-13 B3: survival-expr source-copy port

ported_from: TOTO-git-q/medstat@12292d0:skills/survival-nonph/scripts/nonph_core.R
ported_from: TOTO-git-q/medstat@12292d0:skills/competing-risks/scripts/cr_core.R

## A. Scope and independent maintenance
The existing survival-expr candidate gains opt-in nonph and competing-risks modes. There is no
new module, no MedStat runtime/environment/MCP dependency, and no source write to MedStat.
PORT_SOURCE.json identifies full source commit12292d020ef4a8575a3a1db880b81786ee3547fa and10 raw
code/documentation Git blobs. COPIED_FUNCTIONS.json binds17 original/adapted functions, selected
LF source references and each change. The original Cox/KM numeric, render and QC function bodies
remain unchanged under private names. Existing scientific parameter rows/defaults are preserved.

## B. Adaptations that affect interpretation
- OS diagnostic mapping and module-private environments replace MedStat runtime plumbing.
- Survey inference is refused; no unweighted screening substitutes for weighted formal inference.
- Non-PH classification preserves source fixed P0.05 and explicitly declared engineering magnitude;
  source low-with-missing-magnitude behavior remains visible with NA/reason/QC. It never chooses a
  model or drops a gene. RMST/landmark methods are not added outside the selected plan scope.
- Piecewise fitting preserves source native Cox defaults under explicit source-native acknowledgement.
  Original ties/max-iter/cox-eps control only the original continuous fits. Native version/formals,
  all period rows, non-estimability, warnings, event support and independent original n are recorded.
  Display intervals are corrected to (start,stop] while retaining the original source_period_label.
- AJ explicitly retains censor factor level0 even with no censored records. This corrects a source
  encoding defect; no equality claim is made for the defective all-event source case. Independent
  product-integral native tests cover the corrected case. Valid-censor source parity is separate.
- CIF is descriptive point-only: no invented CI, Gray, Cox or Fine-Gray result. Binary event must
  match the nominated cause; status is explicit0..k. No automatic recoding, cutpoint optimization,
  extrapolated milestones or hidden row deletion. One-minus-KM is diagnostic-only, never the CIF.
- New technical bounds are10 cuts and20 event types, alongside inherited100 genes/5000 subjects.
  The cause bound limits full all-cause observed-time rows to100040; it never merges/drops causes.
- Shared os_cif renders precomputed values only, with initial-state risk counts, common axes,
  dataset label and explicit lack of intervals. New-type restyle remains an open gap.

## C. Anchors and real-evidence boundary
All10 existing independent synthetic Cox/KM mathematical checks retain their definitions and
original tolerances. Four extra checks require actual R4.6.1/survival3.8-9 source-copy/CLI work,
independent AJ arithmetic and exact numeric replay; they never run a fake native engine.
The source CR-mgus2-cif anchor is a Mayo clinical dataset, not obtained here. Its method/time365 /
1e-8 tolerance and exact source identities are retained in ORIGINAL_ANCHOR_STATUS.json with an
explicit blocker. Source SN-V1 is RMST and outside the selected B3 functions. Neither is called
passed. The six-unit exact-fraction oracle is an invented software contract, not real owner data.

## D. Calls/defaults and output contract
All15 previous call-registry rows/default values remain; three call sites are disambiguated with
site_requires. Eight new call records retain source values and explicitly unknown uncaptured
native defaults. Original historical R4.5.0/survival3.8.3 metadata is not relabelled as R4.6.1.
Native default capture and locked API checks remain required. Entry/SSOT/conditional guards,
existing development handoff, os_module_finish and shared PNG/PDF/spec output are used.

## E. Same-input evidence and acceptance
Python source-body/hash equality is executed. Actual native same-input before/after/refusal/plot
work is implemented in tests/run_port_smoke.R and tests/run_port_cli.py, but not executed here:
Rscript and Docker are absent. The CLI runner preserves every inherited smoke check, executes
all45 refusals, and verifies four actual resolved-spec replays with byte-identical numeric CSVs.
It uses only the invented seed9182 fixture through a real limma-array producer; no fabricated
handoff acceptance. It exits127 without a new run directory when R is absent.

Read VALIDATION.md and docs/build/P0-13-survival-expr-port/source_requirements.json for status.
No golden/lock write, sealing, merging, deployment, production access or new installation occurs.
Every owner figure still needs real eligible data/input/code/table/figure binding and owner review.

<!-- anchors:begin -->
| ID | Metric | Expected | Tolerance | Source | Scope | How |
|---|---|---|---|---|---|---|
| coefficient_max_error | Maximum absolute error for coefficient across signal and two covariates | 0 | 5e-07 | tests/anchors.py: independently implemented Efron partial likelihood, score, observed information and Newton solve using Python standard-library arithmetic; Cox model equations https://stat.ethz.ch/R-manual/R-patched/library/survival/doc/survival.pdf | Synthetic seed9182 input only; independently recomputed mathematical reference, not published patient anchors and not wrapper-generated expected values | replay |
| se_max_error | Maximum absolute error for se across signal and two covariates | 0 | 5e-07 | tests/anchors.py: independently implemented Efron partial likelihood, score, observed information and Newton solve using Python standard-library arithmetic; Cox model equations https://stat.ethz.ch/R-manual/R-patched/library/survival/doc/survival.pdf | Synthetic seed9182 input only; independently recomputed mathematical reference, not published patient anchors and not wrapper-generated expected values | replay |
| z_max_error | Maximum absolute error for z across signal and two covariates | 0 | 5e-07 | tests/anchors.py: independently implemented Efron partial likelihood, score, observed information and Newton solve using Python standard-library arithmetic; Cox model equations https://stat.ethz.ch/R-manual/R-patched/library/survival/doc/survival.pdf | Synthetic seed9182 input only; independently recomputed mathematical reference, not published patient anchors and not wrapper-generated expected values | replay |
| p_value_max_error | Maximum absolute error for p_value across signal and two covariates | 0 | 5e-07 | tests/anchors.py: independently implemented Efron partial likelihood, score, observed information and Newton solve using Python standard-library arithmetic; Cox model equations https://stat.ethz.ch/R-manual/R-patched/library/survival/doc/survival.pdf | Synthetic seed9182 input only; independently recomputed mathematical reference, not published patient anchors and not wrapper-generated expected values | replay |
| estimate_max_error | Maximum absolute error for estimate across signal and two covariates | 0 | 5e-07 | tests/anchors.py: independently implemented Efron partial likelihood, score, observed information and Newton solve using Python standard-library arithmetic; Cox model equations https://stat.ethz.ch/R-manual/R-patched/library/survival/doc/survival.pdf | Synthetic seed9182 input only; independently recomputed mathematical reference, not published patient anchors and not wrapper-generated expected values | replay |
| ci_low_max_error | Maximum absolute error for ci_low across signal and two covariates | 0 | 5e-07 | tests/anchors.py: independently implemented Efron partial likelihood, score, observed information and Newton solve using Python standard-library arithmetic; Cox model equations https://stat.ethz.ch/R-manual/R-patched/library/survival/doc/survival.pdf | Synthetic seed9182 input only; independently recomputed mathematical reference, not published patient anchors and not wrapper-generated expected values | replay |
| ci_high_max_error | Maximum absolute error for ci_high across signal and two covariates | 0 | 5e-07 | tests/anchors.py: independently implemented Efron partial likelihood, score, observed information and Newton solve using Python standard-library arithmetic; Cox model equations https://stat.ethz.ch/R-manual/R-patched/library/survival/doc/survival.pdf | Synthetic seed9182 input only; independently recomputed mathematical reference, not published patient anchors and not wrapper-generated expected values | replay |
| km_product_limit_max_error | km_product_limit_max_error | 0 | 1e-12 | tests/anchors.py: direct product-limit risk-set arithmetic and counts from synthetic source inputs | Synthetic canonical output independently checked; not published numerical anchors | replay |
| risk_count_max_error | risk_count_max_error | 0 | 0 | tests/anchors.py: direct product-limit risk-set arithmetic and counts from synthetic source inputs | Synthetic canonical output independently checked; not published numerical anchors | replay |
| sample_event_count_max_error | sample_event_count_max_error | 0 | 0 | tests/anchors.py: direct product-limit risk-set arithmetic and counts from synthetic source inputs | Synthetic canonical output independently checked; not published numerical anchors | replay |
| port_aj_max_error | Maximum exported AJ error against independent exact-fraction risk sets | 0 | 1e-12 | tests/port_anchors.py + run_port_cli.py + run_port_smoke.R; original selected MedStat code at12292d0 and independent invented risk-set arithmetic in port_oracle.py | Software contracts only; not a real owner anchor. Requires exact R4.6.1/survival3.8-9 and actual CLI execution; no clinical rows acquired. Original CR-mgus2-cif stays blocked separately. | replay |
| port_legacy_table_invariance | Original same-input tables unchanged with optional diagnostics | 1 | 0 | tests/port_anchors.py + run_port_cli.py + run_port_smoke.R; original selected MedStat code at12292d0 and independent invented risk-set arithmetic in port_oracle.py | Software contracts only; not a real owner anchor. Requires exact R4.6.1/survival3.8-9 and actual CLI execution; no clinical rows acquired. Original CR-mgus2-cif stays blocked separately. | replay |
| port_replay_csv_invariance | Four actual CLI branches replay identical numeric CSV bytes | 1 | 0 | tests/port_anchors.py + run_port_cli.py + run_port_smoke.R; original selected MedStat code at12292d0 and independent invented risk-set arithmetic in port_oracle.py | Software contracts only; not a real owner anchor. Requires exact R4.6.1/survival3.8-9 and actual CLI execution; no clinical rows acquired. Original CR-mgus2-cif stays blocked separately. | replay |
| port_copied_source_same_input | Copied source native diagnostics/piecewise parity and independent AJ checks | 1 | 0 | tests/port_anchors.py + run_port_cli.py + run_port_smoke.R; original selected MedStat code at12292d0 and independent invented risk-set arithmetic in port_oracle.py | Software contracts only; not a real owner anchor. Requires exact R4.6.1/survival3.8-9 and actual CLI execution; no clinical rows acquired. Original CR-mgus2-cif stays blocked separately. | replay |
<!-- anchors:end -->
