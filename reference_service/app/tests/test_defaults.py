"""Locked default versus literature report and the default_context line of reference_advise."""
import json
import unittest
from pathlib import Path
from unittest.mock import patch

import defaults
from reference_core import ReferenceStore
from s0_loader import load
from scratch import scratch_directory

OPTION_DEFAULTS = {"modules": {
    "scanpy-markers": {"--test": {"default": "'t-test'", "keys": ["test"]}, "--cluster-col": {"default": "no scientific default; consult L1", "keys": ["cluster_col"]}},
    "deseq2-wald": {"--alpha": {"default": "0.05", "keys": ["padj_cutoff"]}, "--shrinkage": {"default": "apeglm", "keys": ["shrinkage"]},
                    "--condition": {"default": "condition", "keys": ["design"]}, "--reference": {"default": None, "keys": ["design"]}},
}}


def obs(module, paper, option, value, options=None):
    return {"module": module, "paper": paper, "options": [option] if options is None else options, "value": value}


def _scanpy_markers_bundle():
    papers = [{"paper_id": f"PMID-{i}", "pmid": str(i), "pmcid": f"PMC{i}", "title": f"Paper {i}", "year": 2024, "journal": "Genome Biology",
               "doi": f"10.1/{i}", "licence": "cc-by", "jats_sha256": "0" * 64, "metadata_status": "corpus_metadata", "url": "u"} for i in range(1, 12)]
    usages = []
    for i, paper in enumerate(papers):
        value = "wilcoxon" if i < 9 else "t-test"
        usages.append({"usage_id": f"S0-scanpy-markers-{paper['pmid']}", "paper_id": paper["paper_id"], "paper": paper, "module_tags": ["scanpy-markers"],
                       "method": "scanpy-markers", "column": "reviewed_supplement", "context": [], "coverage": [], "ecosystems": ["scverse"],
                       "parameters": [{"extraction_key": "test", "value": value, "options": ["--test"], "mapping_status": "mapped", "ecosystem": "scverse",
                                       "applies": True, "note": "", "provenance": {"evidence_state": "verified_S0"},
                                       "source_locator": {"url": "u", "snippet": "rank_genes_groups with the " + value, "section_path": "Methods", "line": 1}}],
                       "provenance": {"evidence_state": "verified_S0"}, "support_role": "direct_application", "reviewer_status": "ready_for_root_review",
                       "verification_status": "primary_source_methods_verified",
                       "implementation_compatibility": {"status": "inventory_supported", "scope": "x"},
                       "source_locator": {"observations": [{"url": "u", "snippet": "s", "section_path": "Methods", "line": 1}]},
                       "limitations": ["x"], "execution_authorized": False, "automatic_parameter_application": False})
    bundle = {"schema": "omicstat.s0-evidence.v1", "papers": papers, "usages": usages, "decisions": [], "inputs": [], "counts": {}, "excluded": [],
              "execution_authorized": False, "automatic_parameter_application": False}
    return bundle


class CompareTests(unittest.TestCase):
    def test_value_parsing(self):
        self.assertEqual(defaults.parse_value("fdr < 0.05", "num"), 0.05)
        self.assertEqual(defaults.parse_value("<0.05", "num"), 0.05)
        self.assertEqual(defaults.parse_value("0.05 (qvaluecutoff)", "num"), 0.05)
        self.assertEqual(defaults.parse_value("5%", "num"), 0.05)
        self.assertEqual(defaults.parse_value("10,000 umi", "num"), 10000.0)
        self.assertIsNone(defaults.parse_value("a model with ~ treatment", "num"))
        self.assertIsNone(defaults.parse_value("not reported", "word"))
        self.assertEqual(defaults.parse_value("Wilcoxon rank sum test", "word"), "wilcoxon")
        self.assertEqual(defaults.parse_value("t-test", "word"), "t-test")
        self.assertEqual(defaults.clean_default("0.9 (model.train.train_size; value)"), ("num", 0.9))
        self.assertEqual(defaults.clean_default("'t-test'"), ("word", "t-test"))
        for text in ("no scientific default; consult L1 tutorial", 'c("sum", "mean")', "NULL", "off", None, 'TRUE"; native'):
            self.assertIsNone(defaults.clean_default(text), text)

    def test_minority_default_is_flagged_and_ambiguity_is_skipped(self):
        rows = [obs("scanpy-markers", f"P{i}", "--test", "wilcoxon") for i in range(9)] + [obs("scanpy-markers", f"Q{i}", "--test", "t-test") for i in range(2)]
        rows += [obs("deseq2-wald", f"A{i}", "--alpha", "0.05") for i in range(10)]            # default is the majority
        rows += [obs("deseq2-wald", f"B{i}", "--alpha", v) for i, v in enumerate(["0.1", "0.01"])]
        rows += [obs("deseq2-wald", "D1", "--condition", "x", options=["--condition", "--reference"])]  # ambiguous key
        rows += [obs("deseq2-wald", "S1", "--shrinkage", "ashr"), obs("deseq2-wald", "S1", "--shrinkage", "apeglm")]  # same paper counted once
        report = defaults.compare(rows, OPTION_DEFAULTS["modules"])
        markers = report["scanpy-markers"]["--test"]
        self.assertEqual((markers["n_parsed"], markers["n_at_default"], markers["default_share"]), (11, 2, 0.182))
        self.assertEqual(markers["flags"], ["default_minority"])
        self.assertEqual(markers["top_values"][0], {"value": "wilcoxon", "n": 9})
        self.assertNotIn("--cluster-col", report["scanpy-markers"])                             # descriptive default: not compared
        alpha = report["deseq2-wald"]["--alpha"]
        self.assertEqual((alpha["n_parsed"], alpha["default_share"], alpha["flags"]), (12, 0.833, []))
        self.assertNotIn("--condition", report["deseq2-wald"])
        self.assertEqual(report["deseq2-wald"]["--shrinkage"]["n_parsed"], 1)
        self.assertTrue(report["deseq2-wald"]["--shrinkage"]["low_n"])

    def test_bimodal_flag_needs_enough_papers(self):
        rows = [obs("deseq2-wald", f"X{i}", "--alpha", "0.05") for i in range(5)] + [obs("deseq2-wald", f"Y{i}", "--alpha", "0.1") for i in range(4)]
        self.assertEqual(defaults.compare(rows, OPTION_DEFAULTS["modules"])["deseq2-wald"]["--alpha"]["flags"], ["bimodal"])
        few = defaults.compare(rows[:3] + rows[5:7], OPTION_DEFAULTS["modules"])["deseq2-wald"]["--alpha"]
        self.assertEqual(few["flags"], [])

    def test_cross_ecosystem_rows_are_excluded_counted_and_do_not_shadow_a_paper(self):
        defaults_table = {"scran-cluster": {"--cluster-method": {"default": "walktrap", "keys": ["graph_cluster_method"]}}}
        rows = [obs("scran-cluster", f"B{i}", "--cluster-method", "walktrap") for i in range(3)]
        rows += [dict(obs("scran-cluster", f"S{i}", "--cluster-method", "leiden"), cross_ecosystem=True) for i in range(6)]
        rows += [dict(obs("scran-cluster", "B0", "--cluster-method", "louvain"), cross_ecosystem=True)]   # same paper as an own-ecosystem row
        rows.insert(0, dict(obs("scran-cluster", "B1", "--cluster-method", "leiden"), cross_ecosystem=True))  # excluded row listed before B1's own value
        row = defaults.compare(rows, defaults_table)["scran-cluster"]["--cluster-method"]
        self.assertEqual((row["n_parsed"], row["n_at_default"], row["n_excluded_cross_ecosystem"]), (3, 3, 8))
        self.assertEqual(row["flags"], [])                                    # foreign values do not create a minority
        self.assertEqual(row["top_values"], [{"value": "walktrap", "n": 3}])
        pooled = defaults.compare([dict(r, cross_ecosystem=False) for r in rows], defaults_table)["scran-cluster"]["--cluster-method"]
        self.assertIn("default_minority", pooled["flags"])                      # the old pooled behaviour, for contrast

    def test_locked_default_is_shown_without_its_trailing_remark(self):
        table = {"m": {"--x": {"default": "1 (scvi.model.SCVI.n_layers; value)", "keys": ["x"]}, "--y": {"default": "'t-test' (package default; tutorial uses wilcoxon)", "keys": ["y"]}}}
        report = defaults.compare([obs("m", "P1", "--x", "2"), obs("m", "P1", "--y", "wilcoxon")], table)["m"]
        self.assertEqual((report["--x"]["locked_default"], report["--y"]["locked_default"]), ("1", "'t-test'"))

    def test_unparsed_count_is_reported(self):
        rows = [obs("deseq2-wald", f"A{i}", "--alpha", "0.05") for i in range(3)] + [obs("deseq2-wald", "M1", "--alpha", "0.25; 0.1 (second call)")]
        row = defaults.compare(rows, OPTION_DEFAULTS["modules"])["deseq2-wald"]["--alpha"]
        self.assertEqual((row["n_parsed"], row["n_unparsed"]), (3, 1))

    def test_owner_verdict_attaches_only_to_the_default_it_was_made_for(self):
        rows = [obs("scanpy-markers", f"P{i}", "--test", "wilcoxon") for i in range(9)] + [obs("scanpy-markers", f"Q{i}", "--test", "t-test") for i in range(2)]
        verdict = {"verdict": "keep_documented", "note": "n", "decided": "2026-10-11"}
        row = defaults.compare(rows, OPTION_DEFAULTS["modules"], {("scanpy-markers", "--test", "t-test"): verdict})["scanpy-markers"]["--test"]
        self.assertEqual(row["owner_verdict"], verdict)
        self.assertEqual(row["flags"], ["default_minority"])                    # still flagged in the full report
        other = defaults.compare(rows, OPTION_DEFAULTS["modules"], {("scanpy-markers", "--test", "wilcoxon"): verdict})["scanpy-markers"]["--test"]
        self.assertIsNone(other["owner_verdict"])                               # the locked default changed: the verdict lapses
        self.assertIsNone(defaults.compare(rows, OPTION_DEFAULTS["modules"])["scanpy-markers"]["--test"]["owner_verdict"])

    def test_default_key_and_adjudication_file_load(self):
        self.assertEqual(defaults.default_key(("num", 1.0)), "1")
        self.assertEqual(defaults.default_key(("num", 0.25)), "0.25")
        self.assertEqual(defaults.default_key(("word", "t-test")), "t-test")
        self.assertEqual(defaults.load_adjudications(Path("/nonexistent/adjudications.json")), {})
        with scratch_directory() as tmp:
            path = Path(tmp) / "a.json"
            path.write_text(json.dumps({"adjudications": [{"module": "m", "option": "--o", "locked_default": "1", "verdict": "v", "note": "n"}, {"module": "bad"}]}), encoding="utf-8")
            self.assertEqual(defaults.load_adjudications(path), {("m", "--o", "1"): {"verdict": "v", "note": "n"}})

    def test_shipped_adjudications_match_shipped_option_defaults(self):
        raw = json.loads(defaults.ADJUDICATIONS_PATH.read_text(encoding="utf-8"))
        self.assertEqual(raw["schema"], "omicstat.default-adjudications.v1")
        shipped = defaults.load_option_defaults()
        self.assertEqual(len(defaults.load_adjudications()), len(raw["adjudications"]))
        for row in raw["adjudications"]:
            self.assertIn(row["verdict"], raw["verdicts"], row)
            info = shipped[row["module"]][row["option"]]                         # a verdict for a vanished option is a stale verdict
            cleaned = defaults.clean_default(info["default"])
            self.assertIsNotNone(cleaned, row)
            self.assertEqual(defaults.default_key(cleaned), row["locked_default"], "the locked default changed: revisit the verdict %s" % row)

    def test_option_defaults_file_ships_and_is_consistent(self):
        shipped = defaults.load_option_defaults()
        method_map = json.loads((Path(__file__).resolve().parents[1] / "method_map.json").read_text(encoding="utf-8"))
        modules = {m["module"] for m in method_map["modules"]}
        self.assertTrue(set(shipped) <= modules)
        self.assertGreaterEqual(len(shipped), 30)
        self.assertEqual(shipped["deseq2-wald"]["--alpha"]["default"], "0.05")


class AdviseDefaultContextTests(unittest.TestCase):
    def test_adjudicated_flag_moves_out_of_flagged_but_stays_visible(self):
        bundle = _scanpy_markers_bundle()
        with scratch_directory() as tmp:
            tmp = Path(tmp)
            (tmp / "bundle.json").write_text(json.dumps(bundle), encoding="utf-8")
            (tmp / "defaults.json").write_text(json.dumps(OPTION_DEFAULTS), encoding="utf-8")
            (tmp / "adj.json").write_text(json.dumps({"adjudications": [{"module": "scanpy-markers", "option": "--test", "locked_default": "t-test",
                                                       "verdict": "keep_documented", "note": "owner kept it", "decided": "2026-10-11"}]}), encoding="utf-8")
            data = tmp / "data"
            with patch.object(defaults, "OPTION_DEFAULTS_PATH", tmp / "defaults.json"), patch.object(defaults, "ADJUDICATIONS_PATH", tmp / "adj.json"):
                load(tmp / "bundle.json", data)
                store = ReferenceStore(data / "reference.sqlite", Path(__file__).resolve().parents[1] / "seed" / "catalog.json")
                contract = {k: ("x" if v != "list_or_not_applicable" else []) for k, v in store._common_required().items()}
                context = store.advise("scanpy-markers", contract)["default_context"]
                self.assertEqual(context["status"], "no_flag")
                self.assertEqual(context["flagged"], [])
                self.assertEqual(context["adjudicated"][0]["option"], "--test")
                self.assertEqual(context["adjudicated"][0]["owner_verdict"]["verdict"], "keep_documented")
                self.assertEqual(context["adjudicated"][0]["flags"], ["default_minority"])
                self.assertIn("already decided", context["adjudicated_note"])
                store.close()

    def test_advise_carries_default_context_without_changing_authority(self):
        bundle = _scanpy_markers_bundle()
        with scratch_directory() as tmp:
            tmp = Path(tmp)
            (tmp / "bundle.json").write_text(json.dumps(bundle), encoding="utf-8")
            (tmp / "defaults.json").write_text(json.dumps(OPTION_DEFAULTS), encoding="utf-8")
            data = tmp / "data"
            with patch.object(defaults, "OPTION_DEFAULTS_PATH", tmp / "defaults.json"), patch.object(defaults, "ADJUDICATIONS_PATH", tmp / "no-adjudications.json"):
                load(tmp / "bundle.json", data)
                store = ReferenceStore(data / "reference.sqlite", Path(__file__).resolve().parents[1] / "seed" / "catalog.json")
                contract = {k: ("x" if v != "list_or_not_applicable" else []) for k, v in store._common_required().items()}
                answer = store.advise("scanpy-markers", contract)
                context = answer["default_context"]
                self.assertEqual(context["status"], "flagged")
                self.assertEqual(context["flagged"][0]["option"], "--test")
                self.assertEqual(context["flagged"][0]["flags"], ["default_minority"])
                self.assertEqual(context["flagged"][0]["top_reported_values"][0], {"value": "wilcoxon", "n": 9})
                self.assertFalse(answer["execution_authorized"])
                self.assertFalse(answer["automatic_parameter_application"])
                self.assertIn("nothing here changes a parameter", context["caveat"])
                other = store.advise("deseq2-wald", contract)["default_context"]
                self.assertEqual(other["status"], "no_default_context")
                store.close()


if __name__ == "__main__":
    unittest.main()
