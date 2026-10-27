"""Coverage probe: budget, spacing, query shape and resumability (network mocked)."""
import datetime as dt
import json
import re
import unittest
from pathlib import Path
from urllib.parse import parse_qs, urlparse

import lexicon
import probe
import worker
from harvest import HarvestError, HarvestStore
from scratch import scratch_directory

OCT = dt.datetime(2026, 10, 10, 6, tzinfo=dt.timezone.utc)
NOV = dt.datetime(2026, 11, 5, 6, tzinfo=dt.timezone.utc)


class FakeEpmc:
    def __init__(self, fail_terms=()):
        self.urls, self.fail_terms = [], tuple(fail_terms)

    def __call__(self, url):
        self.urls.append(url)
        query = parse_qs(urlparse(url).query)["query"][0]
        if any(t in query for t in self.fail_terms):
            raise HarvestError("network_failure", "mock outage")
        return json.dumps({"hitCount": (len(query) * 7) % 991 + 1, "resultList": {"result": []}}).encode()


class ProbeTests(unittest.TestCase):
    def setUp(self):
        self.scratch = scratch_directory()
        self.dir = Path(self.scratch.__enter__())
        self.store = HarvestStore(self.dir / "harvest.sqlite")
        self.sleeps = []

    def tearDown(self):
        self.scratch.__exit__(None, None, None)

    def run_probe(self, fetcher, now=OCT, **kw):
        return probe.run_probe(self.store, now=now, fetcher=fetcher, sleep=self.sleeps.append, **kw)

    def rows(self, sql):
        import sqlite3
        with sqlite3.connect(self.dir / "harvest.sqlite") as db:
            return db.execute(sql).fetchall()

    def test_windows_are_stable_within_a_month(self):
        self.assertEqual(probe.windows(OCT.date())[-1], (2026, "2026-01-01", "2026-09-30"))
        self.assertEqual(probe.windows(dt.date(2026, 10, 31))[-1], (2026, "2026-01-01", "2026-09-30"))
        self.assertEqual(probe.windows(dt.date(2027, 1, 12))[-1], (2026, "2026-01-01", "2026-12-31"))
        self.assertEqual(probe.windows(OCT.date())[0], (2020, "2020-01-01", "2020-12-31"))

    def test_dry_run_sends_nothing_and_fits_the_first_month(self):
        fetch = FakeEpmc()
        plan = self.run_probe(fetch, dry_run=True)
        self.assertEqual(plan["state"], "dry_run")
        self.assertEqual(fetch.urls, [])
        eligible = [e for e in lexicon.default_lexicon()["entries"] if e["rank_eligible"]]
        by = plan["by_priority"]
        self.assertEqual(by[0], 8)                            # whitelist totals: 2020..2025, 2026 year to date, and the S0 baseline date
        self.assertEqual(by[1], 2 * len(eligible))            # each rank-eligible term: last full year + year to date
        self.assertEqual(by[2], 21)                           # the three display modules have no S0 baseline: 3 x 7 windows
        self.assertLessEqual(by[0] + by[1] + by[2], probe.BUDGET_PER_MONTH)   # the first pass fits the monthly budget
        self.assertEqual(self.rows("SELECT count(*) FROM method_probe WHERE source LIKE 's0_search_log%'"), [(266,)])  # baseline import costs no request

    def test_first_month_budget_query_shape_and_spacing(self):
        fetch = FakeEpmc()
        summary = probe.run_to_completion(self.store, now=OCT, fetcher=fetch, sleep=self.sleeps.append)
        self.assertLessEqual(len(fetch.urls), 400)
        self.assertEqual(summary["state"], "budget_exhausted")
        self.assertEqual(summary["budget_used"], len(fetch.urls))
        self.assertEqual(self.store.probe_requests("2026-10"), len(fetch.urls))
        for url in fetch.urls:
            parsed = urlparse(url)
            self.assertEqual(parsed.hostname, "www.ebi.ac.uk")
            self.assertNotIn("fullTextXML", url)
            args = parse_qs(parsed.query)
            self.assertEqual((args["pageSize"], args["resultType"], args["format"]), (["1"], ["lite"], ["json"]))
            query = args["query"][0]
            for needle in ("HAS_FT:Y", "OPEN_ACCESS:Y", "SRC:MED", 'ISSN:"1474-7596"', "FIRST_PDATE:["):
                self.assertIn(needle, query)
            self.assertNotIn("{today}", query)
            self.assertEqual(len(re.findall(r"FIRST_PDATE:\[", query)), 1)
        queries = [parse_qs(urlparse(u).query)["query"][0] for u in fetch.urls]
        self.assertEqual(len(queries), len(set(queries)))                     # no query is sent twice
        self.assertTrue(any('METHODS:"DESeq2"' in q and "FIRST_PDATE:[2025-01-01 TO 2025-12-31]" in q for q in queries))
        self.assertTrue(any('METHODS:"DESeq2"' in q and "FIRST_PDATE:[2026-01-01 TO 2026-09-30]" in q for q in queries))
        self.assertTrue(any("FIRST_PDATE:[2026-01-01 TO 2026-09-27]" in q and "METHODS:" not in q for q in queries))  # baseline-date total
        # ineligible entries (databases, upstream tools, visualisation) are never probed
        for banned in ('METHODS:"KEGG"', 'METHODS:"UMAP"', 'METHODS:"STAR"', 'METHODS:"ggplot2"'):
            self.assertFalse(any(banned in q for q in queries), banned)
        # >= 1 s between consecutive requests (the injected sleep records the requested waits)
        self.assertTrue(self.sleeps and all(0.5 <= s <= 1.0 for s in self.sleeps))
        # the S0 baseline came in without a request: 38 modules x 7 years
        self.assertEqual(self.rows("SELECT count(*) FROM method_probe WHERE source LIKE 's0_search_log%'"), [(266,)])

    def test_small_budget_is_never_exceeded_and_month_reset(self):
        fetch = FakeEpmc()
        summary = probe.run_to_completion(self.store, now=OCT, fetcher=fetch, sleep=self.sleeps.append, budget=50)
        self.assertEqual(len(fetch.urls), 50)
        self.assertEqual(summary["state"], "budget_exhausted")
        again = self.run_probe(fetch, budget=50)
        self.assertEqual((again["requests"], len(fetch.urls)), (0, 50))
        next_month = self.run_probe(fetch, now=NOV, budget=50)               # a new month has a new budget
        self.assertEqual(next_month["requests"], 50)

    def test_resumable_in_chunks_and_finished_month_is_a_noop(self):
        fetch = FakeEpmc()
        first = self.run_probe(fetch, max_requests=30)
        self.assertEqual((first["state"], first["requests"]), ("partial", 30))
        second = self.run_probe(fetch, max_requests=30)
        self.assertEqual(second["requests"], 30)
        self.assertEqual(len(fetch.urls), len(set(fetch.urls)))
        self.assertEqual(self.store.probe_requests("2026-10"), 60)
        done = self.rows("SELECT count(*) FROM method_probe WHERE source='probe'")[0][0]
        self.assertEqual(done, 60)

    def test_failures_are_counted_not_recorded_not_retried_at_once_and_redone_later(self):
        fetch = FakeEpmc(fail_terms=['METHODS:"DESeq2"'])
        summary = self.run_probe(fetch, max_requests=120)
        deseq = [u for u in fetch.urls if "DESeq2" in u]
        self.assertEqual(len(deseq), 2)                                         # one attempt per window, no immediate retry
        self.assertEqual(summary["failures"], 2)
        self.assertEqual(self.rows("SELECT count(*) FROM method_probe WHERE term='deseq2'"), [(0,)])
        self.assertEqual(self.store.probe_requests("2026-10"), summary["requests"])    # failed attempts spent budget
        healthy = self.run_probe(FakeEpmc(), max_requests=120)
        self.assertGreaterEqual(self.rows("SELECT count(*) FROM method_probe WHERE term='deseq2'")[0][0], 1)
        self.assertEqual(healthy["failures"], 0)

    def test_three_consecutive_failures_end_the_chunk(self):
        fetch = FakeEpmc(fail_terms=["HAS_FT"])
        summary = self.run_probe(fetch, max_requests=100)
        self.assertEqual((summary["failures"], summary["requests"]), (3, 3))

    def test_version_only_answer_is_not_zero(self):
        summary = self.run_probe(lambda url: b'{"version":"6.9"}', max_requests=10)
        self.assertEqual(self.rows("SELECT count(*) FROM method_probe WHERE source='probe'"), [(0,)])
        self.assertEqual(summary["failures"], 3)

    def test_next_month_probes_year_to_date_again_but_not_full_years(self):
        fetch = FakeEpmc()
        probe.run_to_completion(self.store, now=OCT, fetcher=fetch, sleep=self.sleeps.append, budget=400)
        before = set(fetch.urls)
        fetch2 = FakeEpmc()
        probe.run_probe(self.store, now=NOV, fetcher=fetch2, sleep=self.sleeps.append, max_requests=400)
        queries = [parse_qs(urlparse(u).query)["query"][0] for u in fetch2.urls]
        self.assertTrue(queries)
        self.assertTrue(all(q.count("FIRST_PDATE:") == 1 for q in queries))
        deseq = [q for q in queries if 'METHODS:"DESeq2"' in q]
        ytd = [q for q in deseq if "FIRST_PDATE:[2026-" in q]
        self.assertTrue(ytd and all("2026-01-01 TO 2026-10-31" in q for q in ytd))   # only the new year-to-date window
        self.assertFalse(any("FIRST_PDATE:[2025-" in q for q in deseq))               # the full year 2025 is not asked again
        self.assertFalse(set(fetch2.urls) & before)

    def test_worker_runs_probe_after_harvest_only_when_injected_or_real(self):
        calls = []
        harvest_stub = lambda store, **kw: {"day": "2026-10-10", "state": "completed"}
        probe_stub = lambda store, now=None: calls.append(now) or {"month": "2026-10", "state": "partial", "requests": 60, "budget_used": 60}
        summary = worker._attempt(self.store, OCT, harvest_stub, probe_stub)
        self.assertEqual(summary["probe"]["requests"], 60)
        self.assertNotIn("probe", worker._attempt(self.store, OCT, harvest_stub))   # no network surprise in other tests
        boom = lambda store, now=None: (_ for _ in ()).throw(RuntimeError("x"))
        self.assertEqual(worker._attempt(self.store, OCT, harvest_stub, boom)["probe"]["state"], "probe_error")


if __name__ == "__main__":
    unittest.main()
