"""Explicit scientific guardrail, sourced from the display workflow contract."""
from ospy import sc_module as S, module_kit as K

def qc(res, a, module_dir):
    return S.standard_qc(res, a, 'YA', module_dir,
        [K.qc_rule('YA' + '-03', 'annotation_descriptive', True, 'info', 'Names are descriptive user decisions, supported by panel means and marker evidence.', 'Review the panel and label-map; unresolved clusters are retained.', 'CONVENTIONS display-vs-analysis rule')])
