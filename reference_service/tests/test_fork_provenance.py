"""The fork in app/ records its provenance: base medstat-reference 07fdebd, every change declared."""
from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HERE))
import fork_status  # noqa: E402


class ForkProvenanceTests(unittest.TestCase):
    def test_base_is_deployed_v2_not_v21(self):
        base = json.loads((HERE / "FORK_BASE.json").read_text(encoding="utf-8"))
        self.assertEqual(base["base_commit"], "07fdebd7bf37b8d58e3f0578574c5a4995ec33a8")
        self.assertEqual(base["file_count"], len(base["files"]))
        self.assertNotIn("review_v2.py", base["files"])

    def test_every_change_is_declared(self):
        report = fork_status.classify()
        self.assertEqual(report["problems"], [])
        self.assertIn("server.py", report["actual"]["modified"])
        self.assertIn("registry.py", report["actual"]["added"])
        self.assertIn("medstat_entry.py", report["actual"]["removed"])

    def test_no_v21_code(self):
        self.assertFalse((HERE / "app" / "review_v2.py").exists())
        self.assertNotIn("review_v2", (HERE / "app" / "curation.py").read_text(encoding="utf-8"))

    def test_runtime_texts_are_omicstat_only(self):
        for name in ("server.py", "service.py", "worker.py", "cli.py", "backup.py", "literature_requests.py", "curation.py"):
            text = (HERE / "app" / name).read_text(encoding="utf-8")
            self.assertNotIn("MEDSTAT_", text, name)
            self.assertNotIn("27 modules", text, name)
            self.assertNotIn("Medstat contract", text, name)
        self.assertIn('FastMCP("omicstat_reference"', (HERE / "app" / "server.py").read_text(encoding="utf-8"))

    def test_seed_is_empty(self):
        seed = json.loads((HERE / "app" / "seed" / "catalog.json").read_text(encoding="utf-8"))
        self.assertEqual((seed["papers"], seed["usages"], seed["decisions"]), ([], [], []))


if __name__ == "__main__":
    unittest.main()
