# maftools-landscape independent S3 request
S2 build only. Run in omicstat-r:2026.09.1 offline with repo mounted /omicstat and scratch /scratch:
`OMICSTAT_TEST_TMP=/scratch Rscript skills/maftools-landscape/tests/run_smoke_test.R`
`Rscript tools/make_module_lock.R maftools-landscape --check`

Checked: 14 smoke assertions, locked TCGA-LAML extdata hashes, native object and tables, clinical-only rows, from-run, spec determinism, registry/defaults, flag docs and lint. Locked official maftools vignette read.maf output: 193 samples, 1241 genes, 1732 non-silent and 475 silent variants; exact counts asserted. TMB has 192 rows because native tmb omits the zero-eligible-mutation sample; interactions retain 300 pairs and pAdj. Outputs/log: /home/<user>/omic-sol61/build_m4/maf-smoke/anchor and maf_smoke.log. Four PNGs opened and readable: oncoplot, variant_summary, tmb, interactions; suite figure lint passed. Factor-valued native sample IDs explicitly converted to character in lane fig_mod_m4.R; avoids doubled oncoplot denominator.

Limitations: callable territory is explicitly required (50 Mb is the example only), clinical-only samples are not treated as mutation-free; descriptive pair tests and BH P are retained without interpreting driver status. No annotation downloads/CADD. S0 correction ledger applies independent verification §3; original extraction is historical.

Proposed router row: `maftools-landscape | somatic MAF -> mutation landscape, TMB, cooccurrence | skills/maftools-landscape/scripts/run_maftools_landscape.R | R | maftools`.
Publication rules proposal: require caller/build/filter audit, assay territory, observed tumor n, valid module lock; prohibit inferred mutation-free clinical-only samples and automatic TMB threshold claims. Registries are unchanged; awaiting independent S3.
