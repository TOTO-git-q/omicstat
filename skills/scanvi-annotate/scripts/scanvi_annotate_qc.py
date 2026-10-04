"""Typed QC rules with explicit source references."""
from ospy import module_kit as K, sc_module as S

def qc(res, a, module_dir):
    extra = [K.qc_rule("VA-03", "low_probability", res["summary"]["n_low_confidence"] > 0, "warning", "Some predictions fall below the display confidence cutoff.", "Review labels; probabilities are not calibrated accuracy.", str(a["min-confidence"]))]
    return S.standard_qc(res, a, "VA", module_dir, extra)
