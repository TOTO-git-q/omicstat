"""Acquisition gates: whitelist, Methods-section signal, year, pub types, quota, shortfall, legacy.

omicstat fork: ported from the medstat-reference v2 tests to the omics configuration."""
import datetime as dt
import json
import re
import sqlite3
import tarfile
import unittest
from pathlib import Path

import discovery
from harvest import LEGACY_FLAG, HarvestStore, harvest_daily
from scratch import scratch_directory
from v2fixtures import ALL_SIGNALS, OFF_LIST, TODAY, Fetcher, UniqueStream, jats, profiles_with_meta, result

ROOT = Path(__file__).resolve().parents[1]
DAY = "2026-09-20"


class ConfigTests(unittest.TestCase):
    def test_journal_whitelist_is_verified_and_tiered(self):
        journals = discovery.load_journals()
        self.assertEqual(len(journals["journals"]), 38)
        for j in journals["journals"]:
            self.assertIn(j["tier"], ("A", "B"))
            self.assertRegex(j["verified_on"], r"^\d{4}-\d{2}-\d{2}$")
            self.assertIn("Europe PMC", j["verified_via"])
            for issn in j["issn"]:
                self.assertIn(issn, j["verified_via"] + json.dumps(j["issn"]))
        self.assertEqual({j["tier"] for j in journals["journals"]}, {"A", "B"})

    def test_profiles_cover_the_registry_and_validation_is_recorded(self):
        config = discovery.load_profiles()
        order = [m["module"] for m in json.loads((ROOT / "method_map.json").read_text(encoding="utf-8"))["modules"]]
        self.assertEqual(len(order), 38)
        self.assertEqual(sorted(config["profiles"]), sorted(order))
        raw = json.loads((ROOT / "discovery_profiles.json").read_text(encoding="utf-8"))["profiles"]
        for record in raw:
            self.assertIn(record["profile_status"], ("ok", "weak"))
            self.assertLessEqual(record["validation_rounds"], 3)
            self.assertIsInstance(record["s0_validation"]["hit_count"], int)
            self.assertEqual(record["profile_status"], "ok" if record["s0_validation"]["screened"] > 0 else "weak")

    def test_every_profile_signal_is_specific_not_generic(self):
        config = discovery.load_profiles()
        generic = "The statistical analysis used a regression model and methods for data analysis."
        for module, profile in config["profiles"].items():
            self.assertIsNone(profile["compiled"]["signal"].search(generic), module)
            self.assertTrue(profile["compiled"]["signal"].search(ALL_SIGNALS), module)
            if profile["compiled"]["require"] is not None:
                self.assertTrue(profile["compiled"]["require"].search(ALL_SIGNALS), module)

    def test_limma_array_signal_needs_microarray_context(self):
        profile = discovery.load_profiles()["profiles"]["limma-array"]
        self.assertIsNone(profile["compiled"]["require"].search("RNA-seq counts were analysed with limma."))
        self.assertTrue(profile["compiled"]["require"].search("Affymetrix GeneChip data were analysed with limma."))

    def test_query_has_gate_filters_and_journal_clause(self):
        config, journals = discovery.load_profiles(), discovery.load_journals()
        query = discovery.build_query(config["profiles"]["deseq2-wald"], config, journals, today=dt.date(2026, 9, 20))
        self.assertIn('METHODS:"DESeq2"', query)
        for part in ("HAS_FT:Y", "OPEN_ACCESS:Y", "SRC:MED", 'NOT PUB_TYPE:"review"', 'NOT PUB_TYPE:"preprint"',
                     'NOT PUB_TYPE:"retracted publication"', "FIRST_PDATE:[2020-01-01 TO 2026-09-20]", 'ISSN:"1474-760X"'):
            self.assertIn(part, query)
        self.assertNotIn('ISSN:"0277-6715"', query)  # a medstat (statistics) journal is not on the omics whitelist
        with scratch_directory() as tmp:
            meta_config = discovery.load_profiles(profiles_with_meta(tmp))
        meta = discovery.build_query(meta_config["profiles"]["fixture-meta"], meta_config, journals, today=dt.date(2026, 9, 20))
        self.assertIn('METHODS:"random-effects meta-analysis"', meta)


class MetadataGateTests(unittest.TestCase):
    def setUp(self):
        self.journals = discovery.load_journals()
        self.config = discovery.load_profiles()
        self.wald = self.config["profiles"]["deseq2-wald"]
        self.today = dt.date(2026, 9, 20)
        with scratch_directory() as tmp:
            self.meta = discovery.load_profiles(profiles_with_meta(tmp))["profiles"]["fixture-meta"]

    def verdict(self, item, profile=None):
        return discovery.screen_metadata(item, profile or self.wald, self.journals, today=self.today)[0]

    def test_whitelist_gate(self):
        self.assertEqual(self.verdict(result(1, journal=OFF_LIST)), "off_whitelist")
        self.assertEqual(self.verdict(result(1)), "pass")
        lite = {"source": "MED", "pmid": "7", "title": "t", "journalIssn": "1476-4687; 0028-0836; ", "pubYear": "2024"}
        verdict, info = discovery.screen_metadata(lite, self.wald, self.journals, today=self.today)
        self.assertEqual((verdict, info["journal_tier"]), ("pass", "A"))
        nejm = {"source": "MED", "pmid": "8", "title": "t", "journalIssn": "0028-4793; 1533-4406", "pubYear": "2024"}
        self.assertEqual(discovery.screen_metadata(nejm, self.wald, self.journals, today=self.today)[0], "off_whitelist")

    def test_year_interception(self):
        self.assertEqual(self.verdict(result(1, year="2027")), "year_out_of_range")
        self.assertEqual(self.verdict(result(1, year="2028")), "year_out_of_range")
        self.assertEqual(self.verdict(result(1, year="2017")), "year_out_of_range")
        self.assertEqual(self.verdict(result(1, year="2026", first_date="2027-01-02")), "year_out_of_range")
        self.assertEqual(self.verdict(result(1, year="2018")), "pass")

    def test_retracted_preprint_and_review_types(self):
        self.assertEqual(self.verdict(result(1, pubtypes=("Journal Article", "Retracted Publication"))), "retracted")
        self.assertEqual(self.verdict(result(1, title="RETRACTED: an old paper")), "retracted")
        self.assertEqual(self.verdict(result(1, pubtypes=("Preprint",))), "pubtype_excluded")
        self.assertEqual(self.verdict(result(1, pubtypes=("Review",))), "pubtype_excluded")
        self.assertEqual(self.verdict(result(1, pubtypes=("Review",)), self.meta), "pubtype_excluded")
        self.assertEqual(self.verdict(result(1, pubtypes=("Review", "Systematic Review", "Network Meta-Analysis")), self.meta), "pass")

    def test_exclude_regex_on_title_and_abstract(self):
        self.assertEqual(self.verdict(result(1, title="Study protocol for a multi-omics cohort")), "excluded_by_regex")
        self.assertEqual(self.verdict(result(1, abstract="We profiled 20,000 cells by single-cell RNA sequencing.")), "excluded_by_regex")
        seurat = self.config["profiles"]["seurat-qc"]
        self.assertEqual(self.verdict(result(1, abstract="We profiled 20,000 cells by single-cell RNA sequencing."), seurat), "pass")
        self.assertEqual(self.verdict(result(1, title="A narrative review of pathway methods"), self.meta), "excluded_by_regex")


class FulltextGateTests(unittest.TestCase):
    def screen(self, raw, module="deseq2-wald"):
        import xml.etree.ElementTree as ET
        profile = discovery.load_profiles()["profiles"][module]
        return discovery.screen_article(ET.fromstring(raw), profile)

    def test_introduction_or_results_mentions_are_not_methods_signal(self):
        raw = jats("PMC1", methods="Reads were aligned with STAR and counted with featureCounts.",
                   intro="DESeq2 differential expression has been used before.", results="DESeq2 Wald tests found 200 genes.")
        self.assertEqual(self.screen(raw)[0], "off_topic")

    def test_nested_statistical_analysis_hit_has_locator_and_short_snippet(self):
        long_methods = ("word " * 60) + "Differential expression between groups was tested with DESeq2 using the Wald test. " + ("tail " * 60)
        gate, detail = self.screen(jats("PMC1", methods=long_methods, nested=True))
        self.assertEqual(gate, "screened")
        signal = detail["signal"]
        self.assertEqual(signal["section_path"], "Methods > Statistical analysis")
        self.assertEqual(signal["section_id"], "s2.1")
        self.assertLessEqual(len(signal["snippet"].split()), 25)
        self.assertIn("DESeq2", signal["snippet"])

    def test_negated_method_mention_is_not_a_signal(self):
        negated = jats("PMC1", methods="Differential expression was assessed by t-tests; DESeq2 was not applied because counts were unavailable.")
        self.assertEqual(self.screen(negated)[0], "off_topic")
        later = jats("PMC1", methods="DESeq2 was not applied to the pilot. The main differential expression analysis used DESeq2 with the Wald test.")
        gate, detail = self.screen(later)
        self.assertEqual(gate, "screened")
        self.assertIn("used DESeq2", detail["signal"]["snippet"])

    def test_require_regex_must_also_hit(self):
        only_signal = jats("PMC1", methods="Quasi-likelihood F-tests were applied to the counts.")
        self.assertEqual(self.screen(only_signal, "edger-qlf")[0], "off_topic")
        both = jats("PMC1", methods="edgeR quasi-likelihood F-tests were applied to the counts.")
        self.assertEqual(self.screen(both, "edger-qlf")[0], "screened")

    def test_rights_and_missing_methods(self):
        self.assertEqual(self.screen(jats("PMC1", license_text="All rights reserved"))[0], "rights_unconfirmed")
        ali = jats("PMC1").replace(b"<license><license-p>Creative Commons Attribution</license-p></license>",
                                   b"<license><ali:license_ref xmlns:ali='http://www.niso.org/schemas/ali/1.0/'>https://creativecommons.org/licenses/by-nc-nd/4.0/</ali:license_ref><license-p>CC-BY-NC-ND License.</license-p></license>")
        self.assertIn(b"ali:license_ref", ali)
        # R1: an ND licence is never countable (was wrongly asserted 'screened' before remediation, F-01/F-15).
        self.assertEqual(self.screen(ali), ("rights_restricted", {"licence": "cc-by-nc-nd", "tdm_prohibited": False, "license_links": []}))
        raw = b"<article><front><article-meta><permissions>Creative Commons Attribution 4.0</permissions></article-meta></front><body><sec><title>Results</title><p>DESeq2 differential expression</p></sec></body></article>"
        self.assertEqual(self.screen(raw)[0], "no_method_section")

    def test_r1_licence_fixtures(self):
        from v2fixtures import RIGHTS
        expected = {"jama_nd_with_ali_url": "rights_restricted", "jama_nd_without_url": "rights_restricted",
                    "nejm_aam_nd": "rights_restricted", "jama_cc_by_text_only": "screened", "cc_by_nc_href": "screened",
                    "cc0_href": "screened", "cc_by_url_but_tdm_prohibited": "rights_restricted"}
        for name, gate in expected.items():
            got, detail = self.screen(jats("PMC1", permissions=RIGHTS[name]))
            self.assertEqual(got, gate, name)
            if got == "screened":
                self.assertIn(detail["licence"], discovery.COUNTABLE_LICENCES, name)
        got, _ = self.screen(jats("PMC1", permissions=RIGHTS["all_rights_reserved_tdm_prohibited"]))
        self.assertNotEqual(got, "screened")
        self.assertEqual(discovery.classify_rights("under the CC BY-NC-SA 3.0 IGO licence", []), {"licence": "cc-by-nc-sa", "tdm_prohibited": False})
        self.assertEqual(self.screen(jats("PMC1", license_text="CC BY-NC-SA 3.0 IGO"))[0], "rights_restricted")
        # the bare phrase 'text mining' no longer grants anything
        self.assertEqual(self.screen(jats("PMC1", license_text="Available for text mining."))[0], "rights_unconfirmed")


class HarvestGateTests(unittest.TestCase):
    def setUp(self):
        self.scratch = scratch_directory()
        self.dir = Path(self.scratch.__enter__())
        self.store = HarvestStore(self.dir / "harvest.sqlite")

    def tearDown(self):
        self.scratch.__exit__(None, None, None)

    def test_off_whitelist_is_counted_but_never_stored(self):
        fetcher = Fetcher(pages=lambda q, n: [result(10 + n, journal=OFF_LIST)])
        answer = harvest_daily(self.store, target=1, transport="direct", fetcher=fetcher, now=TODAY, max_requests=5)
        self.assertEqual(answer["daily_total"], 0)
        self.assertGreaterEqual(answer["gate_counts"]["off_whitelist"], 1)
        self.assertEqual(self.store.list_candidates(include_legacy=True)["total"], 0)
        self.assertEqual(fetcher.fulltext, [])

    def test_quota_counts_only_screened_and_shortfall_is_reported(self):
        bodies = {"PMC501": jats("PMC501", methods="Reads were counted with featureCounts only.")}
        pages = lambda q, n: [result(501), result(502, pmcid=False)]
        answer = harvest_daily(self.store, target=10, transport="direct", fetcher=Fetcher(pages=pages, bodies=bodies), now=TODAY, max_requests=6)
        self.assertEqual(answer["daily_total"], 0)
        self.assertEqual(answer["state"], "shortage")
        self.assertEqual(answer["shortfall"], 10)
        statuses = sorted(i["status"] for i in self.store.list_candidates()["items"])
        self.assertEqual(statuses, ["metadata_only"])  # off_topic PMC501 kept as identifiers only
        self.assertTrue(self.store.has_identity({"pmid:501"}, "deseq2-wald"))
        status = self.store.status()
        self.assertEqual(status["quota_basis"], "screened_only")
        con = sqlite3.connect(self.dir / "harvest.sqlite")
        run = con.execute("SELECT detail_json FROM daily_runs WHERE day=?", (DAY,)).fetchone()
        con.close()
        self.assertEqual(json.loads(run[0])["shortfall"], 10)
        self.assertGreaterEqual(self.store.gate_counts(DAY)["off_topic"], 1)

    def test_screened_counts_and_off_topic_is_not_refetched(self):
        fetcher = Fetcher(pages=UniqueStream(size=3))
        answer = harvest_daily(self.store, target=3, transport="direct", fetcher=fetcher, now=TODAY)
        self.assertEqual(answer["daily_total"], 3)
        item = self.store.get_candidate(self.store.list_candidates()["items"][0]["candidate_id"])
        self.assertEqual(item["status"], "screened")
        self.assertEqual(item["review_state"], "unreviewed_machine_screened")
        self.assertIn(item["journal_tier"], ("A", "B"))
        # off-topic paper remembered by identifier: never fetched again *for the same module*
        # (F-04: off_topic memory is module-scoped; budget 2 = one search + one fetch keeps day 1 on deseq2-wald only,
        # and day 2 starts again at deseq2-wald because nothing advanced the map cursor)
        off = Fetcher(pages=lambda q, n: [result(777)], bodies={"PMC777": jats("PMC777", methods="Reads were counted with featureCounts only.")})
        store2 = HarvestStore(self.dir / "h2.sqlite")
        harvest_daily(store2, target=1, transport="direct", fetcher=off, now=TODAY, max_requests=2)
        harvest_daily(store2, target=1, transport="direct", fetcher=off, now=TODAY + dt.timedelta(days=1), max_requests=2)
        self.assertEqual(off.fulltext.count("PMC777"), 1)
        self.assertTrue(store2.has_identity({"pmid:777"}, "deseq2-wald"))
        self.assertFalse(store2.has_identity({"pmid:777"}, "deseq2-qc"))

    def test_candidate_never_stores_article_body(self):
        marker = "UNIQUEBODYSENTINEL"
        methods = marker + " " + ("filler " * 40) + "differential expression was tested with DESeq2 Wald tests. " + ("more " * 40) + marker
        fetcher = Fetcher(pages=lambda q, n: [result(900)], bodies={"PMC900": jats("PMC900", methods=methods)})
        harvest_daily(self.store, target=1, transport="direct", fetcher=fetcher, now=TODAY)
        raw = (self.dir / "harvest.sqlite").read_bytes()
        self.assertNotIn(marker.encode(), raw)


class RemediationGateTests(unittest.TestCase):
    """Audit remediation: R1 licences in harvest (F-01), module-scoped memory (F-03/F-04), MICE (F-05), pre-R2 guard (F-02b)."""
    def setUp(self):
        self.scratch = scratch_directory()
        self.dir = Path(self.scratch.__enter__())
        self.store = HarvestStore(self.dir / "harvest.sqlite")
        self.config, self.journals = discovery.load_profiles(), discovery.load_journals()
        self.today = dt.date(2026, 9, 20)

    def tearDown(self):
        self.scratch.__exit__(None, None, None)

    def consume(self, items, module, fetcher):
        from harvest import _Run, _consume_results
        run = _Run(self.store, DAY, transport="direct", max_requests=20, fetcher=fetcher)
        out = _consume_results(run, items, self.config["profiles"][module], self.journals, set(), self.today,
                               quota=10, max_fulltext=3, map_hash=None, next_module=None)
        return out, run.gates

    def test_nd_article_is_metadata_only_and_not_counted(self):
        from v2fixtures import RIGHTS
        fetcher = Fetcher(pages=lambda q, n: [result(610)], bodies={"PMC610": jats("PMC610", permissions=RIGHTS["jama_nd_with_ali_url"])})
        answer = harvest_daily(self.store, target=1, transport="direct", fetcher=fetcher, now=TODAY, max_requests=4)
        self.assertGreaterEqual(answer["gate_counts"]["rights_restricted"], 1)
        self.assertEqual(self.store.day_count(DAY), 0)
        item = self.store.get_candidate(self.store.list_candidates()["items"][0]["candidate_id"])
        self.assertEqual((item["status"], item["rights"], item["licence"]), ("metadata_only", "tdm_restricted", "cc-by-nc-nd"))

    def test_screened_records_only_carry_countable_licences(self):
        harvest_daily(self.store, target=3, transport="direct", fetcher=Fetcher(pages=UniqueStream(size=2)), now=TODAY)
        con = self.store._connection()
        try:
            rows = [json.loads(r[0]) for r in con.execute("SELECT record_json FROM candidates WHERE status='screened'")]
        finally:
            con.close()
        self.assertEqual(len(rows), 3)
        self.assertTrue(all(r["licence"] in discovery.COUNTABLE_LICENCES for r in rows))

    def test_meta_analysis_rejected_by_wald_is_later_screened_by_a_meta_profile(self):
        meta = result(620, pubtypes=("Journal Article", "Meta-Analysis", "Systematic Review"))
        fetcher = Fetcher(bodies={"PMC620": jats("PMC620", methods="A random-effects meta-analysis pooled the studies.")})
        _, gates = self.consume([meta], "deseq2-wald", fetcher)
        self.assertEqual(gates, {"pubtype_excluded": 1})
        self.config = discovery.load_profiles(profiles_with_meta(self.dir))
        out, _ = self.consume([meta], "fixture-meta", fetcher)
        self.assertEqual(len(out["screened"]), 1)

    def test_off_topic_in_module_a_can_be_screened_in_module_b(self):
        body = jats("PMC630", methods="The variance stabilizing transformation was followed by principal component analysis of the DESeq2 object.")
        fetcher = Fetcher(bodies={"PMC630": body})
        _, gates = self.consume([result(630)], "deseq2-lrt", fetcher)
        self.assertEqual(gates, {"off_topic": 1})
        again, gates = self.consume([result(630)], "deseq2-lrt", fetcher)
        self.assertEqual(gates, {"duplicate": 1})  # same module: not re-fetched
        out, _ = self.consume([result(630)], "deseq2-qc", fetcher)
        self.assertEqual(len(out["screened"]), 1)

    def test_paper_level_rejection_applies_to_every_module(self):
        retracted = result(640, pubtypes=("Journal Article", "Retracted Publication"))
        _, gates = self.consume([retracted], "deseq2-wald", Fetcher())
        self.assertEqual(gates, {"retracted": 1})
        fetcher = Fetcher()
        _, gates = self.consume([retracted], "deseq2-qc", fetcher)
        self.assertEqual(gates, {"duplicate": 1})
        self.assertEqual(fetcher.fulltext, [])

    def test_request_exclusion_is_not_remembered(self):
        import literature_requests as lr
        lr.submit(self.store, {"module": "deseq2-wald", "question": "Shrinkage estimator for two-group DESeq2", "requester": "t",
                               "study_context": {"design": "two_group", "data_structure": "bulk_counts", "outcome_type": "gene_level_differential_expression"},
                               "required_conditions": ["bulk RNA-seq"], "exclusions": ["pilot feasibility"]}, now=TODAY)
        excluded = result(650, title="A pilot feasibility RNA-seq study with DESeq2")
        answer = harvest_daily(self.store, target=1, transport="direct", fetcher=Fetcher(pages=lambda q, n: [excluded]), now=TODAY, max_requests=6)
        self.assertEqual(answer["gate_counts"]["excluded_by_request"], 1)
        self.assertEqual(answer["daily_total"], 1)  # rotation screened the same paper afterwards
        con = self.store._connection()
        try:
            self.assertEqual(con.execute("SELECT count(*) FROM screened_out WHERE outcome='excluded_by_request'").fetchone()[0], 0)
        finally:
            con.close()

    def test_study_protocols_are_excluded_by_every_profile(self):
        for module, profile in self.config["profiles"].items():
            got = discovery.screen_metadata(result(1, title="Study protocol for a multi-omics cohort"), profile, self.journals, today=self.today)[0]
            self.assertEqual(got, "excluded_by_regex", module)

    def test_pre_r2_v2_schema_is_refused(self):
        from harvest import HarvestError
        for ddl in ("CREATE TABLE literature_requests (request_id TEXT PRIMARY KEY, fingerprint TEXT NOT NULL UNIQUE, module TEXT NOT NULL)",
                    "CREATE TABLE screened_out (alias TEXT PRIMARY KEY, outcome TEXT NOT NULL, module TEXT NOT NULL, day TEXT NOT NULL, recorded_at TEXT NOT NULL)"):
            path = self.dir / ("old-%d.sqlite" % len(ddl))
            con = sqlite3.connect(path)
            con.execute(ddl)
            con.commit()
            con.close()
            with self.assertRaises(HarvestError) as refused:
                HarvestStore(path)
            self.assertEqual(refused.exception.code, "schema_predates_r2")


V1_DDL = """
CREATE TABLE candidates (candidate_id TEXT PRIMARY KEY, title TEXT NOT NULL, module TEXT NOT NULL,
  status TEXT NOT NULL, flags_json TEXT NOT NULL, provenance_json TEXT NOT NULL, record_json TEXT NOT NULL, created_at TEXT NOT NULL);
CREATE TABLE identity_aliases (alias TEXT PRIMARY KEY, candidate_id TEXT NOT NULL REFERENCES candidates(candidate_id));
CREATE TABLE daily_ledger (day TEXT NOT NULL, candidate_id TEXT NOT NULL REFERENCES candidates(candidate_id), counted_at TEXT NOT NULL, PRIMARY KEY(day, candidate_id));
"""


class LegacyMigrationTests(unittest.TestCase):
    def setUp(self):
        self.scratch = scratch_directory()
        self.dir = Path(self.scratch.__enter__())
        con = sqlite3.connect(self.dir / "harvest.sqlite")
        con.executescript(V1_DDL)
        for i, status in enumerate(["candidate_review_required", "metadata_only", "rejected"]):
            cid = f"H-legacy{i}"
            rec = {"title": f"Old {i}", "module": "deseq2-wald", "status": status, "pmid": str(4000 + i)}
            con.execute("INSERT INTO candidates VALUES(?,?,?,?,?,?,?,?)", (cid, rec["title"], "deseq2-wald", status, "[]", "{}", json.dumps(rec), "2026-09-21T00:00:00+00:00"))
            con.execute("INSERT INTO identity_aliases VALUES(?,?)", (f"pmid:{4000 + i}", cid))
            if status != "rejected":
                con.execute("INSERT INTO daily_ledger VALUES(?,?,?)", (DAY, cid, "2026-09-21T00:00:00+00:00"))
        con.commit()
        self.ledger_before = con.execute("SELECT * FROM daily_ledger ORDER BY day, candidate_id").fetchall()
        con.close()

    def tearDown(self):
        self.scratch.__exit__(None, None, None)

    def test_v1_rows_are_kept_marked_hidden_and_uncounted(self):
        store = HarvestStore(self.dir / "harvest.sqlite")
        con = sqlite3.connect(self.dir / "harvest.sqlite")
        rows = con.execute("SELECT status, legacy_flag FROM candidates ORDER BY candidate_id").fetchall()
        self.assertEqual(rows, [("candidate_review_required", LEGACY_FLAG), ("metadata_only", LEGACY_FLAG), ("rejected", LEGACY_FLAG)])
        self.assertEqual(con.execute("SELECT * FROM daily_ledger ORDER BY day, candidate_id").fetchall(), self.ledger_before)
        con.close()
        self.assertEqual(store.day_count(DAY), 0)  # legacy ledger rows never count toward v2 quota
        self.assertEqual(store.list_candidates()["total"], 0)
        self.assertEqual(store.list_candidates(include_legacy=True)["total"], 3)
        self.assertIn(LEGACY_FLAG, store.get_candidate("H-legacy0")["flags"])
        self.assertEqual(store.search_screened([], None, 10, 0)["total"], 0)
        backups = list((self.dir / "backups").glob("omicstat-reference-data-*-pre-v2-migration-*.tar"))
        self.assertEqual(len(backups), 1)
        with tarfile.open(backups[0]) as tar:
            self.assertIn("data/harvest.sqlite", tar.getnames())
        # idempotent: reopening neither re-marks nor re-backs-up
        HarvestStore(self.dir / "harvest.sqlite")
        self.assertEqual(len(list((self.dir / "backups").glob("*.tar"))), 1)
        self.assertEqual(store.migration_status()[0]["detail"]["legacy_marked"], 3)

    def test_new_rows_after_migration_are_not_legacy(self):
        store = HarvestStore(self.dir / "harvest.sqlite")
        stored, cid = store.add_candidate({"title": "New", "module": "deseq2-wald", "status": "screened", "pmid": "5555", "flags": [], "provenance": {}}, day=DAY, quota=10)
        self.assertTrue(stored)
        self.assertIsNone(store.get_candidate(cid).get("legacy_flag"))
        self.assertEqual(store.day_count(DAY), 1)


if __name__ == "__main__":
    unittest.main()
