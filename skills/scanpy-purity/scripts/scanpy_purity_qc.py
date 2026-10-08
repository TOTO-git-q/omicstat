"""Explicit scientific guardrail, sourced from the display workflow contract."""
from ospy import sc_module as S, module_kit as K

def qc(res, a, module_dir):
    return S.standard_qc(res, a, 'YP', module_dir,
        [K.qc_rule('YP' + '-03', 'display_curation_only', True, 'info', 'Purity cleaning is display/curation only; not valid for proportions, pseudobulk, markers or DE.', 'Rerun explicitly with retained_cells.csv for display; keep uncurated data for inference.', 'CONVENTIONS display-vs-analysis rule')])
