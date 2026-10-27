#!/usr/bin/env python3
"""Write an actual Scanpy report request from invented pre-filter metrics only.

This fixture tests the Python-report/R-render boundary. It does not invoke
Scanpy inference or use PBMC, pancreas or other public biological records.
"""
from pathlib import Path
import importlib.util
import sys
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "skills/_shared/py"))
from ospy.figure_request import FigureRequest
spec = importlib.util.spec_from_file_location("stage_qc_report", ROOT / "skills/scanpy-qc/scripts/scanpy_qc_report.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
out = Path(sys.argv[1]); out.mkdir(parents=True, exist_ok=True)
audit = pd.DataFrame({"cell": [f"invented_{i}" for i in range(8)], "sample_id": ["artificial_A"]*4 + ["artificial_B"]*4,
                      "n_genes_by_counts": [2,3,4,5,2,3,4,5], "total_counts": [4,6,8,10,5,7,9,11],
                      "pct_counts_mito": [0,10,20,60,5,15,25,70], "retained": [True,True,True,False]*2})
res = {"tables": {"cell_qc": audit}, "summary": {"n_input_genes": 8, "n_mito_genes": 2}}
args = {"sample-col": "sample_id", "min-genes": 1, "max-genes": 100, "min-counts": 0, "max-counts": 1000,
        "max-mito-percent": 50, "mito-prefix": "MT-", "species": "artificial_fixture", "annotation": "invented symbols"}
request = FigureRequest(out, module="scanpy-qc", module_version="1.0.0", journal="nature")
for name, builder, data, opts in module.report(res, args):
    request.add(name, builder, data=data, args=opts, width="double")
request.write()
audit.to_csv(out/"synthetic_input_audit.csv", index=False)
print("Wrote project-generated eight-row Scanpy report fixture; no engine inference claimed")
