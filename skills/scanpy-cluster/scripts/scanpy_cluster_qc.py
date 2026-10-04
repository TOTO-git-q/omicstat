"""Typed QC rules with explicit source references."""
from ospy import module_kit as K, sc_module as S

def qc(res, a, module_dir):
    extra = [K.qc_rule("YC-03", "single_cluster", res["summary"]["n_clusters"] < 2, "warning", "Only one descriptive cluster was found.", "Report the prespecified resolution; do not tune it to a desired conclusion.", str(a["resolution"]))]
    return S.standard_qc(res, a, "YC", module_dir, extra)
