# monocle3-trajectory independent S3 request
Run `bash /home/<user>/omic-sol61/build_m3b/docker_run.sh Rscript skills/monocle3-trajectory/tests/run_smoke_test.R`; `OMICSTAT_WRITE_GOLDEN=1` only to regenerate locked-container goldens.

PACK C / pinned official trajectories guide Packer/Zhu anchor: input and native CDS **20222 genes × 6188 cells PASS**, cell/gene metadata align. Fixture constructs/preprocesses/alines/embeds/clusters directly from registered files; no front-end lane module is called. Backend preserves that UMAP, clusters and four partitions, then calls learn_graph/order_cells/graph_test. Explicit guide earliest embryo.time.bin=130-170 chooses root **Y_134**. Observed 5576 finite and 612 infinite pseudotimes; retained without replacement. This is an observed reachability result, not a published exact pseudotime assertion. No stable printed pseudotime is present in the pinned guide.

Direct/from-run pseudotime table hashes equal and ecosystem retained; calls/default drift/R lint pass. Graph association smoke deliberately selects **20 explicit genes** for runtime; full trajectory uses all genes/cells. Shape sanity: graph_test table 20 native rows. Production default tests all genes. Pseudotime golden generated in container, module_lock --check required. Both trajectory PNGs opened, nonblank/readable/unclipped, caption n/reachability/no cutoff.

Outputs: `/home/<user>/omic-sol61/build_m3b/monocle3-trajectory-smoke/{direct,chain}/`, `monocle-smoke.log`, `monocle-summary.log`; native CDS + graph_test table in objects/native.rds. GitHub version 1.4.27 / commit 536f1033d6de7c957f26a1f403f81efbd825e0db verified in container.

Limitations: native pinned CDS slots transport existing clusters/partitions, because there is no public cluster setter in this pinned API. This is conversion only; no backend re-clustering/re-embedding. User must supply a biological root rationale and partitions, and cover each desired partition with roots. graph_test is exploratory association; it does not prove lineage/causality. The 20-gene smoke does not accept all-gene test performance. Python-to-R label pending; options consult reference service.

Proposed router: `| Monocle3 graph trajectory, rooted pseudotime and graph-associated genes | monocle3-trajectory | scripts/run_monocle3_trajectory.R |`.
Publication proposal: root rationale, partition reachability, input embedding/preprocessing source, graph controls, tested gene scope and native graph_test multiplicity columns required.

2026.10.1 environment correction: non-root offline h5ad full smoke PASS, native table equals original RDS route. Converter preserves embedding order and singleton axes/categories through native AnnData/pandas operations with strict regression. Validation used a disposable fixed environment; final tagged-image check awaits owner load exception.

Final 2026.10.1 live-image validation supersedes the provisional image notes above: full smoke PASS as non-root with --network none and OMICSTAT_TEST_H5AD=1; actual h5ad input native tables match the RDS path/golden. Image ID sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7. Independent S3 remains pending.
