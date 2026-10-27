"""Method lexicon + method mentions (coverage upgrade): tokens only, countable licences only."""
import json
import sqlite3
import unittest
from pathlib import Path

import lexicon
from harvest import HarvestStore, harvest_daily
from scratch import scratch_directory
from v2fixtures import TODAY, Fetcher, jats, result

OFF_TOPIC_BODY = ("Cells were integrated with Harmony and doublets were removed using DoubletFinder; "
                  "RNA velocity was estimated with scVelo. The harmony of the design was discussed in the lab.")


class LexiconTests(unittest.TestCase):
    def test_lexicon_is_valid_and_scoped(self):
        lex = lexicon.default_lexicon()
        self.assertEqual(lex["version"], "lexicon-v1")
        self.assertGreaterEqual(len(lex["entries"]), 180)
        self.assertLessEqual(len(lex["entries"]), 260)
        tokens = [e["token"] for e in lex["entries"]]
        self.assertEqual(len(tokens), len(set(tokens)))
        # clinical statistics are out of scope
        for banned in ("cox", "coxph", "survival", "mixed-model", "lme4", "meta-analysis", "kaplan-meier", "logistic"):
            self.assertNotIn(banned, tokens)
        method_map = json.loads((Path(__file__).resolve().parents[1] / "method_map.json").read_text(encoding="utf-8"))
        modules = {m["module"] for m in method_map["modules"]}
        for entry in lex["entries"]:
            self.assertTrue(set(entry["our_module"]) <= modules, entry["token"])
            if entry["licence_note"]:
                self.assertFalse(entry["rank_eligible"], entry["token"])
        # every module has at least one lexicon entry pointing at it
        covered = {m for e in lex["entries"] for m in e["our_module"]}
        self.assertEqual(modules - covered, set())

    def test_scan_returns_tokens_only(self):
        found = lexicon.scan([{"text": OFF_TOPIC_BODY}])
        self.assertEqual(found, ["doubletfinder", "harmony", "scvelo"])
        self.assertEqual(lexicon.scan(["The harmony of colours and a velocity of 3 m/s."]), [])
        self.assertIn("deseq2", lexicon.scan(["Counts were analysed with DESeq2."]))
        self.assertIn("combat-seq", lexicon.scan(["Batches were adjusted with ComBat-seq."]))
        self.assertNotIn("combat", lexicon.scan(["Batches were adjusted with ComBat-seq."]))
        self.assertEqual(lexicon.scan(["The epic EPIC array was used"]), [])  # methylation array, not the deconvolution tool
        self.assertIn("epic-deconv", lexicon.scan(["EPIC was used for immune cell fraction deconvolution."]))


class MentionStoreTests(unittest.TestCase):
    def setUp(self):
        self.scratch = scratch_directory()
        self.dir = Path(self.scratch.__enter__())
        self.store = HarvestStore(self.dir / "harvest.sqlite")

    def tearDown(self):
        self.scratch.__exit__(None, None, None)

    def rows(self, sql):
        with sqlite3.connect(self.dir / "harvest.sqlite") as db:
            return db.execute(sql).fetchall()

    def test_migration_is_recorded_and_idempotent(self):
        HarvestStore(self.dir / "harvest.sqlite")
        versions = [m["version"] for m in self.store.migration_status()]
        self.assertIn("v3-001-coverage", versions)
        self.assertEqual(versions.count("v3-001-coverage"), 1)

    def test_one_count_per_paper(self):
        ids = {"pmid:11", "pmcid:PMC11"}
        self.assertTrue(self.store.add_mentions(ids, ["harmony", "seurat"], "lexicon-v1", "off_topic", "2026-09-20"))
        self.assertFalse(self.store.add_mentions(ids, ["harmony", "scanpy"], "lexicon-v1", "screened", "2026-09-21", "H-1"))
        self.assertEqual(self.rows("SELECT token,from_outcome,candidate_id FROM method_mentions ORDER BY token"),
                         [("harmony", "off_topic", "H-1"), ("seurat", "off_topic", "H-1")])
        self.assertEqual(self.rows("SELECT count(*) FROM mention_papers"), [(1,)])

    def test_harvest_stores_tokens_for_countable_licences_only(self):
        bodies = {"PMC7001": jats("PMC7001", methods=OFF_TOPIC_BODY),
                  "PMC7002": jats("PMC7002", methods=OFF_TOPIC_BODY, license_text="All rights reserved"),
                  "PMC7003": jats("PMC7003", methods=OFF_TOPIC_BODY, license_text="Creative Commons Attribution-NonCommercial-NoDerivatives")}
        fetcher = Fetcher(pages=lambda q, n: [result(7001), result(7002), result(7003)] if n == 1 else [result(8000 + n)], bodies=bodies)
        answer = harvest_daily(self.store, target=1, transport="direct", fetcher=fetcher, now=TODAY)
        self.assertEqual(answer["state"], "completed")
        gates = answer["gate_counts"]
        self.assertEqual((gates.get("off_topic"), gates.get("rights_unconfirmed"), gates.get("rights_restricted")), (1, 1, 1))
        refs = self.rows("SELECT DISTINCT paper_ref FROM method_mentions ORDER BY paper_ref")
        self.assertEqual(refs, [("pmid:7001",), ("pmid:8002",)])  # 7002 / 7003 were not countable
        off = self.rows("SELECT token FROM method_mentions WHERE paper_ref='pmid:7001' ORDER BY token")
        self.assertEqual(off, [("doubletfinder",), ("harmony",), ("scvelo",)])
        self.assertEqual(self.rows("SELECT from_outcome FROM mention_papers WHERE paper_ref='pmid:7001'"), [("off_topic",)])
        screened = self.rows("SELECT from_outcome,candidate_id FROM method_mentions WHERE paper_ref='pmid:8002' LIMIT 1")
        self.assertEqual(screened[0][0], "screened")
        self.assertTrue(screened[0][1].startswith("H-"))
        # the record carries the tokens and the version, never text
        record = self.store.get_candidate(screened[0][1])
        self.assertEqual(record["mentions_version"], "lexicon-v1")
        self.assertIn("deseq2", record["method_mentions"])
        # tokens only: no table of the store holds a sentence of the Methods text
        with sqlite3.connect(self.dir / "harvest.sqlite") as db:
            dump = "\n".join(db.iterdump())
        self.assertNotIn("doublets were removed", dump)
        self.assertNotIn("The harmony of the design", dump)
        self.assertEqual(self.store.status()["coverage"]["mention_papers"], 2)


class S0MethodsUsedTests(unittest.TestCase):
    """The shipped bundle carries methods_used per paper; the loader keeps it in candidate_json but out of the search index and citations."""
    def test_bundle_loader_and_search(self):
        import curation
        from s0_loader import load
        bundle = Path(__file__).resolve().parents[1] / "s0_evidence" / "catalog.json"
        doc = json.loads(bundle.read_text(encoding="utf-8"))
        self.assertGreaterEqual(len([u for u in doc["usages"] if u["column"] == "reviewed_supplement"]), 958)
        self.assertEqual(doc["methods_used_source"]["lexicon_version"], lexicon.default_lexicon()["version"])
        self.assertTrue(all("methods_used" in p for p in doc["papers"]))
        self.assertFalse(any(e["reason"] == "verification_section_3_nonverbatim" for e in doc["excluded"]))
        self.assertTrue(any(u["usage_id"] == "S0-immunedeconv-infiltration-32647202" for u in doc["usages"]))
        with scratch_directory() as tmp:
            load(bundle, Path(tmp))
            with sqlite3.connect(Path(tmp) / "reference.sqlite") as db:
                row = db.execute("SELECT candidate_json,searchable FROM reviewed_supplement WHERE supplement_id='S0-deseq2-wald-33298436'").fetchone()
            candidate = json.loads(row[0])
            self.assertEqual(candidate["methods_used"]["lexicon_version"], "lexicon-v1")
            self.assertTrue(candidate["methods_used"]["tokens"])
            self.assertNotIn('"tokens"', row[1])
            hit = curation.search_supplement(Path(tmp), [], "deseq2-wald", 3, 0)["results"][0]
            self.assertNotIn("methods_used", hit["citations"][0])


if __name__ == "__main__":
    unittest.main()
