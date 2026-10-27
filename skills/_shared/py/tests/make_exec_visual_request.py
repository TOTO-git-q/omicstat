"""Write shared-builder requests from the exact project-created R fixture."""
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from ospy.figure_request import FigureRequest, frame

source, out, journal = sys.argv[1:]
x = json.loads(pathlib.Path(source).read_text())
request = FigureRequest(out, module="synthetic-visual", module_version="0.0.0", journal=journal)
request.add("km", "os_km", data={"curves": frame(x["curves"], types={"time":"numeric", "survival":"numeric", "n_censor":"numeric"}),
    "risk": frame(x["risk"], types={"time":"numeric", "n_risk":"numeric"})}, args={"time_unit":"months"})
request.add("group_bar", "os_group_points", data={"d":frame(x["group"], types={"value":"numeric"})},
    args={"unit_col":"unit", "ylab":"Synthetic response", "display":"bar"})
request.add("standard_curve", "os_standard_curve", data={"obs":frame(x["obs"], types={"dose":"numeric", "response":"numeric"}),
    "grid":frame(x["grid"], types={"dose":"numeric", "predicted":"numeric"})},
    args={"unit":"synthetic units/mL", "model":"4PL", "lloq":.5, "uloq":100})
print(request.write())
