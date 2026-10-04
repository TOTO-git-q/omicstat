"""Tables and figure data come from the single computed result object."""
from ospy import figure_request as F, sc_module as S

def report(res, a):
    return [("marker_dotplot", "os_marker_dotplot", {"md": F.frame(res["tables"]["marker_dot_data"])},
             {"mean_definition": "log_mean", "descriptive_note": True, "scaled": False, "clip": 2})]
