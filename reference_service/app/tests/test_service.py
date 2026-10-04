import json
import os
from pathlib import Path
from scratch import scratch_directory
import unittest
from unittest.mock import patch

import service


class ServiceTests(unittest.TestCase):
    def test_budget_preserves_json(self):
        result = service.bounded({"text": "超长\"\n" * 100000})
        self.assertTrue(result["response_omitted"])
        self.assertLess(len(json.dumps(result).encode()), service.MAX_RESPONSE_BYTES)
        self.assertEqual(json.loads(json.dumps(result)), result)

    def test_pointer_escaping_and_bounds(self):
        self.assertEqual(service.resolve_pointer({"a/b": {"~": [7]}}, "/a~1b/~0/0"), 7)
        self.assertEqual(service.invoke(service.resolve_pointer, {}, "../../bad")["status"], "needs_input")

    def test_text_pages_explicit(self):
        class FakeCore:
            def get(self, *args):
                return {"record": {"text": "abc" * 1000}}
        with patch.object(service, "core", return_value=FakeCore()):
            result = service.get_record("paper", "P1", "/record/text", 100, 2)
        self.assertEqual(len(result["data"]), 200)
        self.assertEqual(result["next_offset"], 300)
        self.assertTrue(result["partial"])

    def test_no_nonfinite_json(self):
        result = service.invoke(lambda: {"x": float("nan")})
        self.assertEqual(result["error"]["code"], "invalid_request")

    def test_review_idempotent_no_promotion(self):
        class FakeHarvest:
            def get_candidate(self, candidate_id):
                return {"candidate_id": candidate_id, "status": "candidate_review_required"}
        review = {"reviewer": "test agent", "source_locators": ["Methods/Statistics"],
                  "findings": ["Review proposal only"], "limitations": ["Synthetic test"],
                  "proposed_module_tags": ["deseq2-wald"]}
        with scratch_directory() as directory, patch.dict(os.environ, {"OMICSTAT_REFERENCE_DATA": directory}), patch.object(service, "harvest_store", return_value=FakeHarvest()):
            first = service.submit_review("synthetic-1", review)
            second = service.submit_review("synthetic-1", review)
            self.assertEqual(first["review_id"], second["review_id"])
            self.assertFalse(first["promotion_performed"])
            self.assertFalse((Path(directory) / "reference.sqlite").exists())

    def test_unknown_candidate_cannot_review(self):
        class FakeHarvest:
            def get_candidate(self, candidate_id):
                return {"error": "not_found"}
        review = {"reviewer": "test", "source_locators": ["x"], "findings": ["x"],
                  "limitations": [], "proposed_module_tags": []}
        with patch.object(service, "harvest_store", return_value=FakeHarvest()):
            self.assertEqual(service.invoke(service.submit_review, "missing", review)["error"]["code"], "invalid_request")


class NewToolFailureShapeTests(unittest.TestCase):
    def test_busy_and_broken_storage_are_structured(self):
        import sqlite3
        def busy(*_):
            raise sqlite3.OperationalError("database is locked")
        def broken(*_):
            raise sqlite3.DatabaseError("database disk image is malformed")
        for fn in (service.request_literature, service.request_status, service.cancel_request, service.propose_domain):
            with patch.object(service, "harvest_store", side_effect=busy), patch.object(service, "data_dir", side_effect=busy):
                answer = service.invoke(fn, {})
                self.assertEqual((answer["status"], answer["error"]["code"]), ("needs_input", "storage_unavailable"))
            with patch.object(service, "harvest_store", side_effect=broken), patch.object(service, "data_dir", side_effect=broken):
                answer = service.invoke(fn, {})
                self.assertEqual((answer["status"], answer["error"]["code"]), ("blocked", "storage_error"))

    def test_invalid_inputs_are_needs_input(self):
        with scratch_directory() as directory, patch.dict(os.environ, {"OMICSTAT_REFERENCE_DATA": directory}):
            try:
                self.assertEqual(service.invoke(service.request_literature, "not an object")["status"], "needs_input")
                self.assertEqual(service.invoke(service.request_status, 42)["status"], "needs_input")
                self.assertEqual(service.invoke(service.propose_domain, [])["status"], "needs_input")
            finally:
                service._instances.clear()


if __name__ == "__main__":
    unittest.main()
