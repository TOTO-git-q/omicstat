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
