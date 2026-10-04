# Independent S3 request: wgcna-network
S2 only; no installation or router registration performed.

Run in omicstat-r:2026.09.1 with OMICSTAT_CONTAINER=1, single-thread BLAS, writable scratch and the read-only acceptance layer:
`Rscript skills/wgcna-network/tests/run_smoke_test.R`
Then `Rscript tools/make_module_lock.R wgcna-network --check`.

Anchor: FemaleLiver tutorial part 1 retained 134 samples / 3600 probes; tutorial part 2 power 6, unsigned TOM, minModuleSize 30, deepSplit 2, merge 0.25. Assert every assignment against the official code and printed part 2 PDF label counts: grey99; 18 assigned modules, size34–609. The 19-count table includes grey. One trait replay uses complete other_fat. Outputs and logs: /home/<user>/omic-sol61/build_m4/wgcna-smoke/anchor and wgcna-smoke.log. Inspect every suite PNG and caption, golden manifest and neutral handoff. Goldens are hashes of the main native-derived tables from the locked container.

Limitations: power and preprocessing/outlier choices are explicit; no preservation/covariate association inference. FemaleLiver origin is a documented mirror, not byte-compared with unavailable UCLA server. WGCNA 1.74 is pinned. Options refer callers to reference_advise/reference_search. No S3 claim is made.

Proposed router row: `wgcna-network | normalized bulk expression -> exploratory coexpression modules and traits | skills/wgcna-network/scripts/run_wgcna_network.R | R | WGCNA`. Publication rule proposal: require module seal, scale/preprocessing/exclusions, explicit power and rationale, sample n, exploratory wording; block causal hub claims and missing choice declarations.
