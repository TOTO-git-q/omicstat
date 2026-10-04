---
name: wgcna-network
description: "Build WGCNA expression modules, soft-power diagnostics, trait associations and hub ranks. Triggers: WGCNA, coexpression, 共表达网络, 模块性状关联. NOT for differential expression (use limma-voom); NOT for pathway scoring (use gsva-score)."
---
# wgcna-network
## When to use
Exploratory coexpression modules from normalized biological-sample expression.
## Inputs
Feature-by-sample numeric CSV, explicit scale/preprocessing, aligned numeric traits, prior exclusion audit.
## Parameters
See references/parameters.md and --help. Power and its rationale are required. Tutorial values are examples.
## Run
Run scripts/run_wgcna_network.R with --input or --from-run and required arguments. --spec replays a resolved run.
## Outputs
Full gene modules/membership ranks, module sizes, eigengenes, soft-fit diagnostics, module-trait Pearson r/raw P/BH, network RDS, figures and draft.
## QC
See references/qc-rules.md. Blockers occur before fitting; gray genes remain in full tables.
## Reporting
Methods and Results use references/reporting-templates.md. Correlations and hub ranks are exploratory; no causal claim.
## Known limitations
待裁决: power, biological sample exclusions, preprocessing and hub interpretation remain explicit user choices. No universal significance/stability/hub cutoff. No adjusted covariate association or preservation analysis. Mirrored FemaleLiver bytes cannot be compared with the original UCLA server. Corrected lineage is refused. New handoff types: WGCNA_network and module_eigengenes.

## Choosing options / 待裁决
- Before choosing `--power`, query `reference_advise(module="wgcna-network", …)` and `reference_search`; if no curated evidence applies, explain the tutorial example in references/options.md and ask the user.
- Before choosing `--power-reason`, query `reference_advise(module="wgcna-network", …)` and `reference_search`; if no curated evidence applies, explain the tutorial example in references/options.md and ask the user.
- Before choosing `--input-scale`, query `reference_advise(module="wgcna-network", …)` and `reference_search`; if no curated evidence applies, explain the tutorial example in references/options.md and ask the user.
- Before choosing `--preprocessing`, query `reference_advise(module="wgcna-network", …)` and `reference_search`; if no curated evidence applies, explain the tutorial example in references/options.md and ask the user.
- Before choosing `--outlier-rule`, query `reference_advise(module="wgcna-network", …)` and `reference_search`; if no curated evidence applies, explain the tutorial example in references/options.md and ask the user.
- Before choosing `--traits`, query `reference_advise(module="wgcna-network", …)` and `reference_search`; if no curated evidence applies, explain the tutorial example in references/options.md and ask the user.
- Before choosing `--network-type`, query `reference_advise(module="wgcna-network", …)` and `reference_search`; if no curated evidence applies, explain the tutorial example in references/options.md and ask the user.
- Before choosing `--tom-type`, query `reference_advise(module="wgcna-network", …)` and `reference_search`; if no curated evidence applies, explain the tutorial example in references/options.md and ask the user.
- Before choosing `--min-module-size`, query `reference_advise(module="wgcna-network", …)` and `reference_search`; if no curated evidence applies, explain the tutorial example in references/options.md and ask the user.
- Before choosing `--deep-split`, query `reference_advise(module="wgcna-network", …)` and `reference_search`; if no curated evidence applies, explain the tutorial example in references/options.md and ask the user.
- Before choosing `--merge-height`, query `reference_advise(module="wgcna-network", …)` and `reference_search`; if no curated evidence applies, explain the tutorial example in references/options.md and ask the user.
- Before choosing `--max-block-size`, query `reference_advise(module="wgcna-network", …)` and `reference_search`; if no curated evidence applies, explain the tutorial example in references/options.md and ask the user.
- Before choosing `--pam-respects-dendro`, query `reference_advise(module="wgcna-network", …)` and `reference_search`; if no curated evidence applies, explain the tutorial example in references/options.md and ask the user.
- Before choosing `--reassign-threshold`, query `reference_advise(module="wgcna-network", …)` and `reference_search`; if no curated evidence applies, explain the tutorial example in references/options.md and ask the user.

Unsigned networks group positive and negative correlations; signed networks preserve direction. Higher deepSplit produces finer modules; a larger merge height merges more similar eigengenes. A larger minModuleSize limits small modules. Choose power after reviewing scale-free fit and connectivity; never maximize fit automatically.

Native controls: `--gsg-weights`, `--gsg-min-fraction`, `--gsg-min-nsamples`, `--gsg-min-ngenes`, `--gsg-tol`, `--gsg-min-relative-weight`, `--soft-weights`, `--soft-rsquared-cut`, `--soft-remove-first`, `--soft-n-breaks`, `--soft-cor-fnc`, `--soft-cor-options`, `--network-cor-type`, `--network-max-poutliers`, `--network-quick-cor`, `--network-pearson-fallback`, `--network-cosine-correlation`, `--network-tomdenom`, `--network-replace-missing-adjacencies`, `--network-suppress-tomfor-zero-adjacencies`, `--network-suppress-negative-tom`, `--network-detect-cut-height`, `--network-pam-stage`, `--network-min-core-kme`, `--network-min-core-kmesize`, `--network-min-kmeto-stay`, `--network-impute`, `--eigengene-impute`, `--eigengene-n-pc`, `--eigengene-align`, `--eigengene-exclude-grey`, `--eigengene-sub-hubs`, `--eigengene-scale`, `--cor-use`, `--cor-method`, `--cor-weights-x`, `--cor-weights-y`, `--cor-cosine`, `--cor-cosine-x`, `--cor-cosine-y`, `--cor-quick`, `--trait-p-adjust`. They bind sample/gene eligibility, soft-threshold diagnostics, network correlation/TOM/module detection, eigengenes and association correlations. Consult `reference_advise` and `reference_search` before choosing these scientific options; show the defaults in references/options.md and ask the user if evidence is absent. Adjustment is an added exploratory summary over all module-trait tests; native unadjusted P values are retained.
