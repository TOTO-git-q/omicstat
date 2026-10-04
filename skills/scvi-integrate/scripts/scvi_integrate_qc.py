"""Typed QC rules with explicit source references."""
from ospy import module_kit as K, sc_module as S

def qc(res, a, module_dir):
    extra = [K.qc_rule("VI-03", "mixing_is_descriptive", True, "info", "Batch mixing does not establish biological validity.", "Review cell identity and confounding before interpretation.", "SCVI batch covariate documentation")]
    return S.standard_qc(res, a, "VI", module_dir, extra)
