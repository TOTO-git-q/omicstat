"""Typed QC rules with explicit source references."""
from ospy import module_kit as K, sc_module as S

def qc(res, a, module_dir):
    import numpy as np
    table = res["tables"]["feature_table"]
    extra = [K.qc_rule("YM-03", "descriptive_markers", True, "info", "Cells are descriptive units, not biological replicates.", "Use muscat-pseudobulk for condition-level inference.", "scanpy rank_genes_groups warning"),
             K.qc_rule("YM-04", "nonfinite_fold_change", bool((~np.isfinite(table["log2fc"])).any()), "warning", "Some estimated log2 fold changes are nonfinite.", "Inspect zero-expression groups and retain the full table.", "scanpy rank_genes_groups"),
             K.qc_rule("YM-05", "all_padj_missing", bool(table["padj"].isna().all()), "blocker", "All adjusted P values are missing.", "Inspect the input and test design.", "ENGINEERING_PLAN 4.5")]
    return S.standard_qc(res, a, "YM", module_dir, extra)
