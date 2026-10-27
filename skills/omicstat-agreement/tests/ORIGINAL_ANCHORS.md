# Three original cases (public published tables)

The original source identities are in references/PORT_SOURCE.json. Its three
published cases contribute 30 numerical checks in anchors.json: SAS SkinCondition
kappa and independent FCE formulas; Bland-Altman PEFR bias/limits and their CIs;
Shrout-Fleiss ICC2,1/ICC3,1 and independent ANOVA/F-interval formulas.

The three input tables are public textbook/journal data and are committed under
tests/fixtures/published_anchor_inputs/ (skin.csv, pefr.csv, sf.csv plus
SOURCE.json with source references and byte hashes). No patient-level clinical
records and no owner data are involved. official_anchor_inputs.json holds the
expected normalized value hashes; verify_official_inputs.py checks every actual
file and normalized value hash, so changing a hash cannot turn different values
into the original case.

tests/run_anchors.R reads that folder by default. OMICSTAT_AGREEMENT_ANCHOR_DIR
and OMICSTAT_AGREEMENT_PRIVATE_ANCHOR_OUT remain optional overrides (alternative
folder with the same identity check; scratch directory, default a fresh temporary
directory outside the repository).

These statistical examples are separate from the registered real-data owner
adapter/contact-sheet requirement. The module has no owner_review receipt yet.
