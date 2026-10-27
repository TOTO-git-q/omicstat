---
name: dropletutils-emptydrops
description: >
  Annotate nonempty droplets using DropletUtils emptyDrops with explicit lower and FDR,
  unfiltered raw counts and ambient-input provenance. Candidate only; never automatically removes barcodes.
---
# dropletutils-emptydrops

## When to use / when not
For raw unfiltered UMI matrices from one droplet library. Not filtered cells, normalized values,
ambient correction, doublet detection, health/viability inference or sample-level differential analysis.

## Input requirements
Unique feature/barcode identities, finite nonnegative integer counts and explicit unfiltered declaration.
Mandatory refdata ID binds the raw input used as ambient reference, not an external atlas. SHA, species,
source, version, licence/use provenance and study contract are required. Materialized matrix or sparse
matrix only; no rounding or hidden conversion. At least20 positive ambient barcodes and100 pooled UMIs.

## Run
Use the complete command in tests/acceptance.json, replacing synthetic fixtures deliberately. All scientific
settings are required: lower, FDR, niters, retain, alpha, ignore, test-ambient and seed. retain is a positive
threshold above lower/ignore or none; automatic knee selection is outside this explicit scope. alpha is
multinomial, estimate or a positive DM concentration. Runtime performs no downloads. Development mode
is mandatory. Limits are40000 features,100000 barcodes,20million barcode-iteration products and25minutes;
exceeding them refuses rather than subsampling. Production API must be inspected1.32.x.

## What gets produced
Every original barcode and raw count is preserved in a candidate SCE. Tables contain total UMIs, log
probability, original Monte Carlo P, Limited, FDR, nonempty label and count-retention status, plus ambient
probabilities and full plot data. qc_complete remains false. The generic shared layer draws barcode ranks
and ambient diagnostics; zero counts stay in tables and are explicitly omitted from log axes, never censored.

## Reading the results
Nonempty is not a healthy cell. Damaged cells, fragments and nuclei can reject the ambient null. BH uses
correction-P0 for total>=retain, matching inspected upstream source; the prose manual says above retain,
so the equality boundary has a dedicated test. Original Monte Carlo P is preserved. Totals<=lower are
excluded from FDR even when test-ambient is true. Good-Turing ambient probabilities are not raw observed
fractions; globally-zero features are reconstructed with zero probability without altering counts.

## When a QC rule fires
EDP-01 always blocks candidate publication. EDP-02 warns when Monte Carlo resolution may conceal calls;
EDP-03 marks no nonempty calls; EDP-04 requires downstream QC. Prespecify more iterations if justified;
do not lower FDR after viewing results. No automatic filtering or threshold relaxation.

## Known limitations
Single library only, no knee/by-rank/known-empty overrides, no cell-quality claim. Real engine execution,
locked-image acceptance and independent scientific/visual review remain required. Synthetic arithmetic
anchors cannot substitute for a separately reproduced author printed example.

## Reference files
parameters.md, method-basis.md, qc-rules.md, reporting-templates.md and troubleshooting.md.
