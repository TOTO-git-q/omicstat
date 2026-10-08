"""Explicit scientific guardrail, sourced from the display workflow contract."""
from ospy import sc_module as S, module_kit as K

def qc(res, a, module_dir):
    return S.standard_qc(res, a, 'YG', module_dir,
        [K.qc_rule('YG' + '-03', 'display_projection_only', True, 'info', 'Fixed-reference projection is display only; neighbour label agreement does not validate cell identities.', 'Use the uncurated analysis cohort for proportions, pseudobulk, markers and DE.', 'CONVENTIONS display-vs-analysis rule')])
