"""Tables and figure data come from the single computed result object."""
from ospy import figure_request as F, sc_module as S

def report(res, a):
    return [("umap_clusters", "os_embedding", {"emb": F.frame(S.embedding_frame(res["adata"], a["cluster-col"]))},
             {"group_col": a["cluster-col"], "reduction": "UMAP", "label": True}),
            ("umap_samples", "os_embedding", {"emb": F.frame(S.embedding_frame(res["adata"], a["sample-col"]))},
             {"group_col": a["sample-col"], "reduction": "UMAP", "label": False})]
