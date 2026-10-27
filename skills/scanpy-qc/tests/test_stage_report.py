#!/usr/bin/env python3
"""Report-stage metadata test using artificial rows; no native fit or download."""
from pathlib import Path
import importlib.util
import sys
import unittest
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "skills/_shared/py"))
spec = importlib.util.spec_from_file_location("qc_report", ROOT / "skills/scanpy-qc/scripts/scanpy_qc_report.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class StageReportTest(unittest.TestCase):
    def test_raw_audit_scope_and_metric_definitions(self):
        audit = pd.DataFrame({"cell": ["invented_a", "invented_b", "invented_c"],
                              "sample_id": ["invented_sample"] * 3,
                              "n_genes_by_counts": [2, 3, 1], "total_counts": [5, 8, 2],
                              "pct_counts_mito": [20.0, 12.5, 100.0], "retained": [True, True, False]})
        before = audit.copy(deep=True)
        res = {"tables": {"cell_qc": audit}, "summary": {"n_input_genes": 8, "n_mito_genes": 2}}
        args = {"sample-col": "sample_id", "min-genes": 1, "max-genes": 100, "min-counts": 0,
                "max-counts": 1000, "max-mito-percent": 50, "mito-prefix": "MT-", "species": "artificial_fixture",
                "annotation": "invented symbols"}
        [(name, builder, data, opts)] = module.report(res, args)
        self.assertEqual((name, builder, opts["data_stage"]), ("qc_metrics", "os_qc_violin", "raw_input"))
        self.assertEqual(data["qc"]["n"], 3)
        self.assertEqual(data["qc"]["data"]["retained"], [True, True, False])
        md = opts["metric_definitions"]["pct_counts_mito"]
        self.assertEqual(md["matched_feature_count"], 2)
        self.assertEqual(md["input_feature_count"], 8)
        self.assertEqual(md["organism"], "artificial_fixture")
        self.assertIn("same cell", md["definition"])
        pd.testing.assert_frame_equal(audit, before)

if __name__ == "__main__":
    unittest.main()
