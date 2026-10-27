---
name: drc-calibrate
description: >
  One plate, continuous signals, 4PL/5PL unweighted drc fit; explicit blank handling, technical precision, inverse prediction and dilution correction. Candidate development execution only; absent from the production router.
---

# ELISA / immunoassay calibration and titer

One plate, continuous signals, 4PL/5PL unweighted drc fit; explicit blank handling, technical precision, inverse prediction and dilution correction.

Status: **development_unsealed**, publication blocked by DEV-01. Runtime
`omicstat-r-exp:20261015` is verified candidate evidence; no production lock,
golden or seal is generated. Run `scripts/run_drc_calibrate.R` with
`--development-mode`. Use a new/empty `--outdir`; `--spec` replays resolved choices.
All scientific choices are explicit; none are selected from significance.

Ask the user for design, biological unit, population, comparison and measure,
outcomes and timing, covariates, missingness, multiplicity and analysis sets.
Call MCP `omicstat_create_study_contract` with these structured fields, retain the
stored JSON, and pass its returned `sha256` to `--study-contract-sha256`.
See `mcp/STUDY_CONTRACT.md`. The helper validates declarations; agreement with
executed settings remains a review responsibility.

Read `references/parameters.md`, `references/input-contract.md` and the candidate
`acceptance/exemplars/drc-calibrate/PACK.md` before executing. Outputs include native model
RDS, development-only typed handoff, validated canonical effect table, native
results/diagnostics and plotted tables, PNG/PDF/figure specs, QC, engine warning
log, exact input/output SHA256 and replay spec. No technical well is a biological
replicate. No unsupported external model/formula is evaluated.

Methods are candidate notes with limitations. Full manuscript reporting and
independent/owner scientific acceptance remain pending. Evidence and numerical
anchor scope are in `VALIDATION_STATUS.json` and `docs/build/DOSE_SCOPE.md`.

## When to use / when not

## Input requirements

## Run

## What gets produced

## Reading the results

## When a QC rule fires

## Known limitations

## Reference files
