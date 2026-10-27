import copy
import hashlib
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import server
from jsonschema import ValidationError


FIELDS = dict(design="paired serial dose", biological_unit="donor",
              population="All enrolled donors; no exclusions",
              comparison=dict(target="population ED50", measure="concentration ng/mL",
                              exposure="concentration", comparator="lower asymptote"),
              outcomes=[dict(name="assay response", timepoint="24 h")],
              covariates=[], missing_data="Refuse missing analysis data",
              multiplicity="One prespecified ED50; no multiple tests",
              analysis_sets=["All complete donors"])


class StudyContractTests(unittest.TestCase):
    def call(self, **changes):
        fields = copy.deepcopy(FIELDS)
        fields.update(changes)
        return json.loads(server.omicstat_create_study_contract(**fields))

    def test_saved_bytes_hash_and_stability(self):
        with tempfile.TemporaryDirectory() as root, patch.object(server, "RUNS_ROOT", root):
            a = self.call()
            b = self.call(comparison=dict(reversed(list(FIELDS["comparison"].items()))))
            self.assertNotEqual(a["path"], b["path"])
            self.assertEqual(a["sha256"], b["sha256"])
            data = Path(a["path"]).read_bytes()
            self.assertEqual(hashlib.sha256(data).hexdigest(), a["sha256"])
            self.assertEqual(json.loads(data), a["study_contract"])
            self.assertTrue(a["validated"])
            self.assertNotEqual(a["sha256"], self.call(biological_unit="animal")["sha256"])

    def test_invalid_fields_do_not_allocate_run(self):
        with tempfile.TemporaryDirectory() as root, patch.object(server, "RUNS_ROOT", root):
            for change in [dict(design=" "), dict(biological_unit=""), dict(population=None),
                           dict(outcomes=[]), dict(outcomes=[dict(name="response")]),
                           dict(outcomes=[dict(name="response", timepoint=" ")]),
                           dict(covariates=[""]), dict(analysis_sets=[]),
                           dict(multiplicity=None), dict(comparison={"target": "ED50"})]:
                with self.subTest(change=change), self.assertRaises((ValueError, ValidationError)):
                    self.call(**change)
            self.assertEqual(list(Path(root).iterdir()), [])

    def test_symlink_run_root_refused(self):
        with tempfile.TemporaryDirectory() as root:
            link = Path(root) / "redirect"
            link.symlink_to(Path(root), target_is_directory=True)
            with patch.object(server, "RUNS_ROOT", str(link)), self.assertRaisesRegex(ValueError, "symlink"):
                self.call()

    def test_registered_surface(self):
        import asyncio
        names = {tool.name for tool in asyncio.run(server.mcp.list_tools())}
        self.assertEqual(names, {"omicstat_create_study_contract", "omicstat_run",
                                "omicstat_read", "omicstat_describe", "omicstat_list_modules",
                                "omicstat_validate_publication"})


if __name__ == "__main__":
    unittest.main()
