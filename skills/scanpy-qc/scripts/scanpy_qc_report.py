"""Tables and figure data come from the single computed result object."""
from ospy import figure_request as F, sc_module as S

def report(res, a):
    data = res["tables"]["cell_qc"].copy()
    data["sample"] = data[a["sample-col"]].astype(str)
    return [("qc_metrics", "os_qc_violin", {"qc": F.frame(data)},
             {"metrics": ["n_genes_by_counts", "total_counts", "pct_counts_mito"],
              "thresholds": {"n_genes_by_counts": [a["min-genes"], a["max-genes"]], "total_counts": [a["min-counts"], a["max-counts"]], "pct_counts_mito": [a["max-mito-percent"]]},
              "metric_labels": {"n_genes_by_counts": "Detected genes", "total_counts": "Total counts", "pct_counts_mito": "Mitochondrial counts (%)"}})]
