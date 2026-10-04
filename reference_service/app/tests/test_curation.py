"""Promotion channel, domain proposals, and the three-column search (omicstat fork: omics fixtures)."""
import hashlib
import json
import os
import sqlite3
import unittest
from pathlib import Path
from unittest.mock import patch

import curation
import service
from harvest import HarvestStore, harvest_daily
from scratch import scratch_directory
from v2fixtures import TODAY, Fetcher, result

REVIEW = {"reviewer": "test agent", "source_locators": ["Methods > Statistical analysis"],
          "findings": ["apeglm shrinkage after a Wald test; padj < 0.05"], "limitations": ["Single tissue"],
          "proposed_module_tags": ["deseq2-wald"]}


def proposal(**extra):
    base = {"kind": "method_family", "name": "Spatial domain detection",
            "rationale": "Several spatial transcriptomics papers detect tissue domains with BayesSpace rather than clustering.",
            "modules_checked": [{"module": "seurat-cluster", "reason_not_applicable": "graph clustering ignores spatial neighbourhoods"}],
            "evidence_locators": ["PMID: 31234567 Methods", "doi:10.1000/xyz Methods section"], "proposer": "analysis agent"}
    base.update(extra)
    return base


class CurationBase(unittest.TestCase):
    def setUp(self):
        self.scratch = scratch_directory()
        self.dir = Path(self.scratch.__enter__())
        self.env = patch.dict(os.environ, {"OMICSTAT_REFERENCE_DATA": str(self.dir)})
        self.env.start()
        self.store = service.harvest_store()
        ok, self.screened_id = self.store.add_candidate({"title": "Shrinkage RNA-seq paper", "module": "deseq2-wald", "status": "screened",
            "pmid": "1111", "journal": "Genome Biology", "journal_tier": "A", "year": "2025",
            "signal": {"snippet": "DESeq2 Wald tests with apeglm shrinkage", "section_id": "s2", "section_path": "Methods"},
            "flags": [], "provenance": {}}, day="2026-09-20", quota=10)
        ok2, self.meta_id = self.store.add_candidate({"title": "Metadata only paper", "module": "deseq2-wald", "status": "metadata_only",
            "pmid": "2222", "flags": [], "provenance": {}}, day="2026-09-20", quota=10)
        self.assertTrue(ok and ok2)

    def tearDown(self):
        for instance in list(service._instances.values()):
            if hasattr(instance, "close"):
                instance.close()
        service._instances.clear()
        self.env.stop()
        self.scratch.__exit__(None, None, None)

    def records_digest(self):
        con = sqlite3.connect(self.dir / "reference.sqlite")
        try:
            rows = con.execute("SELECT record_type,record_id,data FROM records ORDER BY record_type,record_id").fetchall()
            meta = con.execute("SELECT key,value FROM metadata ORDER BY key").fetchall()
        finally:
            con.close()
        return hashlib.sha256(json.dumps([rows, meta]).encode()).hexdigest()


class PromotionTests(CurationBase):
    def test_promote_requires_review_and_screened_candidate(self):
        service.core()
        with self.assertRaises(curation.CurationError) as missing:
            curation.promote(self.dir, self.store, review_id="review-none", curator="curator")
        self.assertEqual(missing.exception.code, "review_not_found")
        meta_review = service.submit_review(self.meta_id, REVIEW)["review_id"]
        with self.assertRaises(curation.CurationError) as not_screened:
            curation.promote(self.dir, self.store, review_id=meta_review, curator="curator")
        self.assertEqual(not_screened.exception.code, "candidate_not_screened")

    def test_promote_demote_versions_and_seed_untouched(self):
        service.core()
        before = self.records_digest()
        review_id = service.submit_review(self.screened_id, REVIEW)["review_id"]
        pending = curation.list_reviews(self.dir, self.store, pending_only=True)
        self.assertEqual([r["review_id"] for r in pending["reviews"]], [review_id])
        self.assertTrue(pending["reviews"][0]["eligible_for_promotion"])
        promoted = curation.promote(self.dir, self.store, review_id=review_id, curator="Dr Curator", note="checked Methods")
        self.assertEqual((promoted["supplement_version"], promoted["status"]), (1, "active"))
        self.assertFalse(promoted["seed_modified"])
        with self.assertRaises(curation.CurationError) as twice:
            curation.promote(self.dir, self.store, review_id=review_id, curator="Dr Curator")
        self.assertEqual(twice.exception.code, "already_promoted")
        self.assertEqual(curation.list_reviews(self.dir, self.store, pending_only=True)["total"], 0)
        found = service.search("shrinkage", "deseq2-wald")["reviewed_supplement"]
        self.assertEqual([r["supplement_id"] for r in found["results"]], [promoted["supplement_id"]])
        record = service.get_record("supplement", promoted["supplement_id"])
        self.assertEqual(record["curator"], "Dr Curator")
        demoted = curation.demote(self.dir, supplement_id=promoted["supplement_id"], reason="Wrong contrast", curator="Dr Curator")
        self.assertEqual((demoted["status"], demoted["supplement_version"], demoted["row_deleted"]), ("demoted", 2, False))
        with self.assertRaises(curation.CurationError):
            curation.demote(self.dir, supplement_id=promoted["supplement_id"], reason="again")
        self.assertEqual(service.search("shrinkage", "deseq2-wald")["reviewed_supplement"]["total"], 0)
        self.assertEqual(service.get_record("supplement", promoted["supplement_id"])["status"], "demoted")
        self.assertEqual(before, self.records_digest())

    def test_no_mcp_promotion_tool(self):
        import asyncio
        from v2fixtures import load_reference_server
        server = load_reference_server()
        names = {t.name for t in asyncio.run(server.mcp.list_tools())}
        self.assertFalse(any("promote" in n or "demote" in n or "accept" in n for n in names))


class DomainTests(CurationBase):
    def test_proposal_validation_and_pii(self):
        bad = [proposal(kind="new_engine"), proposal(modules_checked=[]),
               proposal(modules_checked=[{"module": "nope", "reason_not_applicable": "x"}]),
               proposal(modules_checked=[{"module": "seurat-cluster"}]),
               proposal(rationale="email me at x@y.org"), proposal(extra=1),
               proposal(evidence_locators=["x"] * 11)]
        for item in bad:
            with self.assertRaises(curation.CurationError, msg=str(item)[:100]):
                curation.propose_domain(self.dir, item)
        answer = curation.propose_domain(self.dir, proposal())
        self.assertEqual(answer["status"], "proposed")
        self.assertEqual(answer["effects"], {"rotation_changed": False, "code_installed": False, "analysis_supported": False})
        again = curation.propose_domain(self.dir, proposal())
        self.assertEqual((again["proposal_id"], again["merged"]), (answer["proposal_id"], True))
        self.assertEqual(self.store.accepted_profiles(), [])

    def test_accept_and_ack_restrictions(self):
        module_req = curation.propose_domain(self.dir, proposal(kind="analysis_module_request", name="Spatial deconvolution engine"))
        with self.assertRaises(curation.CurationError) as refused:
            curation.domain_accept(self.dir, self.store, proposal_id=module_req["proposal_id"], curator="c")
        self.assertEqual(refused.exception.code, "analysis_module_request_not_acceptable")
        acked = curation.domain_ack(self.dir, proposal_id=module_req["proposal_id"], curator="c")
        self.assertEqual((acked["status"], acked["module_created"]), ("acknowledged_engineering_backlog", False))
        knowledge = curation.propose_domain(self.dir, proposal(kind="knowledge_domain", name="Tumour microenvironment biology"))
        with self.assertRaises(curation.CurationError) as wrong:
            curation.domain_ack(self.dir, proposal_id=knowledge["proposal_id"], curator="c")
        self.assertEqual(wrong.exception.code, "use_domain_accept")
        accepted = curation.domain_accept(self.dir, self.store, proposal_id=knowledge["proposal_id"], curator="c")
        self.assertEqual((accepted["status"], accepted["added_to_rotation"], accepted["analysis_supported"]), ("accepted", False, False))
        with self.assertRaises(curation.CurationError):
            curation.domain_accept(self.dir, self.store, proposal_id=knowledge["proposal_id"], curator="c")

    def test_accept_with_profile_requires_live_validation_then_joins_rotation(self):
        family = curation.propose_domain(self.dir, proposal())
        profile = {"epmc_query": '(METHODS:"BayesSpace" OR METHODS:"spatial domain")', "signal_regex": r"BayesSpace|spatial domains?",
                   "exclude_regex": r"(?i)\bprotocol\b"}
        empty = lambda url: json.dumps({"hitCount": 0, "resultList": {"result": []}}).encode()
        with self.assertRaises(curation.CurationError) as failed:
            curation.domain_accept(self.dir, self.store, proposal_id=family["proposal_id"], curator="c", profile=profile, fetch=empty)
        self.assertEqual(failed.exception.code, "profile_validation_failed")
        self.assertEqual(curation.list_domains(self.dir, "proposed")["proposals"][0]["proposal_id"], family["proposal_id"])
        hits = lambda url: json.dumps({"hitCount": 3, "resultList": {"result": [{"title": "A BayesSpace tissue study"}]}}).encode()
        accepted = curation.domain_accept(self.dir, self.store, proposal_id=family["proposal_id"], curator="c", profile=profile, fetch=hits)
        self.assertTrue(accepted["added_to_rotation"])
        self.assertEqual(accepted["discovery_profile_key"], "domain:spatial-domain-detection")
        fetcher = Fetcher(pages=lambda q, n: [])
        harvest_daily(self.store, target=10, transport="direct", fetcher=fetcher, now=TODAY)
        self.assertTrue(any('METHODS:"BayesSpace"' in q for q in fetcher.search_queries))


class DomainRotationRemediationTests(CurationBase):
    """F-06 (domain profiles really rotate), F-13 (slug collisions), F-10 (read-only supplement lookup)."""
    PROFILE = {"epmc_query": '(METHODS:"BayesSpace" OR METHODS:"spatial domain")', "signal_regex": r"WGCNA built",
               "exclude_regex": r"(?i)\bprotocol\b"}

    def hits(self, url):
        return json.dumps({"hitCount": 3, "resultList": {"result": [{"title": "A BayesSpace tissue study"}]}}).encode()

    def test_domain_profile_runs_even_when_every_module_yields(self):
        from v2fixtures import UniqueStream
        family = curation.propose_domain(self.dir, proposal())
        accepted = curation.domain_accept(self.dir, self.store, proposal_id=family["proposal_id"], curator="c",
                                          profile=self.PROFILE, fetch=self.hits)
        key = accepted["discovery_profile_key"]
        fetcher = Fetcher(pages=UniqueStream(size=2))
        answer = harvest_daily(self.store, target=10, transport="direct", fetcher=fetcher, now=TODAY)
        self.assertLessEqual(answer["daily_total"], 10)
        self.assertTrue(any('METHODS:"BayesSpace"' in q for q in fetcher.search_queries))
        domain_rows = [i for i in self.store.list_candidates(limit=50)["items"] if i["module"] == key and i["status"] == "screened"]
        self.assertEqual(len(domain_rows), 1)
        self.assertEqual(self.store.cursor("v2:domain-rotation"), key)  # single profile: cursor wraps to itself
        # 1 fixture candidate already counted today + 1 domain paper -> only 8 modules advance the map cursor
        self.assertEqual(self.store.status()["method_map"]["next_module"], "clusterprofiler-ora")

    def test_same_slug_proposals_get_distinct_active_keys(self):
        first = curation.propose_domain(self.dir, proposal(name="Spatial domains", rationale="first rationale"))
        second = curation.propose_domain(self.dir, proposal(name="Spatial  Domains!", rationale="second rationale"))
        a = curation.domain_accept(self.dir, self.store, proposal_id=first["proposal_id"], curator="c", profile=self.PROFILE, fetch=self.hits)
        b = curation.domain_accept(self.dir, self.store, proposal_id=second["proposal_id"], curator="c", profile=self.PROFILE, fetch=self.hits)
        self.assertEqual((a["discovery_profile_key"], b["discovery_profile_key"]), ("domain:spatial-domains", "domain:spatial-domains-2"))
        self.assertEqual(sorted(p["profile_key"] for p in self.store.accepted_profiles()), ["domain:spatial-domains", "domain:spatial-domains-2"])

    def test_reference_failure_deactivates_the_new_profile(self):
        family = curation.propose_domain(self.dir, proposal())
        with patch.object(curation, "_accept_in_reference", side_effect=sqlite3.OperationalError("database is locked")):
            with self.assertRaises(sqlite3.OperationalError):
                curation.domain_accept(self.dir, self.store, proposal_id=family["proposal_id"], curator="c", profile=self.PROFILE, fetch=self.hits)
        self.assertEqual(self.store.accepted_profiles(), [])
        self.assertTrue(self.store.profile_key_taken("domain:spatial-domain-detection"))
        self.assertEqual(curation.list_domains(self.dir, "proposed")["proposals"][0]["proposal_id"], family["proposal_id"])

    def test_supplement_lookup_on_v1_shaped_reference_is_read_only(self):
        service.core()  # v1-shaped reference.sqlite: seed tables only
        con = sqlite3.connect(self.dir / "reference.sqlite")
        tables_before = sorted(r[0] for r in con.execute("SELECT name FROM sqlite_master WHERE type='table'"))
        con.close()
        self.assertNotIn("reviewed_supplement", tables_before)
        answer = service.invoke(service.get_record, "supplement", "RS-x")
        self.assertEqual((answer["status"], answer["error"]["code"]), ("needs_input", "not_found"))
        con = sqlite3.connect(self.dir / "reference.sqlite")
        self.assertEqual(sorted(r[0] for r in con.execute("SELECT name FROM sqlite_master WHERE type='table'")), tables_before)
        con.close()
        self.assertFalse((self.dir / "backups").exists())


class SearchColumnTests(CurationBase):
    def test_three_labelled_columns_and_legacy_hidden(self):
        con = self.store._connection()
        try:
            con.execute("INSERT INTO candidates(candidate_id,title,module,status,flags_json,provenance_json,record_json,created_at,legacy_flag,pipeline) VALUES('H-old','Old shrinkage paper','deseq2-wald','candidate_review_required','[]','{}','{\"title\":\"Old shrinkage paper\"}','2026-09-20',?,NULL)", ("legacy_v1_unscreened",))
        finally:
            con.close()
        answer = service.search("shrinkage", "deseq2-wald", 10, 0)
        self.assertEqual(answer["columns_order"], ["curated", "reviewed_supplement", "discovery"])
        self.assertEqual(answer["column"], "curated")
        self.assertTrue(all(r["column"] == "curated" for r in answer["results"]))
        discovery_ids = [r["candidate_id"] for r in answer["discovery"]["results"]]
        self.assertEqual(discovery_ids, [self.screened_id])  # metadata_only and legacy never appear
        item = answer["discovery"]["results"][0]
        self.assertEqual((item["label"], item["journal_tier"]), ("unreviewed_machine_screened", "A"))
        self.assertIn("apeglm", item["signal_snippet"])
        self.assertEqual(item["locator"]["section_path"], "Methods")
        off = service.search("shrinkage", "deseq2-wald", 10, 0, include_discovery=False)
        self.assertEqual(off["discovery"]["results"], [])
        self.assertFalse(off["discovery"]["included"])
        other = service.search("", "seurat-qc", 10, 0)
        self.assertEqual(other["discovery"]["total"], 0)
        self.assertEqual(service.invoke(service.search, "x", None, 10, 0, "yes")["status"], "needs_input")


if __name__ == "__main__":
    unittest.main()
