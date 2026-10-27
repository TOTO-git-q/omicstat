"""Tables and figure data come from the single computed result object."""
from ospy import figure_request as F, sc_module as S

def report(res, a):
    embedding = S.embedding_frame(res["adata"], a["prediction-col"]).rename(columns={a["prediction-col"]: "Predicted label"})
    return [("umap_annotations", "os_embedding", {"emb": F.frame(embedding)},
             {"group_col": "Predicted label", "family": a["prediction-col"], "reduction": "UMAP", "label": False}),
            ("prediction_probability", "os_feature_embedding", {"emb": F.frame(S.embedding_frame(res["adata"], a["prediction-col"])),
             "values": F.vector(res["tables"]["annotations"]["max_probability"].tolist(), type="numeric", names=res["tables"]["annotations"]["cell"].tolist())},
             {"feature": "Maximum class probability", "value_title": "Class probability", "italic": False, "reduction": "UMAP"})]
