# Options and locked evidence

| option | locked default / vignette value | required? | S0 extraction parameter key |
|---|---|---|---|
| --input | none; local SCE RDS | no | none |
| --from-run | none; upstream single-cell run | no | none |
| --outdir | none; output directory | yes | none |
| --spec | none; resolved spec replay | no | none |
| --cluster-col | none; cluster metadata; example colLabels in locked Rd | yes | groups |
| --sample-col | "sample"; biological sample column; absent allows only upstream cluster_col | no | none |
| --route | "scoreMarkers"; scoreMarkers effect summaries or compatibility findMarkers | no | none |
| --lfc | 0; native effect threshold; no display-only filtering | no | lfc |
| --block-col | none; optional blocking column | no | block |
| --rank-by | none; native ranking column; recommend mean.AUC for scoreMarkers or summary.logFC for findMarkers; FDR ranking is ranking, not significance | yes | rank_by |
| --rank-decreasing | "TRUE"; descending effect ranking; set false for P-value/FDR ranking | no | none |
| --top-n | none; display genes per cluster; S0 examples 10 or 100 | yes | top_n |
| --test-type | "t"; compatibility test t/wilcox/binom | no | test_type |
| --direction | "any"; compatibility direction any/up/down | no | direction |
| --pval-type | "any"; compatibility p-value any/some/all | no | pval_type |
| --marker-args | none; supplementary native options including subset.row, pairings and summaries | no | none |
| --seed | 100; explicit random seed | no | none |
| --journal | "nature"; figure preset | no | none |

Supplementary named JSON files expose every native argument, including delegated arguments. Omitted keys keep locked defaults; primary CLI options take precedence. calls_registry.json records container-read defaults. Every scientific choice must be informed by reference_advise and reference_search; absent curated evidence, show the official example and ask the user.
