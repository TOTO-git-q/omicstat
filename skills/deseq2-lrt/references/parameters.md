# deseq2-lrt parameters

Locked implementation: DESeq2 1.52.0 in `omicstat-r:2026.09.1`; decisions: PACK S1 appendix P-1 to P-4. All registered defaults were read from `formals()` in the locked container.

| Flag | Default | Allowed | Why |
|---|---|---|---|
| `--counts` | none | existing raw count file | direct input |
| `--samples` | none | existing sample table | required with counts |
| `--from-run` | none | upstream run | deseq2-qc handoff |
| `--outdir` | (required) | directory | run output |
| `--spec` | none | existing spec | deterministic replay |
| `--sample-col` | sample | column | sample ID |
| `--full` | (required) | one-sided formula | full model, P-1 |
| `--reduced` | (required) | nested one-sided formula | reduced model, P-1; no automatic ~1 |
| `--adjust` | none | comma-separated terms | verify terms kept in both models |
| `--group-col` | none | sample column | figure colour; inferred only when unambiguous |
| `--group-reference` | none | group level | figure colour reference |
| `--time-col` | none | sample column | optional trajectory display |
| `--min-count` | 10 | integer >=0 | pre-filter counts |
| `--min-samples` | 0 | integer >0 in a run | required explicit pre-filter sample count |
| `--alpha` | 0.05 | 1e-6 to 0.5 | FDR threshold and independent filtering target |
| `--report-coef` | none | resultsNames entry | labels one LFC; does not redefine joint P |
| `--fit-type` | parametric | parametric, local, mean | dispersion fit |
| `--sf-type` | ratio | ratio, poscounts | size-factor estimator |
| `--gene-annotation` | none | feature_id,symbol table | labels |
| `--top-n` | 50 | 2 to 500 | top heatmap features |
| `--pattern-clustering` | off | switch | explicit opt-in; gene list and time field required |
| `--seed` | 20260925 | integer | random seed recorded in provenance |
| `--journal` | nature | nature, cell, science, generic | figure preset |

## Fixed package calls

`DESeq(test="LRT", full=--full, reduced=--reduced, betaPrior=FALSE, minReplicatesForReplace=7, useT=FALSE, minmu=0.5, parallel=FALSE)`; `results(name=<--report-coef, else the last resultsNames() entry>, lfcThreshold=0, independentFiltering=TRUE, pAdjustMethod="BH", test="LRT")` -- `name` is always written out; without `--report-coef` it is the value `results()` itself would substitute (`lastCoefName`). The full argument list and locked defaults are in `scripts/calls_registry.json`. `name` changes the displayed coefficient only; stat, P and BH-adjusted P are the joint test's (smoke test F3). Display transformation for the heatmap (after the fit, never part of the test): `vst(blind=FALSE, nsub=1000, fitType=--fit-type)`, or `varianceStabilizingTransformation(blind=FALSE, fitType=--fit-type)` when fewer than 1,000 features have mean normalized count > 5; the call that ran is written into the Methods, the heatmap caption and the results JSON. Joint significance is never screened on a single LFC (P-3).


### Optional DEGreport patterns (2026.10.1)
--pattern-clustering is off by default (S1 P-2). Enabling it requires --pattern-genes (one retained tested ID per line) and --time-col; --pattern-group-col defaults NULL. There is no inferred significant-gene selection. Query reference_advise(module='deseq2-lrt', ...) and reference_search before choosing genes, metadata fields or native options; absent evidence, show the vignette and ask the user.
--pattern-options accepts named JSON overrides: minc=15, summarize="merge", consensusCluster=false, reduce=false, cutoff=0.7, scale=true, pattern=null, groupDifference=null, eachStep=false, fixy=null, nClusters=null, skipDendrogram=true. These are locked degPatterns defaults. ma is the selected display VST matrix, metadata is the aligned sample table, time/col are explicit metadata columns; plot=false avoids native graphics devices. The native result is saved in objects/patterns.rds, native assignments in tables/patterns.csv, and the gene list, all options and metadata fields in objects/pattern_options.json. Clusters are exploratory displays, never another confirmatory test. LRT results and its default golden remain unchanged.
