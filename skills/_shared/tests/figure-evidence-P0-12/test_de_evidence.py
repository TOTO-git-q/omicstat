"""Audit archived invented DE evidence without claiming production acceptance."""
from pathlib import Path
import hashlib
import json
import struct
import unittest

ROOT = Path(__file__).resolve().parents[4]
E = ROOT / "acceptance/figure-evidence-P0-12/de-semantics"


def read(path):
    return json.loads(path.read_text())


def resolve(relative):
    path = (ROOT / relative).resolve()
    assert path.is_relative_to(ROOT.resolve()), relative
    return path


class DEEvidenceTest(unittest.TestCase):
    def test_archived_bytes_and_provenance(self):
        rows = read(E / "ARTIFACT_PROVENANCE.json")
        self.assertEqual(len(rows), len({r["path"] for r in rows}))
        self.assertGreaterEqual(sum(r["path"].endswith((".pdf", ".png")) for r in rows), 58)
        for row in rows:
            with self.subTest(path=row["path"]):
                data = resolve(row["path"]).read_bytes()
                self.assertEqual(len(data), row["bytes"])
                self.assertEqual(hashlib.sha256(data).hexdigest(), row["sha256"])
                self.assertEqual(hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest(), row["git_blob_sha1"])
                self.assertIn("Project-invented", row["provenance"])

    def test_complete_original_clauses_and_open_scope(self):
        doc = read(ROOT / "docs/build/figure-evidence-P0-12/DE_SEMANTICS_REQUIREMENTS.json")
        self.assertEqual({x["id"] for x in doc["items"]}, {f"FE-{i:03}" for i in range(12, 18)})
        self.assertEqual(sum(len(x["source_requirements"]) for x in doc["items"]), 27)
        self.assertEqual(sum(len(r["acceptance_criteria"]) for x in doc["items"] for r in x["source_requirements"]), 107)
        for item in doc["items"]:
            self.assertFalse(item["full_item_complete"])
            self.assertIsNone(item["owner_visual_review"])
            self.assertTrue(item["remaining_work"])
            clauses = {(r["proposal_key"], i): c for r in item["source_requirements"] for i, c in enumerate(r["acceptance_criteria"])}
            self.assertEqual(clauses, {(c["proposal_key"], c["acceptance_index"]): c["criterion"] for c in item["clause_coverage"]})

    def test_same_input_same_canvas(self):
        self.assertEqual((E / "before/FIXTURES.json").read_bytes(), (E / "after/FIXTURES.json").read_bytes())
        for journal, width in (("nature", 183), ("cell", 174)):
            for name in ("volcano_zero", "ma_caps", "ma_small", "ma_log_abundance", "volcano_annotation"):
                for stage in ("before", "after"):
                    spec = read(E / stage / journal / (name + ".figure_spec.json"))
                    self.assertEqual((spec["journal"], spec["width_mm"], spec["height_mm"]), (journal, width, 118))
                    png = (E / stage / journal / (name + ".png")).read_bytes()
                    self.assertEqual(png[:8], b"\x89PNG\r\n\x1a\n")
                    x, y = struct.unpack(">II", png[16:24])
                    self.assertLessEqual(abs(x - width * spec["png_dpi"] / 25.4), 1)
                    self.assertLessEqual(abs(y - 118 * spec["png_dpi"] / 25.4), 1)

    def test_absent_before_view_is_not_fabricated(self):
        observations = read(E / "before/OBSERVATIONS.json")
        for journal in ("nature", "cell"):
            item = observations[journal + "/selected_features"]
            self.assertEqual(item["status"], "unavailable_at_parent")
            self.assertTrue(item["figure_not_fabricated"])
            self.assertIn("os_selected_feature_points", item["native_lookup_error"])
            self.assertFalse((E / "before" / journal / "selected_features.png").exists())
            self.assertTrue((E / "after" / journal / "selected_features.png").is_file())

    def test_hypothesis_and_clipping_source(self):
        for journal in ("nature", "cell"):
            small = read(E / "after" / journal / "ma_small.figure_spec.json")
            self.assertEqual(small["definition"]["de_contract"]["test"]["hypothesis"], "small_effect")
            decision = small["data"]["decision_table"]
            self.assertEqual(decision["statistical_call"][6], "within_margin")
            self.assertEqual(decision["statistical_call"][7], "inconclusive")
            cap = read(E / "after" / journal / "ma_caps.figure_spec.json")
            raw = cap["data"]["raw_source"]
            self.assertEqual(raw["log2fc"][:4], [8, -8, 4, -4])
            shown = cap["data"]["display_table"]
            indices = [shown["feature_id"].index(x) for x in raw["feature_id"][:4]]
            self.assertEqual([shown["cap_direction"][i] for i in indices], ["upper", "lower", "none", "none"])
            self.assertEqual(set(cap["data"]["labelled_feature_ids"]), set(raw["feature_id"][:4]))

    def test_native_and_environment_limits_are_honest(self):
        summary = read(E / "TEST_SUMMARY.json")
        self.assertFalse(summary["full_production_acceptance"])
        self.assertIsNone(summary["owner_visual_review"])
        self.assertFalse(summary["native_context"]["muscat_native_fit_executed"])
        self.assertEqual(summary["native_context"]["versions"]["R"], "4.6.1")
        self.assertEqual(summary["actual_remote_parent"], "14ec992722ba16688d72ede47510f834a90b7ba4")
        self.assertTrue(summary["retained_failed_checks"])
        inherited = read(E / "INHERITED_FULL_CONTRACT_FAILURE.json")
        self.assertEqual(len(inherited["unregistered_candidate_package_modules"]), 18)
        self.assertTrue(inherited["all_inputs_equal_parent"])


if __name__ == "__main__":
    unittest.main()
