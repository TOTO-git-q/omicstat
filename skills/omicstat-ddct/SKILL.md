---
name: omicstat-ddct
description: >
  Normalize technical qPCR Ct wells within biological units, then calculate delta-delta-Ct and relative
  expression with an explicit stable reference and calibrator. Optional biological Welch or paired t
  inference acts on delta-Ct, with reversed back-transformed fold intervals. Candidate development only.
---
# omicstat-ddct

## When to use / when not
Use for a declared equal-efficiency, near-doubling qPCR assay and one validated reference gene.
Use drc-calibrate for standard-curve inverse concentration; use lme4-lmm for complex adjusted/repeated designs.
No efficiency-corrected Pfaffl calculation, automatic reference selection or undetermined-Ct imputation.

## Input requirements
Long Ct CSV with explicit --unit-col biological identity and --well-col technical identity. All assay,
group, unit and well identities are mandatory. --ct-max is the declared detection limit; Ct must be finite,
positive and detected. --well-layout separate averages target/reference wells separately; same requires
exact matching well IDs and averages within-well delta-Ct. All requested genes must occur in every unit/group.
--assay-validation is a JSON declaration with schema omicstat.qpcr-assay.v1, target_genes, reference_gene,
equal_efficiency_confirmed, near_two_amplification_confirmed, reference_stability_confirmed, source and basis.
All three confirmations must be true. This records the user's validation claim; it does not measure efficiency.

## Run
Prepare the exact source fixture with tests/prepare_acceptance.py, then use tests/acceptance.json flags.
All scientific choices are required; --development-mode only permits candidate execution. This module
is excluded from accepted MCP routing. --spec replays the resolved parameters into another empty output.
See references/parameters.md for every flag and tests/livak_source.json for source-transcription limitations.

## What gets produced
Biological-unit Ct means, delta-Ct, delta-delta-Ct, fold changes and technical-well counts; group summaries;
when requested, biological test and mean delta-delta-Ct effect tables with fold-transformed marginal CIs.
Two shared biological-point plots per target show delta-Ct cycles and relative expression. Typed candidate
handoff, validated StudyContract hash, assay JSON/input hashes, engine warning log and candidate Methods draft.

## Reading the results
Fold is 2^(-delta-delta-Ct). Group fold_geometric transforms mean delta-Ct; fold_arithmetic averages
individual transformed values, and they generally differ. Neither technical well count nor a technical-SD
range is biological replication. Per-unit technical ranges hold the calibrator mean constant and reproduce
only the original descriptive convention; they are not confidence intervals. Biological CIs include the
calibrator uncertainty via Welch/paired t on delta-Ct; their transformed endpoints are reversed.
All target/calibrator tests share the declared multiplicity family. CIs remain marginal, not simultaneous.

## When a QC rule fires
DDC-01 blocks candidate publication; DDC-02 reminds that assay validation is supplied evidence;
DDC-03 identifies descriptive-only output. Design/identity/detection violations stop, without row deletion.

## Known limitations
One reference gene, complete paired designs only, no efficiency estimation or multiple-plate correction.
Original Livak Table1 represents technical replicates and is tested only descriptively, not as n=6 biology.
Reference-group individual fold points share a calibration mean; they are not independent calibrator estimates.
Owner scientific decisions, immutable-image exec and owner visual review remain pending.

## Reference files
method-basis.md, parameters.md, qc-rules.md, reporting-templates.md, troubleshooting.md and tests/livak_source.json.
