"""Reference store tests (omicstat fork).

Ported from the medstat-reference v2 tests. The base tests ran against the medstat seed; the omicstat
seed is empty, so behaviour with records is exercised on a synthetic omics fixture catalogue
(tests/fixtures/omics_catalog_fixture.json) and the empty-seed behaviour on the real app seed.
"""
from __future__ import annotations

import hashlib
import json
import unittest
from pathlib import Path

from reference_core import ReferenceError, ReferenceStore
from scratch import scratch_directory


ROOT = Path(__file__).resolve().parents[1]
SEED = ROOT / "seed" / "catalog.json"
FIXTURE = ROOT / "tests" / "fixtures" / "omics_catalog_fixture.json"
ORDER = [m["module"] for m in json.loads((ROOT / "method_map.json").read_text(encoding="utf-8"))["modules"]]


def contract(**extra: object) -> dict[str, object]:
    result: dict[str, object] = {
        "study_design": "two-group, 3 vs 3 biological replicates, one batch",
        "analysis_population": "samples.csv; 6 samples; replicate unit = mouse",
        "estimand": "condition treated vs control; shrunken log2 fold change",
        "exposure_or_intervention": "condition = treated",
        "comparator": "control",
        "outcomes": ["Mus musculus genes, GENCODE vM33"],
        "covariates": ["batch"],
        "missing_data": "genes with >= 10 counts in >= 3 samples kept",
        "multiplicity": "Benjamini-Hochberg, padj < 0.05"}
    result.update(extra)
    return result


class ReferenceCoreTests(unittest.TestCase):
    def setUp(self) -> None:
        self.scratch = scratch_directory()
        self.dir = Path(self.scratch.__enter__())
        self.seed = self.dir / "catalog.json"
        self.seed.write_bytes(FIXTURE.read_bytes())
        self.store = ReferenceStore(self.dir / "reference.sqlite", self.seed)

    def tearDown(self) -> None:
        self.store.close()
        self.scratch.__exit__(None, None, None)

    def test_registry_is_the_method_map_not_the_seed(self) -> None:
        status = self.store.status()
        self.assertEqual(38, status["registered_modules"])
        self.assertEqual({"deseq2-wald": 3, "scran-cluster": 1, "seurat-qc": 2}, status["module_counts"])
        self.assertIn("limma-voom", status["modules_without_curated_evidence"])
        self.assertEqual(35, len(status["modules_without_curated_evidence"]))
        rules = json.loads((ROOT / "decision_rules.json").read_text(encoding="utf-8"))
        self.assertEqual({}, rules["modules"])
        self.assertEqual(4, len(rules["reusable_covariate_goals"]))
        self.assertEqual(9, len(rules["common_required"]))

    def test_status_and_seed_hash(self) -> None:
        status = self.store.status()
        self.assertEqual({"papers": 4, "usages": 4, "decisions": 2}, status["counts"])
        self.assertEqual(hashlib.sha256(self.seed.read_bytes()).hexdigest(), status["seed_hash"])

    def test_unicode_alias_and_sql_like_queries_are_safe(self) -> None:
        self.assertGreater(self.store.search("差异表达")["total"], 0)
        self.assertGreater(self.store.search("DESeq2")["total"], 0)
        self.assertEqual(0, self.store.search("%' OR 1=1 --")["total"])

    def test_pagination_is_deterministic_and_bounded(self) -> None:
        first = self.store.search(limit=3)
        second = self.store.search(limit=3, offset=3)
        self.assertEqual(3, len(first["results"]))
        self.assertEqual(3, len(second["results"]))
        self.assertNotEqual([x["record_id"] for x in first["results"]], [x["record_id"] for x in second["results"]])
        self.assertEqual(3, first["next_offset"])
        with self.assertRaises(ReferenceError): self.store.search(limit=51)

    def test_module_search_includes_related_papers_and_evidence_first_decisions(self) -> None:
        result = self.store.search(module="deseq2-wald", limit=50)
        types = [x["record_type"] for x in result["results"]]
        self.assertIn("paper", types)
        self.assertIn("usage", types)
        self.assertIn("decision", types)
        self.assertEqual("decision", types[0])
        self.assertEqual("curated_evidence_available", result["curated_evidence"]["status"])

    def test_registered_module_without_records_is_not_unknown(self) -> None:
        result = self.store.search(module="limma-voom")
        self.assertEqual(0, result["total"])
        self.assertEqual("no_curated_evidence_yet", result["curated_evidence"]["status"])
        advice = self.store.advise("limma-voom", contract())
        self.assertEqual("review_required", advice["status"])
        self.assertEqual("no_curated_evidence_yet", advice["curated_evidence"]["status"])
        self.assertEqual([], advice["candidate_decisions"])
        self.assertEqual([], advice["parameter_options"])
        for module in ("rcs-analysis", "agreement", "not-a-module"):
            with self.assertRaises(ReferenceError) as unknown:
                self.store.search(module=module)
            self.assertEqual("unknown_module", unknown.exception.code)
            with self.assertRaises(ReferenceError):
                self.store.advise(module, contract())

    def test_get_relations_and_structured_errors(self) -> None:
        usage = self.store.get("usage", "F-U-001")
        self.assertIn("F-P-001", usage["related_ids"]["paper_ids"])
        self.assertIn("F-D-001", usage["related_ids"]["decision_ids"])
        with self.assertRaises(ReferenceError) as unknown: self.store.get("path", "anything")
        self.assertEqual("unknown_record_type", unknown.exception.code)
        with self.assertRaises(ReferenceError) as absent: self.store.get("paper", "not-a-paper")
        self.assertEqual("not_found", absent.exception.code)

    def test_missing_and_wrong_typed_context_needs_input(self) -> None:
        result = self.store.advise("seurat-qc", {"study_design": "", "covariates": "batch"})
        self.assertEqual("needs_input", result["status"])
        fields = {x["field"] for x in result["material_unknowns"]}
        self.assertTrue({"study_design", "analysis_population", "covariates", "multiplicity"} <= fields)
        self.assertFalse(result["execution_authorized"])
        self.assertFalse(result["automatic_parameter_application"])

    def test_description_fields_accept_objects(self) -> None:
        result = self.store.advise("deseq2-wald", contract(estimand={"contrast": "treated vs control", "effect": "log2FC"}))
        self.assertEqual("review_required", result["status"])
        empty = self.store.advise("deseq2-wald", contract(estimand={}))
        self.assertIn("estimand", {x["field"] for x in empty["material_unknowns"]})

    def test_unknown_sentinels_and_contract_bounds_fail_closed(self) -> None:
        result = self.store.advise("deseq2-wald", contract(estimand="unknown", comparator="待定"))
        unknowns = {item["field"]: item for item in result["material_unknowns"]}
        self.assertEqual("unknown_or_not_applicable", unknowns["estimand"]["provided_as"])
        self.assertEqual("unknown_or_not_applicable", unknowns["comparator"]["provided_as"])
        with self.assertRaises(ReferenceError) as long_value:
            self.store.advise("deseq2-wald", contract(estimand="x" * 4001))
        self.assertEqual("study_contract_string_too_long", long_value.exception.code)
        with self.assertRaises(ReferenceError) as too_large:
            self.store.advise("deseq2-wald", contract(estimand="x" * 4000, note=["x" * 3000] * 22))
        self.assertEqual("study_contract_too_large", too_large.exception.code)

    def test_only_located_root_reviewed_usages_become_parameter_options(self) -> None:
        wald = self.store.advise("deseq2-wald", contract())
        self.assertEqual("review_required", wald["status"])
        candidates = {x["usage_id"]: x for x in wald["candidate_usages"]}
        self.assertFalse(candidates["F-U-001"]["eligible_for_parameter_proposal"])
        self.assertEqual("legacy_unspecified", candidates["F-U-001"]["support_role"])
        self.assertTrue(candidates["F-U-003"]["eligible_for_parameter_proposal"])
        self.assertEqual(["F-U-003"], [x["usage_id"] for x in wald["parameter_options"]])
        self.assertEqual("not_checked_against_study_contract", wald["parameter_options"][0]["applicability_status"])
        qc = self.store.advise("seurat-qc", contract())
        self.assertEqual([], qc["parameter_options"])  # pending verification never becomes an option

    def test_bare_verified_or_passed_text_cannot_clear_the_gate(self) -> None:
        usage = self.store.get("usage", "F-U-004")["record"]
        self.assertFalse(self.store._eligible(usage))
        usage.update({"verification_status": "passed verified", "reviewer_status": "root_reviewed", "support_role": "direct_application", "implementation_compatibility": {"status": "inventory_supported"}})
        self.assertFalse(self.store._eligible(usage))

    def test_seed_immutability_duplicate_dangling_and_unregistered_rejection(self) -> None:
        changed = self.dir / "changed.json"
        payload = json.loads(self.seed.read_text(encoding="utf-8")); payload["limitations"].append("different")
        changed.write_text(json.dumps(payload), encoding="utf-8")
        with self.assertRaises(ReferenceError) as mismatch: ReferenceStore(self.dir / "reference.sqlite", changed)
        self.assertEqual("seed_mismatch", mismatch.exception.code)
        duplicate = self.dir / "duplicate.json"; payload = json.loads(self.seed.read_text(encoding="utf-8")); payload["papers"].append(payload["papers"][0]); duplicate.write_text(json.dumps(payload), encoding="utf-8")
        with self.assertRaises(ReferenceError) as duplicated: ReferenceStore(self.dir / "duplicate.sqlite", duplicate)
        self.assertEqual("invalid_catalog", duplicated.exception.code)
        dangling = self.dir / "dangling.json"; payload = json.loads(self.seed.read_text(encoding="utf-8")); payload["usages"][0]["paper_id"] = "missing"; dangling.write_text(json.dumps(payload), encoding="utf-8")
        with self.assertRaises(ReferenceError) as broken: ReferenceStore(self.dir / "dangling.sqlite", dangling)
        self.assertEqual("dangling_reference", broken.exception.code)
        foreign = self.dir / "foreign.json"; payload = json.loads(self.seed.read_text(encoding="utf-8")); payload["usages"][0]["module_tags"] = ["rcs-analysis"]; foreign.write_text(json.dumps(payload), encoding="utf-8")
        with self.assertRaises(ReferenceError) as outside: ReferenceStore(self.dir / "foreign.sqlite", foreign)
        self.assertEqual("invalid_catalog", outside.exception.code)


class EmptySeedTests(unittest.TestCase):
    """The deployed seed is empty; every registered module still works."""
    def setUp(self) -> None:
        self.scratch = scratch_directory()
        self.dir = Path(self.scratch.__enter__())
        self.store = ReferenceStore(self.dir / "reference.sqlite", SEED)

    def tearDown(self) -> None:
        self.store.close()
        self.scratch.__exit__(None, None, None)

    def test_seed_is_empty(self) -> None:
        raw = json.loads(SEED.read_text(encoding="utf-8"))
        self.assertEqual(([], [], []), (raw["papers"], raw["usages"], raw["decisions"]))
        status = self.store.status()
        self.assertEqual({"papers": 0, "usages": 0, "decisions": 0}, status["counts"])
        self.assertEqual(sorted(ORDER), status["modules_without_curated_evidence"])

    def test_every_module_answers_no_curated_evidence_yet(self) -> None:
        for module in ORDER:
            found = self.store.search(module=module)
            self.assertEqual((0, "no_curated_evidence_yet"), (found["total"], found["curated_evidence"]["status"]), module)
            advice = self.store.advise(module, contract())
            self.assertEqual("review_required", advice["status"], module)
            self.assertEqual("no_curated_evidence_yet", advice["curated_evidence"]["status"], module)
            self.assertFalse(advice["automatic_parameter_application"])
        needs = self.store.advise("scanpy-qc", {})
        self.assertEqual("needs_input", needs["status"])


if __name__ == "__main__":
    unittest.main()
