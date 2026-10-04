"""Configuration validation for omicstat_reference (offline).

The staged build context (stage_build.py = the fork in app/) is loaded with the fork's own loaders in a
subprocess, exactly as the container will load it.

  python -m unittest discover -s tests -p "test_*.py"      (from reference_service/)
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HERE))
import stage_build  # noqa: E402

APP = HERE / "app"
EXPECTED_MODULES = [
    "deseq2-wald", "deseq2-qc", "deseq2-lrt", "edger-qlf", "limma-voom", "limma-array", "limma-dupcor", "sva-batch",
    "clusterprofiler-ora", "clusterprofiler-gsea", "clusterprofiler-compare", "fgsea-prerank", "gsva-score",
    "limma-camera", "seurat-qc", "seurat-cluster", "seurat-integrate", "seurat-markers", "seurat-modulescore",
    "scater-qc", "scran-cluster", "batchelor-integrate", "scran-markers", "aucell-score", "singler-annotate",
    "muscat-pseudobulk", "speckle-propeller", "cellchat-communication", "monocle3-trajectory",
    "slingshot-trajectory", "wgcna-network", "maftools-landscape", "immunedeconv-infiltration", "scanpy-qc",
    "scanpy-cluster", "scanpy-markers", "scvi-integrate", "scanvi-annotate"]

PROBE = textwrap.dedent(r'''
    import datetime as dt, json, tempfile
    from pathlib import Path
    import discovery, harvest, literature_requests, curation, registry
    from reference_core import ReferenceStore, ReferenceError
    out = {}
    j = discovery.load_journals(); p = discovery.load_profiles(); m = harvest._load_method_map()
    out["journals"] = len(j["journals"]); out["profiles"] = sorted(p["profiles"]); out["order"] = m["order"]
    out["registry"] = registry.module_order()
    out["query"] = discovery.build_query(p["profiles"]["deseq2-wald"], p, j, today=dt.date(2026, 9, 29))
    out["known_modules"] = sorted(curation.known_modules())
    out["schema_enum"] = literature_requests.load_schema()["properties"]["module"]["enum"]
    out["request_ok"] = literature_requests.validate_request({"module": "scran-cluster", "question": "Resolution choice for graph clustering",
        "study_context": {"design": "multi_sample_single_cell", "data_structure": "single_cell_counts", "outcome_type": "cell_clusters_or_types"},
        "requester": "config test"})["module"]
    refused = []
    for bad in ({"module": "rcs-analysis"}, {"study_context": {"design": "cohort", "data_structure": "time_to_event", "outcome_type": "binary"}}):
        req = {"module": "scran-cluster", "question": "x", "requester": "t",
               "study_context": {"design": "other", "data_structure": "other", "outcome_type": "other"}}
        req.update(bad)
        try:
            literature_requests.validate_request(req); refused.append(False)
        except ValueError:
            refused.append(True)
    out["clinical_refused"] = refused
    with tempfile.TemporaryDirectory() as tmp:
        store = ReferenceStore(Path(tmp) / "reference.sqlite", Path("seed/catalog.json"))
        out["counts"] = store.status()["counts"]
        found = store.search(module="deseq2-wald")
        out["search_module"] = [found["total"], found["curated_evidence"]["status"]]
        out["advise_status"] = store.advise("deseq2-wald", {})["status"]
        try:
            store.search(module="rcs-analysis"); out["rcs_unknown"] = False
        except ReferenceError as exc:
            out["rcs_unknown"] = exc.code == "unknown_module"
        store.close()
    print(json.dumps(out))
''')


class ConfigTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = Path(tempfile.mkdtemp(prefix="omicref-stage-"))
        cls.staged = cls.tmp / "context"
        stage_build.stage(cls.staged)
        env = {"PYTHONPATH": str(cls.staged), "PYTHONDONTWRITEBYTECODE": "1", "PATH": os.environ.get("PATH", "")}
        if os.environ.get("SYSTEMROOT"):
            env["SYSTEMROOT"] = os.environ["SYSTEMROOT"]
        run = subprocess.run([sys.executable, "-c", PROBE], cwd=cls.staged, capture_output=True, text=True, env=env)
        if run.returncode != 0:
            raise AssertionError(run.stderr[-3000:])
        cls.probe = json.loads(run.stdout.strip().splitlines()[-1])

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def test_loaders_accept_config_and_registry_is_the_method_map(self):
        self.assertEqual(self.probe["journals"], 38)
        self.assertEqual(self.probe["profiles"], sorted(EXPECTED_MODULES))
        self.assertEqual(self.probe["order"], EXPECTED_MODULES)
        self.assertEqual(self.probe["registry"], EXPECTED_MODULES)
        self.assertEqual(self.probe["known_modules"], sorted(EXPECTED_MODULES))
        self.assertEqual(self.probe["schema_enum"], EXPECTED_MODULES + ["unmapped"])
        self.assertEqual(self.probe["request_ok"], "scran-cluster")
        self.assertEqual(self.probe["clinical_refused"], [True, True])

    def test_query_composition(self):
        q = self.probe["query"]
        self.assertIn('METHODS:"DESeq2"', q)
        self.assertIn("FIRST_PDATE:[2020-01-01 TO 2026-09-29]", q)
        self.assertIn('ISSN:"1474-760X"', q)
        self.assertNotIn('ISSN:"0028-4793"', q)

    def test_empty_seed_answers_without_unknown_module(self):
        self.assertEqual(self.probe["counts"], {"papers": 0, "usages": 0, "decisions": 0})
        self.assertEqual(self.probe["search_module"], [0, "no_curated_evidence_yet"])
        self.assertEqual(self.probe["advise_status"], "needs_input")
        self.assertTrue(self.probe["rcs_unknown"])

    def test_staged_provenance(self):
        record = json.loads((self.staged / "STAGED.json").read_text(encoding="utf-8"))
        self.assertEqual(record["service"], "omicstat_reference")
        self.assertIn("07fdebd", record["fork_base"])
        self.assertFalse((self.staged / "medstat_entry.py").exists())

    def test_journals_and_profiles_files(self):
        doc = json.loads((APP / "journals.json").read_text(encoding="utf-8"))
        self.assertEqual(doc["schema"], "omicstat.reference.journals.v1")
        issn = re.compile(r"^\d{4}-\d{3}[\dX]$")
        for j in doc["journals"]:
            self.assertIn(j["tier"], ("A", "B"))
            self.assertTrue(all(issn.match(x) for x in j["issn"]), j["name"])
        prof = json.loads((APP / "discovery_profiles.json").read_text(encoding="utf-8"))
        self.assertEqual(prof["schema"], "omicstat.reference.discovery-profiles.v1")
        self.assertEqual(prof["shared_m1m2_profile_drift"], {})

    def test_compose_isolated_from_medstat(self):
        text = (HERE / "compose.yaml").read_text(encoding="utf-8")
        self.assertIn("name: omicstat-reference", text)
        self.assertIn("container_name: omicstat-reference", text)
        self.assertRegex(text, r"image: omicstat-reference:\S+")
        self.assertNotIn("ports:", text)
        self.assertNotIn("MEDSTAT_", text)
        self.assertNotRegex(text, r"container_name:\s*medstat|image:\s*medstat|medstat-reference/data")
        for needle in ("read_only: true", "cap_drop: [ALL]", "no-new-privileges:true", 'user: "1000:1000"',
                       "../runtime/data:/data", "../runtime/logs:/logs", "OMICSTAT_REFERENCE_DATA: /data",
                       "OMICSTAT_REFERENCE_LOGS: /logs"):
            self.assertIn(needle, text)

    def test_config_matches_builder(self):
        if not (HERE.parent / ".git").exists():
            self.skipTest("no git checkout (release archive): build_config --check needs git history")
        # Check every historical generated asset plus the integration's complete
        # method-map extension (current router hash and code-derived statuses).
        run = subprocess.run([sys.executable, str(HERE.parent / "tools/check_reference_integration.py")], capture_output=True, text=True)
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)


if __name__ == "__main__":
    unittest.main()
