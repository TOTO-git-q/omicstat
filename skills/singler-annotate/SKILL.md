---
name: singler-annotate
description: >
  Produce SingleR cell-type annotation tables, full label scores, diagnostic heatmaps and a Methods/Results draft. Triggers: SingleR, reference annotation, 细胞类型注释, 参考注释. Use a clustered single-cell object and a compatible labelled reference. NOT for marker discovery (use seurat-markers or scran-markers); NOT for condition differential expression (use muscat-pseudobulk).
---
# singler-annotate

## When to use / when not
Annotate cells against a supplied labelled reference. Use scanvi-annotate for scANVI label transfer and muscat-pseudobulk for replicated condition comparisons.

## Input requirements
Clustered SCE or Seurat RDS, or AnnData h5ad. Explicit assay/layer roles and cluster metadata. Direct input declares its front-end ecosystem. A reference SCE must have normalized logcounts and labelled cells; name its identity, version and species. Verified --from-run inputs preserve chain state and contract.

## Run
```bash
Rscript scripts/run_singler_annotate.R --input clustered.rds --cluster-col cluster --logcounts-layer logcounts --ecosystem bioconductor --reference reference.rds --reference-name Muraro --reference-version EH2692-EH2693 --species human --reference-label-col label --de-method wilcox --outdir annotation
```

### Via MCP
After independent S3 and router registration, call the analysis entry through the suite MCP. This partial S2 module is not registered or accepted. `--help` lists every option; the ones that matter most are --reference, --reference-label-col, --unit and --de-method. See parameters.md for locked defaults and scientific input choices.

## What gets produced
`tables/annotations.csv`, full `tables/scores.csv`, `tables/cluster_labels.csv`; `figures/scores.{png,pdf,figure_spec.json}` and `figures/cluster_labels.{png,pdf,figure_spec.json}`; `qc/qc_results.csv`, captured engine warnings, `draft/methods_results.md`, results JSON, provenance, and annotated SCE handoff.

## Reading the results
Keep raw and pruned labels distinct. Unassigned cells are uncertain, not a new inferred biological cell type. Scores describe relative assignment confidence, not calibrated probabilities. See reporting-templates.md.

## When a QC rule fires
SA-01..SA-04 identify pruning, total assignment failure, ecosystem crossing and engine warnings. SA-02 withholds the draft. See qc-rules.md.

## Known limitations
The 2026.10.1 image includes scrapper. The official pancreas wilcox anchor reproduces 1718 cells, 59 pruned labels and all printed label counts; its first golden and lock are available for independent S3. No automatic atlas or species inference. Python-to-R ecosystem label remains 待裁决; provenance preserves the upstream ecosystem and QC flags the crossing. Score heatmaps use the shared renderer reproducing relative-score grammar instead of native pheatmap. See build_worklog.md.

## Reference files
method-basis.md: evidence; parameters.md: all flags and fixed calls; qc-rules.md: criteria and sources; reporting-templates.md: result-derived wording; troubleshooting.md: typed errors and remedies.

Before selecting reference, label level, annotation unit or marker method, query `reference_advise(module="singler-annotate", ...)` and `reference_search`; if uncurated, show the vignette example and ask the user. Every SingleR/pruneScores formal has a JSON-valued `--singler-<argument>` / `--prune-<argument>` option (`.` and `_` become `-`). These override the legacy convenience flags; absent flags use locked defaults. Enum choices: genes="de"|"sd"|"all", de.method="classic"|"wilcox"|"t"; unit cell|cluster.

`omicstat-r:2026.10.1` prebuilds the AnnData environment at `BASILISK_EXTERNAL_DIR=/opt/omicstat/basilisk`; non-root h5ad input works offline through the shared conversion contract. A custom environment without this prebuilt environment gives `OS_ENV_MISSING`; the runtime never downloads it.
