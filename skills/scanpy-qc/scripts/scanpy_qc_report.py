"""Tables and figure data come from the single computed result object."""
from ospy import figure_request as F, sc_module as S

def report(res, a):
    data = res["tables"]["cell_qc"].copy()
    data["sample"] = data[a["sample-col"]].astype(str)
    return [("qc_metrics", "os_qc_violin", {"qc": F.frame(data)},
             {"data_stage": "raw_input",
              "metric_definitions": {
                  "n_genes_by_counts": {"unit": "detected RNA features", "definition": "Number of input features with raw count greater than zero per cell", "measured_at": "raw_input", "input_feature_count": res["summary"]["n_input_genes"]},
                  "total_counts": {"unit": "raw RNA counts", "definition": "Sum of raw counts across input RNA features per cell", "measured_at": "raw_input", "input_feature_count": res["summary"]["n_input_genes"]},
                  "pct_counts_mito": {"unit": "percent", "definition": "100 times raw counts in prefix-matched input RNA features divided by total raw RNA counts in the same cell", "measured_at": "raw_input",
                                      "mitochondrial_prefix": a["mito-prefix"], "matched_feature_count": res["summary"]["n_mito_genes"], "input_feature_count": res["summary"]["n_input_genes"],
                                      "organism": a["species"], "annotation": a["annotation"]}},
              "metrics": ["n_genes_by_counts", "total_counts", "pct_counts_mito"],
              "thresholds": {"n_genes_by_counts": [a["min-genes"], a["max-genes"]], "total_counts": [a["min-counts"], a["max-counts"]], "pct_counts_mito": [a["max-mito-percent"]]},
              "metric_labels": {"n_genes_by_counts": "Detected genes", "total_counts": "Total counts", "pct_counts_mito": "Mitochondrial counts (%)"}})]
