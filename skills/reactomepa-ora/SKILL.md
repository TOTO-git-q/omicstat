---
name: reactomepa-ora
description: >
  ReactomePA over-representation analysis with an explicit eligible Entrez universe,
  fixed offline SQLite resources and provenance. Candidate only. Triggers: Reactome ORA, pathway overlap.
---
# reactomepa-ora

## When to use / when not
For prespecified selected Entrez genes against a justified assay-eligible background. Not GSEA,
activation direction, causal pathway inference, expression differential testing or automatic ID guessing.

## Input requirements
Unique positive canonical Entrez strings in selected/background CSV; selected must be a proper subset.
Every scientific threshold, organism, selection rule and universe policy is explicit. refdata ID is
mandatory and must resolve in the v2 registry. A user-supplied manifest and licence/use provenance
are mandatory. The actual installed reactome.db and species OrgDb SQLite SHA/version and canonical
membership/name hashes must match the manifest before enrichment. No online query or silent update.
Only inspected ReactomePA1.56.0 is currently supported. Limits:20000 selected,60000 background,
2000000 effective memberships; no implicit downsampling.

## Run
Use tools/export_reactome_snapshot.R to declare already installed resource bytes with your explicit
licence and permitted-use statement. The exporter does not fetch or grant rights. Do not pass a package
tarball checksum in place of the actual queried SQLite/mapping checksum. Example full command is in
tests/acceptance.json. All runs require --development-mode and a validated study contract.

## What gets produced
Full tested enrichment table, raw engine rows, every input mapping status and effective memberships,
resource hashes/version, QC, methods and deterministic replay spec. Handoff enrichment_table remains
candidate. A shared enrichment dotplot is emitted only when declared BH alpha is passed.

## Reading the results
Universe policy strict refuses any annotation loss; annotated-intersection reports it explicitly.
More than5% loss in either selected or background IDs raises QC. Upstream tests only nonzero-overlap
pathways meeting effective-background set-size limits; BH covers this complete tested family.
Zero-overlap pathways are excluded, not silently added to the denominator. Counts and probabilities
are checked against independent hypergeometric arithmetic. All raw tested terms remain in tables,
regardless of display alpha or top-n. This is membership over-representation, not pathway activation.

## When a QC rule fires
RPA-01 candidate publication blocker; RPA-02 annotation-loss warning; RPA-03 no significant terms.
A null result omits the dotplot and writes the threshold/number-tested/minimum-P note, without
relaxing thresholds. Wrong resource/species/hash or universe is a typed refusal.

## Known limitations
Entrez only; symbol/Ensembl callers must first run the explicit offline ID-mapping helper and review
its loss/one-to-many policy. No implicit mapping in this module. BH only, no pooled contrasts.
Owner scientific/visual review, locked-image regression and resource licence review remain pending.

## Reference files
parameters.md, method-basis.md, qc-rules.md, reporting-templates.md and troubleshooting.md.
