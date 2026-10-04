# Reporting templates
```template methods
WGCNA (v{version}) analyzed {genes} genes in {n} biological samples on the {scale} scale. Preprocessing: {preprocessing}. Prior sample exclusion audit: {outlier}. goodSamplesGenes checked missingness and variance, without automatic biological outlier removal. The explicit soft power was {power} ({reason}); pickSoftThreshold assessed fit and mean connectivity. blockwiseModules used {cor_type} correlation, networkType={network}, TOMType={tom}, minModuleSize={minsize}, deepSplit={split}, mergeCutHeight={merge}. {cor_method} module-trait correlations used corPvalueStudent with n={n}; {adjustment} adjustment covered all {tests} module-trait tests. Hubs were ranked within modules by absolute module eigengene membership; all genes were retained and no universal hub cutoff was applied.
```
```template results
The network contained {modules} assigned modules and {grey} unassigned genes. Full module assignments, membership ranks and all {tests} module-trait tests are retained. These associations and candidate hub ranks are exploratory and do not establish causality.
```
