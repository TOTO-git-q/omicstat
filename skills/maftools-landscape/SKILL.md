---
name: maftools-landscape
description: "Summarize somatic mutation MAFs using maftools, with oncoplot, variant summaries, TMB and pairwise interactions. Triggers: maftools, MAF, oncoplot, 突变景观. Not for variant calling or driver discovery."
---
# maftools-landscape
Input: standard MAF with the required maftools fields, optional clinical TSV keyed by Tumor_Sample_Barcode. Supply --call-source with caller, accession, genome build and filtering, and exactly one of --capture-size (callable territory in Mb) or --capture-regions (offline chrom/start/end TSV with --capture-regions-source). --input accepts raw MAF; --from-run consumes verified maf_file or native MAF.

Run: Rscript scripts/run_maftools_landscape.R --input tcga_laml.maf.gz --clinical tcga_laml_annot.tsv --call-source TCGA-LAML-vignette --capture-size 50 --outdir run. The 50 Mb example is not an assay estimate. --spec replays resolved options.

Outputs: native MAF RDS, unchanged native variant/silent/sample/gene/clinical/TMB/interaction CSV tables, clinical join ledger, suite oncoplot and variant-summary figures, Methods draft, provenance and neutral handoff. Interactions preserve raw and adjusted P; plots are descriptive. The MAF contains observed samples; clinical-only rows are not assumed mutation-free. No CADD or licence-gated annotation is used.

Options and exact defaults are in references/options.md and --help. Default oncoplot top=10 follows the official vignette; ranking uses mutated sample counts with deterministic ties and waterfall sample order. The oncoplot uses the suite's ggplot builder; it does not expose maftools native cosmetic plot options. --interaction-genes overrides --interaction-top. All interaction pairs are retained. TMB uses package default point-mutation classes with explicit CNV policy, not a new class definition.

## 待裁决 / choosing options
- Before choosing `--call-source`, query `reference_advise(module="maftools-landscape", …)` and `reference_search`; if no curated evidence applies, show the locked default/vignette example and ask the user.
- Before choosing `--capture-size`, query `reference_advise(module="maftools-landscape", …)` and `reference_search`; if no curated evidence applies, show the locked default/vignette example and ask the user.
- Before choosing `--non-synonymous`, query `reference_advise(module="maftools-landscape", …)` and `reference_search`; if no curated evidence applies, show the locked default/vignette example and ask the user.
- Before choosing `--use-all`, query `reference_advise(module="maftools-landscape", …)` and `reference_search`; if no curated evidence applies, show the locked default/vignette example and ask the user.
- Before choosing `--is-tcga`, query `reference_advise(module="maftools-landscape", …)` and `reference_search`; if no curated evidence applies, show the locked default/vignette example and ask the user.
- Before choosing `--remove-duplicates`, query `reference_advise(module="maftools-landscape", …)` and `reference_search`; if no curated evidence applies, show the locked default/vignette example and ask the user.
- Before choosing `--rm-flags`, query `reference_advise(module="maftools-landscape", …)` and `reference_search`; if no curated evidence applies, show the locked default/vignette example and ask the user.
- Before choosing `--top`, query `reference_advise(module="maftools-landscape", …)` and `reference_search`; if no curated evidence applies, show the locked default/vignette example and ask the user.
- Before choosing `--interaction-top`, query `reference_advise(module="maftools-landscape", …)` and `reference_search`; if no curated evidence applies, show the locked default/vignette example and ask the user.
- Before choosing `--interaction-genes`, query `reference_advise(module="maftools-landscape", …)` and `reference_search`; if no curated evidence applies, show the locked default/vignette example and ask the user.
- Before choosing `--ignore-cnv`, query `reference_advise(module="maftools-landscape", …)` and `reference_search`; if no curated evidence applies, show the locked default/vignette example and ask the user.
- Before choosing `--cn-table`, query `reference_advise(module="maftools-landscape", …)` and `reference_search`; if no curated evidence applies, show the locked default/vignette example and ask the user.
- Before choosing `--cn-level`, query `reference_advise(module="maftools-landscape", …)` and `reference_search`; if no curated evidence applies, show the locked default/vignette example and ask the user.

Choose interaction genes before testing, tied to the biological question; a higher top N expands multiplicity. Choose top only for readable display, retain full tables. Use isTCGA only when 12-character patient IDs are intended. Changing class and duplicate policies changes counts. No automatic TMB high/low cutoff or clinical hypothesis test. S2 build awaits independent S3.

`--capture-regions` is the mutually exclusive alternative to `--capture-size`; use an offline native chrom/start/end TSV and declare `--capture-regions-source` (source/build/version). Consult `reference_advise` and `reference_search` before choosing territory; ask the user when unspecified. Full variants/summaries remain available, while native tmb subsets to the supplied regions and uses sum(end-start) as territory.
