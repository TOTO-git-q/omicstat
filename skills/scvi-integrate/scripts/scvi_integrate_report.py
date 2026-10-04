"""Tables and figure data come from the single computed result object."""
from ospy import figure_request as F, sc_module as S

def report(res, a):
    frames = res["tables"]["embedding_comparison"]
    return [("umap_" + stage, "os_embedding", {"emb": F.frame(frames[frames["stage"] == stage].drop(columns="stage"))},
             {"group_col": a["batch-col"], "reduction": "UMAP", "label": False}) for stage in ("before", "after")]
