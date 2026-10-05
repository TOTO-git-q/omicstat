#!/usr/bin/env python3
"""Focused tests for omicstat publication contracts and MCP envelope logic."""

import atexit
import csv
import json
import os
import shutil
import sys
import subprocess
import tempfile
import unittest
from contextlib import contextmanager
from pathlib import Path
from unittest import mock


HERE = os.path.dirname(os.path.abspath(__file__))
SUITE_ROOT = str(Path(HERE).parent)
sys.path.insert(0, HERE)


def ensure_dev_native_env():
    """Point the native engine at a usable native-env.json BEFORE server is
    imported (server.NATIVE_ENV is resolved at import time).

    Order: an explicit OMICSTAT_NATIVE_ENV; the real environment made by
    env/native/setup_native.R (<suite>/.omicstat-r/native-env.json); otherwise
    a TEMPORARY development environment: the Rscript on PATH, the library that
    holds ggplot2 (override with OMICSTAT_TEST_R_LIBRARY) and the suite's
    env/native/Rprofile.omicstat, written to a temp file and exported as
    OMICSTAT_NATIVE_ENV for this process and its children.  Returns the path,
    or None when no Rscript exists (native cases then skip)."""
    given = os.environ.get("OMICSTAT_NATIVE_ENV")
    if given and os.path.isfile(given):
        return given
    real = os.path.join(SUITE_ROOT, ".omicstat-r", "native-env.json")
    if os.path.isfile(real) and not given:
        return real
    rscript = shutil.which("Rscript")
    if not rscript:
        return None
    library = os.environ.get("OMICSTAT_TEST_R_LIBRARY")
    if not library:
        probe = subprocess.run([rscript, "-e", "cat(dirname(find.package('ggplot2')))"],
                               stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=120)
        library = probe.stdout.strip()
    if not library or not os.path.isdir(library):
        return None
    folder = tempfile.mkdtemp(prefix="omicstat-dev-native-")
    atexit.register(shutil.rmtree, folder, True)
    path = os.path.join(folder, "native-env.json")
    with open(path, "w", encoding="utf-8") as fh:
        json.dump({"schema": "omicstat.native-env.v1", "note": "temporary test environment",
                   "rscript": rscript, "library": library,
                   "rprofile": os.path.join(SUITE_ROOT, "env", "native", "Rprofile.omicstat")}, fh)
    os.environ["OMICSTAT_NATIVE_ENV"] = path
    return path


DEV_NATIVE_ENV = ensure_dev_native_env()

import publication  # noqa: E402
import server  # noqa: E402

# The fixture module of every module-dependent test: the environment
# self-test, omicstat's utility module (section-1 router row, module rule
# record, entry script on disk).
FIXTURE_MODULE = "omicstat-selftest"


def _fixture_module_installed(name=FIXTURE_MODULE):
    try:
        server._entry_path(name)
    except (ValueError, RuntimeError):
        return False
    return bool(publication.load_rule_catalogs(name).get("ok"))


requires_installed_module = unittest.skipUnless(
    _fixture_module_installed(),
    "requires the fixture module %s (router row + module rule record)" % FIXTURE_MODULE,
)
requires_native_engine = unittest.skipUnless(
    server._native_available(),
    "no native omicstat environment and no Rscript for a temporary one",
)


def valid_contract():
    return {
        "schema_version": publication.STUDY_CONTRACT_VERSION,
        "study_design": "parallel randomized trial",
        "analysis_population": {"description": "All randomized participants"},
        "estimand": {"summary_measure": "risk ratio", "timepoint": "30 days"},
        "exposure_or_intervention": {"name": "Treatment"},
        "comparator": {"name": "Control"},
        "outcomes": [{"name": "Primary outcome", "timepoint": "30 days"}],
        "covariates": [],
        "missing_data": {"strategy": "complete outcome ascertainment"},
        "multiplicity": {"strategy": "single primary outcome"},
        "analysis_sets": [{"name": "intention-to-treat"}],
        "semantic_declarations": {
            "study_design": {"design_type": "parallel randomized trial"},
            "population": {"definition": "all randomized participants"},
            "estimand": {"measure": "risk ratio", "target": "30-day primary outcome"},
            "exposure": {"variable_or_intervention": "Treatment"},
            "comparator": {"definition": "Control"},
            "outcomes": [{"identity": "Primary outcome", "timing": "30 days"}],
            "missing_data": {"strategy": "complete outcome ascertainment"},
            "multiplicity": {"strategy": "single primary outcome"},
        },
    }


def base_manifest(outdir, run_id="11111111-1111-4111-8111-111111111111"):
    return {
        "run_id": run_id,
        "module": FIXTURE_MODULE,
        "engine": "native",
        "exit_code": 0,
        "duration_s": 0.1,
        "outdir": outdir,
        "requested_outdir": None,
        "command": "Rscript run_omicstat_selftest.R",
        "command_argv": ["Rscript", "run_omicstat_selftest.R"],
        "artifact_count": 1,
        "engine_artifact_count": 1,
        "artifacts": {},
        "qc_triggered": [],
        "engine_warnings": [],
        "effect_table": [],
        "effect_table_sources": [],
        "effect_table_schema": "none",
        "degenerate_estimates": [],
        "results_summary": {},
        "stderr_tail": "",
        "stdout_tail": "",
        "timed_out": False,
        "request": {
            "module": FIXTURE_MODULE, "engine": "native", "args": {},
            "study_contract": valid_contract(),
        },
    }


def complete_versions(repository):
    entry = server._entry_path(FIXTURE_MODULE)
    return {
        "python": "test", "mcp": "test", "r": "test",
        "execution_engine": "native",
        "python_packages": {"mcp": "test"},
        "r_session_info": "R version test",
        "r_packages": {"base": "test"},
        "repository": repository,
        "module_entry_script": {
            "path": os.path.relpath(entry, server.SUITE).replace("\\", "/"),
            "sha256": publication.sha256_file(entry),
        },
        "container_image_id": None,
        "effect_validator_sha256": publication.sha256_file(server.EFFECT_VALIDATOR),
        "publication_module_rules_sha256": publication.sha256_file(
            os.path.join(server.SKILLS_DIR, "_shared", "publication", "module_rules_v1.json")),
        "publication_universal_rules_sha256": publication.sha256_file(
            os.path.join(server.SKILLS_DIR, "_shared", "publication", "universal_rules_v1.json")),
        "publication_finalizer_sha256": publication.sha256_file(publication.__file__),
    }


def observed_repository_versions():
    """Build a release-ready fixture from the current trust-boundary state."""
    entry = os.path.relpath(server._entry_path(FIXTURE_MODULE), server.SUITE).replace("\\", "/")
    commit, dirty, identity = publication._observed_repository_state(entry)
    if commit is None or dirty is None:
        raise RuntimeError("test repository state is unavailable")
    return {
        "commit": commit,
        "dirty": dirty,
        "worktree_identity": identity if dirty else None,
    }


@contextmanager
def temporary_directory_with_windows_cleanup():
    """Remove a deep test directory through the native filesystem boundary."""
    parent = tempfile.mkdtemp()
    directory = os.path.join(parent, "publication-native-boundary-" + "x" * 96)
    os.makedirs(publication._native_path(directory), exist_ok=True)
    try:
        yield directory
    finally:
        shutil.rmtree(publication._native_path(directory))
        os.rmdir(publication._native_path(parent))


class PublicationContractTests(unittest.TestCase):
    def test_native_path_uses_extended_windows_prefix_at_filesystem_boundary(self):
        probe = os.path.join(tempfile.gettempdir(), "x" * 240, "artifact.json")
        native = publication._native_path(probe)
        if os.name == "nt":
            self.assertTrue(native.startswith("\\\\?\\"))
        else:
            self.assertEqual(probe, native)

    def test_json_schemas_are_valid_draft_202012(self):
        if publication.jsonschema is None:
            self.skipTest("jsonschema is unavailable")
        for name in (
            "study_contract", "literature_evidence", "publication_review",
            "publication_manifest",
        ):
            publication.jsonschema.Draft202012Validator.check_schema(
                publication.load_schema(name)
            )

    def test_study_contract_default_version_and_validation(self):
        contract = valid_contract()
        del contract["schema_version"]
        normalized, errors = publication.normalize_study_contract(contract)
        self.assertEqual([], errors)
        self.assertEqual(publication.STUDY_CONTRACT_VERSION, normalized["schema_version"])
        del contract["estimand"]
        _normalized, errors = publication.normalize_study_contract(contract)
        self.assertTrue(any("estimand" in item for item in errors))

    def test_study_contract_rejects_arbitrary_null_or_blank_object_values(self):
        for bad in (
            {"x": None}, {"foo": ""}, {"": "meaningful"}, {"x": False},
            {"x": []}, {"x": {}}, {"x": "   "},
        ):
            contract = valid_contract()
            contract["estimand"] = bad
            _normalized, errors = publication.normalize_study_contract(contract)
            self.assertTrue(errors, bad)

    def test_study_contract_rejects_deep_numeric_and_placeholder_escape_but_keeps_semantic_declarations(self):
        for placeholder in ({"x": {"y": [0]}}, {"x": {"y": [True]}},
                            {"x": {"y": [None]}}, {"description": "TBD"}):
            contract = valid_contract()
            for field in ("analysis_population", "estimand", "exposure_or_intervention",
                          "comparator", "missing_data", "multiplicity"):
                contract[field] = placeholder
            contract["outcomes"] = [{"name": placeholder, "timepoint": placeholder}]
            _normalized, errors = publication.normalize_study_contract(contract)
            self.assertTrue(errors, placeholder)
        contract = valid_contract()
        contract.update({
            "analysis_population": {"cohort_id": "UKB-2026-001", "minimum_age": 40},
            "estimand": {"definition": "intention-to-treat risk ratio", "horizon_days": 90},
            "exposure_or_intervention": {"variable": "trt_arm", "definition": "randomized treatment"},
            "comparator": {"variable": "control_arm", "definition": "usual care"},
            "covariates": [{"variable": "baseline_age", "definition": "age at randomization", "unit": "years"}],
            "outcomes": [{"name": "MACE", "definition": "cardiovascular death, MI, or stroke", "time_horizon": "90 days"}],
        })
        _normalized, errors = publication.normalize_study_contract(contract)
        self.assertEqual([], errors)

    def test_study_contract_requires_typed_semantics_and_rejects_additional_placeholder_variants(self):
        contract = valid_contract()
        contract.pop("semantic_declarations")
        contract["estimand"] = {"free_text": "a prose-only declaration"}
        _normalized, errors = publication.normalize_study_contract(contract)
        self.assertTrue(any("semantic_declarations" in item for item in errors), errors)
        # Probe each new whole-declaration phrase through nested, punctuation,
        # and case-normalized values.  A real sentence remains legitimate.
        for phrase in ("not stated", "not disclosed", "not documented", "not defined",
                       "to be decided", "T.B.A.", "pending", "not yet specified"):
            contract = valid_contract()
            contract["estimand"] = {"nested": {"description": phrase.upper() + "!!!"}}
            contract["semantic_declarations"]["estimand"] = {
                "measure": phrase, "target": "Risk at 30 days"}
            _normalized, errors = publication.normalize_study_contract(contract)
            self.assertTrue(errors, phrase)
        contract = valid_contract()
        contract["estimand"] = {"definition": "The protocol did not state one covariate, but estimates the 30-day risk ratio."}
        _normalized, errors = publication.normalize_study_contract(contract)
        self.assertEqual([], errors)

    def test_study_contract_rejects_whitespace_and_meaningless_outcome_identity_or_time(self):
        probes = [
            {"study_design": "   "},
            {"outcomes": [{"name": "   ", "timepoint": "30 days"}]},
            {"outcomes": [{"name": "Primary", "timepoint": "   "}]},
            {"outcomes": [{"name": {"x": False}, "timepoint": {"x": []}}]},
        ]
        for changes in probes:
            contract = valid_contract()
            contract.update(changes)
            _normalized, errors = publication.normalize_study_contract(contract)
            self.assertTrue(errors, changes)
        contract = valid_contract()
        contract["study_design"] = "  parallel randomized trial  "
        normalized, errors = publication.normalize_study_contract(contract)
        self.assertEqual([], errors)
        self.assertEqual("parallel randomized trial", normalized["study_design"])

    def test_study_contract_rejects_common_placeholder_phrase_variants_only_as_whole_declarations(self):
        for phrase in ("Not specified", " not-available ", "NOT PROVIDED", "Not applicable",
                       "T.B.C.", "tbd", "UNKNOWN", "N / A"):
            contract = valid_contract()
            placeholder = {"nested": {"description": phrase}}
            for field in ("analysis_population", "estimand", "exposure_or_intervention",
                          "comparator", "missing_data", "multiplicity"):
                contract[field] = placeholder
            contract["outcomes"] = [{"name": placeholder, "timepoint": placeholder}]
            _normalized, errors = publication.normalize_study_contract(contract)
            self.assertTrue(errors, phrase)
        contract = valid_contract()
        contract["estimand"] = {"definition": "Risk ratio when an outcome is not applicable to a participant"}
        contract["missing_data"] = {"strategy": "Record why data are not available, then use complete cases"}
        _normalized, errors = publication.normalize_study_contract(contract)
        self.assertEqual([], errors)

    def test_study_contract_requires_outcome_timepoint_or_horizon(self):
        contract = valid_contract()
        contract["outcomes"] = [{"name": "Primary outcome"}]
        _normalized, errors = publication.normalize_study_contract(contract)
        self.assertTrue(any("outcomes" in item for item in errors), errors)
        contract["outcomes"] = [{"name": "Primary outcome", "time_horizon": "90 days"}]
        _normalized, errors = publication.normalize_study_contract(contract)
        self.assertEqual([], errors)
        contract["outcomes"] = [{"timepoint": "30 days"}]
        _normalized, errors = publication.normalize_study_contract(contract)
        self.assertTrue(any("outcomes" in item for item in errors), errors)

    def test_budget_never_slices_json(self):
        payload = {
            "run_id": "22222222-2222-4222-8222-222222222222",
            "status": "review_required",
            "module": "x" * 20000,
            "outdir": "y" * 20000,
            "stderr_tail": "bad\udcff" * 10000,
            "artifacts": {"tables": [{"name": "z" * 1000, "bytes": 1}] * 100},
            "upstream_runs": ["11111111-1111-4111-8111-111111111111", "22222222-2222-4222-8222-222222222222"],
        }
        rendered = server._fit_budget(payload)
        parsed = json.loads(rendered)
        self.assertLessEqual(len(rendered), server.MANIFEST_BUDGET)
        self.assertEqual("review_required", parsed["status"])
        self.assertEqual(payload["upstream_runs"], parsed["upstream_runs"])

    def test_nonfinite_numbers_are_standard_json_with_structured_warning(self):
        warnings = []
        safe = publication.json_safe(
            {"nan": float("nan"), "nested": [float("inf")]}, warnings
        )
        rendered = json.dumps(safe, allow_nan=False)
        self.assertEqual({"nan": None, "nested": [None]}, json.loads(rendered))
        self.assertEqual(2, len(warnings))
        self.assertEqual({"$/nan", "$/nested/0"}, {item["path"] for item in warnings})
        self.assertEqual({"nan": None}, json.loads(server._dumps({"nan": float("nan")})))
        budgeted = json.loads(server._fit_budget({"status": "review_required", "nan": float("nan")}))
        self.assertIsNone(budgeted["nan"])
        self.assertEqual("OS_JSON_NONFINITE", budgeted["serialization_warnings"][0]["code"])

    def test_json_safe_normalizes_keys_and_reports_collisions(self):
        warnings = []
        value = publication.json_safe({"bad\udcff": 1, "bad\ufffd": 2}, warnings)
        self.assertEqual({"bad\ufffd": 2}, value)
        self.assertTrue(any(x["code"] == "OS_JSON_KEY_COLLISION" for x in warnings))

    def test_safe_join_rejects_escapes_and_links(self):
        with tempfile.TemporaryDirectory() as root, tempfile.TemporaryDirectory() as outside:
            with self.assertRaises(ValueError):
                publication.safe_join_under(root, "../outside.txt")
            with self.assertRaises(ValueError):
                publication.safe_join_under(root, os.path.join(outside, "x"))
            link = os.path.join(root, "escape")
            try:
                os.symlink(outside, link, target_is_directory=True)
            except (OSError, NotImplementedError):
                self.skipTest("symlink/junction creation unavailable")
            with self.assertRaises(ValueError):
                publication.safe_join_under(root, "escape/x.txt")

    @unittest.skipUnless(os.name == "nt", "Windows junction test")
    def test_safe_join_and_finalizer_reject_windows_junction(self):
        with tempfile.TemporaryDirectory() as root, tempfile.TemporaryDirectory() as outside:
            junction = os.path.join(root, "junction")
            made = subprocess.run(["cmd", "/c", "mklink", "/J", junction, outside],
                                  stdin=subprocess.DEVNULL, capture_output=True, text=True)
            if made.returncode:
                self.skipTest("junction creation unavailable: " + made.stderr)
            try:
                with self.assertRaises(ValueError):
                    publication.safe_join_under(root, "junction/escaped.csv")
                outside_file = os.path.join(outside, "escaped.csv")
                with open(outside_file, "w", encoding="utf-8") as fh:
                    fh.write("x\n")
                records, errors = publication.collect_input_records(
                    {"data": os.path.join(junction, "escaped.csv")}, root, [root]
                )
                self.assertEqual([], records)
                self.assertTrue(errors)
                with self.assertRaises(ValueError):
                    publication.finalize_run(base_manifest(junction), study_contract=valid_contract(),
                                             effect_validation={"ok": True, "canonical": [], "invalid_named": [], "local": [], "files": [], "errors": []},
                                             software_versions={}, input_base=junction)
            finally:
                # This removes only the exact junction created above, never its target.
                if os.path.lexists(junction):
                    os.rmdir(junction)

    @unittest.skipUnless(os.name == "nt", "Windows junction test")
    def test_unsafe_walker_evidence_becomes_blocking_review_finding(self):
        with tempfile.TemporaryDirectory() as outdir, tempfile.TemporaryDirectory() as outside:
            os.makedirs(os.path.join(outdir, "tables"))
            with open(os.path.join(outdir, "tables", "x.csv"), "w", encoding="utf-8") as fh:
                fh.write("x\n1\n")
            junction = os.path.join(outdir, "escaped")
            made = subprocess.run(["cmd", "/c", "mklink", "/J", junction, outside],
                                  stdin=subprocess.DEVNULL, capture_output=True, text=True)
            if made.returncode:
                self.skipTest("junction creation unavailable: " + made.stderr)
            try:
                effect = {"ok": True, "canonical": [], "invalid_named": [], "local": [], "files": [], "errors": []}
                manifest = publication.finalize_run(base_manifest(outdir), study_contract=valid_contract(), effect_validation=effect, software_versions={}, input_base=outdir)
                review = publication._read_json(os.path.join(outdir, *publication.REVIEW_REL.split("/")))
                integrity = next(item for item in review["findings"] if item["rule_id"] == "PUB-INTEGRITY-002")
                self.assertEqual("blocked", manifest["status"])
                self.assertTrue(integrity["blocking"])
                self.assertIn("unsafe link/reparse artifact", integrity["message"])
            finally:
                if os.path.lexists(junction):
                    os.rmdir(junction)

    def test_artifact_aliases_preserve_draft_contract(self):
        aliases = {"report": "draft", "*_machine.json": "other"}
        self.assertEqual("draft", publication.classify_artifact("report/results.md", aliases))
        self.assertEqual("draft", publication.classify_artifact("draft/results.md"))
        self.assertEqual("other", publication.classify_artifact("x_machine.json", aliases))
        self.assertEqual("draft", server._classify("report/results.md"))

    def test_legacy_artifact_shape_omits_empty_groups_and_remains_engine_only(self):
        with tempfile.TemporaryDirectory() as outdir:
            os.makedirs(os.path.join(outdir, "tables"))
            with open(os.path.join(outdir, "tables", "engine.csv"), "w", encoding="utf-8") as fh:
                fh.write("x\n1\n")
            manifest = {"outdir": outdir, "engine_outputs": [{"path": "tables/engine.csv"}]}
            server._refresh_legacy_artifacts(manifest)
            self.assertEqual({"tables"}, set(manifest["artifacts"]))
            self.assertEqual(1, manifest["artifact_count"])
            self.assertNotIn(publication.MANIFEST_REL, {
                row["name"] for rows in manifest["all_artifacts"].values() for row in rows
            })

    def test_oversized_json_read_returns_valid_summary(self):
        with tempfile.TemporaryDirectory() as outdir:
            path = os.path.join(outdir, "large.json")
            publication.write_json(path, {"rows": ["x" * 1000] * 100})
            response = server.omicstat_read(path)
            parsed = json.loads(response)
            self.assertTrue(parsed["truncated"])
            self.assertEqual("object", parsed["summary"]["type"])

    def test_uuid_leaf_allocation_and_realpath_guard(self):
        with tempfile.TemporaryDirectory() as parent:
            run_id, outdir, requested = server._allocate_run_directory(
                FIXTURE_MODULE, parent
            )
            self.assertEqual(parent, requested)
            self.assertEqual(run_id, os.path.basename(outdir))
            self.assertTrue(os.path.isdir(outdir))
            self.assertTrue(server._under_allowed_root(outdir))
        # On POSIX a Windows drive path is just a relative file name under cwd,
        # so probe a real outside-the-roots file per platform (same choice as
        # test_client.py).
        outside = r"C:\Windows\win.ini" if os.name == "nt" else "/etc/hostname"
        self.assertFalse(server._under_allowed_root(outside))

    def test_explicit_parent_components_are_refused_before_normalization(self):
        with self.assertRaises(ValueError):
            server._guard_path(os.path.join(server.WORKSPACE, "x", "..", "omicstat-runs"), "outdir", server.WORKSPACE)
        with self.assertRaises(ValueError):
            server._guard_path(r"C:\omicstat workspace\x\..\omicstat-runs", "outdir", server.WORKSPACE)

    def test_qc_dialects_are_normalized(self):
        with tempfile.TemporaryDirectory() as outdir:
            qc_dir = os.path.join(outdir, "qc")
            os.makedirs(qc_dir)
            with open(os.path.join(qc_dir, "classic_qc.csv"), "w", newline="", encoding="utf-8") as fh:
                writer = csv.writer(fh)
                writer.writerow(["id", "severity", "triggered", "blocking", "message"])
                writer.writerow(["A-1", "high", "TRUE", "TRUE", "classic warning"])
            with open(os.path.join(qc_dir, "qc_results.csv"), "w", newline="", encoding="utf-8") as fh:
                writer = csv.writer(fh)
                writer.writerow(["qc_id", "severity", "status", "message", "evidence_artifact"])
                writer.writerow(["B-1", "WARN", "WARN", "status warning", "tables/x.csv"])
                writer.writerow(["B-2", "FAIL", "PASS", "not triggered", "tables/y.csv"])
            with open(os.path.join(qc_dir, "warnings.csv"), "w", newline="", encoding="utf-8") as fh:
                writer = csv.writer(fh)
                writer.writerow(["code", "severity", "message", "action"])
                writer.writerow(["C-1", "warning", "warning-only dialect", "inspect"])
            normalized = publication.scan_qc(outdir)
            self.assertEqual(3, normalized["triggered"])
            self.assertEqual(1, normalized["blocking"])
            self.assertEqual({"A-1", "B-1", "C-1"}, {x["id"] for x in normalized["findings"]})

    def test_semantic_value_map_tolerates_rounding_but_records_real_conflicts(self):
        with tempfile.TemporaryDirectory() as outdir:
            header = list(publication.CORE_EFFECT_COLUMNS)
            os.makedirs(os.path.join(outdir, "tables"))
            for name, estimate in (("tables/a.csv", "1"), ("tables/b.csv", "1.0")):
                row = {key: "" for key in header}
                row.update({"analysis_id": "a", "term": "x", "effect_type": "RR", "estimate": estimate,
                            "ci_low": "0.9", "ci_high": "1.1", "p_value": "0.1", "n_unweighted": "10"})
                with open(os.path.join(outdir, *name.split("/")), "w", newline="", encoding="utf-8") as fh:
                    writer = csv.DictWriter(fh, fieldnames=header); writer.writeheader(); writer.writerow(row)
            compatible = publication.semantic_value_map(outdir, ["tables/a.csv", "tables/b.csv"])
            self.assertEqual([], compatible["conflicts"])
            row = {key: "" for key in header}
            row.update({"analysis_id": "a", "term": "x", "effect_type": "RR", "estimate": "1.6",
                        "ci_low": "0.9", "ci_high": "1.1", "p_value": "0.1", "n_unweighted": "10"})
            with open(os.path.join(outdir, "tables", "c.csv"), "w", newline="", encoding="utf-8") as fh:
                writer = csv.DictWriter(fh, fieldnames=header); writer.writeheader(); writer.writerow(row)
            conflicted = publication.semantic_value_map(outdir, ["tables/a.csv", "tables/c.csv"])
            self.assertEqual("estimate", conflicted["conflicts"][0]["differences"][0]["field"])

    def test_semantic_value_map_nonfinite_is_a_structured_conflict(self):
        with tempfile.TemporaryDirectory() as outdir:
            os.makedirs(os.path.join(outdir, "tables"))
            header = list(publication.CORE_EFFECT_COLUMNS)
            for name, value in (("a.csv", "NaN"), ("b.csv", "1")):
                row = {field: "" for field in header}
                row.update({"analysis_id": "a", "term": "x", "effect_type": "RR", "estimate": value})
                with open(os.path.join(outdir, "tables", name), "w", newline="", encoding="utf-8") as fh:
                    writer = csv.DictWriter(fh, fieldnames=header); writer.writeheader(); writer.writerow(row)
            result = publication.semantic_value_map(outdir, ["tables/a.csv", "tables/b.csv"])
            self.assertTrue(result["conflicts"])
            self.assertEqual("OS_VALUE_NONFINITE", result["conflicts"][0]["code"])

    def test_semantic_value_map_includes_mappable_json_and_records_coverage(self):
        with tempfile.TemporaryDirectory() as outdir:
            os.makedirs(os.path.join(outdir, "tables"))
            header = list(publication.CORE_EFFECT_COLUMNS)
            row = {field: "" for field in header}
            row.update({"analysis_id": "a", "term": "x", "effect_type": "RR", "estimate": "1.0"})
            with open(os.path.join(outdir, "tables", "canonical.csv"), "w", newline="", encoding="utf-8") as fh:
                writer = csv.DictWriter(fh, fieldnames=header); writer.writeheader(); writer.writerow(row)
            with open(os.path.join(outdir, "tables", "mapped.json"), "w", encoding="utf-8") as fh:
                json.dump({"rows": [{"analysis": "a", "variable": "x", "measure": "RR", "effect": "1.6"}]}, fh)
            with open(os.path.join(outdir, "tables", "unmappable.json"), "w", encoding="utf-8") as fh:
                json.dump({"note": "not an estimate"}, fh)
            result = publication.semantic_value_map(outdir, ["tables/canonical.csv"])
            self.assertIn("tables/mapped.json", result["included_sources"])
            self.assertIn("tables/unmappable.json", result["unmappable_sources"])
            self.assertTrue(result["conflicts"])

    def test_semantic_value_map_treats_one_sided_missing_as_coverage_not_conflict(self):
        with tempfile.TemporaryDirectory() as outdir:
            os.makedirs(os.path.join(outdir, "tables"))
            header = list(publication.CORE_EFFECT_COLUMNS)
            for name, p_value, analysis_id in (
                ("canonical.csv", "", "  a  "), ("reported.csv", "0.05", "a"),
            ):
                row = {field: "" for field in header}
                row.update({"analysis_id": analysis_id, "term": " x ", "effect_type": " RR ",
                            "estimate": "1.2", "ci_low": "", "ci_high": "" if p_value == "" else "1.4",
                            "p_value": p_value})
                with open(os.path.join(outdir, "tables", name), "w", newline="", encoding="utf-8") as fh:
                    writer = csv.DictWriter(fh, fieldnames=header); writer.writeheader(); writer.writerow(row)
            result = publication.semantic_value_map(outdir, ["tables/canonical.csv"])
            self.assertEqual([], result["conflicts"])
            self.assertEqual("0.05", result["values"]["a|x|||RR"]["p_value"])
            self.assertEqual({"ci_high", "p_value"}, {item["field"] for item in result["coverage_gaps"]})

    @requires_installed_module
    def test_release_gate_tracks_every_applicable_rule_and_pending_is_not_ready(self):
        with tempfile.TemporaryDirectory() as outdir:
            os.makedirs(os.path.join(outdir, "tables"))
            with open(os.path.join(outdir, "tables", "x.csv"), "w", encoding="utf-8") as fh:
                fh.write("x\n1\n")
            effect = {"ok": True, "canonical": [], "invalid_named": [], "local": [], "files": [], "errors": []}
            manifest = publication.finalize_run(base_manifest(outdir), study_contract=valid_contract(), effect_validation=effect, software_versions={}, input_base=outdir)
            review = publication._read_json(os.path.join(outdir, *publication.REVIEW_REL.split("/")))
            catalog = publication.load_rule_catalogs(FIXTURE_MODULE)
            expected = {rule["rule_id"] for rule in catalog["universal"]}
            expected.add(catalog["module"]["rule_id"])
            self.assertEqual(expected, {item["rule_id"] for item in review["rule_execution"]})
            self.assertGreater(review["summary"]["pending"], 0)
            self.assertNotEqual("ready_for_manuscript_integration", manifest["status"])
            self.assertTrue(all(item["status"] in {"pass", "fail", "warning", "needs_input", "not_checked", "decision"}
                                for item in review["rule_execution"]))
            pending_ids = {item["rule_id"] for item in review["human_review_pending"]}
            self.assertTrue({"PUB-U-001", "PUB-U-002", "PUB-U-003", "PUB-U-005"} <= pending_ids)
            execution = {item["rule_id"]: item for item in review["rule_execution"]}
            self.assertFalse(execution["PUB-U-004"]["applicable"])
            self.assertFalse(execution["PUB-U-006"]["applicable"])

    def test_file_record_paths_reject_windows_and_posix_parent_forms(self):
        with tempfile.TemporaryDirectory() as outdir:
            os.makedirs(os.path.join(outdir, "tables"))
            with open(os.path.join(outdir, "tables", "x.csv"), "w", encoding="utf-8") as fh:
                fh.write("x\n1\n")
            effect = {"ok": True, "canonical": [], "invalid_named": [], "local": [], "files": [], "errors": []}
            manifest = publication.finalize_run(base_manifest(outdir), study_contract=valid_contract(), effect_validation=effect, software_versions={}, input_base=outdir)
            for unsafe in (r"C:\x.csv", r"\\host\share\x.csv", "/x.csv", r"a\..\x.csv", "a/../x.csv"):
                changed = json.loads(json.dumps(manifest))
                changed["outputs"][0]["path"] = unsafe
                self.assertTrue(publication.validate_instance(changed, "publication_manifest"), unsafe)

    def test_registry_digest_tamper_is_rejected_before_any_update(self):
        with tempfile.TemporaryDirectory() as outdir, tempfile.TemporaryDirectory() as registry:
            os.makedirs(os.path.join(outdir, "tables"))
            with open(os.path.join(outdir, "tables", "x.csv"), "w", encoding="utf-8") as fh:
                fh.write("x\n1\n")
            effect = {"ok": True, "canonical": [], "invalid_named": [], "local": [], "files": [], "errors": []}
            manifest = publication.finalize_run(base_manifest(outdir), study_contract=valid_contract(), effect_validation=effect, software_versions={}, input_base=outdir)
            publication.write_registry(registry, manifest)
            manifest_path = os.path.join(outdir, *publication.MANIFEST_REL.split("/"))
            with open(manifest_path, "a", encoding="utf-8") as fh:
                fh.write("\n")
            with self.assertRaises(ValueError):
                publication.lookup_registry(registry, manifest["run_id"], verify_current=True)

    def test_registry_stale_second_validator_leaves_manifest_and_registry_consistent(self):
        with tempfile.TemporaryDirectory() as parent, tempfile.TemporaryDirectory() as registry:
            run_id = "33333333-3333-4333-8333-333333333333"
            outdir = os.path.join(parent, run_id)
            os.makedirs(os.path.join(outdir, "tables"))
            with open(os.path.join(outdir, "tables", "x.csv"), "w", encoding="utf-8") as fh:
                fh.write("x\n1\n")
            effect = {"ok": True, "canonical": [], "invalid_named": [], "local": [], "files": [], "errors": []}
            first = publication.finalize_run(base_manifest(outdir, run_id), study_contract=valid_contract(), effect_validation=effect, software_versions={}, input_base=outdir)
            publication.write_registry(registry, first)
            original = publication.lookup_registry(registry, first["run_id"])["manifest_digest"]
            candidate_a = publication.finalize_run(first, study_contract=valid_contract(), effect_validation=effect, software_versions={}, input_base=outdir, write_manifest=False)
            candidate_b = publication.finalize_run(first, study_contract=valid_contract(), effect_validation=effect, software_versions={}, input_base=outdir, write_manifest=False)
            publication.commit_manifest_and_registry(registry, candidate_a, expected_previous_digest=original)
            committed = publication.lookup_registry(registry, first["run_id"])["manifest_digest"]
            with self.assertRaises(ValueError):
                publication.commit_manifest_and_registry(registry, candidate_b, expected_previous_digest=original)
            self.assertEqual(committed, publication.sha256_file(os.path.join(outdir, *publication.MANIFEST_REL.split("/"))))

    def test_registry_write_failure_rolls_back_manifest_and_registry_bytes(self):
        with tempfile.TemporaryDirectory() as parent, tempfile.TemporaryDirectory() as registry:
            run_id = "44444444-4444-4444-8444-444444444444"
            outdir = os.path.join(parent, run_id)
            os.makedirs(os.path.join(outdir, "tables"))
            with open(os.path.join(outdir, "tables", "x.csv"), "w", encoding="utf-8") as fh:
                fh.write("x\n1\n")
            effect = {"ok": True, "canonical": [], "invalid_named": [], "local": [], "files": [], "errors": []}
            first = publication.finalize_run(base_manifest(outdir, run_id), study_contract=valid_contract(), effect_validation=effect, software_versions={}, input_base=outdir)
            publication.write_registry(registry, first)
            digest = publication.lookup_registry(registry, run_id)["manifest_digest"]
            candidate = publication.finalize_run(first, study_contract=valid_contract(), effect_validation=effect, software_versions={}, input_base=outdir, write_manifest=False)
            manifest_path = os.path.join(outdir, *publication.MANIFEST_REL.split("/"))
            registry_path = os.path.join(registry, run_id + ".json")
            with open(manifest_path, "rb") as fh:
                before_manifest = fh.read()
            with open(registry_path, "rb") as fh:
                before_registry = fh.read()
            before_artifacts = {}
            for rel in publication.PUBLICATION_DYNAMIC:
                with open(os.path.join(outdir, *rel.split("/")), "rb") as fh:
                    before_artifacts[rel] = fh.read()
            original_write = publication.write_json
            def fail_registry(path, value):
                if os.path.normcase(path) == os.path.normcase(registry_path):
                    raise OSError("injected registry write failure")
                return original_write(path, value)
            with mock.patch.object(publication, "write_json", side_effect=fail_registry):
                with self.assertRaises(OSError):
                    publication.commit_manifest_and_registry(registry, candidate, expected_previous_digest=digest)
            with open(manifest_path, "rb") as fh:
                self.assertEqual(before_manifest, fh.read())
            with open(registry_path, "rb") as fh:
                self.assertEqual(before_registry, fh.read())
            for rel, expected in before_artifacts.items():
                with open(os.path.join(outdir, *rel.split("/")), "rb") as fh:
                    self.assertEqual(expected, fh.read(), rel)

    @requires_installed_module
    def test_transaction_rolls_back_every_artifact_on_late_evidence_race(self):
        with temporary_directory_with_windows_cleanup() as parent, tempfile.TemporaryDirectory() as registry:
            run_id = "66666666-6666-4666-8666-666666666666"
            outdir = os.path.join(parent, run_id)
            os.makedirs(os.path.join(outdir, "tables"))
            evidence = os.path.join(outdir, "tables", "x.csv")
            with open(evidence, "w", encoding="utf-8") as fh:
                fh.write("x\n1\n")
            versions = complete_versions(observed_repository_versions())
            effect = {"ok": True, "canonical": [], "invalid_named": [], "local": [], "files": [], "errors": []}
            first = publication.finalize_run(base_manifest(outdir, run_id), study_contract=valid_contract(),
                                             effect_validation=effect, software_versions=versions, input_base=outdir)
            review = publication._read_json(os.path.join(outdir, *publication.REVIEW_REL.split("/")))
            decisions = {}
            for item in review["human_review_pending"]:
                decisions[item["rule_id"]] = {
                    "decision": "accepted", "decided_at": "2026-09-04T00:00:00Z", "reviewer": "r1",
                    "evidence_locations": ["tables/x.csv"],
                    "evidence_sha256": {"tables/x.csv": publication.sha256_file(evidence)},
                }
            first["reviewer_decisions"] = decisions
            candidate = publication.finalize_run(first, study_contract=valid_contract(), effect_validation=effect,
                                                 software_versions=versions, input_base=outdir, write_manifest=False)
            self.assertEqual("ready_for_manuscript_integration", candidate["status"])
            before = {}
            for rel in publication.PUBLICATION_DYNAMIC:
                with open(os.path.join(outdir, *rel.split("/")), "rb") as fh:
                    before[rel] = fh.read()
            manifest_path = os.path.join(outdir, *publication.MANIFEST_REL.split("/"))
            original_write = publication.write_json
            def mutate_after_manifest(path, value):
                result = original_write(path, value)
                if os.path.normcase(path) == os.path.normcase(manifest_path):
                    with open(evidence, "a", encoding="utf-8") as fh:
                        fh.write("mutated\n")
                return result
            with mock.patch.object(publication, "write_json", side_effect=mutate_after_manifest):
                publication.commit_manifest_and_registry(registry, candidate)
            # The source changed after the final source-path check, but the
            # committed decision is bound to a content-addressed copy ingested
            # before the transaction; it cannot claim the changed bytes.
            snapshot = publication._evidence_snapshot_path(
                outdir, decisions["PUB-U-001"]["evidence_sha256"]["tables/x.csv"])
            with open(publication._native_path(snapshot), encoding="utf-8") as fh:
                self.assertEqual("x\n1\n", fh.read())
            persisted = publication.read_publication_manifest(outdir)
            self.assertEqual("ready_for_manuscript_integration", persisted["status"])
            publication.validate_reviewer_decisions(outdir, persisted["reviewer_decisions"], use_snapshots=True)
            with self.assertRaisesRegex(ValueError, "SHA-256 mismatch"):
                publication.validate_reviewer_decisions(outdir, persisted["reviewer_decisions"])
            marker = os.path.join(outdir, *publication.COMMIT_MARKER_REL.split("/"))
            self.assertTrue(os.path.isfile(marker))
            os.remove(marker)
            with self.assertRaisesRegex(ValueError, "atomic commit marker"):
                publication.read_publication_manifest(outdir)

    def test_late_input_blocker_persists_blocked_review_outline_and_manifest(self):
        with tempfile.TemporaryDirectory() as outdir:
            os.makedirs(os.path.join(outdir, "tables"))
            with open(os.path.join(outdir, "tables", "x.csv"), "w", encoding="utf-8") as fh:
                fh.write("x\n1\n")
            manifest = base_manifest(outdir)
            manifest["request"]["args"] = {"data": r"C:\Windows\win.ini"}
            result = publication.finalize_run(
                manifest, study_contract=valid_contract(),
                effect_validation={"ok": True, "canonical": [], "invalid_named": [], "local": [], "files": [], "errors": []},
                software_versions={}, input_base=outdir, allowed_input_roots=[outdir],
            )
            review = publication._read_json(os.path.join(outdir, *publication.REVIEW_REL.split("/")))
            with open(os.path.join(outdir, *publication.OUTLINE_REL.split("/")), encoding="utf-8") as fh:
                outline = fh.read()
            self.assertEqual("blocked", result["status"])
            self.assertEqual("blocked", review["status"])
            self.assertIn("Publication status: `blocked`.", outline)

    @requires_installed_module
    def test_ready_commit_refuses_repository_change_at_the_final_boundary(self):
        with temporary_directory_with_windows_cleanup() as parent, tempfile.TemporaryDirectory() as registry:
            run_id = "77777777-7777-4777-8777-777777777777"
            outdir = os.path.join(parent, run_id)
            os.makedirs(os.path.join(outdir, "tables"))
            evidence = os.path.join(outdir, "tables", "x.csv")
            with open(evidence, "w", encoding="utf-8") as fh:
                fh.write("x\n1\n")
            versions = complete_versions(observed_repository_versions())
            effect = {"ok": True, "canonical": [], "invalid_named": [], "local": [], "files": [], "errors": []}
            first = publication.finalize_run(base_manifest(outdir, run_id), study_contract=valid_contract(),
                                             effect_validation=effect, software_versions=versions, input_base=outdir)
            review = publication._read_json(os.path.join(outdir, *publication.REVIEW_REL.split("/")))
            first["reviewer_decisions"] = {
                item["rule_id"]: {"decision": "accepted", "decided_at": "2026-09-04T00:00:00Z", "reviewer": "r1",
                                  "evidence_locations": ["tables/x.csv"],
                                  "evidence_sha256": {"tables/x.csv": publication.sha256_file(evidence)}}
                for item in review["human_review_pending"]
            }
            candidate = publication.finalize_run(first, study_contract=valid_contract(), effect_validation=effect,
                                                 software_versions=versions, input_base=outdir, write_manifest=False)
            self.assertEqual("ready_for_manuscript_integration", candidate["status"])
            with mock.patch.object(publication, "_current_manifest_provenance_is_bound", side_effect=[True, False]):
                with self.assertRaisesRegex(ValueError, "provenance changed"):
                    publication.commit_manifest_and_registry(registry, candidate)
            self.assertFalse(os.path.exists(os.path.join(registry, run_id + ".json")))
            self.assertNotEqual("ready_for_manuscript_integration", publication._read_json(
                os.path.join(outdir, *publication.REVIEW_REL.split("/")))["status"])

    def test_rollback_write_failure_is_fault_isolated(self):
        with tempfile.TemporaryDirectory() as outdir:
            os.makedirs(os.path.join(outdir, "tables"))
            with open(os.path.join(outdir, "tables", "x.csv"), "w", encoding="utf-8") as fh:
                fh.write("x\n1\n")
            effect = {"ok": True, "canonical": [], "invalid_named": [], "local": [], "files": [], "errors": []}
            first = publication.finalize_run(base_manifest(outdir), study_contract=valid_contract(),
                                             effect_validation=effect, software_versions={}, input_base=outdir)
            candidate = publication.finalize_run(first, study_contract=valid_contract(), effect_validation=effect,
                                                 software_versions={}, input_base=outdir, write_manifest=False)
            original_write = publication.write_json
            manifest_path = os.path.join(outdir, *publication.MANIFEST_REL.split("/"))
            def fail_manifest(path, value):
                if os.path.normcase(path) == os.path.normcase(manifest_path):
                    raise OSError("injected manifest write failure")
                return original_write(path, value)
            original_restore = publication._restore_snapshot
            def fail_review_restore(path, prior):
                normalized = os.path.normcase(path).replace("\\", "/")
                if normalized.endswith(os.path.normcase(publication.REVIEW_REL)):
                    raise OSError("injected rollback failure")
                return original_restore(path, prior)
            with mock.patch.object(publication, "write_json", side_effect=fail_manifest), \
                    mock.patch.object(publication, "_restore_snapshot", side_effect=fail_review_restore):
                with self.assertRaisesRegex(RuntimeError, "rollback could not restore"):
                    publication._commit_publication_group(candidate)
            marker = publication._read_json(os.path.join(outdir, *publication.COMMIT_FAILURE_REL.split("/")))
            self.assertEqual("blocked", marker["status"])

    def test_manifest_provenance_rejects_empty_versions_or_validator_hash(self):
        with tempfile.TemporaryDirectory() as outdir:
            os.makedirs(os.path.join(outdir, "tables"))
            with open(os.path.join(outdir, "tables", "x.csv"), "w", encoding="utf-8") as fh:
                fh.write("x\n1\n")
            effect = {"ok": True, "canonical": [], "invalid_named": [], "local": [], "files": [], "errors": []}
            manifest = publication.finalize_run(base_manifest(outdir), study_contract=valid_contract(), effect_validation=effect, software_versions={}, input_base=outdir)
            bad_versions = json.loads(json.dumps(manifest)); bad_versions["software_versions"] = {}
            self.assertTrue(publication.validate_instance(bad_versions, "publication_manifest"))
            bad_hash = json.loads(json.dumps(manifest)); bad_hash["validator"]["sha256"] = "unknown"
            self.assertTrue(publication.validate_instance(bad_hash, "publication_manifest"))
            bad_finalizer = json.loads(json.dumps(manifest)); bad_finalizer["finalizer"] = {"path": 0, "sha256": []}
            self.assertTrue(publication.validate_instance(bad_finalizer, "publication_manifest"))
            bad_rule_hash = json.loads(json.dumps(manifest)); bad_rule_hash["rule_catalog_hashes"]["module"] = []
            self.assertTrue(publication.validate_instance(bad_rule_hash, "publication_manifest"))
            bad_container = json.loads(json.dumps(manifest))
            bad_container["engine"] = "container"
            bad_container["software_versions"]["execution_engine"] = "container"
            bad_container["software_versions"]["container_image_id"] = "unknown"
            bad_container["runtime"]["execution_engine"] = "container"
            bad_container["runtime"]["container_image_id"] = "unknown"
            self.assertTrue(publication.validate_instance(bad_container, "publication_manifest"))

    def test_unknown_required_provenance_blocks_readiness(self):
        with tempfile.TemporaryDirectory() as outdir:
            os.makedirs(os.path.join(outdir, "tables"))
            with open(os.path.join(outdir, "tables", "x.csv"), "w", encoding="utf-8") as fh:
                fh.write("x\n1\n")
            effect = {"ok": True, "canonical": [], "invalid_named": [], "local": [], "files": [], "errors": []}
            manifest = publication.finalize_run(base_manifest(outdir), study_contract=valid_contract(),
                                                effect_validation=effect, software_versions={}, input_base=outdir)
            self.assertEqual("blocked", manifest["status"])
            review = publication._read_json(os.path.join(outdir, *publication.REVIEW_REL.split("/")))
            finding = next(item for item in review["findings"] if item["rule_id"] == "PUB-PROVENANCE-001")
            self.assertTrue(finding["blocking"])

    @requires_installed_module
    def test_dirty_provenance_is_derived_not_trusted_from_the_caller(self):
        observed = {"status_sha256": "1" * 64, "diff_sha256": "2" * 64,
                    "untracked_sha256": "3" * 64, "code_inventory_sha256": "4" * 64,
                    "worktree_sha256": "5" * 64, "code_inventory": [{"path": "mcp/server.py", "sha256": "6" * 64}]}
        with mock.patch.object(publication, "_observed_repository_state", return_value=("b" * 40, True, observed)):
            clean, clean_gaps = publication.normalize_provenance(
                complete_versions({"commit": "a" * 40, "dirty": False}), "native")
        self.assertTrue(clean["repository"]["dirty"])
        self.assertIn("repository.dirty", clean_gaps)
        self.assertIn("repository.worktree_identity", clean_gaps)

        with mock.patch.object(publication, "_observed_repository_state", return_value=("b" * 40, True, observed)):
            dirty, dirty_gaps = publication.normalize_provenance(
                complete_versions({"commit": "a" * 40, "dirty": True}), "native")
        self.assertIn("repository.worktree_identity", dirty_gaps)
        self.assertIsNone(dirty["repository"]["worktree_identity"])

        identity = server._dirty_worktree_identity(FIXTURE_MODULE)
        self.assertIsNotNone(identity)
        actual_commit = subprocess.run(["git", "rev-parse", "HEAD"], cwd=server.SUITE,
                                       capture_output=True, text=True, check=True).stdout.strip()
        replayable, replayable_gaps = publication.normalize_provenance(
            complete_versions({"commit": actual_commit, "dirty": True,
                               "worktree_identity": identity}), "native")
        self.assertNotIn("repository.worktree_identity", replayable_gaps)
        self.assertEqual(identity["worktree_sha256"],
                         replayable["repository"]["worktree_identity"]["worktree_sha256"])

        with tempfile.TemporaryDirectory() as outdir:
            os.makedirs(os.path.join(outdir, "tables"))
            with open(os.path.join(outdir, "tables", "x.csv"), "w", encoding="utf-8") as fh:
                fh.write("x\n1\n")
            manifest = publication.finalize_run(
                base_manifest(outdir), study_contract=valid_contract(),
                effect_validation={"ok": True, "canonical": [], "invalid_named": [], "local": [], "files": [], "errors": []},
                software_versions=complete_versions({"commit": "a" * 40, "dirty": True}),
                input_base=outdir,
            )
            self.assertEqual("blocked", manifest["status"])
            self.assertEqual("not_applicable", manifest["validator"]["status"])

    @requires_installed_module
    @requires_native_engine
    def test_unknown_engine_is_refused_before_uuid_leaf_allocation(self):
        # The flag whitelist is read from --help first (native engine), then
        # the engine name is refused before any UUID leaf is allocated.
        with tempfile.TemporaryDirectory() as parent:
            with self.assertRaises(ValueError):
                server.omicstat_run(FIXTURE_MODULE, {"seed": 7, "outdir": parent}, engine="unknown")
            self.assertEqual([], os.listdir(parent))

    @requires_installed_module
    def test_dirty_provenance_recomputes_and_rejects_forged_inventory_or_aggregates(self):
        actual_commit = subprocess.run(["git", "rev-parse", "HEAD"], cwd=server.SUITE,
                                       capture_output=True, text=True, check=True).stdout.strip()
        identity = server._dirty_worktree_identity(FIXTURE_MODULE)
        self.assertIsNotNone(identity)
        for mutate in (
            lambda item: item.update({"worktree_sha256": "0" * 64}),
            lambda item: item.update({"code_inventory_sha256": "0" * 64}),
            lambda item: item["code_inventory"].__setitem__(0, {
                **item["code_inventory"][0], "sha256": "0" * 64}),
            lambda item: item["code_inventory"].pop(),
            lambda item: item["code_inventory"].append({"path": "mcp/extra.py", "sha256": "0" * 64}),
        ):
            forged = json.loads(json.dumps(identity))
            mutate(forged)
            with mock.patch.object(publication, "_observed_repository_state",
                                   return_value=(actual_commit, True, identity)):
                _normalized, gaps = publication.normalize_provenance(
                    complete_versions({"commit": actual_commit, "dirty": True,
                                       "worktree_identity": forged}), "native")
            self.assertIn("repository.worktree_identity", gaps)

    def test_finalizer_writes_standard_artifacts_and_detects_tamper(self):
        with tempfile.TemporaryDirectory() as outdir:
            tables = os.path.join(outdir, "tables")
            os.makedirs(tables)
            result_path = os.path.join(tables, "summary.csv")
            with open(result_path, "w", encoding="utf-8", newline="") as fh:
                fh.write("metric,value\nn_features,1000\n")
            effect_validation = {
                "schema_version": "omicstat.effect-table-validation.v1",
                "ok": True, "canonical": [], "invalid_named": [], "local": [],
                "files": [], "errors": [],
            }
            starting_manifest = base_manifest(outdir)
            starting_manifest["request"]["args"] = {
                "label": "正常中文",
                "invalid": "bad\udcffvalue",
            }
            first = publication.finalize_run(
                starting_manifest,
                study_contract=valid_contract(),
                effect_validation=effect_validation,
                software_versions={"python": "test", "r": "test", "execution_engine": "native"},
                input_base=outdir,
            )
            for rel in (
                publication.MANIFEST_REL, publication.REVIEW_REL,
                publication.INDEX_REL, publication.OUTLINE_REL,
                publication.VALUE_MAP_REL,
            ):
                self.assertTrue(os.path.isfile(os.path.join(outdir, *rel.split("/"))), rel)
            self.assertEqual([], publication.validate_instance(first, "publication_manifest"))
            self.assertEqual("正常中文", first["request"]["args"]["label"])
            self.assertEqual("bad\ufffdvalue", first["request"]["args"]["invalid"])
            self.assertTrue(any(
                item["code"] == "OS_JSON_INVALID_UNICODE"
                for item in first["serialization_warnings"]
            ))
            with open(
                os.path.join(outdir, *publication.MANIFEST_REL.split("/")),
                encoding="utf-8",
            ) as fh:
                json.load(fh)
            with open(result_path, "a", encoding="utf-8") as fh:
                fh.write("tampered,999\n")
            second = publication.finalize_run(
                first,
                study_contract=valid_contract(),
                effect_validation=effect_validation,
                software_versions={"python": "test", "r": "test", "execution_engine": "native"},
                input_base=outdir,
            )
            self.assertEqual("blocked", second["status"])
            review = publication._read_json(
                os.path.join(outdir, *publication.REVIEW_REL.split("/"))
            )
            self.assertTrue(any(x["rule_id"] == "PUB-INTEGRITY-001" for x in review["findings"]))
            self.assertIn("automated_checks", review)
            self.assertIn("human_review_pending", review)
            self.assertEqual(
                "not_present", review["automated_checks"]["effect_table_schema"]["status"]
            )
            ids = [item["rule_id"] for item in review["findings"]]
            self.assertEqual(len(ids), len(set(ids)))

    def test_engine_anchor_is_immutable_across_repeated_tamper_validation(self):
        with tempfile.TemporaryDirectory() as outdir:
            os.makedirs(os.path.join(outdir, "tables"))
            artifact = os.path.join(outdir, "tables", "result.csv")
            with open(artifact, "w", encoding="utf-8") as fh:
                fh.write("x\n1\n")
            effect_validation = {"ok": True, "canonical": [], "invalid_named": [], "local": [], "files": [], "errors": []}
            first = publication.finalize_run(base_manifest(outdir), study_contract=valid_contract(), effect_validation=effect_validation, software_versions={}, input_base=outdir)
            anchor = first["engine_anchor_digest"]
            with open(artifact, "a", encoding="utf-8") as fh:
                fh.write("2\n")
            for _ in range(3):
                first = publication.finalize_run(first, study_contract=valid_contract(), effect_validation=effect_validation, software_versions={}, input_base=outdir)
                self.assertEqual("blocked", first["status"])
                self.assertEqual(anchor, first["engine_anchor_digest"])
            os.remove(artifact)
            deleted = publication.finalize_run(first, study_contract=valid_contract(), effect_validation=effect_validation, software_versions={}, input_base=outdir)
            self.assertEqual("blocked", deleted["status"])

    def test_reviewer_decision_cannot_clear_automated_failure(self):
        findings = [publication.finding("PUB-X", "universal_hard", "critical", "bad", "fix", blocking=True, check_status="fail")]
        decision = {"decision": "accepted", "reviewer": "reviewer-1",
                    "evidence_locations": ["tables/x.csv"],
                    "evidence_sha256": {"tables/x.csv": "0" * 64}}
        self.assertEqual("blocked", publication._status(findings, {"PUB-X": decision}))
        pending = [publication.finding("PUB-H", "advisory", "warning", "human", "review", human_review=True, check_status="not_checked")]
        self.assertEqual("ready_for_manuscript_integration", publication._status(pending, {"PUB-H": decision}))
        self.assertEqual("review_required", publication._status(pending, {"PUB-H": {"decision": "accepted"}}))
        dynamic = json.loads(json.dumps(decision))
        dynamic["evidence_locations"] = [publication.REVIEW_REL]
        dynamic["evidence_sha256"] = {publication.REVIEW_REL: "0" * 64}
        self.assertEqual("review_required", publication._status(pending, {"PUB-H": dynamic}))

    def test_reviewer_decisions_require_fixed_exactly_hashed_evidence_in_core(self):
        with tempfile.TemporaryDirectory() as outdir:
            os.makedirs(os.path.join(outdir, "tables"))
            evidence = os.path.join(outdir, "tables", "x.csv")
            with open(evidence, "w", encoding="utf-8") as fh:
                fh.write("x\n1\n")
            decision = {
                "decision": "accepted", "decided_at": "2026-09-04T00:00:00Z",
                "reviewer": "reviewer-1", "evidence_locations": ["tables/x.csv"],
                "evidence_sha256": {"tables/x.csv": publication.sha256_file(evidence)},
            }
            valid = base_manifest(outdir)
            valid["reviewer_decisions"] = {"PUB-U-001": decision}
            effect = {"ok": True, "canonical": [], "invalid_named": [], "local": [], "files": [], "errors": []}
            publication.finalize_run(valid, study_contract=valid_contract(), effect_validation=effect,
                                     software_versions={}, input_base=outdir)
            persisted_manifest = publication.read_publication_manifest(outdir)
            self.assertEqual(publication.sha256_file(evidence),
                             persisted_manifest["reviewer_decisions"]["PUB-U-001"]["evidence_sha256"]["tables/x.csv"])
            self.assertEqual(persisted_manifest["reviewer_decisions"], publication.validate_reviewer_decisions(
                outdir, persisted_manifest["reviewer_decisions"]))
            valid_review = publication._read_json(os.path.join(outdir, *publication.REVIEW_REL.split("/")))
            schema_invalid_review = json.loads(json.dumps(valid_review))
            schema_invalid_review["reviewer_decisions"]["PUB-U-001"].pop("evidence_sha256")
            self.assertTrue(publication.validate_instance(schema_invalid_review, "publication_review"))
            rejected = base_manifest(outdir)
            rejected_decision = json.loads(json.dumps(decision))
            rejected_decision["decision"] = "rejected"
            rejected["reviewer_decisions"] = {"PUB-U-001": rejected_decision}
            publication.finalize_run(rejected, study_contract=valid_contract(), effect_validation=effect,
                                     software_versions={}, input_base=outdir)
            for mutate in (
                lambda item: item.pop("evidence_sha256"),
                lambda item: item["evidence_sha256"].update({"extra.txt": "0" * 64}),
                lambda item: item["evidence_sha256"].update({"tables/x.csv": "0" * 64}),
                lambda item: (item.update({"evidence_locations": [publication.REVIEW_REL]}),
                              item.update({"evidence_sha256": {publication.REVIEW_REL: "0" * 64}})),
            ):
                bad = base_manifest(outdir)
                bad_decision = json.loads(json.dumps(decision))
                mutate(bad_decision)
                bad["reviewer_decisions"] = {"PUB-U-001": bad_decision}
                with self.assertRaises(ValueError):
                    publication.finalize_run(bad, study_contract=valid_contract(), effect_validation=effect,
                                             software_versions={}, input_base=outdir)

    def test_dynamic_evidence_rejects_all_case_slash_and_dot_aliases(self):
        with tempfile.TemporaryDirectory() as outdir:
            os.makedirs(os.path.join(outdir, "tables"))
            with open(os.path.join(outdir, "tables", "x.csv"), "w", encoding="utf-8") as fh:
                fh.write("x\n1\n")
            effect = {"ok": True, "canonical": [], "invalid_named": [], "local": [], "files": [], "errors": []}
            publication.finalize_run(base_manifest(outdir), study_contract=valid_contract(),
                                     effect_validation=effect, software_versions={}, input_base=outdir)
            for dynamic in publication.PUBLICATION_DYNAMIC:
                aliases = (dynamic.upper(), dynamic.replace("/", "\\"),
                           dynamic.replace("/", "/./", 1), dynamic + " ")
                for alias in aliases:
                    decision = {
                        "decision": "accepted", "decided_at": "2026-09-04T00:00:00Z",
                        "reviewer": "reviewer-1", "evidence_locations": [alias],
                        "evidence_sha256": {alias: "0" * 64},
                    }
                    with self.assertRaisesRegex(ValueError, "dynamic publication artifacts"):
                        publication.validate_reviewer_decisions(outdir, {"PUB-U-001": decision})
                    self.assertFalse(publication._accepted_human_decision(decision), alias)

    def test_outline_omits_missing_clauses_and_pipe_keys(self):
        review = {"status": "review_required", "findings": []}
        value_map = {"values": {" a | x ||| RR ": {
            "analysis_id": "a", "term": "x", "effect_type": "RR", "estimate": "1.2",
            "ci_low": None, "ci_high": None, "p_value": None,
            "sources": ["tables/effect.csv:2"],
        }}}
        outline = publication._outline(review, [], valid_contract(), value_map)
        self.assertNotIn("None", outline)
        self.assertNotIn("a | x ||| RR", outline)
        self.assertIn("a - x - RR", outline)
        self.assertIn("source: `tables/effect.csv:2`", outline)

    def test_imported_preseeded_unhashed_decisions_are_rejected(self):
        with tempfile.TemporaryDirectory() as source, tempfile.TemporaryDirectory() as target_parent:
            os.makedirs(os.path.join(source, "tables"))
            with open(os.path.join(source, "tables", "x.csv"), "w", encoding="utf-8") as fh:
                fh.write("x\n1\n")
            effect = {"ok": True, "canonical": [], "invalid_named": [], "local": [], "files": [], "errors": []}
            manifest = publication.finalize_run(base_manifest(source), study_contract=valid_contract(),
                                                effect_validation=effect, software_versions={}, input_base=source)
            manifest["reviewer_decisions"] = {"PUB-U-001": {
                "decision": "accepted", "decided_at": "2026-09-04T00:00:00Z",
                "reviewer": "seeded", "evidence_locations": ["tables/x.csv"],
            }}
            publication.write_json(os.path.join(source, *publication.MANIFEST_REL.split("/")), manifest)
            imported_run_id = "55555555-5555-4555-8555-555555555555"
            imported_target = os.path.join(target_parent, imported_run_id)
            def allocate(_module, _requested):
                os.makedirs(imported_target)
                return imported_run_id, imported_target, None
            with tempfile.TemporaryDirectory() as registry, \
                    mock.patch.object(server, "_allocate_run_directory", side_effect=allocate), \
                    mock.patch.object(server, "RUN_REGISTRY", registry), \
                    mock.patch.object(server, "_software_versions", return_value={}):
                with self.assertRaisesRegex(ValueError, "evidence_sha256"):
                    server.omicstat_validate_publication(outdir=source)

    def test_public_status_vocabulary_is_reachable(self):
        self.assertEqual("blocked", publication._status([publication.finding("x", "universal_hard", "critical", "x", "x", blocking=True, check_status="fail")]))
        self.assertEqual("needs_input", publication._status([publication.finding("x", "design_conditional", "warning", "x", "x", check_status="needs_input")]))
        self.assertEqual("review_required", publication._status([publication.finding("x", "advisory", "warning", "x", "x", human_review=True, check_status="not_checked")]))
        self.assertEqual("ready_for_manuscript_integration", publication._status([]))


class EffectTableCliTests(unittest.TestCase):
    @requires_native_engine
    def test_persisted_types_are_restored_and_fake_schema_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            valid = os.path.join(tmp, "effect_table.csv")
            header = [
                "term", "level", "analysis_id", "effect_type", "estimate", "ci_low",
                "ci_high", "ci_level", "p_value", "p_adjusted", "p_adj_method",
                "n_unweighted", "n_events", "design_df", "weighted", "stratum_var",
                "stratum", "test_name", "model_spec_hash", "notes",
            ]
            with open(valid, "w", newline="", encoding="utf-8") as fh:
                writer = csv.writer(fh)
                writer.writerow(header)
                writer.writerow([
                    "treatment", "", "primary", "RR", "0.8", "0.7", "0.9",
                    "0.95", "0.01", "", "", "100", "10", "", "FALSE",
                    "", "", "glm", "abc", "",
                ])
            fake = os.path.join(tmp, "fake.csv")
            with open(fake, "w", newline="", encoding="utf-8") as fh:
                writer = csv.writer(fh)
                writer.writerow(["term", "analysis_id", "effect_type", "estimate", "ci_low", "ci_high", "p_value"])
                writer.writerow(["x", "m1", "RR", "1.2", "1.0", "1.4", "0.05"])
            # Through the router exactly like the shell does (engine "native").
            proc = subprocess.run(
                server._build_cmd(server.EFFECT_VALIDATOR, [valid, fake], "native"),
                stdin=subprocess.DEVNULL, capture_output=True, check=True, timeout=120,
                env=server._engine_env("native"),
            )
            payload = json.loads(proc.stdout.decode("utf-8"))
            self.assertFalse(payload["ok"])
            files = payload["files"]
            self.assertTrue(files[0]["ok"], files[0])
            self.assertFalse(files[1]["ok"], files[1])
            self.assertIn("missing required column", json.dumps(files[1]["errors"]))


FEATURE_HEADER = ("feature_id,symbol,contrast,base_mean,log2fc,log2fc_se,stat,pvalue,padj,"
                  "method,shrinkage,n_group1,n_group2,filtered_reason\n")


class OmicstatForkAdditionsTests(unittest.TestCase):
    """The omicstat-only MCP additions (IMPLEMENTATION_SPEC section 3 step 7;
    ENGINEERING_PLAN section 1.3 upstream_runs) and the router-table registry."""

    def _write(self, outdir, rel, text):
        path = os.path.join(outdir, *rel.split("/"))
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8", newline="") as fh:
            fh.write(text)

    def test_router_table_registers_the_selftest_module(self):
        modules = server._modules()
        self.assertEqual("scripts/run_omicstat_selftest.R", modules.get(FIXTURE_MODULE))
        listing = json.loads(server.omicstat_list_modules())
        self.assertEqual(len(modules), listing["count"])
        by_name = {m["module"]: m for m in listing["modules"]}
        self.assertTrue(by_name[FIXTURE_MODULE]["summary"].startswith("Check that the omicstat R environment"))
        for name in modules:   # every router row points at an existing entry script
            self.assertTrue(os.path.isfile(server._entry_path(name)), name)
            self.assertTrue(by_name[name]["summary"], name)
        with self.assertRaisesRegex(ValueError, "unknown module 'no-such-module'"):
            server.omicstat_describe("no-such-module")

    def test_plain_description_with_unquoted_colon_remains_discoverable(self):
        text = "Run a complete differential expression workflow and return its tables. Chinese triggers: 差异表达."
        with tempfile.TemporaryDirectory() as tmp:
            self._write(tmp, "legacy/SKILL.md", "---\nname: legacy\ndescription: " + text + "\n---\n")
            with mock.patch.object(server, "SKILLS_DIR", tmp), mock.patch.dict(server._SUMMARY_CACHE, {}, clear=True):
                self.assertEqual(text.split(". ")[0] + ".", server._summary("legacy"))

    def test_empty_router_table_gives_empty_registry(self):
        with tempfile.TemporaryDirectory() as tmp:
            router = os.path.join(tmp, "SKILL.md")
            with open(router, "w", encoding="utf-8") as fh:
                fh.write("| The question sounds like... | -> Module | CLI entry script |\n|---|---|---|\n")
            with mock.patch.object(server, "ROUTER_SKILL", router), \
                    mock.patch.object(server, "_MODULES", None):
                self.assertEqual({}, server._modules())
                self.assertEqual(0, json.loads(server.omicstat_list_modules())["count"])

    def test_router_without_table_header_is_still_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            router = os.path.join(tmp, "SKILL.md")
            with open(router, "w", encoding="utf-8") as fh:
                fh.write("# no routing table here\n")
            with mock.patch.object(server, "ROUTER_SKILL", router), \
                    mock.patch.object(server, "_MODULES", None):
                with self.assertRaisesRegex(RuntimeError, "could not parse the module table"):
                    server._modules()

    def test_feature_table_is_recognized_by_header_as_primary_payload(self):
        with tempfile.TemporaryDirectory() as outdir:
            self._write(outdir, "tables/de_results.csv", FEATURE_HEADER
                        + "ENSG1,A,treated_vs_control,100,2.5,0.3,8.1,1e-10,2e-9,DESeq2-Wald,apeglm,3,3,\n"
                        + "ENSG2,B,treated_vs_control,50,-0.1,0.2,-0.5,0.6,NA,DESeq2-Wald,apeglm,3,3,independent_filtering\n"
                        + "ENSG3,C,treated_vs_control,80,0.2,0.2,0.9,0.4,0.7,DESeq2-Wald,apeglm,3,3,\n")
            rows, sources, kind = server._scan_effect_tables(outdir)
            self.assertEqual("feature-table", kind)
            self.assertEqual(["tables/de_results.csv"], sources)
            self.assertEqual("ENSG1", rows[0]["feature_id"])
            self.assertEqual("2.5", rows[0]["log2fc"])
            self.assertNotIn("padj", rows[1])      # NA is omitted like the effect-table tier
            self.assertEqual([], server._degenerate_features(outdir, sources))

    def test_shared_effect_table_still_wins_over_feature_table(self):
        with tempfile.TemporaryDirectory() as outdir:
            columns = sorted(publication.CORE_EFFECT_COLUMNS)
            self._write(outdir, "tables/effects.csv", ",".join(columns) + "\n"
                        + ",".join("1" for _ in columns) + "\n")
            self._write(outdir, "tables/features.csv", FEATURE_HEADER
                        + "ENSG1,A,c,1,1,0.1,1,0.01,0.02,m,none,3,3,\n")
            _rows, sources, kind = server._scan_effect_tables(outdir)
            self.assertEqual("shared-schema", kind)
            self.assertEqual(["tables/effects.csv"], sources)

    def test_feature_degenerate_criteria(self):
        with tempfile.TemporaryDirectory() as outdir:
            self._write(outdir, "tables/ft.csv", FEATURE_HEADER
                        # contrast a: padj all NA
                        + "G1,,a,1,0.5,0.1,1,0.5,NA,m,none,3,3,\n"
                        + "G2,,a,1,0.4,0.1,1,0.6,NA,m,none,3,3,\n"
                        # contrast b: every non-NA padj < 0.05, plus Inf log2fc
                        + "G1,,b,1,Inf,0.1,1,1e-5,0.001,m,none,3,3,\n"
                        + "G2,,b,1,-2,0.1,1,1e-4,0.01,m,none,3,3,\n"
                        + "G3,,b,1,0.1,0.1,1,0.9,NA,m,none,3,3,low_count\n"
                        # contrast c: healthy
                        + "G1,,c,1,1,0.1,1,1e-5,0.001,m,none,3,3,\n"
                        + "G2,,c,1,0.1,0.1,1,0.8,0.9,m,none,3,3,\n")
            rows, sources, kind = server._scan_effect_tables(outdir)
            self.assertEqual("feature-table", kind)
            self.assertIn("Inf", [row.get("log2fc") for row in rows])   # no OverflowError
            flagged = server._degenerate_features(outdir, sources)
            issues = {(item["row"], item["issue"].split(" ")[0]) for item in flagged}
            self.assertIn(("tables/ft.csv / contrast a", "padj"), issues)
            self.assertTrue(any(item["row"].endswith("contrast b") and item["issue"].startswith("all 2 features")
                                for item in flagged), flagged)
            self.assertTrue(any(item["row"].endswith("contrast b") and "non-finite" in item["issue"]
                                for item in flagged), flagged)
            self.assertFalse(any(item["row"].endswith("contrast c") for item in flagged), flagged)

    def test_upstream_runs_read_from_handoff_json(self):
        with tempfile.TemporaryDirectory() as outdir:
            self.assertEqual([], server._upstream_runs(outdir))
            self._write(outdir, "objects/handoff.json", json.dumps({
                "object_type": "dds", "upstream_runs": [
                    "11111111-1111-4111-8111-111111111111",
                    {"run_id": "22222222-2222-4222-8222-222222222222"},
                    "11111111-1111-4111-8111-111111111111", "", 7]}))
            self.assertEqual(["11111111-1111-4111-8111-111111111111",
                              "22222222-2222-4222-8222-222222222222"],
                             server._upstream_runs(outdir))
            self._write(outdir, "objects/handoff.json", "{not json")
            self.assertEqual([], server._upstream_runs(outdir))

    def test_blocker_severity_of_omicstat_qc_is_critical_and_blocking(self):
        with tempfile.TemporaryDirectory() as outdir:
            self._write(outdir, "qc/qc_results.csv",
                        "id,check,severity,triggered,blocking,message,action,evidence\n"
                        "ST-01,r_version,error,TRUE,FALSE,R mismatch,use the container,environment_report.md\n"
                        "ST-06,figure_packages,blocker,TRUE,TRUE,ggplot2 missing,install,environment_report.md\n"
                        "ST-08,library_isolation,blocker,FALSE,FALSE,no leak,,environment_report.md\n")
            qc = publication.scan_qc(outdir)
            self.assertEqual(3, qc["checked"])
            self.assertEqual(2, qc["triggered"])
            self.assertEqual(1, qc["blocking"])
            by_id = {item["id"]: item for item in qc["findings"]}
            self.assertEqual("critical", by_id["ST-06"]["severity"])
            self.assertTrue(by_id["ST-06"]["blocking"])
            self.assertEqual("error", by_id["ST-01"]["severity"])
            self.assertFalse(by_id["ST-01"]["blocking"])

    def test_native_env_override_reaches_the_router(self):
        if os.environ.get("OMICSTAT_NATIVE_ENV"):
            self.assertEqual(os.path.abspath(os.environ["OMICSTAT_NATIVE_ENV"]), server.NATIVE_ENV)
        native = server._engine_env("native")
        self.assertEqual("1", native["OMICSTAT_R_NATIVE"])
        self.assertEqual(server.NATIVE_ENV, native["OMICSTAT_NATIVE_ENV"])
        self.assertNotIn("OMICSTAT_R_NATIVE", server._engine_env("container"))
        with tempfile.TemporaryDirectory() as tmp, \
                mock.patch.object(server, "NATIVE_ENV", os.path.join(tmp, "absent.json")):
            self.assertFalse(server._native_available())
            with self.assertRaisesRegex(RuntimeError, "absent.json is missing"):
                server._build_cmd(server.EFFECT_VALIDATOR, [], "native")

    @unittest.skipIf(os.name == "nt", "POSIX router (bin/omicstat-r-route.sh)")
    @requires_native_engine
    def test_posix_router_isolates_the_native_library(self):
        with open(server.NATIVE_ENV, encoding="utf-8") as fh:
            native = json.load(fh)
        cmd = server._router_cmd() + ["Rscript", "-e", "cat(.libPaths(), sep='\\n')"]
        proc = subprocess.run(cmd, stdin=subprocess.DEVNULL, capture_output=True, text=True,
                              timeout=120, env=server._engine_env("native"))
        self.assertEqual(0, proc.returncode, proc.stderr)
        paths = [os.path.realpath(p) for p in proc.stdout.split()]
        self.assertEqual(os.path.realpath(native["library"]), paths[0])
        self.assertEqual(2, len(paths), paths)   # omicstat library + R's base library, nothing else
        env = server._engine_env("native")
        env["OMICSTAT_NATIVE_ENV"] = os.path.join(tempfile.gettempdir(), "omicstat-no-such-native-env.json")
        proc = subprocess.run(cmd, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=60, env=env)
        self.assertEqual(3, proc.returncode)
        self.assertIn("OS_ENV_MISSING", proc.stderr)

    def test_manifest_schema_accepts_upstream_runs(self):
        schema = publication.load_schema("publication_manifest")
        self.assertEqual("array", schema["properties"]["upstream_runs"]["type"])
        self.assertNotIn("upstream_runs", schema["required"])


class OmicsPublicationGateTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.write('tables/feature_table.csv', 'feature_id,contrast,log2fc,pvalue,padj,n_group1,n_group2,filtered_reason\ngeneA,A_vs_B,1.23456,0.00001234,0.02,3,4,\ngeneB,A_vs_B,-2,0.2,NA,3,4,independent_filtering\n')
        self.write('results/run_results.json', json.dumps({'contrast': 'A_vs_B', 'n_tested': 2, 'n_target': 3, 'n_reference': 4, 'threshold': 0.05, 'share': 0.25, 'package_version': '9.8.7'}))

    def write(self, rel, body):
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(body)

    def value_map(self):
        return publication.semantic_value_map(str(self.root), [])

    def review(self, vm):
        with mock.patch('module_seal.verify_module_seal', return_value={'ok': True, 'problems': []}):
            return publication.build_review(outdir=str(self.root), run_id='11111111-1111-4111-8111-111111111111', module=FIXTURE_MODULE,
                exit_code=0, timed_out=False, artifact_count=2, study_contract=None, contract_errors=[],
                effect_validation={'ok': True, 'canonical': [], 'invalid_named': [], 'local': [], 'errors': []},
                qc={'blocking': False, 'triggered': []}, integrity_findings=[], output_records=[], value_map=vm)

    def test_root_results_json_covers_reported_count(self):
        self.write("results.json", json.dumps({"n_cells": 1718}))
        self.write("draft/results.md", "Annotated 1718 cells.")
        coverage = publication._text_coverage(str(self.root), [])
        self.assertEqual(1, coverage["coverage_share"])
        self.assertEqual(1, coverage["numbers_checked"])

    def test_covered_draft_and_caption_precision_and_exclusions(self):
        self.write('draft/results.md', 'In 2026, DESeq2 version 1.50.0 tested 2 features. Effect 1.235; P = 1.23e-5; share 25%; threshold 0.05.\n')
        self.write('figures/result.png', 'not-a-real-png')
        self.write('figures/result.figure_spec.json', json.dumps({'caption': 'Groups: 3 and 4.', 'width': 999}))
        vm = self.value_map()
        self.assertFalse(vm['conflicts'])
        self.assertEqual(1, vm['text_coverage']['coverage_share'])
        self.assertEqual(7, vm['text_coverage']['numbers_checked'])
        self.assertIn('figures/result.figure_spec.json', vm['text_coverage']['sources'])
        finding = next(f for f in self.review(vm)['findings'] if f['rule_id'] == 'PUB-U-003')
        self.assertEqual('pass', finding['check_status'])
        self.assertTrue(finding['human_review'])
        self.assertFalse(finding['blocking'])

    def test_uncovered_number_sentence_and_warning(self):
        self.write('draft/results.md', 'We tested 2 features. There were 987654 cells.')
        vm = self.value_map()
        self.assertEqual(0.5, vm['text_coverage']['coverage_share'])
        self.assertEqual('987654', vm['text_coverage']['mismatches'][0]['number'])
        self.assertIn('cells', vm['text_coverage']['mismatches'][0]['sentence'])
        review = self.review(vm)
        f = next(f for f in review['findings'] if f['rule_id'] == 'PUB-U-003')
        self.assertEqual('fail', f['check_status'])
        self.assertEqual('warning', f['severity'])
        self.assertFalse(f['blocking'])
        self.assertIn(review['status'], {'needs_input', 'review_required'})

    def test_number_sources_and_qc_evidence(self):
        self.write('draft/results.md', 'The declared threshold is 17; observed 23.')
        self.write('draft/number_sources.json', json.dumps({'numbers': [{'value': 17, 'source': 'locked vignette threshold'}]}))
        self.write('qc/qc_results.csv', 'id,evidence\nQC-001,observed=23\n')
        self.assertEqual([], self.value_map()['text_coverage']['mismatches'])
        for invalid in ('{bad json', '[]', '{"numbers": 17}'):
            self.write('draft/number_sources.json', invalid)
            self.assertTrue(self.value_map()['text_coverage']['errors'])

    def test_feature_ledger_match_and_natural_keys(self):
        vm = self.value_map()
        self.assertEqual('checked', vm['case_flow']['status'])
        self.assertEqual([], vm['case_flow']['mismatches'])
        self.assertEqual(3, len(vm['case_flow']['comparisons']))
        keys = [k for k in vm['values'] if k.startswith('feature|')]
        self.assertEqual(2, len(keys))
        self.assertEqual({'geneA', 'geneB'}, {vm['values'][k]['feature_id'] for k in keys})
        self.assertEqual({'independent_filtering': 1, 'unfiltered': 1}, vm['case_flow']['ledgers'][0]['filtered_by_reason'])
        f = next(f for f in self.review(vm)['findings'] if f['rule_id'] == 'PUB-U-001')
        self.assertEqual('pass', f['check_status'])

    def test_feature_ledger_mismatch(self):
        self.write('results/run_results.json', json.dumps({'contrast': 'A_vs_B', 'n_tested': 99, 'n_target': 8}))
        vm = self.value_map()
        self.assertEqual(2, len(vm['case_flow']['mismatches']))
        f = next(f for f in self.review(vm)['findings'] if f['rule_id'] == 'PUB-U-001')
        self.assertEqual('fail', f['check_status'])
        self.assertFalse(f['blocking'])

    def test_not_present_without_matching_denominator(self):
        (self.root / 'results/run_results.json').unlink()
        vm = self.value_map()
        self.assertEqual('not_present', vm['case_flow']['status'])
        self.assertFalse(any(f['rule_id'] == 'PUB-U-001' and f['check_status'] in {'pass', 'fail'} for f in self.review(vm)['findings']))
        self.assertEqual('not_present', vm['text_coverage']['status'])

    def test_contrasts_are_not_conflated(self):
        self.write('results/run_results.json', json.dumps({'contrast': 'other', 'n_tested': 99}))
        self.assertEqual('not_present', self.value_map()['case_flow']['status'])
        self.write('tables/other.csv', 'feature_id,contrast,log2fc,pvalue,padj\ngeneA,other,9,0.1,0.2\n')
        vm = self.value_map()
        self.assertFalse(vm['conflicts'])
        self.assertEqual(3, len(vm['values']))

    def test_single_cell_retention_and_mismatch(self):
        self.write('tables/filter_flow.csv', 'sample,input,retained\ns1,4,3\ns2,2,1\n')
        self.write('tables/cell_qc.csv', 'cell,sample,pass\nc1,s1,TRUE\nc2,s1,TRUE\nc3,s1,TRUE\nc4,s1,FALSE\nc5,s2,TRUE\nc6,s2,FALSE\n')
        self.write('results/run_results.json', json.dumps({'n_input_cells': 6, 'n_retained': 4}))
        vm = self.value_map()
        self.assertEqual([], vm['case_flow']['mismatches'])
        self.assertEqual('checked', vm['case_flow']['status'])
        self.write('tables/filter_flow.csv', 'sample,input,retained\ns1,4,2\ns2,2,1\n')
        self.assertTrue(self.value_map()['case_flow']['mismatches'])

    def test_scanpy_stage_flow_and_sample_counts(self):
        self.write('tables/filter_flow.csv', 'stage,n_cells,n_genes\ninput,100,20\ncell_qc,80,20\ngene_qc,80,10\ndoublet_filter,70,10\n')
        self.write('tables/proportions.csv', 'sample,cluster,proportion\ns1,A,0.5\ns1,B,0.5\ns2,A,0.3\ns2,B,0.7\n')
        self.write('results/run_results.json', json.dumps({'n_input_cells': 100, 'n_cells': 70, 'n_samples': 2}))
        self.assertEqual([], self.value_map()['case_flow']['mismatches'])
        self.write('results/run_results.json', json.dumps({'n_cells': 71, 'n_samples': 3}))
        self.assertEqual(2, len(self.value_map()['case_flow']['mismatches']))


    def test_numeric_tokens_do_not_split_exponents_or_intervals(self):
        self.write('draft/results.md', 'Threshold .05; P 1.23e-5; interval (3,4); version 9.8; 10x and geneA3; year 2026.')
        coverage = self.value_map()['text_coverage']
        self.assertEqual(4, coverage['numbers_checked'])
        self.assertEqual([], coverage['mismatches'])
        self.write('draft/results.md', 'Effect 1.2347; threshold 0.051.')
        coverage = self.value_map()['text_coverage']
        self.assertEqual({'1.2347', '0.051'}, {m['number'] for m in coverage['mismatches']})

    def test_native_measurements_with_shared_row_labels_stay_separate(self):
        self.write('tables/normalized_counts.csv', 'feature_id,s1\ngeneA,100\n')
        self.write('tables/vst_matrix.csv', 'feature_id,s1\ngeneA,7.1\n')
        self.write('tables/summary.csv', 'sample,n_cells\ns1,20\ns2,30\n')
        vm = self.value_map()
        self.assertEqual([], vm['conflicts'])
        self.assertEqual(2, len([k for k in vm['values'] if k.startswith('summary|tables/summary.csv|')]))
        self.assertNotIn('tables/vst_matrix.csv', vm['canonical_sources'])

    def test_prefilter_accounting_uses_independent_result_input_count(self):
        self.write('results/run_results.json', json.dumps({'contrast': 'A_vs_B', 'n_tested': 2, 'n_prefiltered_out': 3, 'n_input_features': 5}))
        vm = self.value_map()
        self.assertEqual([], vm['case_flow']['mismatches'])
        ledger = next(l for l in vm['case_flow']['ledgers'] if l['source'] == 'tables/feature_table.csv')
        self.assertEqual(5, ledger['features_in'])
        self.write('results/run_results.json', json.dumps({'contrast': 'A_vs_B', 'n_prefiltered_out': 3, 'n_input_features': 6}))
        self.assertEqual('n_input_features', self.value_map()['case_flow']['mismatches'][0]['field'])

    def test_per_sample_retention_mismatch_cannot_hide_in_total(self):
        self.write('tables/filter_flow.csv', 'sample,input,retained\ns1,2,2\ns2,2,0\n')
        self.write('tables/cell_qc.csv', 'cell,sample,pass\nc1,s1,TRUE\nc2,s1,FALSE\nc3,s2,TRUE\nc4,s2,FALSE\n')
        vm = self.value_map()
        mismatches = vm['case_flow']['mismatches']
        self.assertEqual(2, len(mismatches))
        self.assertEqual({'s1', 's2'}, {m['context']['sample'] for m in mismatches})


if __name__ == "__main__":
    unittest.main(verbosity=2)
