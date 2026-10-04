---
name: scran-cluster
description: Generate scran-cluster tables, diagnostic figures and a checked single-cell handoff. Triggers include scran-cluster, SingleCellExperiment, 单细胞 and 生信. Use only for this module's documented analysis. For condition inference use muscat-pseudobulk; for GSVA use gsva-score.
---
# scran-cluster
## When to use / when not
Use for the analysis in method-basis.md. Follow the declared ecosystem and chain state. See Known limitations for scope boundaries.
## Input requirements
Local SCE RDS with unique cell/feature IDs, raw integer counts, declared species/ID namespace and the required chain state. --from-run verifies every hash and propagates the contract and upstream chain. Raw-input paths never bypass object-state validation.
## Run
Run `Rscript scripts/run_scran_cluster.R --help` in `omicstat-r:2026.10.1`. Supply the required choices in [parameters.md](references/parameters.md). --spec replays the resolved command and explicit flags override it.
## What gets produced
Full tables under tables/, PDF and PNG figures with captions/figure_spec under figures/, QC rules and captured warnings under qc/, Methods/Results under draft/, results JSON, provenance/resolved_spec.json, and objects/handoff.json with SCE and colour registry.
## Reading the results
Read QC first, then the complete tables and figure captions. Check that choices and input sizes agree with the study. No automatic condition inference is performed.
## When a QC rule fires
Typed input/blocking errors withhold estimation. Read qc/engine_warnings.csv for package warnings. See [qc-rules.md](references/qc-rules.md) and [troubleshooting.md](references/troubleshooting.md).
## Known limitations
待裁决: HVG count, PCA rank and graph/UMAP neighbour counts require explicit input. Walktrap is the locked NNGraphParam function default; no resolution is invented. No automatic scientific dimension choice.
S2 handover awaits independent S3; no acceptance or installation is claimed.
## Reference files
[method-basis.md](references/method-basis.md), [parameters.md](references/parameters.md), [qc-rules.md](references/qc-rules.md), [reporting-templates.md](references/reporting-templates.md), [troubleshooting.md](references/troubleshooting.md).
## Choices and reference service
Before choosing each of `--n-hvg`, `--n-pcs`, `--graph-k`, `--umap-neighbors`, `--cluster-method`, `--block-col`, `--batch-col` and `--sample-col`, call `reference_advise(module='scran-cluster', ...)` and `reference_search`. If nothing is curated, show the locked examples and ask the user. HVGs target biological variation; PCA trades signal against noise; graph k changes local community granularity; UMAP neighbours changes the displayed local/global balance. Inspect mean-variance and PCA elbow figures. Graph k=10 and UMAP neighbours=15 are native defaults/examples, not scientific recommendations. `--n-hvg 1000 --n-pcs 15` are smoke values. No automatic resolution choice: if using Leiden/Louvain, select `cluster.args` in `--graph-args` explicitly after the same reference-service consultation.

Native JSON files expose **all** supplementary result-affecting arguments of the named package calls. Examples: `--quickcluster-args` (`use.ranks`, `d`, `min.mean`, `graph.fun`, `block`); `--pool-args` (`positive`, `min.mean`, `ref.clust`, `max.cluster.size`, `scaling`); `--lognorm-args` (`center.size.factors`, `transform`, `use.altexps`); `--variance-args` (`design`, `subset.fit`, `equiweight`, `method`); `--hvg-args` (`var.threshold`, `fdr.threshold`); `--pca-args` (`scale`); `--graph-args` (`shared`, `type`, `cluster.args`); `--umap-args` (`metric`, `spread`, `init`, `n_epochs`). Locked defaults apply when omitted; primary CLI options override JSON. Seed follows scran vignette 100; computational threads remain one. See [options.md](references/options.md) and container-read calls_registry.json.

The locked 2026 scran vignette starts with `scrapper::analyze.se`, but scrapper is absent in the locked image. This module wraps its Quick clustering section and the documented OSCA/scater/bluster stages, not a reimplementation of scrapper. Its printed size-factor summary depends on scrapper's initial filtering and cannot be asserted as equivalent on the slim smoke subset; independent S3 must retain this limitation. Grun counts include fractional values from published processing; finite nonnegative native input is accepted.
`--resolution` is required for Leiden/Louvain unless provided in `--graph-args` `cluster.args.resolution`; before selecting it query both reference tools as above. Resolution controls community granularity; walktrap has no resolution option. The upstream QC smoke retains 396 of its 400 deterministic Grun cells (four empty cells), returns 1000 HVGs, 15 PCs, and nine clusters. These are regression checks, not scientific defaults.
