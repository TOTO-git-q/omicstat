"""Typed QC rules with explicit source references."""
from ospy import module_kit as K, sc_module as S

def qc(res, a, module_dir):
    extra = [K.qc_rule("YQ-03", "doublets_not_removed", a["doublet-mode"] != "filter", "warning", "Doublets were not removed.", "State the chosen doublet policy.", a["doublet-mode"]),
             K.qc_rule("YQ-04", "no_mito_features", res["summary"]["n_mito_genes"] == 0, "warning", "The declared mitochondrial prefix matched no genes.", "Check the feature namespace and organism.", a["mito-prefix"])]
    return S.standard_qc(res, a, "YQ", module_dir, extra)
