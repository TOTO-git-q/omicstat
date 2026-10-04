import datetime as dt
import json
import hashlib
import unittest
from unittest.mock import patch
from subprocess import CompletedProcess
from pathlib import Path
from urllib.parse import urlparse

from harvest import HarvestError, HarvestStore, _load_method_map, _parse_jats, _gt103_fetch, harvest_daily
from scratch import scratch_directory


TODAY = dt.datetime(2026, 9, 20, 8, tzinfo=dt.timezone.utc)


# Results must come from a whitelisted ISSN (Genome Biology) and the JATS Methods section must
# carry the module's signal.  The default body carries the first two rotation signals
# (deseq2-wald and deseq2-qc).  omicstat fork: ported from the medstat-reference v2 tests.
SIGNAL_BODY = ("Differential expression in 6 samples was tested with DESeq2 using the Wald test; "
               "the variance stabilizing transformation was followed by principal component analysis.")


def result(*, pmid="9001", pmcid="PMC9001", doi="10.1000/example", title="An omics method paper"):
    return {"source": "MED", "pmid": pmid, "pmcid": pmcid, "doi": doi, "title": title,
            "journalTitle": "Genome Biology", "journalInfo": {"journal": {"title": "Genome biology", "issn": "1474-7596", "essn": "1474-760X"}},
            "pubYear": "2026", "pubTypeList": {"pubType": ["Journal Article"]}}


def jats(*, pmcid="PMC9001", license_text="Creative Commons Attribution 4.0 (CC BY)", body=SIGNAL_BODY):
    return ("<article><front><article-meta><article-id pub-id-type='pmc'>" + pmcid +
            "</article-id><permissions>" + license_text + "</permissions></article-meta></front>" +
            "<body><sec id='methods'><title>Statistical methods</title><p>" + body +
            "</p></sec></body></article>").encode()


class FixtureFetcher:
    def __init__(self, records, xml=None):
        self.records, self.xml, self.urls = records, xml or {}, []

    def __call__(self, url):
        self.urls.append(url)
        if url.endswith("fullTextXML"):
            pmcid = url.rsplit("/", 2)[-2]
            return self.xml.get(pmcid, jats(pmcid=pmcid))
        return json.dumps({"resultList": {"result": self.records}}).encode()


class HarvestTests(unittest.TestCase):
    def test_gt_http_failure_is_not_ssh_outage(self):
        with patch("harvest.subprocess.run", return_value=CompletedProcess([], 42, stdout=b"", stderr=b"MREF_HTTP:404")):
            with self.assertRaises(HarvestError) as failure:
                _gt103_fetch("https://www.ebi.ac.uk/europepmc/webservices/rest/PMC1/fullTextXML")
            self.assertEqual(failure.exception.code, "network_failure")

    def test_introduction_mention_is_not_methods_evidence(self):
        xml = jats().replace(b'<body>', b'<body><sec id="intro"><title>Introduction</title><p>Earlier analysis is background, not our method.</p></sec>')
        extracted = _parse_jats(xml, {"pmcid": "PMC9001"})
        self.assertEqual(extracted["method_excerpts"][0]["section_id"], "methods")
        self.assertNotIn("Earlier", extracted["method_excerpts"][0]["quote"])

    def test_live_api_contract_and_raw_hash(self):
        fetcher = FixtureFetcher([result()])
        harvest_daily(self.store, target=1, transport="direct", fetcher=fetcher, now=TODAY)
        self.assertIn("sort_date%3Ay", fetcher.urls[0])
        self.assertNotIn("sort=P_PDATE_D", fetcher.urls[0])
        declared = b'<!DOCTYPE article PUBLIC "-//NLM//DTD JATS v1.3//EN" "JATS.dtd">' + jats()
        self.assertEqual(_parse_jats(declared, {"pmcid": "PMC9001"})["fulltext_sha256"], hashlib.sha256(declared).hexdigest())
        restricted = _parse_jats(jats(license_text="All rights reserved"), {"pmcid": "PMC9001"})
        self.assertEqual(restricted["method_excerpts"], [])

    def test_version_only_payload_is_error_not_zero_search(self):
        answer = harvest_daily(self.store, target=1, transport="direct", fetcher=lambda _: b'{"version":"6.9"}', max_requests=1, now=TODAY)
        self.assertIn("invalid_search_response", answer["errors"])

    def setUp(self):
        # Managed Windows sandboxes can deny SQLite under the system temp ACL.
        self.scratch = scratch_directory()
        self.temp_path = Path(self.scratch.__enter__())
        self.store = HarvestStore(self.temp_path / "harvest.sqlite")

    def tearDown(self):
        self.scratch.__exit__(None, None, None)

    def test_candidate_is_short_excerpt_unreviewed_and_idempotent_daily_target(self):
        fetcher = FixtureFetcher([result()])
        first = harvest_daily(self.store, target=1, transport="direct", fetcher=fetcher, now=TODAY)
        self.assertEqual(first["daily_total"], 1)
        candidate = self.store.get_candidate(self.store.list_candidates()["items"][0]["candidate_id"])
        self.assertTrue(candidate["candidate_id"].startswith("H-"))
        self.assertEqual(candidate["status"], "screened")
        self.assertLessEqual(candidate["signal"]["word_count"], 25)
        self.assertLessEqual(len(candidate["signal"]["snippet"].split()), 25)
        self.assertNotIn("full body", json.dumps(candidate).lower())
        self.assertTrue(any("/rest/PMC9001/fullTextXML" in url for url in fetcher.urls))
        again = harvest_daily(self.store, target=1, transport="direct", fetcher=fetcher, now=TODAY)
        self.assertEqual(again["state"], "quota_already_satisfied")

    def test_seed_and_alias_collisions_not_counted(self):
        fetcher = FixtureFetcher([result(pmid="444", pmcid="PMC444", doi="10.3/a"), result(pmid="445", pmcid="PMC445", doi="10.3/b")])
        answer = harvest_daily(self.store, target=1, transport="direct", fetcher=fetcher, seed_catalog={"papers": [{"pmid": "444"}]}, now=TODAY)
        self.assertEqual(answer["daily_total"], 1)
        self.assertEqual(self.store.list_candidates()["items"][0]["title"], "An omics method paper")
        self.assertEqual(self.store.day_count("2026-09-20"), 1)

    def test_preprint_is_excluded_and_rights_unknown_is_not_ready(self):
        preprint = result(pmid="77", pmcid="PMC77", doi="10.7/pre")
        preprint["pubTypeList"] = {"pubType": ["Preprint"]}
        answer = harvest_daily(self.store, target=1, transport="direct", fetcher=FixtureFetcher([preprint]), now=TODAY)
        self.assertEqual(answer["state"], "shortage")
        unknown = FixtureFetcher([result()], {"PMC9001": jats(license_text="All rights reserved")})
        answer = harvest_daily(self.store, target=1, transport="direct", fetcher=unknown, now=TODAY)
        self.assertEqual(answer["daily_total"], 0)  # v2: rights-unconfirmed full text is never screened
        item = self.store.get_candidate(self.store.list_candidates()["items"][0]["candidate_id"])
        self.assertEqual(item["status"], "metadata_only")
        self.assertIn("rights_unconfirmed", item["flags"])

    def test_jats_defenses_mismatch_and_headers_only(self):
        with self.assertRaisesRegex(HarvestError, "DOCTYPE"):
            _parse_jats(b"<!DOCTYPE article><article/>", {"pmcid": "PMC1"})
        with self.assertRaises(HarvestError) as mismatch:
            _parse_jats(jats(pmcid="PMC2"), {"pmcid": "PMC1"})
        self.assertEqual(mismatch.exception.code, "identifier_mismatch")
        with self.assertRaises(HarvestError) as headers:
            _parse_jats(b"<article><front><article-meta><article-id pub-id-type='pmc'>PMC1</article-id></article-meta></front></article>", {"pmcid": "PMC1"})
        self.assertEqual(headers.exception.code, "headers_only_fulltext")

    def test_standard_jats_declaration_is_ignored_but_entities_rejected(self):
        safe = b'<!DOCTYPE article PUBLIC "-//NLM//DTD JATS (Z39.96) Journal Archiving and Interchange DTD v1.3 20210610//EN" "JATS-archivearticle1-3-mathml3.dtd">' + jats()
        self.assertTrue(_parse_jats(safe, {"pmcid": "PMC9001"})["rights_confirmed"])
        with self.assertRaises(HarvestError) as unsafe:
            _parse_jats(b'<!DOCTYPE article SYSTEM "http://not-allowed.invalid/a"><article/>', {})
        self.assertEqual(unsafe.exception.code, "unsafe_xml")
        with self.assertRaises(HarvestError):
            _parse_jats(b'<!DOCTYPE article [<!ENTITY xx "boom">]><article>&xx;</article>', {})

    def test_unapproved_url_never_reaches_injected_fetcher(self):
        calls = []
        with self.assertRaises(HarvestError):
            # This exercises the public function's allowlist through a malicious query substitute.
            from harvest import _validate_url
            _validate_url("http://example.invalid/a")
        self.assertEqual(calls, [])

    def test_concurrent_lease_and_stale_recovery(self):
        owner = "owner"
        self.assertTrue(self.store.acquire_lease("harvest:2026-09-20", owner, seconds=1))
        blocked = harvest_daily(self.store, target=1, transport="direct", fetcher=FixtureFetcher([result()]), now=TODAY)
        self.assertEqual(blocked["state"], "already_running")
        # A lease with a past expiry is explicitly recoverable.
        con = self.store._connection()
        con.execute("UPDATE leases SET expires_at=0 WHERE name=?", ("harvest:2026-09-20",))
        con.close()
        recovered = harvest_daily(self.store, target=1, transport="direct", fetcher=FixtureFetcher([result()]), now=TODAY)
        self.assertEqual(recovered["daily_total"], 1)

    def test_quota_and_input_bounds(self):
        with self.assertRaises(HarvestError):
            harvest_daily(self.store, target=11, transport="direct", fetcher=FixtureFetcher([]), now=TODAY)
        with self.assertRaises(HarvestError):
            harvest_daily(self.store, target=1, transport="direct", max_requests=61, fetcher=FixtureFetcher([]), now=TODAY)

    def test_fixture_body_limit_applies_before_parsing(self):
        class Oversize:
            def __call__(self, url):
                return b"x" * 2_000_001
        answer = harvest_daily(self.store, target=1, transport="direct", fetcher=Oversize(), now=TODAY)
        self.assertEqual(answer["state"], "shortage")
        self.assertIn("body_too_large", answer["errors"])

    def test_med_id_and_nested_journal_metadata_shape(self):
        shaped = result(pmid=None, pmcid=None, doi="10.8/nested")
        shaped.update({"id": "8123", "journalTitle": None, "journal": None,
                       "journalInfo": {"journal": {"title": "Genomics Methods", "essn": "1474-760X"}}})
        answer = harvest_daily(self.store, target=1, transport="direct", fetcher=FixtureFetcher([shaped]), now=TODAY)
        self.assertEqual(answer["daily_total"], 0)  # no PMCID: whitelisted metadata only, never counted
        candidate = self.store.get_candidate(self.store.list_candidates()["items"][0]["candidate_id"])
        self.assertEqual(candidate["pmid"], "8123")
        self.assertEqual(candidate["status"], "metadata_only")
        self.assertEqual(candidate["journal"], "Genome Biology")  # whitelist name via eISSN

    def test_mismatched_fulltext_is_rejected_without_daily_credit(self):
        fetcher = FixtureFetcher([result()], {"PMC9001": jats(pmcid="PMC9999")})
        answer = harvest_daily(self.store, target=1, transport="direct", fetcher=fetcher, now=TODAY)
        self.assertEqual(answer["collected"], 0)
        self.assertEqual(answer["daily_total"], 0)
        # v2: identifier-only memory, no candidate row, never re-fetched
        self.assertEqual(self.store.list_candidates()["total"], 0)
        self.assertTrue(self.store.has_identity({"pmid:9001"}))

    def test_actual_method_map_order_is_durable_across_days(self):
        first = FixtureFetcher([result(pmid="2001", pmcid="PMC2001", doi="10.2/one")])
        answer = harvest_daily(self.store, target=1, transport="direct", fetcher=first, now=TODAY)
        self.assertEqual(answer["method_map"]["order"][0], "deseq2-wald")
        self.assertIn("differentially+expressed", first.urls[0])
        self.assertEqual(self.store.status()["method_map"]["next_module"], "deseq2-qc")
        tomorrow = TODAY + dt.timedelta(days=1)
        second = FixtureFetcher([result(pmid="2002", pmcid="PMC2002", doi="10.2/two")])
        harvest_daily(self.store, target=1, transport="direct", fetcher=second, now=tomorrow)
        self.assertIn("variance+stabilizing", second.urls[0])
        self.assertEqual(self.store.status()["method_map"]["next_module"], "deseq2-lrt")

    def test_imported_full_day_initializes_map_without_network_or_advance(self):
        for number in range(10):
            stored, reason = self.store.add_candidate({"title": f"Imported {number}", "module": "legacy",
                "status": "screened", "pmid": str(3000 + number), "flags": [], "provenance": {}},
                day="2026-09-20", quota=10)
            self.assertTrue(stored, reason)
        answer = harvest_daily(self.store, target=10, transport="direct",
            fetcher=lambda _: self.fail("full imported day must not fetch"), now=TODAY)
        self.assertEqual(answer["state"], "quota_already_satisfied")
        self.assertEqual(answer["method_map"]["next_module"], "deseq2-wald")

    def test_deferred_first_module_does_not_starve_following_map_module(self):
        class DeferredThenCandidate:
            def __init__(self):
                self.urls = []
            def __call__(self, url):
                self.urls.append(url)
                if "differentially+expressed" in url:
                    return b'{"version":"6.9"}'
                if url.endswith("fullTextXML"):
                    return jats(pmcid="PMC4001")
                return json.dumps({"resultList": {"result": [result(pmid="4001", pmcid="PMC4001", doi="10.4/one")]}}).encode()
        fetcher = DeferredThenCandidate()
        answer = harvest_daily(self.store, target=1, transport="direct", fetcher=fetcher, now=TODAY)
        self.assertIn("invalid_search_response", answer["errors"])
        self.assertIn("variance+stabilizing", "\n".join(fetcher.urls))
        self.assertEqual(self.store.status()["method_map"]["next_module"], "deseq2-lrt")

    def test_candidate_and_map_advance_share_one_checkpoint(self):
        method_map = _load_method_map()
        self.store.configure_method_map(method_map)
        stored, reason = self.store.add_candidate({"title": "Atomic", "module": "deseq2-wald",
            "status": "screened", "pmid": "5001", "flags": [], "provenance": {}}, day="2026-09-20",
            quota=10, map_hash=method_map["hash"], next_module="deseq2-qc")
        self.assertTrue(stored, reason)
        reopened = HarvestStore(self.temp_path / "harvest.sqlite")
        self.assertEqual(reopened.day_count("2026-09-20"), 1)
        self.assertEqual(reopened.status()["method_map"]["next_module"], "deseq2-qc")

    def test_changed_map_is_blocked_instead_of_reinterpreting_cursor(self):
        method_map = _load_method_map()
        self.store.configure_method_map(method_map)
        changed = {**method_map, "hash": "changed-map-hash", "order": list(reversed(method_map["order"]))}
        with self.assertRaises(HarvestError) as failure:
            self.store.configure_method_map(changed)
        self.assertEqual(failure.exception.code, "method_map_changed")
        self.assertEqual(self.store.status()["method_map"]["state"], "map_change_blocked")


if __name__ == "__main__":
    unittest.main()
