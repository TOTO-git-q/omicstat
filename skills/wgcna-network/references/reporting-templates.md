# Reporting templates
```template methods
WGCNA (v{version}) analyzed {genes} genes in {n} biological samples on the {scale} scale. Preprocessing: {preprocessing}. Prior sample exclusion audit: {outlier}. goodSamplesGenes checked missingness and variance, without automatic biological outlier removal. The explicit soft power was {power} ({reason}); pickSoftThreshold assessed fit and mean connectivity. blockwiseModules used {cor_type} correlation, networkType={network}, TOMType={tom}, minModuleSize={minsize}, deepSplit={split}, mergeCutHeight={merge}. {trait_inference} Hubs were ranked within modules by absolute module eigengene membership; all genes were retained and no universal hub cutoff was applied.
```
```template results
The network contained {modules} assigned modules and {grey} unassigned genes. Full module assignments, membership ranks and all {tests} module-trait {assoc_noun} are retained.{results_inference} These associations and candidate hub ranks are exploratory and do not establish causality.
```

Inference slots (owner decision 2026-10-05). `{trait_inference}` on the plain Pearson path without missing trait values is the sentence "{cor_method} module-trait correlations used corPvalueStudent with n={n}; {adjustment} adjustment covered all {tests} module-trait tests."; with missing trait values it names the pairwise complete counts; on descriptive settings (Spearman, Kendall, cosine, weights) it states that no P values were computed because a Student-t P value is not valid for that setting and that the correlations are descriptive. `{results_inference}` is empty on the plain complete Pearson path and otherwise carries the matching sentence with a leading space. `{assoc_noun}` is `tests` with inference and `correlations` without.
